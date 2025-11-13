// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:pm_monitor/core/models/user_management_model.dart';

// class UserManagementService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   /// Obtener usuarios por rol
//   Stream<List<UserManagementModel>> getUsersByRole(String role) {
//     return _firestore
//         .collection('users')
//         .where('role', isEqualTo: role)
//         .snapshots()
//         .map((snapshot) {
//       return snapshot.docs.map((doc) {
//         try {
//           return UserManagementModel.fromFirestore(doc);
//         } catch (e) {
//           print('Error parsing user ${doc.id}: $e');
//           return UserManagementModel.fromMap(
//             {
//               'id': doc.id,
//               'name': doc.data()['name'] ?? 'Usuario',
//               'email': doc.data()['email'] ?? '',
//               'phone': doc.data()['phone'] ?? '',
//               'role': role,
//               'isActive': doc.data()['isActive'] ?? true,
//               'createdAt': Timestamp.now(),
//             },
//             doc.id,
//           );
//         }
//       }).toList();
//     });
//   }

//   /// Obtener técnicos activos
//   Future<List<UserManagementModel>> getActiveTechnicians() async {
//     try {
//       final snapshot = await _firestore
//           .collection('users')
//           .where('role', isEqualTo: 'technician')
//           .where('isActive', isEqualTo: true)
//           .get();

//       return snapshot.docs.map((doc) {
//         try {
//           return UserManagementModel.fromFirestore(doc);
//         } catch (e) {
//           print('Error parsing technician ${doc.id}: $e');
//           return UserManagementModel.fromMap(
//             {
//               'id': doc.id,
//               'name': doc.data()['name'] ?? 'Técnico',
//               'email': doc.data()['email'] ?? '',
//               'phone': doc.data()['phone'] ?? '',
//               'role': 'technician',
//               'isActive': true,
//               'createdAt': Timestamp.now(),
//               'assignedEquipments': doc.data()['assignedEquipments'] ?? [],
//               'supervisorId': doc.data()['supervisorId'],
//             },
//             doc.id,
//           );
//         }
//       }).toList();
//     } catch (e) {
//       print('Error getting active technicians: $e');
//       return [];
//     }
//   }

//   /// Obtener supervisores activos
//   Future<List<UserManagementModel>> getActiveSupervisors() async {
//     try {
//       final snapshot = await _firestore
//           .collection('users')
//           .where('role', isEqualTo: 'supervisor')
//           .where('isActive', isEqualTo: true)
//           .get();

//       return snapshot.docs.map((doc) {
//         try {
//           return UserManagementModel.fromFirestore(doc);
//         } catch (e) {
//           print('Error parsing supervisor ${doc.id}: $e');
//           return UserManagementModel.fromMap(
//             {
//               'id': doc.id,
//               'name': doc.data()['name'] ?? 'Supervisor',
//               'email': doc.data()['email'] ?? '',
//               'phone': doc.data()['phone'] ?? '',
//               'role': 'supervisor',
//               'isActive': true,
//               'createdAt': Timestamp.now(),
//               'assignedTechnicians': doc.data()['assignedTechnicians'] ?? [],
//             },
//             doc.id,
//           );
//         }
//       }).toList();
//     } catch (e) {
//       print('Error getting active supervisors: $e');
//       return [];
//     }
//   }

//   /// Obtener supervisor de un técnico
//   Future<UserManagementModel?> getSupervisorByTechnician(
//       String technicianId) async {
//     try {
//       final techDoc =
//           await _firestore.collection('users').doc(technicianId).get();

//       if (!techDoc.exists) return null;

//       final supervisorId = techDoc.data()?['supervisorId'];
//       if (supervisorId == null || supervisorId.isEmpty) return null;

//       final supervisorDoc =
//           await _firestore.collection('users').doc(supervisorId).get();

//       if (!supervisorDoc.exists) return null;

//       return UserManagementModel.fromFirestore(supervisorDoc);
//     } catch (e) {
//       print('Error getting supervisor by technician: $e');
//       return null;
//     }
//   }

