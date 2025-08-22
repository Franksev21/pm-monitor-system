import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_management_model.dart';

class UserManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // Stream de usuarios por rol (incluye clientes de ambas colecciones)
  Stream<List<UserManagementModel>> getUsersByRole(String role) {
    if (role == 'client') {
      // Para clientes, usar una implementación que combine ambas colecciones
      return Stream.periodic(const Duration(seconds: 2), (i) => i)
          .asyncMap((_) => _getCombinedClients())
          .distinct()
          .asBroadcastStream();
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

  // Método para obtener clientes combinados
  Future<List<UserManagementModel>> _getCombinedClients() async {
    final List<UserManagementModel> allClients = [];

    try {
      // Obtener clientes de la colección 'users'
      final usersSnapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'client')
          .get();

      for (final doc in usersSnapshot.docs) {
        allClients.add(UserManagementModel.fromFirestore(doc));
      }

      // Obtener clientes de la colección 'clients'
      final clientsSnapshot = await _firestore.collection('clients').get();

      for (final doc in clientsSnapshot.docs) {
        allClients.add(UserManagementModel.fromFirestore(doc));
      }
    } catch (e) {
      print('Error getting combined clients: $e');
    }

    return allClients;
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

  // Obtener estadísticas por rol (incluye ambas colecciones para clientes)
  Future<Map<String, int>> getStatsByRole(String role) async {
    try {
      if (role == 'client') {
        // Para clientes, consultar ambas colecciones
        final usersClientsSnapshot = await _firestore
            .collection(_collection)
            .where('role', isEqualTo: 'client')
            .get();

        final clientsSnapshot = await _firestore.collection('clients').get();

        int totalUsers = usersClientsSnapshot.docs.length;
        int totalClients = clientsSnapshot.docs.length;
        int total = totalUsers + totalClients;

        int active = 0;
        int withAssignments = 0;

        // Contar usuarios clientes
        for (final doc in usersClientsSnapshot.docs) {
          final data = doc.data();
          if (data['isActive'] == true) active++;

          final locations = data['locations'] as List<dynamic>?;
          if (locations != null && locations.isNotEmpty) {
            withAssignments++;
          }
        }

        // Contar clientes de la colección clients (todos activos por defecto)
        active += totalClients;

        // Contar clientes con branches
        for (final doc in clientsSnapshot.docs) {
          final data = doc.data();
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
        // Para técnicos y supervisores
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
}
