import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:pm_monitor/core/constants/firestore_collections.dart';
import 'package:pm_monitor/core/services/technician_availability_service.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_model.dart';

/// Horas de trabajo separadas en regulares y extra.
class WorkHours {
  final double regular;
  final double overtime;

  const WorkHours({this.regular = 0.0, this.overtime = 0.0});

  static const zero = WorkHours();

  double get total => regular + overtime;

  WorkHours operator +(WorkHours other) => WorkHours(
        regular: regular + other.regular,
        overtime: overtime + other.overtime,
      );
}

/// Carga de una semana concreta (lunes a domingo) para un técnico.
class WeeklyWorkload {
  /// Lunes 00:00 de la semana.
  final DateTime weekStart;

  /// Horas ya asignadas al técnico en esa semana.
  final WorkHours current;

  /// Horas que se agregarían con la asignación propuesta.
  final WorkHours additional;

  /// Cantidad de mantenimientos nuevos en esta semana.
  final int newMaintenances;

  final double maxWeeklyHours;
  final double nearLimitRatio;

  const WeeklyWorkload({
    required this.weekStart,
    required this.current,
    required this.additional,
    required this.newMaintenances,
    required this.maxWeeklyHours,
    required this.nearLimitRatio,
  });

  double get newTotal => current.total + additional.total;
  int get isoWeek => WorkloadCalculator.isoWeekNumber(weekStart);
  DateTime get weekEnd => weekStart.add(const Duration(days: 6));
  DateTimeRange get range => DateTimeRange(start: weekStart, end: weekEnd);

  bool get exceedsLimit => newTotal > maxWeeklyHours;
  bool get isNearLimit =>
      !exceedsLimit && newTotal >= maxWeeklyHours * nearLimitRatio;
}

/// Resultado de validar una asignación de mantenimientos a un técnico.
class WorkloadCheckResult {
  final List<WeeklyWorkload> weeks;
  final double maxWeeklyHours;

  const WorkloadCheckResult({
    required this.weeks,
    required this.maxWeeklyHours,
  });

  /// `false` si alguna semana supera el límite semanal.
  bool get canAssign => weeks.every((w) => !w.exceedsLimit);

  List<WeeklyWorkload> get overloadedWeeks =>
      weeks.where((w) => w.exceedsLimit).toList();

  List<WeeklyWorkload> get nearLimitWeeks =>
      weeks.where((w) => w.isNearLimit).toList();

  bool get hasWarnings => weeks.any((w) => w.exceedsLimit || w.isNearLimit);

  double get totalOvertimeAdded =>
      weeks.fold(0.0, (sum, w) => sum + w.additional.overtime);
}

/// Calcula la carga de trabajo SEMANAL de los técnicos, distinguiendo horas
/// regulares (L-V 8:00-17:00, Sáb 8:00-12:00) de horas extra.
class WorkloadCalculator {
  WorkloadCalculator({
    FirebaseFirestore? firestore,
    this.maxWeeklyHours = TechnicianAvailabilityService.MAX_WEEKLY_HOURS,
    this.nearLimitRatio = 0.9,
  }) : _firestoreOverride = firestore;

  /// Se resuelve de forma perezosa para poder testear la lógica pura sin
  /// inicializar Firebase.
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// Límite de horas por semana (por defecto el mismo que usa
  /// [TechnicianAvailabilityService]).
  final double maxWeeklyHours;

  /// Porcentaje del límite a partir del cual se muestra "casi al límite".
  final double nearLimitRatio;

  /// Horarios laborales
  static const int regularStartHour = 8; // 8am
  static const int regularEndHour = 17; // 5pm
  static const int saturdayEndHour = 12; // 12pm

  /// Duración asumida cuando el mantenimiento no tiene horas estimadas.
  static const double defaultMaintenanceHours = 2.0;

  /// Estados que ocupan tiempo del técnico. Se incluyen ambos formatos
  /// usados por los flujos actuales y legacy.
  static const Set<String> activeStatuses = {
    'assigned',
    'scheduled',
    'inProgress',
    'in_progress',
    'overdue',
  };

  // ============================================
  // Helpers de fechas
  // ============================================