//   /// Asignar técnico a supervisor
//   Future<void> assignTechnicianToSupervisor(
//       String supervisorId, String technicianId) async {
//     try {
//       final batch = _firestore.batch();

//       // Actualizar supervisor
//       final supervisorRef = _firestore.collection('users').doc(supervisorId);
//       batch.update(supervisorRef, {
//         'assignedTechnicians': FieldValue.arrayUnion([technicianId]),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });

//       // Actualizar técnico
//       final technicianRef = _firestore.collection('users').doc(technicianId);
//       batch.update(technicianRef, {
//         'supervisorId': supervisorId,
//         'updatedAt': FieldValue.serverTimestamp(),
//       });

//       await batch.commit();
//     } catch (e) {
//       print('Error assigning technician to supervisor: $e');
//       rethrow;
//     }
//   }

//   /// Asignar múltiples técnicos a supervisor
//   Future<void> assignTechniciansToSupervisor(
//       String supervisorId, List<String> technicianIds) async {
//     try {
//       final batch = _firestore.batch();

//       // Actualizar supervisor
//       final supervisorRef = _firestore.collection('users').doc(supervisorId);
//       batch.update(supervisorRef, {
//         'assignedTechnicians': technicianIds,
//         'updatedAt': FieldValue.serverTimestamp(),
//       });

//       // Actualizar cada técnico
//       for (String technicianId in technicianIds) {
//         final technicianRef = _firestore.collection('users').doc(technicianId);
//         batch.update(technicianRef, {
//           'supervisorId': supervisorId,
//           'updatedAt': FieldValue.serverTimestamp(),
//         });
//       }

//       await batch.commit();
//     } catch (e) {
//       print('Error assigning technicians to supervisor: $e');
//       rethrow;
//     }
//   }

//   /// Remover técnico de supervisor
//   Future<void> removeTechnicianFromSupervisor(
//       String supervisorId, String technicianId) async {
//     try {
//       final batch = _firestore.batch();

//       // Actualizar supervisor
//       final supervisorRef = _firestore.collection('users').doc(supervisorId);
//       batch.update(supervisorRef, {
//         'assignedTechnicians': FieldValue.arrayRemove([technicianId]),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });

//       // Actualizar técnico
//       final technicianRef = _firestore.collection('users').doc(technicianId);
//       batch.update(technicianRef, {
//         'supervisorId': null,
//         'updatedAt': FieldValue.serverTimestamp(),
//       });

//       await batch.commit();
//     } catch (e) {
//       print('Error removing technician from supervisor: $e');
//       rethrow;
//     }
//   }

//   /// Obtener estadísticas del sistema
//   Future<Map<String, dynamic>> getSystemStats() async {
//     try {
//       final usersSnapshot = await _firestore.collection('users').get();

//       int totalTechnicians = 0;
//       int activeTechnicians = 0;
//       int totalSupervisors = 0;
//       int activeSupervisors = 0;
//       int totalClients = 0;
//       int activeClients = 0;

//       for (var doc in usersSnapshot.docs) {
//         final data = doc.data();
//         final role = data['role'] as String?;
//         final isActive = data['isActive'] as bool? ?? true;

//         if (role == 'technician') {
//           totalTechnicians++;
//           if (isActive) activeTechnicians++;
//         } else if (role == 'supervisor') {
//           totalSupervisors++;
//           if (isActive) activeSupervisors++;
//         } else if (role == 'client') {
//           totalClients++;
//           if (isActive) activeClients++;
//         }
//       }

//       return {
//         'technicians': {
//           'total': totalTechnicians,
//           'active': activeTechnicians,
//         },
//         'supervisors': {
//           'total': totalSupervisors,
//           'active': activeSupervisors,
//         },
//         'clients': {
//           'total': totalClients,
//           'active': activeClients,
//         },
//       };
//     } catch (e) {
//       print('Error getting system stats: $e');
//       return {
//         'technicians': {'total': 0, 'active': 0},
//         'supervisors': {'total': 0, 'active': 0},
//         'clients': {'total': 0, 'active': 0},
//       };
//     }
//   }

