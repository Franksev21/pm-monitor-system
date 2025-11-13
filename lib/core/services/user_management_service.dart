import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pm_monitor/core/models/client_model.dart';
import '../models/user_management_model.dart';

class UserManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // Stream de usuarios por rol (incluye clientes de ambas colecciones)
Stream<List<UserManagementModel>> getUsersByRole(String role) {
    if (role == 'client') {
      // Para clientes, retornar stream vacío ya que se usa getClients() para ClientModel
      // La UI debe usar getClients() en lugar de getUsersByRole('client')
      return Stream.value([]);
    } else {
      // Para técnicos y supervisores, usar solo la colección users
      return _firestore
          .collection(_collection)
          .where('role', isEqualTo: role)
          .snapshots()
          .asBroadcastStream()
          .map((snapshot) => snapshot.docs
              .map((doc) => UserManagementModel.fromFirestore(doc))
              .toList());
    }
  }


  Stream<List<ClientModel>> getClients() {
    try {
      return _firestore
          .collection('clients')
          .orderBy('name')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) {
              try {
                return ClientModel.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                });
              } catch (e) {
                print('⚠️ Error parseando cliente ${doc.id}: $e');
                // Retornar null y filtrar después
                return null;
              }
            })
            .whereType<ClientModel>()
            .toList(); // Filtra nulls
      });
    } catch (e) {
      print('❌ Error obteniendo clientes: $e');
      return Stream.value([]);
    }
  }


  // Stream de todos los usuarios
  Stream<List<UserManagementModel>> getAllUsersStream() {
    return _firestore.collection(_collection).snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => UserManagementModel.fromFirestore(doc))
            .toList());
  }

  // Obtener técnicos activos para asignar a supervisores
  Future<List<UserManagementModel>> getActiveTechnicians() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'technician')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => UserManagementModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener técnicos: $e');
    }
  }

  // Obtener supervisores activos para asignar a técnicos
  Future<List<UserManagementModel>> getActiveSupervisors() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'supervisor')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => UserManagementModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener supervisores: $e');
    }
  }

  // Asignar técnicos a supervisor
  Future<void> assignTechniciansToSupervisor(
      String supervisorId, List<String> technicianIds) async {
    try {
      final batch = _firestore.batch();

      // Actualizar supervisor con técnicos asignados
      final supervisorRef =
          _firestore.collection(_collection).doc(supervisorId);
      batch.update(supervisorRef, {
        'assignedTechnicians': technicianIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar cada técnico con el supervisor asignado
      for (String technicianId in technicianIds) {
        final technicianRef =
            _firestore.collection(_collection).doc(technicianId);
        batch.update(technicianRef, {
          'supervisorId': supervisorId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Error al asignar técnicos: $e');
    }
  }

  // Desasignar técnico de supervisor
  Future<void> removeTechnicianFromSupervisor(
      String supervisorId, String technicianId) async {
    try {
      final batch = _firestore.batch();

      // Remover técnico de la lista del supervisor
      final supervisorRef =
          _firestore.collection(_collection).doc(supervisorId);
      batch.update(supervisorRef, {
        'assignedTechnicians': FieldValue.arrayRemove([technicianId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remover supervisor del técnico
      final technicianRef =
          _firestore.collection(_collection).doc(technicianId);
      batch.update(technicianRef, {
        'supervisorId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Error al desasignar técnico: $e');
    }
  }

  // Asignar equipos a técnico
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

  // Asignar ubicaciones a cliente
  Future<void> assignLocationsToClient(
      String clientId, List<String> locationIds) async {
    try {
      await _firestore.collection(_collection).doc(clientId).update({
        'locations': locationIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al asignar ubicaciones: $e');
    }
  }

  // Actualizar estado del usuario
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al cambiar estado: $e');
    }
  }

  // Actualizar tarifa horaria (técnicos/supervisores)
  Future<void> updateHourlyRate(String userId, double hourlyRate) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'hourlyRate': hourlyRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al actualizar tarifa: $e');
    }
  }

  Future<Map<String, int>> getStatsByRole(String role) async {
    try {
      if (role == 'client') {
        // Para clientes, obtener de la colección 'clients'
        final clientsSnapshot = await _firestore.collection('clients').get();

        int total = clientsSnapshot.docs.length;
        int active = 0;
        int withAssignments = 0;

        // Contar clientes activos y con sucursales
        for (final doc in clientsSnapshot.docs) {
          final data = doc.data();

          // Los clientes con status 'active' son activos
          if (data['status'] == 'active') active++;

          // Clientes con branches tienen asignaciones
          final branches = data['branches'] as List<dynamic>?;
          if (branches != null && branches.isNotEmpty) {
            withAssignments++;
          }
        }

        return {
          'total': total,
          'active': active,
          'inactive': total - active,
          'withAssignments': withAssignments,
          'withoutAssignments': total - withAssignments,
        };
      } else {
        // Para técnicos y supervisores (código sin cambios)
        final snapshot = await _firestore
            .collection(_collection)
            .where('role', isEqualTo: role)
            .get();

        int total = snapshot.docs.length;
        int active = 0;
        int withAssignments = 0;

        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data['isActive'] == true) active++;

          List<dynamic>? assignments;
          switch (role) {
            case 'technician':
              assignments = data['assignedEquipments'] as List<dynamic>?;
              break;
            case 'supervisor':
              assignments = data['assignedTechnicians'] as List<dynamic>?;
              break;
          }

          if (assignments != null && assignments.isNotEmpty) {
            withAssignments++;
          }
        }

        return {
          'total': total,
          'active': active,
          'inactive': total - active,
          'withAssignments': withAssignments,
          'withoutAssignments': total - withAssignments,
        };
      }
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }
  // Buscar usuarios por nombre o email
  Future<List<UserManagementModel>> searchUsers(String query,
      {String? role}) async {
    try {
      Query baseQuery = _firestore.collection(_collection);

      if (role != null) {
        baseQuery = baseQuery.where('role', isEqualTo: role);
      }

      final snapshot = await baseQuery.get();

      final queryLower = query.toLowerCase();

      return snapshot.docs
          .map((doc) => UserManagementModel.fromFirestore(doc))
          .where((user) =>
              user.name.toLowerCase().contains(queryLower) ||
              user.email.toLowerCase().contains(queryLower))
          .toList();
    } catch (e) {
      throw Exception('Error en búsqueda: $e');
    }
  }

  // Obtener técnicos sin supervisor
  Future<List<UserManagementModel>> getTechniciansWithoutSupervisor() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'technician')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => UserManagementModel.fromFirestore(doc))
          .where(
              (tech) => tech.supervisorId == null || tech.supervisorId!.isEmpty)
          .toList();
    } catch (e) {
      throw Exception('Error al obtener técnicos sin supervisor: $e');
    }
  }

  // Obtener técnicos asignados a un supervisor
  Future<List<UserManagementModel>> getTechniciansBySupervisor(
      String supervisorId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'technician')
          .where('supervisorId', isEqualTo: supervisorId)
          .get();

      return snapshot.docs
          .map((doc) => UserManagementModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener técnicos del supervisor: $e');
    }
  }

  // Obtener supervisor de un técnico
  Future<UserManagementModel?> getSupervisorByTechnician(
      String technicianId) async {
    try {
      final technicianDoc =
          await _firestore.collection(_collection).doc(technicianId).get();

      if (!technicianDoc.exists) return null;

      final technicianData = technicianDoc.data() as Map<String, dynamic>;
      final supervisorId = technicianData['supervisorId'] as String?;

      if (supervisorId == null || supervisorId.isEmpty) return null;

      final supervisorDoc =
          await _firestore.collection(_collection).doc(supervisorId).get();

      if (!supervisorDoc.exists) return null;

      return UserManagementModel.fromFirestore(supervisorDoc);
    } catch (e) {
      throw Exception('Error al obtener supervisor: $e');
    }
  }

  // Estadísticas generales del sistema
  Future<Map<String, dynamic>> getSystemStats() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();

      Map<String, int> roleStats = {};
      int totalActive = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final role = data['role'] as String? ?? 'unknown';
        final isActive = data['isActive'] as bool? ?? false;

        roleStats[role] = (roleStats[role] ?? 0) + 1;
        if (isActive) totalActive++;
      }

      return {
        'totalUsers': snapshot.docs.length,
        'activeUsers': totalActive,
        'roleStats': roleStats,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas del sistema: $e');
    }
  }
  // Asignar técnico individual a supervisor
  Future<void> assignTechnicianToSupervisor(
      String supervisorId, String technicianId) async {
    try {
      final batch = _firestore.batch();

      // Obtener datos del supervisor
      final supervisorDoc =
          await _firestore.collection(_collection).doc(supervisorId).get();
      final supervisorData = supervisorDoc.data() as Map<String, dynamic>;
      final supervisorName = supervisorData['name'] ?? 'Sin nombre';
      final currentTechnicians =
          List<String>.from(supervisorData['assignedTechnicians'] ?? []);

      // Agregar técnico si no está ya asignado
      if (!currentTechnicians.contains(technicianId)) {
        currentTechnicians.add(technicianId);
      }

      // Actualizar supervisor
      batch.update(_firestore.collection(_collection).doc(supervisorId), {
        'assignedTechnicians': currentTechnicians,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar técnico
      batch.update(_firestore.collection(_collection).doc(technicianId), {
        'supervisorId': supervisorId,
        'assignedSupervisorName': supervisorName, // Para compatibilidad
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Error al asignar técnico: $e');
    }
  }

  // Obtener jerarquía del supervisor con técnicos y equipos
  Future<Map<String, dynamic>> getSupervisorHierarchy(
      String supervisorId) async {
    try {
      // Obtener supervisor
      final supervisorDoc =
          await _firestore.collection(_collection).doc(supervisorId).get();
      final supervisorData = supervisorDoc.data();

      if (supervisorData == null) {
        throw Exception('Supervisor no encontrado');
      }

      // Obtener técnicos asignados a este supervisor
      final techniciansSnapshot = await _firestore
          .collection(_collection)
          .where('supervisorId', isEqualTo: supervisorId)
          .where('role', isEqualTo: 'technician')
          .where('isActive', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> techniciansWithEquipments = [];
      int totalEquipments = 0;

      for (final techDoc in techniciansSnapshot.docs) {
        final techData = techDoc.data();
        final equipmentCount =
            (techData['assignedEquipments'] as List?)?.length ?? 0;
        totalEquipments += equipmentCount;

        techniciansWithEquipments.add({
          'id': techDoc.id,
          'name': techData['name'] ?? 'Sin nombre',
          'email': techData['email'] ?? '',
          'specialization': techData['specialization'] ?? 'General',
          'hourlyRate': (techData['hourlyRate'] ?? 0.0).toDouble(),
          'equipmentCount': equipmentCount,
        });
      }

      return {
        'supervisor': {
          'id': supervisorId,
          'name': supervisorData['name'] ?? 'Sin nombre',
          'email': supervisorData['email'] ?? '',
          'hourlyRate': (supervisorData['hourlyRate'] ?? 0.0).toDouble(),
        },
        'technicians': techniciansWithEquipments,
        'totalTechnicians': techniciansWithEquipments.length,
        'totalEquipments': totalEquipments,
      };
    } catch (e) {
      throw Exception('Error al obtener jerarquía del supervisor: $e');
    }
  }

  // Obtener conteo de técnicos asignados a un supervisor
  Future<int> getAssignedTechniciansCount(String supervisorId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('supervisorId', isEqualTo: supervisorId)
          .where('role', isEqualTo: 'technician')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error al contar técnicos asignados: $e');
      return 0;
    }
  }

  // Sincronizar relaciones supervisor-técnico
  Future<void> syncSupervisorTechnicianRelations() async {
    try {
      print('Iniciando sincronización supervisor-técnico...');

      // Obtener todos los supervisores
      final supervisorsSnapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'supervisor')
          .get();

      // Obtener todos los técnicos
      final techniciansSnapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'technician')
          .get();

      final batch = _firestore.batch();

      // Sincronizar cada supervisor
      for (final supervisorDoc in supervisorsSnapshot.docs) {
        final supervisorData = supervisorDoc.data();
        final supervisorId = supervisorDoc.id;
        final supervisorName = supervisorData['name'] ?? 'Sin nombre';

        // Encontrar técnicos que tienen este supervisor asignado
        final assignedTechnicians = <String>[];

        for (final techDoc in techniciansSnapshot.docs) {
          final techData = techDoc.data();
          final techSupervisorId = techData['supervisorId'];

          if (techSupervisorId == supervisorId &&
              techData['isActive'] == true) {
            assignedTechnicians.add(techDoc.id);

            // Asegurar que el técnico tenga el nombre del supervisor actualizado
            if (techData['assignedSupervisorName'] != supervisorName) {
              batch.update(_firestore.collection(_collection).doc(techDoc.id), {
                'assignedSupervisorName': supervisorName,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        // Actualizar la lista en el supervisor si es diferente
        final currentAssigned =
            List<String>.from(supervisorData['assignedTechnicians'] ?? []);
        if (!_listEquals(currentAssigned, assignedTechnicians)) {
          print(
              'Sincronizando supervisor $supervisorName: ${assignedTechnicians.length} técnicos');
          batch.update(_firestore.collection(_collection).doc(supervisorId), {
            'assignedTechnicians': assignedTechnicians,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      print('Sincronización completada');
    } catch (e) {
      print('Error en sincronización: $e');
      throw Exception('Error en sincronización: $e');
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
