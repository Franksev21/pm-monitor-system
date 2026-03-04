import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
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
      debugPrint('Error obteniendo mantenimientos: $e');
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
      debugPrint('Error obteniendo detalles del mantenimiento: $e');
      return null;
    }
  }

  // Obtener datos del equipo
  Future<Map<String, dynamic>?> getEquipmentData(String equipmentId) async {
    try {
      debugPrint('🔍 Buscando equipo con ID: $equipmentId');

      DocumentSnapshot equipmentDoc =
          await _firestore.collection('equipments').doc(equipmentId).get();

      if (equipmentDoc.exists) {
        Map<String, dynamic> data = equipmentDoc.data() as Map<String, dynamic>;
        debugPrint('✅ Equipo encontrado: ${data['name'] ?? 'Sin nombre'}');
        return data;
      } else {
        debugPrint('⚠️ Equipo no encontrado con ID: $equipmentId');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error obteniendo datos del equipo: $e');
      return null;
    }
  }

  // Obtener progreso guardado previamente de un mantenimiento
  Future<Map<String, dynamic>?> getMaintenanceProgress(
      String maintenanceId) async {
    try {
      debugPrint(
          '🔍 Buscando progreso guardado para mantenimiento: $maintenanceId');

      DocumentSnapshot maintenanceDoc = await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .get();

      if (maintenanceDoc.exists) {
        Map<String, dynamic> data =
            maintenanceDoc.data() as Map<String, dynamic>;

        // Verificar si hay progreso guardado
        if (data.containsKey('taskCompletion') || data.containsKey('notes')) {
          debugPrint('✅ Progreso previo encontrado');
          return {
            'taskCompletion': data['taskCompletion'],
            'notes': data['notes'],
            'completionPercentage': data['completionPercentage'],
          };
        } else {
          debugPrint('ℹ️ No hay progreso previo guardado');
          return null;
        }
      } else {
        debugPrint('⚠️ Mantenimiento no encontrado');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error obteniendo progreso: $e');
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
        'startedAt': FieldValue.serverTimestamp(),
        'actualStartTime': FieldValue.serverTimestamp(),
        'startedBy': _auth.currentUser?.uid,
      });
      return true;
    } catch (e) {
      debugPrint('Error iniciando mantenimiento: $e');
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
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      });
      return true;
    } catch (e) {
      debugPrint('Error actualizando progreso: $e');
      return false;
    }
  }


  Future<List<String>> uploadMaintenancePhotos(
    String maintenanceId,
    List<File> photos,
  ) async {
    List<String> photoUrls = [];

    try {
      debugPrint(
          '📤 Subiendo ${photos.length} fotos para mantenimiento: $maintenanceId');

      for (int i = 0; i < photos.length; i++) {
        try {
          // Verificar que el archivo existe
          bool exists = await photos[i].exists();
          if (!exists) {
            debugPrint('⚠️ Foto $i no existe, saltando...');
            continue;
          }

          // Generar nombre único
          String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          String fileName = 'maintenance_${maintenanceId}_${timestamp}_$i.jpg';

          // ✅ RUTA CORRECTA: maintenance_photos/{maintenanceId}/{fileName}
          Reference ref = _storage
              .ref()
              .child('maintenance_photos')
              .child(maintenanceId)
              .child(fileName);

          debugPrint('📸 Subiendo foto ${i + 1}/${photos.length}: $fileName');
          debugPrint('📍 Ruta: maintenance_photos/$maintenanceId/$fileName');

          // Subir archivo
          UploadTask uploadTask = ref.putFile(photos[i]);

          // Esperar a que termine
          TaskSnapshot snapshot = await uploadTask;

          // Obtener URL de descarga
          String downloadUrl = await snapshot.ref.getDownloadURL();

          photoUrls.add(downloadUrl);
          debugPrint('✅ Foto ${i + 1} subida correctamente');
          debugPrint('🔗 URL: $downloadUrl');
        } catch (e) {
          debugPrint('❌ Error subiendo foto $i: $e');
          // Continuar con la siguiente foto
        }
      }

      if (photoUrls.isEmpty && photos.isNotEmpty) {
        throw Exception('No se pudo subir ninguna foto');
      }

      debugPrint(
          '✅ Total de fotos subidas: ${photoUrls.length}/${photos.length}');
      return photoUrls;
    } catch (e) {
      debugPrint('❌ Error general en uploadMaintenancePhotos: $e');
      throw Exception('Error al subir fotos: $e');
    }
  }

  Future<bool> completeMaintenance(
    String maintenanceId, {
    required Map<String, bool> taskCompletion,
    required List<File> photos,
    String? notes,
    Map<String, String>? skipReasons,
  }) async {
    try {
      debugPrint('🏁 INICIO - Completar mantenimiento: $maintenanceId');
      debugPrint('📸 Fotos recibidas: ${photos.length}');

      // ✅ Subir fotos primero
      List<String> photoUrls = [];
      if (photos.isNotEmpty) {
        debugPrint('🔄 Iniciando subida de fotos...');
        try {
          photoUrls = await uploadMaintenancePhotos(maintenanceId, photos);
          debugPrint('✅ Fotos subidas. URLs generadas: ${photoUrls.length}');
        } catch (e) {
          debugPrint('❌ Error al subir fotos: $e');
          throw Exception('Error al subir fotos: $e');
        }
      }

      // ✅ Calcular porcentaje
      int totalTasks = taskCompletion.length;
      int completedTasks =
          taskCompletion.values.where((completed) => completed).length;
      int percentage =
          totalTasks > 0 ? ((completedTasks / totalTasks) * 100).round() : 0;

      debugPrint('📊 Progreso: $completedTasks/$totalTasks = $percentage%');

      // ✅ Preparar datos de actualización
      Map<String, dynamic> updateData = {
        'status': 'executed',
        'completedDate': FieldValue.serverTimestamp(),
        'taskCompletion': taskCompletion,
        'completionPercentage': percentage,
        'photoUrls': photoUrls,
        'updatedAt': FieldValue.serverTimestamp(),
        'completedBy': _auth.currentUser?.uid,
      };

      // ✅ Agregar notas del técnico si existen
      if (notes != null && notes.isNotEmpty) {
        updateData['technicianNotes'] = notes;
      }

      // ✅ Agregar razones de omisión si existen
      if (skipReasons != null && skipReasons.isNotEmpty) {
        updateData['skipReasons'] = skipReasons;
      }

      // ✅ Actualizar el mantenimiento
      debugPrint('🔄 Actualizando Firestore...');
      await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .update(updateData);

      debugPrint('✅ Firestore actualizado exitosamente');
      debugPrint('🎉 COMPLETADO EXITOSAMENTE');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR en completeMaintenance: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return false;
    }
  }

  // Pausar mantenimiento
  Future<bool> pauseMaintenance(String maintenanceId, String reason) async {
    try {
      await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .update({
        'status': 'paused',
        'pausedAt': FieldValue.serverTimestamp(),
        'pauseReason': reason,
        'pausedBy': _auth.currentUser?.uid,
      });
      return true;
    } catch (e) {
      debugPrint('Error pausando mantenimiento: $e');
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
        'resumedAt': FieldValue.serverTimestamp(),
        'resumedBy': _auth.currentUser?.uid,
      });
      return true;
    } catch (e) {
      debugPrint('Error reanudando mantenimiento: $e');
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
        'reportedAt': FieldValue.serverTimestamp(),
        'reportedBy': _auth.currentUser?.uid,
        'status': 'open',
      });
      return true;
    } catch (e) {
      debugPrint('Error reportando problema: $e');
      return false;
    }
  }
}