//   /// Obtener estadísticas por rol
//   Future<Map<String, int>> getStatsByRole(String role) async {
//     try {
//       final snapshot = await _firestore
//           .collection('users')
//           .where('role', isEqualTo: role)
//           .get();

//       final users = snapshot.docs
//           .map((doc) {
//             try {
//               return UserManagementModel.fromFirestore(doc);
//             } catch (e) {
//               print('Error parsing user stats ${doc.id}: $e');
//               return null;
//             }
//           })
//           .whereType<UserManagementModel>()
//           .toList();

//       int activeCount = users.where((u) => u.isActive).length;
//       int withAssignments = 0;

//       if (role == 'technician') {
//         for (var user in users) {
//           final assignedEquipment = await _firestore
//               .collection('equipments')
//               .where('assignedTechnicianId', isEqualTo: user.id)
//               .limit(1)
//               .get();

//           if (assignedEquipment.docs.isNotEmpty) {
//             withAssignments++;
//           }
//         }
//       } else if (role == 'supervisor') {
//         for (var user in users) {
//           final assignedTechnicians = await _firestore
//               .collection('users')
//               .where('role', isEqualTo: 'technician')
//               .where('supervisorId', isEqualTo: user.id)
//               .limit(1)
//               .get();

//           if (assignedTechnicians.docs.isNotEmpty) {
//             withAssignments++;
//           }
//         }
//       } else if (role == 'client') {
//         for (var user in users) {
//           if (user.clientId != null && user.clientId!.isNotEmpty) {
//             withAssignments++;
//           }
//         }
//       }

//       return {
//         'total': users.length,
//         'active': activeCount,
//         'withAssignments': withAssignments,
//       };
//     } catch (e) {
//       print('Error getting stats for role $role: $e');
//       return {
//         'total': 0,
//         'active': 0,
//         'withAssignments': 0,
//       };
//     }
//   }

//   /// Alternar estado activo/inactivo de un usuario
//   Future<void> toggleUserStatus(String userId, bool newStatus) async {
//     try {
//       await _firestore.collection('users').doc(userId).update({
//         'isActive': newStatus,
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       print('Error toggling user status: $e');
//       rethrow;
//     }
//   }

//   /// Actualizar tarifa por hora
//   Future<void> updateHourlyRate(String userId, double rate) async {
//     try {
//       await _firestore.collection('users').doc(userId).update({
//         'hourlyRate': rate,
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       print('Error updating hourly rate: $e');
//       rethrow;
//     }
//   }

//   /// Obtener un usuario por ID
//   Future<UserManagementModel?> getUserById(String userId) async {
//     try {
//       final doc = await _firestore.collection('users').doc(userId).get();

//       if (!doc.exists) {
//         return null;
//       }

//       return UserManagementModel.fromFirestore(doc);
//     } catch (e) {
//       print('Error getting user by id: $e');
//       return null;
//     }
//   }

//   /// Buscar usuarios por nombre o email
//   Future<List<UserManagementModel>> searchUsers(String query) async {
//     try {
//       final nameQuery = await _firestore
//           .collection('users')
//           .where('name', isGreaterThanOrEqualTo: query)
//           .where('name', isLessThanOrEqualTo: '$query\uf8ff')
//           .get();

//       final emailQuery = await _firestore
//           .collection('users')
//           .where('email', isGreaterThanOrEqualTo: query)
//           .where('email', isLessThanOrEqualTo: '$query\uf8ff')
//           .get();

//       final allDocs = [...nameQuery.docs, ...emailQuery.docs];
//       final uniqueDocs = <String, DocumentSnapshot>{};

//       for (var doc in allDocs) {
//         uniqueDocs[doc.id] = doc;
//       }

//       return uniqueDocs.values
//           .map((doc) {
//             try {
//               return UserManagementModel.fromFirestore(doc);
//             } catch (e) {
//               print('Error parsing search result ${doc.id}: $e');
//               return null;
//             }
//           })
//           .whereType<UserManagementModel>()
//           .toList();
//     } catch (e) {
//       print('Error searching users: $e');
//       return [];
//     }
//   }

