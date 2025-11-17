import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pm_monitor/core/models/technician_model.dart';

class TechnicianService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // Stream de todos los técnicos
  Stream<List<TechnicianModel>> getTechniciansStream() {
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'technician')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TechnicianModel.fromFirestore(doc))
            .toList());
  }

  // Stream de técnicos activos
  Stream<List<TechnicianModel>> getActiveTechniciansStream() {
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'technician')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TechnicianModel.fromFirestore(doc))
            .where((technician) => technician.isActive)
            .toList());
  }

  // Obtener técnico por ID
  Future<TechnicianModel?> getTechnicianById(String technicianId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(technicianId).get();
      if (doc.exists) {
        return TechnicianModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener técnico: $e');
    }
  }

  // Crear nuevo técnico
  Future<String> createTechnician(TechnicianModel technician) async {
    try {
      final docRef = await _firestore.collection(_collection).add({
        ...technician.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear técnico: $e');
    }
  }

  // Actualizar técnico
  Future<void> updateTechnician(
      String technicianId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection(_collection).doc(technicianId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al actualizar técnico: $e');
    }
  }

  // Cambiar estado activo/inactivo
  Future<void> toggleTechnicianStatus(
      String technicianId, bool isActive) async {
    try {
      await _firestore.collection(_collection).doc(technicianId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al cambiar estado del técnico: $e');
    }
  }

  // Asignar equipos a técnico (método legacy)
  Future<void> assignEquipmentsToTechnician(
      String technicianId, List<String> equipmentIds) async {
    try {
      await _firestore.collection(_collection).doc(technicianId).update({
        'assignedEquipments': equipmentIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al asignar equipos: $e');
    }
  }

  // Agregar equipo a técnico (método legacy)
  Future<void> addEquipmentToTechnician(
      String technicianId, String equipmentId) async {
    try {
      await _firestore.collection(_collection).doc(technicianId).update({
        'assignedEquipments': FieldValue.arrayUnion([equipmentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al agregar equipo: $e');
    }
  }

  // Remover equipo de técnico (método legacy)
  Future<void> removeEquipmentFromTechnician(
      String technicianId, String equipmentId) async {
    try {
      await _firestore.collection(_collection).doc(technicianId).update({
        'assignedEquipments': FieldValue.arrayRemove([equipmentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al remover equipo: $e');
    }
  }

  // MÉTODOS SINCRONIZADOS - Estos son los importantes

  // Asignar equipo de forma sincronizada (actualiza ambos lados)
  Future<void> assignEquipmentToTechnicianSync(
      String technicianId, String equipmentId, String technicianName) async {
    try {
      final batch = _firestore.batch();

      // 1. Actualizar el técnico (agregar equipo a su lista)
      final technicianRef = _firestore.collection('users').doc(technicianId);
      batch.update(technicianRef, {
        'assignedEquipments': FieldValue.arrayUnion([equipmentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Actualizar el equipo (asignar técnico)
      final equipmentRef = _firestore.collection('equipments').doc(equipmentId);
      batch.update(equipmentRef, {
        'assignedTechnicianId': technicianId,
        'assignedTechnicianName': technicianName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Error al asignar equipo de forma sincronizada: $e');
    }
  }

  // Desasignar equipo de forma sincronizada
  Future<void> unassignEquipmentFromTechnicianSync(
      String technicianId, String equipmentId) async {
    try {
      final batch = _firestore.batch();

      // 1. Actualizar el técnico (remover equipo de su lista)
      final technicianRef = _firestore.collection('users').doc(technicianId);
      batch.update(technicianRef, {
        'assignedEquipments': FieldValue.arrayRemove([equipmentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Actualizar el equipo (remover técnico)
      final equipmentRef = _firestore.collection('equipments').doc(equipmentId);
      batch.update(equipmentRef, {
        'assignedTechnicianId': null,
        'assignedTechnicianName': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Error al desasignar equipo de forma sincronizada: $e');
    }
  }

  // Obtener conteo real de equipos asignados al técnico
  Future<int> getAssignedEquipmentsCount(String technicianId) async {
    try {
      final snapshot = await _firestore
          .collection('equipments')
          .where('assignedTechnicianId', isEqualTo: technicianId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error al contar equipos asignados: $e');
      return 0;
    }
  }

  // Sincronizar datos de técnicos y equipos
  Future<void> syncTechnicianEquipmentData() async {
    try {
      print('Iniciando sincronización de datos técnico-equipo...');

      final techniciansSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'technician')
          .get();

      final equipmentsSnapshot =
          await _firestore.collection('equipments').get();

      final batch = _firestore.batch();

      for (final techDoc in techniciansSnapshot.docs) {
        final techData = techDoc.data();
        final techId = techDoc.id;
        final techName =
            techData['name'] ?? techData['fullName'] ?? 'Sin nombre';

        print('Procesando técnico: $techName (ID: $techId)');

        final assignedEquipments = <String>[];

        for (final equipDoc in equipmentsSnapshot.docs) {
          final equipData = equipDoc.data();
          final assignedTechId = equipData['assignedTechnicianId'];

          if (assignedTechId == techId && equipData['isActive'] == true) {
            assignedEquipments.add(equipDoc.id);

            if (equipData['assignedTechnicianName'] != techName) {
              print(
                  '  Actualizando nombre del técnico en equipo ${equipDoc.id}');
              batch.update(
                  _firestore.collection('equipments').doc(equipDoc.id), {
                'assignedTechnicianName': techName,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        final currentAssignedEquipments =
            List<String>.from(techData['assignedEquipments'] ?? []);

        if (!_listEquals(currentAssignedEquipments, assignedEquipments)) {
          print(
              '  Actualizando lista de equipos asignados: ${assignedEquipments.length} equipos');
          batch.update(_firestore.collection('users').doc(techId), {
            'assignedEquipments': assignedEquipments,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          print('  Lista de equipos ya está sincronizada');
        }
      }

      await batch.commit();
      print('Sincronización completada');
    } catch (e) {
      print('Error en sincronización: $e');
      throw Exception('Error en sincronización: $e');
    }
  }

  // Actualizar tarifa horaria
  Future<void> updateTechnicianRate(
      String technicianId, double hourlyRate) async {
    try {
      await _firestore.collection(_collection).doc(technicianId).update({
        'hourlyRate': hourlyRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al actualizar tarifa: $e');
    }
  }

  // Obtener técnicos por equipos asignados
  Future<List<TechnicianModel>> getTechniciansByEquipment(
      String equipmentId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'technician')
          .where('assignedEquipments', arrayContains: equipmentId)
          .get();

      return snapshot.docs
          .map((doc) => TechnicianModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener técnicos por equipo: $e');
    }
  }

  // Buscar técnicos
  Future<List<TechnicianModel>> searchTechnicians(String query) async {
    try {
      final queryLower = query.toLowerCase();

      final nameSnapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'technician')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      final emailSnapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'technician')
          .where('email', isGreaterThanOrEqualTo: queryLower)
          .where('email', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .get();

      final Set<String> seenIds = {};
      final List<TechnicianModel> results = [];

      for (final doc in [...nameSnapshot.docs, ...emailSnapshot.docs]) {
        if (!seenIds.contains(doc.id)) {
          seenIds.add(doc.id);
          results.add(TechnicianModel.fromFirestore(doc));
        }
      }

      return results;
    } catch (e) {
      throw Exception('Error en búsqueda de técnicos: $e');
    }
  }

  // Obtener estadísticas de técnicos
  Future<Map<String, int>> getTechnicianStats() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'technician')
          .get();

      int total = snapshot.docs.length;
      int active = 0;
      int withEquipments = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isActive'] == true) active++;

        final equipments = data['assignedEquipments'] as List?;
        if (equipments != null && equipments.isNotEmpty) withEquipments++;
      }

      return {
        'total': total,
        'active': active,
        'inactive': total - active,
        'withEquipments': withEquipments,
        'withoutEquipments': total - withEquipments,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }

  // Eliminar técnico (soft delete)
  Future<void> deleteTechnician(String technicianId) async {
    try {
      await _firestore.collection(_collection).doc(technicianId).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al eliminar técnico: $e');
    }
  }

  // Restaurar técnico
  Future<void> restoreTechnician(String technicianId) async {
    try {
      await _firestore.collection(_collection).doc(technicianId).update({
        'isActive': true,
        'deletedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al restaurar técnico: $e');
    }
  }

  // Helper para comparar listas
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
