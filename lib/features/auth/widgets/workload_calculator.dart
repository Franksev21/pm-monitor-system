import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_model.dart';


/// Calculador de carga de trabajo para técnicos
class WorkloadCalculator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Horarios laborales
  static const int regularStartHour = 8; // 8am
  static const int regularEndHour = 17; // 5pm (17:00)
  static const int saturdayEndHour = 12; // 12pm (mediodía)

  /// Obtener número de semana ISO 8601
  int getWeekNumber(DateTime date) {
    // Calcular número de semana según ISO 8601
    // La semana 1 es la primera semana del año que contiene un jueves
    final startOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(startOfYear).inDays;
    final weekNumber = ((days + startOfYear.weekday) / 7).ceil();
    return weekNumber;
  }

  /// Obtener inicio y fin de una semana
  DateTimeRange getWeekRange(int weekNumber, int year) {
    // Encontrar el primer día del año
    final startOfYear = DateTime(year, 1, 1);

    // Calcular días hasta la semana deseada
    final daysToAdd = (weekNumber - 1) * 7 - startOfYear.weekday + 1;

    // Lunes de la semana
    final monday = startOfYear.add(Duration(days: daysToAdd));

    // Domingo de la semana
    final sunday = monday.add(const Duration(days: 6));

    return DateTimeRange(
      start: DateTime(monday.year, monday.month, monday.day),
      end: DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59),
    );
  }

  /// Determinar si una fecha/hora está en horario regular u overtime
  bool isRegularHours(DateTime dateTime) {
    final dayOfWeek = dateTime.weekday; // 1=Lunes, 7=Domingo
    final hour = dateTime.hour;

    // Lunes a Viernes: 8am - 5pm
    if (dayOfWeek >= 1 && dayOfWeek <= 5) {
      return hour >= regularStartHour && hour < regularEndHour;
    }

    // Sábado: 8am - 12pm
    if (dayOfWeek == 6) {
      return hour >= regularStartHour && hour < saturdayEndHour;
    }

    // Domingo: todo es overtime
    return false;
  }

  /// Calcular horas de un mantenimiento (regular vs overtime)
  Map<String, double> calculateMaintenanceHours(
    DateTime scheduledDate,
    double estimatedHours,
  ) {
    double regularHours = 0.0;
    double overtimeHours = 0.0;

    // Determinar si cae en horario regular
    if (isRegularHours(scheduledDate)) {
      // Calcular cuánto del mantenimiento cae en horario regular
      final dayOfWeek = scheduledDate.weekday;
      final startHour = scheduledDate.hour + (scheduledDate.minute / 60);

      double availableRegularHours;
      if (dayOfWeek >= 1 && dayOfWeek <= 5) {
        // Lunes a Viernes: hasta las 5pm
        availableRegularHours = regularEndHour - startHour;
      } else {
        // Sábado: hasta las 12pm
        availableRegularHours = saturdayEndHour - startHour;
      }

      if (estimatedHours <= availableRegularHours) {
        // Todo el mantenimiento es en horario regular
        regularHours = estimatedHours;
      } else {
        // Parte regular, parte overtime
        regularHours = availableRegularHours;
        overtimeHours = estimatedHours - availableRegularHours;
      }
    } else {
      // Todo es overtime
      overtimeHours = estimatedHours;
    }

    return {
      'regular': regularHours,
      'overtime': overtimeHours,
    };
  }

  /// Obtener carga de trabajo de un técnico para una semana específica
  Future<Map<String, double>> getTechnicianWeeklyHours(
    String technicianId,
    int weekNumber,
    int year,
  ) async {
    final weekRange = getWeekRange(weekNumber, year);

    double regularHours = 0.0;
    double overtimeHours = 0.0;

    try {
      // Obtener todos los mantenimientos ASIGNADOS del técnico en esa semana
      final querySnapshot = await _firestore
          .collection('maintenance_schedules')
          .where('technicianId', isEqualTo: technicianId)
          .where('status', isEqualTo: 'assigned')
          .where('scheduledDate', isGreaterThanOrEqualTo: weekRange.start)
          .where('scheduledDate', isLessThanOrEqualTo: weekRange.end)
          .get();

      // Sumar horas de cada mantenimiento
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();
        final estimatedHours =
            (data['estimatedMaintenanceHours'] ?? 2.0) as num;

        final hours = calculateMaintenanceHours(
          scheduledDate,
          estimatedHours.toDouble(),
        );

        regularHours += hours['regular']!;
        overtimeHours += hours['overtime']!;
      }
    } catch (e) {
      print('Error calculando horas del técnico: $e');
    }

    return {
      'regular': regularHours,
      'overtime': overtimeHours,
      'total': regularHours + overtimeHours,
    };
  }

  /// Obtener cantidad de mantenimientos activos de un técnico
  Future<int> getActiveMaintenancesCount(String technicianId) async {
    try {
      final querySnapshot = await _firestore
          .collection('maintenance_schedules')
          .where('technicianId', isEqualTo: technicianId)
          .where('status', whereIn: ['assigned', 'inProgress']).get();

      return querySnapshot.docs.length;
    } catch (e) {
      print('Error obteniendo mantenimientos activos: $e');
      return 0;
    }
  }

  /// Validar si se puede asignar mantenimientos a un técnico
  Future<Map<String, dynamic>> canAssignMaintenances(
    String technicianId,
    List<MaintenanceSchedule> maintenances,
  ) async {
    // Agrupar mantenimientos por semana
    final Map<String, List<MaintenanceSchedule>> byWeek = {};

    for (var maintenance in maintenances) {
      final weekNumber = getWeekNumber(maintenance.scheduledDate);
      final year = maintenance.scheduledDate.year;
      final key = '$year-$weekNumber';

      if (byWeek[key] == null) {
        byWeek[key] = [];
      }
      byWeek[key]!.add(maintenance);
    }

    // Validar cada semana
    final List<String> warnings = [];
    bool canAssign = true;

    for (var entry in byWeek.entries) {
      final parts = entry.key.split('-');
      final year = int.parse(parts[0]);
      final weekNumber = int.parse(parts[1]);
      final weekMaintenances = entry.value;

      // Obtener horas actuales del técnico
      final currentHours = await getTechnicianWeeklyHours(
        technicianId,
        weekNumber,
        year,
      );

      // Calcular horas a agregar
      double additionalRegular = 0.0;
      double additionalOvertime = 0.0;

      for (var maintenance in weekMaintenances) {
        final estimatedHours = maintenance.estimatedHours?.toDouble() ?? 0.0;
        final hours = calculateMaintenanceHours(
          maintenance.scheduledDate,
          estimatedHours,
        );

        additionalRegular += hours['regular']!;
        additionalOvertime += hours['overtime']!;
      }

      final newTotal =
          currentHours['total']! + additionalRegular + additionalOvertime;

      if (newTotal > 60.0) {
        canAssign = false;
        warnings.add(
            'Semana $weekNumber/$year: Excede límite (${newTotal.toStringAsFixed(1)}/60 hrs)');
      } else if (newTotal >= 54.0) {
        warnings.add(
            'Semana $weekNumber/$year: Casi al límite (${newTotal.toStringAsFixed(1)}/60 hrs)');
      }
    }

    return {
      'canAssign': canAssign,
      'warnings': warnings,
      'weeklyBreakdown': byWeek,
    };
  }

  /// Obtener resumen de todas las semanas con carga de un técnico
  Future<List<Map<String, dynamic>>> getTechnicianWeeklySummary(
    String technicianId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final List<Map<String, dynamic>> summary = [];

    DateTime current = startDate;
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      final weekNumber = getWeekNumber(current);
      final year = current.year;

      final hours =
          await getTechnicianWeeklyHours(technicianId, weekNumber, year);
      final activeCount = await getActiveMaintenancesCount(technicianId);

      summary.add({
        'weekNumber': weekNumber,
        'year': year,
        'regularHours': hours['regular'],
        'overtimeHours': hours['overtime'],
        'totalHours': hours['total'],
        'activeMaintenances': activeCount,
        'weekRange': getWeekRange(weekNumber, year),
      });

      // Siguiente semana
      current = current.add(const Duration(days: 7));
    }

    return summary;
  }
}