//   /// Crear un nuevo usuario
//   Future<String> createUser(UserManagementModel user) async {
//     try {
//       final docRef = await _firestore.collection('users').add({
//         'name': user.name,
//         'email': user.email,
//         'phone': user.phone,
//         'role': user.role,
//         'isActive': user.isActive,
//         'hourlyRate': user.hourlyRate,
//         'supervisorId': user.supervisorId,
//         'clientId': user.clientId,
//         'createdAt': FieldValue.serverTimestamp(),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });

//       return docRef.id;
//     } catch (e) {
//       print('Error creating user: $e');
//       rethrow;
//     }
//   }

//   /// Actualizar un usuario
//   Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
//     try {
//       updates['updatedAt'] = FieldValue.serverTimestamp();
//       await _firestore.collection('users').doc(userId).update(updates);
//     } catch (e) {
//       print('Error updating user: $e');
//       rethrow;
//     }
//   }

//   /// Eliminar un usuario
//   Future<void> deleteUser(String userId) async {
//     try {
//       await _firestore.collection('users').doc(userId).delete();
//     } catch (e) {
//       print('Error deleting user: $e');
//       rethrow;
//     }
//   }

//   /// Asignar equipos a técnico (actualiza array completo)
//   Future<void> assignEquipmentsToTechnician(
//       String technicianId, List<String> equipmentIds) async {
//     try {
//       await _firestore.collection('users').doc(technicianId).update({
//         'assignedEquipments': equipmentIds,
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       print('Error assigning equipments to technician: $e');
//       rethrow;
//     }
//   }

//   /// Agregar un equipo a técnico (agrega al array existente)
//   Future<void> addEquipmentToTechnician(
//       String technicianId, String equipmentId) async {
//     try {
//       await _firestore.collection('users').doc(technicianId).update({
//         'assignedEquipments': FieldValue.arrayUnion([equipmentId]),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       print('Error adding equipment to technician: $e');
//       rethrow;
//     }
//   }

//   /// Remover un equipo de técnico
//   Future<void> removeEquipmentFromTechnician(
//       String technicianId, String equipmentId) async {
//     try {
//       await _firestore.collection('users').doc(technicianId).update({
//         'assignedEquipments': FieldValue.arrayRemove([equipmentId]),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       print('Error removing equipment from technician: $e');
//       rethrow;
//     }
//   }

//   /// Obtener técnicos por supervisor
//   Future<List<UserManagementModel>> getTechniciansBySupervisor(
//       String supervisorId) async {
//     try {
//       final snapshot = await _firestore
//           .collection('users')
//           .where('role', isEqualTo: 'technician')
//           .where('supervisorId', isEqualTo: supervisorId)
//           .get();

//       return snapshot.docs
//           .map((doc) {
//             try {
//               return UserManagementModel.fromFirestore(doc);
//             } catch (e) {
//               print('Error parsing technician ${doc.id}: $e');
//               return null;
//             }
//           })
//           .whereType<UserManagementModel>()
//           .toList();
//     } catch (e) {
//       print('Error getting technicians by supervisor: $e');
//       return [];
//     }
//   }

//   /// Obtener técnicos sin supervisor
//   Future<List<UserManagementModel>> getUnassignedTechnicians() async {
//     try {
//       final snapshot = await _firestore
//           .collection('users')
//           .where('role', isEqualTo: 'technician')
//           .where('isActive', isEqualTo: true)
//           .get();

//       return snapshot.docs
//           .map((doc) {
//             try {
//               return UserManagementModel.fromFirestore(doc);
//             } catch (e) {
//               print('Error parsing technician ${doc.id}: $e');
//               return null;
//             }
//           })
//           .whereType<UserManagementModel>()
//           .where(
//               (tech) => tech.supervisorId == null || tech.supervisorId!.isEmpty)
//           .toList();
//     } catch (e) {
//       print('Error getting unassigned technicians: $e');
//       return [];
//     }
//   }
// }
