import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pm_monitor/core/services/maintenance_schedule_service.dart';
import 'package:pm_monitor/features/technician/screens/technician_availability_model.dart';

class TechnicianAvailabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MaintenanceScheduleService _maintenanceService =
      MaintenanceScheduleService();

  // Configuración de horario laboral
  static const double MAX_WEEKLY_HOURS = 44.0;
  static const double REGULAR_WEEKLY_HOURS = 40.0;

  /// Obtener todos los técnicos con su disponibilidad actual
  Future<List<TechnicianAvailability>> getTechniciansAvailability({
    DateTime? weekStart,
  }) async {
    try {

      final startOfWeek = weekStart ?? _getStartOfWeek(DateTime.now());
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      final techniciansSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'technician')
          .where('isActive', isEqualTo: true)
          .get();

      debugPrint(
          '👥 Técnicos activos encontrados: ${techniciansSnapshot.docs.length}');
      debugPrint('');

      final List<TechnicianAvailability> availabilities = [];

      for (final techDoc in techniciansSnapshot.docs) {
        final techData = techDoc.data();
        final techName = techData['name'] ?? 'Sin nombre';
        debugPrint('   Calculando horas asignadas...');
        final assignedHours =
            await _maintenanceService.getTechnicianHoursInDateRange(
          technicianId: techDoc.id,
          startDate: startOfWeek,
          endDate: endOfWeek,
        );
        final activeMaintenances =
            await _maintenanceService.getActiveMaintenancesCount(techDoc.id);

        availabilities.add(
          TechnicianAvailability(
            id: techDoc.id,
            name: techName,
            email: techData['email'] ?? '',
            photoUrl: techData['photoUrl'],
            isActive: techData['isActive'] ?? true,
            assignedHours: assignedHours,
            maxWeeklyHours: MAX_WEEKLY_HOURS,
            regularHours: REGULAR_WEEKLY_HOURS,
            activeMaintenances: activeMaintenances,
          ),
        );
      }

      // Ordenar por disponibilidad (más disponible primero)
      availabilities.sort((a, b) => a.assignedHours.compareTo(b.assignedHours));

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ RESUMEN FINAL');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      for (final tech in availabilities) {
        debugPrint(
            '${tech.name}: ${tech.assignedHours} hrs / ${tech.activeMaintenances} activos');
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('');

      return availabilities;
    } catch (e, stackTrace) {
      debugPrint('❌ Error calculando disponibilidad: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Obtener disponibilidad de un técnico específico
  Future<TechnicianAvailability?> getTechnicianAvailability({
    required String technicianId,
    DateTime? weekStart,
  }) async {
    try {
      final now = DateTime.now();
      final startOfWeek = DateTime(2020, 1, 1); // Fecha muy antigua
      final endOfWeek = DateTime(2030, 12, 31); // Fecha muy futura

      final techDoc =
          await _firestore.collection('users').doc(technicianId).get();

      if (!techDoc.exists) return null;

      final techData = techDoc.data()!;

      final assignedHours =
          await _maintenanceService.getTechnicianHoursInDateRange(
        technicianId: technicianId,
        startDate: startOfWeek,
        endDate: endOfWeek,
      );

      final activeMaintenances =
          await _maintenanceService.getActiveMaintenancesCount(technicianId);

      return TechnicianAvailability(
        id: techDoc.id,
        name: techData['name'] ?? 'Sin nombre',
        email: techData['email'] ?? '',
        photoUrl: techData['photoUrl'],
        isActive: techData['isActive'] ?? true,
        assignedHours: assignedHours,
        maxWeeklyHours: MAX_WEEKLY_HOURS,
        regularHours: REGULAR_WEEKLY_HOURS,
        activeMaintenances: activeMaintenances,
      );
    } catch (e) {
      debugPrint('❌ Error obteniendo disponibilidad de técnico: $e');
      return null;
    }
  }

  /// Validar si un técnico puede aceptar horas adicionales
  Future<bool> canTechnicianAcceptHours({
    required String technicianId,
    required double additionalHours,
    DateTime? weekStart,
  }) async {
    final availability = await getTechnicianAvailability(
      technicianId: technicianId,
      weekStart: weekStart,
    );

    if (availability == null) return false;

    return availability.canAcceptHours(additionalHours);
  }

  /// Obtener técnicos recomendados para asignación
  Future<List<TechnicianAvailability>> getRecommendedTechnicians({
    required double requiredHours,
    DateTime? weekStart,
  }) async {
    final allTechnicians = await getTechniciansAvailability(
      weekStart: weekStart,
    );

    // Filtrar solo los que pueden aceptar las horas
    return allTechnicians
        .where((tech) => tech.canAcceptHours(requiredHours))
        .toList();
  }

  /// Helper: Obtener inicio de semana (Lunes)
  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysFromMonday));
  }

  /// Stream de disponibilidad en tiempo real
  Stream<List<TechnicianAvailability>> watchTechniciansAvailability({
    DateTime? weekStart,
  }) async* {
    // Actualizar cada 30 segundos
    while (true) {
      yield await getTechniciansAvailability(weekStart: weekStart);
      await Future.delayed(const Duration(seconds: 30));
    }
  }
}
