import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class MaintenanceExecutionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Obtener mantenimientos asignados al técnico actual
  Future<List<Map<String, dynamic>>> getAssignedMaintenances() async {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('maintenanceSchedules')
          .where('technicianId', isEqualTo: currentUserId)
          .where('status', whereIn: ['scheduled', 'in_progress'])
          .orderBy('scheduledDate')
          .get();

      List<Map<String, dynamic>> maintenances = [];

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Obtener información del equipo
        String? equipmentId = data['equipmentId'];
        Map<String, dynamic>? equipmentData;

        if (equipmentId != null) {
          DocumentSnapshot equipmentDoc =
              await _firestore.collection('equipments').doc(equipmentId).get();

          if (equipmentDoc.exists) {
            equipmentData = equipmentDoc.data() as Map<String, dynamic>;
          }
        }

        // Obtener información del cliente
        String? clientId = data['clientId'];
        Map<String, dynamic>? clientData;

        if (clientId != null) {
          DocumentSnapshot clientDoc =
              await _firestore.collection('clients').doc(clientId).get();

          if (clientDoc.exists) {
            clientData = clientDoc.data() as Map<String, dynamic>;
          }
        }

        maintenances.add({
          'id': doc.id,
          ...data,
          'equipmentData': equipmentData,
          'clientData': clientData,
          'equipmentName': equipmentData?['name'] ?? 'Equipo sin nombre',
          'clientName': clientData?['name'] ?? 'Cliente sin nombre',
          'location': equipmentData?['location'] ?? data['location'],
        });
      }

      return maintenances;
    } catch (e) {
      print('Error obteniendo mantenimientos: $e');
      return [];
    }
  }

  // Obtener detalles completos de un mantenimiento
  Future<Map<String, dynamic>?> getMaintenanceDetails(
      String maintenanceId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .get();

      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Obtener información del equipo
      String? equipmentId = data['equipmentId'];
      if (equipmentId != null) {
        DocumentSnapshot equipmentDoc =
            await _firestore.collection('equipments').doc(equipmentId).get();

        if (equipmentDoc.exists) {
          data['equipmentData'] = equipmentDoc.data();
        }
      }

      return {'id': doc.id, ...data};
    } catch (e) {
      print('Error obteniendo detalles del mantenimiento: $e');
      return null;
    }
  }

  // Iniciar mantenimiento
  Future<bool> startMaintenance(String maintenanceId) async {
    try {
      await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .update({
        'status': 'in_progress',
        'startedAt': Timestamp.now(),
        'actualStartTime': Timestamp.now(),
        'startedBy': _auth.currentUser?.uid,
      });
      return true;
    } catch (e) {
      print('Error iniciando mantenimiento: $e');
      return false;
    }
  }

  // Actualizar progreso de tareas
  Future<bool> updateTaskProgress(
      String maintenanceId, Map<String, bool> taskCompletion) async {
    try {
      // Calcular porcentaje de completado
      int totalTasks = taskCompletion.length;
      int completedTasks =
          taskCompletion.values.where((completed) => completed).length;
      double percentage =
          totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0;

      await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .update({
        'taskCompletion': taskCompletion,
        'completionPercentage': percentage,
        'lastUpdated': Timestamp.now(),
        'updatedBy': _auth.currentUser?.uid,
      });
      return true;
    } catch (e) {
      print('Error actualizando progreso: $e');
      return false;
    }
  }

  // Subir fotos a Firebase Storage
  Future<List<String>> uploadMaintenancePhotos(
      String maintenanceId, List<File> photos) async {
    List<String> photoUrls = [];

    try {
      for (int i = 0; i < photos.length; i++) {
        String fileName =
            'maintenance_$maintenanceId/photo_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference ref =
            _storage.ref().child('maintenance_photos').child(fileName);

        UploadTask uploadTask = ref.putFile(photos[i]);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        photoUrls.add(downloadUrl);
      }
    } catch (e) {
      print('Error subiendo fotos: $e');
      throw Exception('Error al subir fotos: $e');
    }

    return photoUrls;
  }

  // Completar mantenimiento
  Future<bool> completeMaintenance(
    String maintenanceId, {
    required Map<String, bool> taskCompletion,
    required List<File> photos,
    String? notes,
    Map<String, dynamic>? equipmentData,
  }) async {
    try {
      // Subir fotos primero
      List<String> photoUrls = [];
      if (photos.isNotEmpty) {
        photoUrls = await uploadMaintenancePhotos(maintenanceId, photos);
      }

      int totalTasks = taskCompletion.length;
      int completedTasks =
          taskCompletion.values.where((completed) => completed).length;
      double percentage =
          totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0;

      // Actualizar el mantenimiento
      await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
        'taskCompletion': taskCompletion,
        'completionPercentage': percentage,
        'photoUrls': photoUrls,
        'notes': notes,
        'equipmentDataUpdated': equipmentData,
        'completedBy': _auth.currentUser?.uid,
      });

      // Si hay datos de equipo actualizados, guardarlos
      if (equipmentData != null) {
        String? equipmentId = equipmentData['equipmentId'];
        if (equipmentId != null) {
          await _updateEquipmentData(equipmentId, equipmentData);
        }
      }

      // Crear registro de historial
      await _createMaintenanceHistory(
          maintenanceId, equipmentData?['equipmentId']);

      return true;
    } catch (e) {
      print('Error completando mantenimiento: $e');
      return false;
    }
  }

  // Actualizar datos del equipo
  Future<void> _updateEquipmentData(
      String equipmentId, Map<String, dynamic> equipmentData) async {
    try {
      Map<String, dynamic> updateData = {
        'lastMaintenanceDate': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      // Solo actualizar campos que no estén vacíos
      if (equipmentData['capacity']?.toString().isNotEmpty == true) {
        updateData['capacity'] = equipmentData['capacity'];
      }
      if (equipmentData['model']?.toString().isNotEmpty == true) {
        updateData['model'] = equipmentData['model'];
      }
      if (equipmentData['brand']?.toString().isNotEmpty == true) {
        updateData['brand'] = equipmentData['brand'];
      }
      if (equipmentData['location']?.toString().isNotEmpty == true) {
        updateData['location'] = equipmentData['location'];
      }
      if (equipmentData['condition']?.toString().isNotEmpty == true) {
        updateData['condition'] = equipmentData['condition'];
      }

      await _firestore
          .collection('equipments')
          .doc(equipmentId)
          .update(updateData);
    } catch (e) {
      print('Error actualizando equipo: $e');
    }
  }

  // Crear registro de historial de mantenimiento
  Future<void> _createMaintenanceHistory(
      String maintenanceId, String? equipmentId) async {
    if (equipmentId == null) return;

    try {
      await _firestore.collection('maintenanceHistory').add({
        'maintenanceId': maintenanceId,
        'equipmentId': equipmentId,
        'technicianId': _auth.currentUser?.uid,
        'completedAt': Timestamp.now(),
        'type': 'preventive',
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error creando historial: $e');
    }
  }

  // Obtener tareas predeterminadas para un tipo de equipo
  Future<List<String>> getDefaultTasks(String equipmentType) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('maintenanceTemplates')
          .doc(equipmentType)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['defaultTasks'] ?? []);
      }
    } catch (e) {
      print('Error obteniendo tareas predeterminadas: $e');
    }

    // Tareas predeterminadas si no hay template
    return [
      'Verificar estado general del equipo',
      'Limpiar filtros',
      'Revisar conexiones eléctricas',
      'Verificar refrigerante',
      'Comprobar funcionamiento',
      'Documentar observaciones',
    ];
  }

  // Pausar mantenimiento
  Future<bool> pauseMaintenance(String maintenanceId, String reason) async {
    try {
      await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .update({
        'status': 'paused',
        'pausedAt': Timestamp.now(),
        'pauseReason': reason,
        'pausedBy': _auth.currentUser?.uid,
      });
      return true;
    } catch (e) {
      print('Error pausando mantenimiento: $e');
      return false;
    }
  }

  // Reanudar mantenimiento
  Future<bool> resumeMaintenance(String maintenanceId) async {
    try {
      await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .update({
        'status': 'in_progress',
        'resumedAt': Timestamp.now(),
        'resumedBy': _auth.currentUser?.uid,
      });
      return true;
    } catch (e) {
      print('Error reanudando mantenimiento: $e');
      return false;
    }
  }

  // Reportar problema durante mantenimiento
  Future<bool> reportIssue(
      String maintenanceId, String issue, String severity) async {
    try {
      await _firestore.collection('maintenanceIssues').add({
        'maintenanceId': maintenanceId,
        'issue': issue,
        'severity': severity,
        'reportedAt': Timestamp.now(),
        'reportedBy': _auth.currentUser?.uid,
        'status': 'open',
      });
      return true;
    } catch (e) {
      print('Error reportando problema: $e');
      return false;
    }
  }
}