  /// Lunes 00:00 de la semana que contiene [date].
  static DateTime weekStartOf(DateTime date) => DateTime(
      date.year, date.month, date.day - (date.weekday - DateTime.monday));

  /// Número de semana ISO 8601 (la semana 1 contiene el primer jueves).
  static int isoWeekNumber(DateTime date) {
    // Se usa UTC para evitar desfases por horario de verano.
    final d = DateTime.utc(date.year, date.month, date.day);
    final thursday = d.add(Duration(days: DateTime.thursday - d.weekday));
    final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
    return (thursday.difference(firstDayOfYear).inDays ~/ 7) + 1;
  }

  /// Determinar si una fecha/hora está en horario regular.
  bool isRegularHours(DateTime dateTime) {
    final window = _regularWindow(dateTime.weekday);
    if (window == null) return false;
    final hour = dateTime.hour + dateTime.minute / 60;
    return hour >= window.$1 && hour < window.$2;
  }

  /// Ventana de horario regular (horaInicio, horaFin) para un día, o `null`
  /// si todo el día es horario extra (domingo).
  (double, double)? _regularWindow(int weekday) {
    if (weekday >= DateTime.monday && weekday <= DateTime.friday) {
      return (regularStartHour.toDouble(), regularEndHour.toDouble());
    }
    if (weekday == DateTime.saturday) {
      return (regularStartHour.toDouble(), saturdayEndHour.toDouble());
    }
    return null;
  }

  /// Divide un mantenimiento en horas regulares y extra según el solape
  /// entre [start, start + estimatedHours] y el horario regular del día.
  WorkHours calculateMaintenanceHours(DateTime start, double estimatedHours) {
    if (estimatedHours <= 0) return WorkHours.zero;

    final window = _regularWindow(start.weekday);
    if (window == null) return WorkHours(overtime: estimatedHours);

    final startHour = start.hour + start.minute / 60;
    final endHour = startHour + estimatedHours;

    final overlapStart = startHour > window.$1 ? startHour : window.$1;
    final overlapEnd = endHour < window.$2 ? endHour : window.$2;
    final regular = (overlapEnd - overlapStart).clamp(0.0, estimatedHours);

    return WorkHours(regular: regular, overtime: estimatedHours - regular);
  }

  static double _hoursFromData(Map<String, dynamic> data) {
    final hours = data['estimatedHours'];
    if (hours is num && hours > 0) return hours.toDouble();
    final minutes = data['estimatedDurationMinutes'];
    if (minutes is num && minutes > 0) return minutes / 60.0;
    return defaultMaintenanceHours;
  }

  static double _hoursOf(MaintenanceSchedule m) =>
      (m.estimatedHours != null && m.estimatedHours! > 0)
          ? m.estimatedHours!
          : defaultMaintenanceHours;

  // ============================================
  // Firestore
  // ============================================

