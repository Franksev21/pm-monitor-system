import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pm_monitor/core/services/notification_service.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_model.dart';

class MaintenanceScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'maintenanceSchedules';
  final NotificationService _notificationService = NotificationService();

  Future<String> createMaintenance(MaintenanceSchedule maintenance) async {
    try {
      debugPrint('📝 Creando mantenimiento...');

      final data = maintenance.toFirestore();
      data['status'] = 'generated';

      final docRef = await _firestore.collection(_collection).add(data);

      debugPrint('✅ Mantenimiento creado con ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creando mantenimiento: $e');
      rethrow;
    }
  }

  /// Actualizar notas del administrador
  Future<void> updateAdminNotes({
    required String maintenanceId,
    String? adminNotes,
    String? adminApprovalNotes,
    bool? isApprovedByAdmin,
    String? approvedBy,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (adminNotes != null) {
        updateData['adminNotes'] = adminNotes;
      }

      if (adminApprovalNotes != null) {
        updateData['adminApprovalNotes'] = adminApprovalNotes;
      }

      if (isApprovedByAdmin != null) {
        updateData['isApprovedByAdmin'] = isApprovedByAdmin;
      }

      if (approvedBy != null) {
        updateData['approvedBy'] = approvedBy;
      }

      if (isApprovedByAdmin == true) {
        updateData['approvedDate'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .update(updateData);

      debugPrint('✅ Notas del admin actualizadas: $maintenanceId');
    } catch (e) {
      debugPrint('❌ Error actualizando notas del admin: $e');
      rethrow;
    }
  }

  /// ⭐ Stream para actualización en tiempo real
  Stream<List<MaintenanceSchedule>> getMaintenancesStream({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    try {
      Query query = _firestore.collection(_collection);

      if (startDate != null) {
        query = query.where(
          'scheduledDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'scheduledDate',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      return query.orderBy('scheduledDate').snapshots().map((snapshot) {
        debugPrint('📡 Stream actualizado: ${snapshot.docs.length} items');
        return snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      debugPrint('❌ Error en stream: $e');
      return Stream.value([]);
    }
  }

  /// Actualizar mantenimiento
  Future<void> updateMaintenance(MaintenanceSchedule maintenance) async {
    try {
      debugPrint('🔄 Actualizando mantenimiento ${maintenance.id}...');

      await _firestore
          .collection(_collection)
          .doc(maintenance.id)
          .update(maintenance.toFirestore());

      debugPrint('✅ Mantenimiento actualizado');
    } catch (e) {
      debugPrint('❌ Error actualizando mantenimiento: $e');
      rethrow;
    }
  }

  /// Eliminar mantenimiento
  Future<void> deleteMaintenance(String id) async {
    try {
      debugPrint('🗑️ Eliminando mantenimiento $id...');

      await _firestore.collection(_collection).doc(id).delete();

      debugPrint('✅ Mantenimiento eliminado');
    } catch (e) {
      debugPrint('❌ Error eliminando mantenimiento: $e');
      rethrow;
    }
  }

  /// Obtener mantenimiento por ID
  Future<MaintenanceSchedule?> getMaintenanceById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();

      if (!doc.exists) return null;

      return MaintenanceSchedule.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error obteniendo mantenimiento: $e');
      return null;
    }
  }

  // ============================================
  // STREAMS ADICIONALES (TIEMPO REAL)
  // ============================================

  /// Stream de todos los mantenimientos
  Stream<List<MaintenanceSchedule>> getAllMaintenances() {
    return _firestore
        .collection(_collection)
        .orderBy('scheduledDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  /// Stream de mantenimientos por cliente
  Stream<List<MaintenanceSchedule>> getMaintenancesByClient(String clientId) {
    return _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .orderBy('scheduledDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  /// Stream de mantenimientos por equipo
  Stream<List<MaintenanceSchedule>> getMaintenancesByEquipment(
      String equipmentId) {
    return _firestore
        .collection(_collection)
        .where('equipmentId', isEqualTo: equipmentId)
        .orderBy('scheduledDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  /// Stream de mantenimientos por técnico
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

  /// Stream de mantenimientos por rango de fechas
  Stream<List<MaintenanceSchedule>> getMaintenancesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _firestore
        .collection(_collection)
        .where('scheduledDate', isGreaterThanOrEqualTo: startDate)
        .where('scheduledDate', isLessThanOrEqualTo: endDate)
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  /// ⭐ Stream de mantenimientos GENERADOS (sin asignar)
  Stream<List<MaintenanceSchedule>> getUnassignedMaintenances() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'generated')
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  /// ⭐ Stream de mantenimientos ASIGNADOS
  Stream<List<MaintenanceSchedule>> getAssignedMaintenances() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'assigned')
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  /// ⭐ Stream de mantenimientos EJECUTADOS
  Stream<List<MaintenanceSchedule>> getExecutedMaintenances() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'executed')
        .orderBy('scheduledDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  /// ⭐ Stream de mantenimientos por estado específico
  Stream<List<MaintenanceSchedule>> getMaintenancesByStatus(
      MaintenanceStatus status) {
    final statusString = status.toString().split('.').last;

    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: statusString)
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceSchedule.fromFirestore(doc))
            .toList());
  }

  // ============================================
  // ⭐ ASIGNACIÓN DE TÉCNICOS
  // ============================================

  /// ⭐ Asignar técnico a UN mantenimiento
  Future<void> assignTechnicianToMaintenance({
    required String maintenanceId,
    required String technicianId,
    required String technicianName,
  }) async {
    try {
      debugPrint(
          '👤 Asignando técnico $technicianName a mantenimiento $maintenanceId...');

      await _firestore.collection(_collection).doc(maintenanceId).update({
        'technicianId': technicianId,
        'technicianName': technicianName,
        'status': 'assigned',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Técnico asignado correctamente');

      await _notificationService.sendMaintenanceAssignedNotification(
        technicianId: technicianId,
        maintenanceId: maintenanceId,
      );
    } catch (e) {
      debugPrint('❌ Error asignando técnico: $e');
      rethrow;
    }
  }

  /// ⭐ Asignar técnico a MÚLTIPLES mantenimientos
  Future<void> assignTechnicianToMaintenances({
    required List<String> maintenanceIds,
    required String technicianId,
    required String technicianName,
  }) async {
    try {
      debugPrint(
          '👤 Asignando técnico $technicianName a ${maintenanceIds.length} mantenimientos...');

      final batch = _firestore.batch();

      for (final maintenanceId in maintenanceIds) {
        final docRef = _firestore.collection(_collection).doc(maintenanceId);

        batch.update(docRef, {
          'technicianId': technicianId,
          'technicianName': technicianName,
          'status': 'assigned',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      debugPrint('✅ ${maintenanceIds.length} mantenimientos asignados');

      await _notificationService.sendBulkMaintenanceAssignedNotification(
        technicianId: technicianId,
        maintenanceCount: maintenanceIds.length,
      );
    } catch (e) {
      debugPrint('❌ Error asignando técnico a múltiples mantenimientos: $e');
      rethrow;
    }
  }

  /// ⭐ Reasignar técnico
  Future<void> reassignTechnician({
    required String maintenanceId,
    required String newTechnicianId,
    required String newTechnicianName,
  }) async {
    try {
      debugPrint('🔄 Reasignando mantenimiento $maintenanceId...');

      await _firestore.collection(_collection).doc(maintenanceId).update({
        'technicianId': newTechnicianId,
        'technicianName': newTechnicianName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Mantenimiento reasignado');

      await _notificationService.sendMaintenanceAssignedNotification(
        technicianId: newTechnicianId,
        maintenanceId: maintenanceId,
      );
    } catch (e) {
      debugPrint('❌ Error reasignando técnico: $e');
      rethrow;
    }
  }

  /// ⭐ Desasignar técnico (volver a GENERATED)
  Future<void> unassignTechnician(String maintenanceId) async {
    try {
      debugPrint('↩️ Desasignando técnico del mantenimiento $maintenanceId...');

      await _firestore.collection(_collection).doc(maintenanceId).update({
        'technicianId': null,
        'technicianName': null,
        'status': 'generated',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Técnico desasignado');
    } catch (e) {
      debugPrint('❌ Error desasignando técnico: $e');
      rethrow;
    }
  }

  // ============================================
  // ⭐ EJECUCIÓN DE MANTENIMIENTO
  // ============================================

  /// ⭐ Marcar como EJECUTADO
  Future<void> markAsExecuted({
    required String maintenanceId,
    required String completedBy,
    required Map<String, bool> taskCompletion,
    List<String>? photoUrls,
    String? notes,
  }) async {
    try {
      debugPrint('✅ Marcando mantenimiento $maintenanceId como ejecutado...');

      final totalTasks = taskCompletion.length;
      final completedTasks = taskCompletion.values.where((v) => v).length;
      final percentage =
          totalTasks > 0 ? ((completedTasks / totalTasks) * 100).round() : 0;

      await _firestore.collection(_collection).doc(maintenanceId).update({
        'status': 'executed',
        'completedBy': completedBy,
        'completedDate': FieldValue.serverTimestamp(),
        'taskCompletion': taskCompletion,
        'completionPercentage': percentage,
        'photoUrls': photoUrls,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Mantenimiento ejecutado ($percentage% completado)');
    } catch (e) {
      debugPrint('❌ Error marcando como ejecutado: $e');
      rethrow;
    }
  }

  Future<double> getTechnicianHoursInDateRange({
    required String technicianId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('technicianId', isEqualTo: technicianId)
          .get();

      double totalHours = 0.0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;

        if (status == 'generated' || status == 'assigned') {
          double? hours;
          if (data['estimatedHours'] != null) {
            hours = (data['estimatedHours'] as num).toDouble();
          } else if (data['estimatedDurationMinutes'] != null) {
            hours = (data['estimatedDurationMinutes'] as num).toDouble() / 60.0;
          }

          if (hours != null && hours > 0) {
            totalHours += hours;
          }
        }
      }

      return totalHours;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return 0.0;
    }
  }

  Future<int> getActiveMaintenancesCount(String technicianId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('technicianId', isEqualTo: technicianId)
          .get();

      int activeCount = 0;
      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'generated' || status == 'assigned') {
          activeCount++;
        }
      }

      debugPrint(
          '   👤 Técnico $technicianId: $activeCount mantenimientos activos');
      return activeCount;
    } catch (e) {
      debugPrint('❌ Error contando mantenimientos activos: $e');
      return 0;
    }
  }

  /// Obtener mantenimientos con filtros múltiples (para compatibilidad)
  Future<List<MaintenanceSchedule>> getFilteredMaintenances({
    DateTime? startDate,
    DateTime? endDate,
    MaintenanceStatus? status,
    MaintenanceType? type,
    String? clientId,
    String? branchId,
    String? technicianId,
    String? equipmentType,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (startDate != null) {
        query = query.where('scheduledDate', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('scheduledDate', isLessThanOrEqualTo: endDate);
      }

      if (status != null) {
        query =
            query.where('status', isEqualTo: status.toString().split('.').last);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.toString().split('.').last);
      }

      if (clientId != null) {
        query = query.where('clientId', isEqualTo: clientId);
      }

      if (branchId != null) {
        query = query.where('branchId', isEqualTo: branchId);
      }

      if (technicianId != null) {
        query = query.where('technicianId', isEqualTo: technicianId);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => MaintenanceSchedule.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo mantenimientos filtrados: $e');
      return [];
    }
  }

  /// Obtener conteo de mantenimientos por estado
  Future<Map<String, int>> getMaintenanceCountsByStatus() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();

      final counts = {
        'generated': 0,
        'assigned': 0,
        'executed': 0,
      };

      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status != null && counts.containsKey(status)) {
          counts[status] = counts[status]! + 1;
        }
      }

      return counts;
    } catch (e) {
      debugPrint('❌ Error obteniendo conteos: $e');
      return {};
    }
  }
}
