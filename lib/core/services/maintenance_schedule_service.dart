import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pm_monitor/core/models/maintenance_calendar_model.dart';

class MaintenanceScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'maintenanceSchedules';

  // Singleton pattern
  static final MaintenanceScheduleService _instance =
      MaintenanceScheduleService._internal();
  factory MaintenanceScheduleService() => _instance;
  MaintenanceScheduleService._internal();

  /// Crear un nuevo mantenimiento
  Future<String?> createMaintenance(MaintenanceSchedule maintenance) async {
    try {
      // Crear el documento con los datos del mantenimiento
      DocumentReference docRef = await _firestore
          .collection(_collection)
          .add(maintenance.toFirestore());

      debugPrint('Mantenimiento creado con ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creando mantenimiento: $e');
      rethrow;
    }
  }

  /// Actualizar un mantenimiento existente
  Future<bool> updateMaintenance(MaintenanceSchedule maintenance) async {
    try {
      if (maintenance.id.isEmpty) {
        throw Exception('ID del mantenimiento no puede estar vacío');
      }

      await _firestore
          .collection(_collection)
          .doc(maintenance.id)
          .update(maintenance.toFirestore());

      debugPrint('Mantenimiento actualizado: ${maintenance.id}');
      return true;
    } catch (e) {
      debugPrint('Error actualizando mantenimiento: $e');
      rethrow;
    }
  }

  /// Eliminar un mantenimiento
  Future<bool> deleteMaintenance(String maintenanceId) async {
    try {
      await _firestore.collection(_collection).doc(maintenanceId).delete();

      debugPrint('Mantenimiento eliminado: $maintenanceId');
      return true;
    } catch (e) {
      debugPrint('Error eliminando mantenimiento: $e');
      rethrow;
    }
  }

  /// Obtener todos los mantenimientos
  Stream<List<MaintenanceSchedule>> getAllMaintenances() {
    return _firestore
        .collection(_collection)
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  /// Obtener mantenimientos por técnico
  Stream<List<MaintenanceSchedule>> getMaintenancesByTechnician(
      String technicianId) {
    return _firestore
        .collection(_collection)
        .where('technicianId', isEqualTo: technicianId)
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  /// Obtener mantenimientos por cliente
  Stream<List<MaintenanceSchedule>> getMaintenancesByClient(String clientId) {
    return _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  /// Obtener mantenimientos por estado
  Stream<List<MaintenanceSchedule>> getMaintenancesByStatus(
      MaintenanceStatus status) {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: status.toString().split('.').last)
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  /// Obtener mantenimientos por rango de fechas
  Future<List<MaintenanceSchedule>> getMaintenancesByDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('scheduledDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('scheduledDate')
          .get();

      return snapshot.docs
          .map((doc) => MaintenanceSchedule.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo mantenimientos por rango de fechas: $e');
      rethrow;
    }
  }

  /// Actualizar estado del mantenimiento
  Future<bool> updateMaintenanceStatus(
    String maintenanceId,
    MaintenanceStatus status, {
    DateTime? completedDate,
    String? completedBy,
    int? completionPercentage,
    Map<String, bool>? taskCompletion,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'status': status.toString().split('.').last,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (completedDate != null) {
        updateData['completedDate'] = Timestamp.fromDate(completedDate);
      }

      if (completedBy != null) {
        updateData['completedBy'] = completedBy;
      }

      if (completionPercentage != null) {
        updateData['completionPercentage'] = completionPercentage;
      }

      if (taskCompletion != null) {
        updateData['taskCompletion'] = taskCompletion;
      }

      await _firestore
          .collection(_collection)
          .doc(maintenanceId)
          .update(updateData);

      debugPrint('Estado del mantenimiento actualizado: $maintenanceId');
      return true;
    } catch (e) {
      debugPrint('Error actualizando estado del mantenimiento: $e');
      rethrow;
    }
  }

  /// Programar mantenimientos recurrentes
  Future<List<String>> scheduleRecurringMaintenances({
    required String equipmentId,
    required String equipmentName,
    required String clientId,
    required String clientName,
    required FrequencyType frequency,
    required DateTime startDate,
    required int durationMonths,
    required List<String> tasks,
    required int estimatedDurationMinutes,
    String? technicianId,
    String? technicianName,
    String? supervisorId,
    String? supervisorName,
    double? estimatedCost,
    String? location,
    String? notes,
    required String createdBy,
  }) async {
    try {
      List<String> createdIds = [];
      final scheduleDates =
          _generateRecurringDates(frequency, startDate, durationMonths);

      for (final date in scheduleDates) {
        final maintenance = MaintenanceSchedule(
          id: '', // Se generará automáticamente
          equipmentId: equipmentId,
          equipmentName: equipmentName,
          clientId: clientId,
          clientName: clientName,
          technicianId: technicianId,
          technicianName: technicianName,
          supervisorId: supervisorId,
          supervisorName: supervisorName,
          scheduledDate: date,
          status: MaintenanceStatus.scheduled,
          type: MaintenanceType.preventive,
          frequency: frequency,
          tasks: tasks,
          estimatedDurationMinutes: estimatedDurationMinutes,
          estimatedCost: estimatedCost,
          location: location,
          notes: notes,
          photoUrls: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: createdBy,
        );

        final id = await createMaintenance(maintenance);
        if (id != null) {
          createdIds.add(id);
        }
      }

      debugPrint('Creados ${createdIds.length} mantenimientos recurrentes');
      return createdIds;
    } catch (e) {
      debugPrint('Error creando mantenimientos recurrentes: $e');
      rethrow;
    }
  }

  /// Generar fechas recurrentes basadas en la frecuencia
  List<DateTime> _generateRecurringDates(
    FrequencyType frequency,
    DateTime startDate,
    int durationMonths,
  ) {
    final dates = <DateTime>[];
    var currentDate = startDate;
    final endDate = startDate.add(Duration(days: durationMonths * 30));

    while (currentDate.isBefore(endDate)) {
      dates.add(currentDate);

      switch (frequency) {
        case FrequencyType.weekly:
          currentDate = currentDate.add(const Duration(days: 7));
          break;
        case FrequencyType.biweekly:
          currentDate = currentDate.add(const Duration(days: 14));
          break;
        case FrequencyType.monthly:
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + 1,
            currentDate.day,
            currentDate.hour,
            currentDate.minute,
          );
          break;
        case FrequencyType.quarterly:
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + 3,
            currentDate.day,
            currentDate.hour,
            currentDate.minute,
          );
          break;
        case FrequencyType.biannual:
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + 6,
            currentDate.day,
            currentDate.hour,
            currentDate.minute,
          );
          break;
        case FrequencyType.annual:
          currentDate = DateTime(
            currentDate.year + 1,
            currentDate.month,
            currentDate.day,
            currentDate.hour,
            currentDate.minute,
          );
          break;
        case FrequencyType.custom:
          // Para personalizado, usar mensual por defecto
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + 1,
            currentDate.day,
            currentDate.hour,
            currentDate.minute,
          );
          break;
      }
    }

    return dates;
  }

  /// Obtener mantenimientos vencidos
  Future<List<MaintenanceSchedule>> getOverdueMaintenances() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'scheduled')
          .where('scheduledDate', isLessThan: Timestamp.fromDate(now))
          .get();

      return snapshot.docs
          .map((doc) => MaintenanceSchedule.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo mantenimientos vencidos: $e');
      rethrow;
    }
  }

  /// Obtener próximos mantenimientos (siguientes X días)
  Future<List<MaintenanceSchedule>> getUpcomingMaintenances(int days) async {
    try {
      final now = DateTime.now();
      final futureDate = now.add(Duration(days: days));

      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'scheduled')
          .where('scheduledDate', isGreaterThan: Timestamp.fromDate(now))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(futureDate))
          .orderBy('scheduledDate')
          .get();

      return snapshot.docs
          .map((doc) => MaintenanceSchedule.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo próximos mantenimientos: $e');
      rethrow;
    }
  }

  /// Buscar mantenimientos por texto
  Future<List<MaintenanceSchedule>> searchMaintenances(
      String searchTerm) async {
    try {
      final snapshot = await _firestore.collection(_collection).get();

      final searchLower = searchTerm.toLowerCase();

      return snapshot.docs
          .map((doc) => MaintenanceSchedule.fromFirestore(doc))
          .where((maintenance) =>
              maintenance.equipmentName.toLowerCase().contains(searchLower) ||
              maintenance.clientName.toLowerCase().contains(searchLower) ||
              (maintenance.technicianName
                      ?.toLowerCase()
                      .contains(searchLower) ??
                  false) ||
              (maintenance.location?.toLowerCase().contains(searchLower) ??
                  false))
          .toList();
    } catch (e) {
      debugPrint('Error buscando mantenimientos: $e');
      rethrow;
    }
  }

  /// Obtener estadísticas de mantenimientos
  Future<Map<String, int>> getMaintenanceStats() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();

      final stats = <String, int>{
        'total': 0,
        'scheduled': 0,
        'inProgress': 0,
        'completed': 0,
        'overdue': 0,
        'cancelled': 0,
      };

      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final maintenance = MaintenanceSchedule.fromFirestore(doc);
        stats['total'] = stats['total']! + 1;

        switch (maintenance.status) {
          case MaintenanceStatus.scheduled:
            if (maintenance.scheduledDate.isBefore(now)) {
              stats['overdue'] = stats['overdue']! + 1;
            } else {
              stats['scheduled'] = stats['scheduled']! + 1;
            }
            break;
          case MaintenanceStatus.inProgress:
            stats['inProgress'] = stats['inProgress']! + 1;
            break;
          case MaintenanceStatus.completed:
            stats['completed'] = stats['completed']! + 1;
            break;
          case MaintenanceStatus.overdue:
            stats['overdue'] = stats['overdue']! + 1;
            break;
          case MaintenanceStatus.cancelled:
            stats['cancelled'] = stats['cancelled']! + 1;
            break;
        }
      }

      return stats;
    } catch (e) {
      debugPrint('Error obteniendo estadísticas: $e');
      rethrow;
    }
  }
}