  /// Mantenimientos activos del técnico como (fecha, horas).
  ///
  /// Se filtra por estado en memoria para no requerir índices compuestos.
  Future<List<(DateTime, double)>> _loadActiveAssignments(
    String technicianId, {
    Set<String> excludeIds = const {},
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestoreCollections.maintenanceSchedules)
        .where('technicianId', isEqualTo: technicianId)
        .where('status', whereIn: activeStatuses.toList());
    if (startDate != null) {
      query = query.where('scheduledDate', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('scheduledDate', isLessThan: endDate);
    }
    final snapshot = await query.get();

    final result = <(DateTime, double)>[];
    for (final doc in snapshot.docs) {
      if (excludeIds.contains(doc.id)) continue;
      final data = doc.data();
      if (!activeStatuses.contains(data['status'])) continue;
      final ts = data['scheduledDate'];
      if (ts is! Timestamp) continue;
      result.add((ts.toDate(), _hoursFromData(data)));
    }
    return result;
  }

  Map<DateTime, WorkHours> _groupByWeek(List<(DateTime, double)> items) {
    final byWeek = <DateTime, WorkHours>{};
    for (final (date, hours) in items) {
      final week = weekStartOf(date);
      byWeek[week] = (byWeek[week] ?? WorkHours.zero) +
          calculateMaintenanceHours(date, hours);
    }
    return byWeek;
  }

  /// Horas asignadas a un técnico en la semana que contiene [anyDayOfWeek].
  Future<WorkHours> getTechnicianWeeklyHours(
    String technicianId,
    DateTime anyDayOfWeek,
  ) async {
    final start = weekStartOf(anyDayOfWeek);
    final end = DateTime(start.year, start.month, start.day + 7);
    final items = await _loadActiveAssignments(
      technicianId,
      startDate: start,
      endDate: end,
    );
    return _groupByWeek(items)[weekStartOf(anyDayOfWeek)] ?? WorkHours.zero;
  }

  /// Valida si se pueden asignar [maintenances] a un técnico sin exceder el
  /// límite semanal. Los mantenimientos que ya estuvieran asignados a ese
  /// técnico no se cuentan dos veces.
  ///
  /// Lanza la excepción de Firestore si la consulta falla, para que la UI
  /// pueda informar en lugar de asumir 0 horas.
  Future<WorkloadCheckResult> checkAssignment(
    String technicianId,
    List<MaintenanceSchedule> maintenances,
  ) async {
    if (maintenances.isEmpty) {
      return WorkloadCheckResult(
          weeks: const [], maxWeeklyHours: maxWeeklyHours);
    }
    final sortedDates = maintenances.map((m) => m.scheduledDate).toList()
      ..sort();
    final start = weekStartOf(sortedDates.first);
    final lastWeek = weekStartOf(sortedDates.last);
    final end = DateTime(lastWeek.year, lastWeek.month, lastWeek.day + 7);
    final existing = await _loadActiveAssignments(
      technicianId,
      excludeIds: maintenances.map((m) => m.id).toSet(),
      startDate: start,
      endDate: end,
    );
    final currentByWeek = _groupByWeek(existing);

    final additionalByWeek = <DateTime, WorkHours>{};
    final countByWeek = <DateTime, int>{};
    for (final m in maintenances) {
      final week = weekStartOf(m.scheduledDate);
      additionalByWeek[week] = (additionalByWeek[week] ?? WorkHours.zero) +
          calculateMaintenanceHours(m.scheduledDate, _hoursOf(m));
      countByWeek[week] = (countByWeek[week] ?? 0) + 1;
    }

    final weeks = additionalByWeek.keys.toList()..sort();
    final result = WorkloadCheckResult(
      maxWeeklyHours: maxWeeklyHours,
      weeks: [
        for (final week in weeks)
          WeeklyWorkload(
            weekStart: week,
            current: currentByWeek[week] ?? WorkHours.zero,
            additional: additionalByWeek[week]!,
            newMaintenances: countByWeek[week]!,
            maxWeeklyHours: maxWeeklyHours,
            nearLimitRatio: nearLimitRatio,
          ),
      ],
    );

    debugPrint('📊 Carga técnico $technicianId: '
        '${result.weeks.map((w) => 'S${w.isoWeek}=${w.newTotal.toStringAsFixed(1)}h').join(', ')}');

    return result;
  }

  /// Resumen semanal de carga de un técnico entre dos fechas.
  Future<List<WeeklyWorkload>> getTechnicianWeeklySummary(
    String technicianId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final start = weekStartOf(startDate);
    final endWeek = weekStartOf(endDate);
    final end = DateTime(endWeek.year, endWeek.month, endWeek.day + 7);
    final byWeek = _groupByWeek(await _loadActiveAssignments(
      technicianId,
      startDate: start,
      endDate: end,
    ));

    final summary = <WeeklyWorkload>[];
    var week = start;
    final last = endWeek;
    while (!week.isAfter(last)) {
      summary.add(WeeklyWorkload(
        weekStart: week,
        current: byWeek[week] ?? WorkHours.zero,
        additional: WorkHours.zero,
        newMaintenances: 0,
        maxWeeklyHours: maxWeeklyHours,
        nearLimitRatio: nearLimitRatio,
      ));
      // Se usa el constructor (no add de 7 días) para no desfasarse con DST.
      week = DateTime(week.year, week.month, week.day + 7);
    }
    return summary;
  }
}
