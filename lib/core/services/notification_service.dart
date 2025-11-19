import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // ============================================
  // NOTIFICACIONES DE FALLAS (Ya existente)
  // ============================================

  Future<void> sendFaultNotifications({
    required String equipmentName,
    required String equipmentId,
    required String severity,
    required String description,
    required String reportId,
  }) async {
    // Obtener técnicos activos con tokens FCM
    QuerySnapshot techSnapshot = await _firestore
        .collection('users')
        .where('role', whereIn: ['technician', 'supervisor'])
        .where('isActive', isEqualTo: true)
        .get();

    String title = 'Nueva Falla Reportada';
    String body = '$equipmentName - Severidad: ${severity.toUpperCase()}';

    Map<String, String> data = {
      'type': 'fault_report',
      'reportId': reportId,
      'equipmentId': equipmentId,
      'severity': severity,
    };

    List<String> fcmTokens = [];

    for (var techDoc in techSnapshot.docs) {
      Map<String, dynamic> techData = techDoc.data() as Map<String, dynamic>;
      String? fcmToken = techData['fcmToken'];

      if (fcmToken != null && fcmToken.isNotEmpty) {
        fcmTokens.add(fcmToken);
      }
    }

    // Enviar push notifications
    if (fcmTokens.isNotEmpty) {
      await _sendBatchNotifications(fcmTokens, title, body, data);
    }

    // Crear notificación en pendingNotifications
    await _firestore.collection('pendingNotifications').add({
      'type': 'fault_report',
      'message':
          'FALLA REPORTADA Equipo: $equipmentName Severidad: ${severity.toUpperCase()} Descripción: $description ID: $reportId',
      'equipmentId': equipmentId,
      'severity': severity,
      'reportId': reportId,
      'createdAt': Timestamp.now(),
      'status': 'pending',
    });

    print('Notificaciones enviadas para reporte: $reportId');
  }

  // ============================================
  // ⭐ NUEVAS: NOTIFICACIONES DE MANTENIMIENTO
  // ============================================

  /// ⭐ Notificar asignación de mantenimiento a UN técnico
  Future<void> sendMaintenanceAssignedNotification({
    required String technicianId,
    required String maintenanceId,
  }) async {
    try {
      // Obtener datos del técnico
      final techDoc =
          await _firestore.collection('users').doc(technicianId).get();
      if (!techDoc.exists) {
        print('⚠️ Técnico no encontrado: $technicianId');
        return;
      }

      final techData = techDoc.data()!;
      final techName = techData['name'] ?? 'Técnico';
      final fcmToken = techData['fcmToken'] as String?;

      // Obtener datos del mantenimiento
      final maintDoc = await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .get();

      if (!maintDoc.exists) {
        print('⚠️ Mantenimiento no encontrado: $maintenanceId');
        return;
      }

      final maintData = maintDoc.data()!;
      final equipmentName = maintData['equipmentName'] ?? 'Equipo';
      final scheduledDate = (maintData['scheduledDate'] as Timestamp).toDate();

      // Crear mensaje
      String message = '''📋 NUEVO MANTENIMIENTO ASIGNADO
Equipo: $equipmentName
Fecha programada: ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledDate)}
ID: $maintenanceId''';

      // Guardar en pendingNotifications
      await _firestore.collection('pendingNotifications').add({
        'userId': technicianId,
        'type': 'maintenance_assigned',
        'title': '🔧 Nuevo Mantenimiento',
        'message': message,
        'data': {
          'maintenanceId': maintenanceId,
          'equipmentName': equipmentName,
          'scheduledDate': Timestamp.fromDate(scheduledDate),
        },
        'status': 'pending',
        'severity': 'media',
        'createdAt': Timestamp.now(),
      });

      // Enviar push notification si tiene token
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _sendSingleNotification(
          fcmToken,
          '🔧 Nuevo Mantenimiento',
          'Se te ha asignado: $equipmentName',
          {
            'type': 'maintenance_assigned',
            'maintenanceId': maintenanceId,
            'equipmentName': equipmentName,
          },
        );
      }

      print('✅ Notificación enviada a $techName');
    } catch (e) {
      print('❌ Error enviando notificación de asignación: $e');
    }
  }

  /// ⭐ Notificar asignación MASIVA de mantenimientos
  Future<void> sendBulkMaintenanceAssignedNotification({
    required String technicianId,
    required int maintenanceCount,
  }) async {
    try {
      // Obtener datos del técnico
      final techDoc =
          await _firestore.collection('users').doc(technicianId).get();
      if (!techDoc.exists) {
        print('⚠️ Técnico no encontrado: $technicianId');
        return;
      }

      final techData = techDoc.data()!;
      final techName = techData['name'] ?? 'Técnico';
      final fcmToken = techData['fcmToken'] as String?;

      // Crear mensaje
      String message = '''📋 NUEVOS MANTENIMIENTOS ASIGNADOS
Se te han asignado $maintenanceCount mantenimientos.
Revisa tu calendario para ver los detalles.''';

      // Guardar en pendingNotifications
      await _firestore.collection('pendingNotifications').add({
        'userId': technicianId,
        'type': 'bulk_maintenance_assigned',
        'title': '🔧 Nuevos Mantenimientos',
        'message': message,
        'data': {
          'maintenanceCount': maintenanceCount,
        },
        'status': 'pending',
        'severity': 'media',
        'createdAt': Timestamp.now(),
      });

      // Enviar push notification si tiene token
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _sendSingleNotification(
          fcmToken,
          '🔧 Nuevos Mantenimientos',
          'Se te han asignado $maintenanceCount mantenimientos',
          {
            'type': 'bulk_maintenance_assigned',
            'maintenanceCount': maintenanceCount.toString(),
          },
        );
      }

      print('✅ Notificación masiva enviada a $techName');
    } catch (e) {
      print('❌ Error enviando notificación masiva: $e');
    }
  }

  /// ⭐ Notificar mantenimiento completado (a supervisor/admin)
  Future<void> sendMaintenanceCompletedNotification({
    required String maintenanceId,
    required String completedBy,
  }) async {
    try {
      // Obtener datos del mantenimiento
      final maintDoc = await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .get();

      if (!maintDoc.exists) {
        print('⚠️ Mantenimiento no encontrado: $maintenanceId');
        return;
      }

      final maintData = maintDoc.data()!;
      final equipmentName = maintData['equipmentName'] ?? 'Equipo';
      final completionPercentage = maintData['completionPercentage'] ?? 0;

      // Obtener supervisores y admins
      final supervisorsSnapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['supervisor', 'admin'])
          .where('isActive', isEqualTo: true)
          .get();

      if (supervisorsSnapshot.docs.isEmpty) {
        print('⚠️ No hay supervisores/admins activos');
        return;
      }

      // Crear mensaje
      String message = '''✅ MANTENIMIENTO COMPLETADO
Equipo: $equipmentName
Completado por: $completedBy
Progreso: $completionPercentage%
ID: $maintenanceId''';

      // Enviar a cada supervisor/admin
      for (final supervisorDoc in supervisorsSnapshot.docs) {
        final supervisorData = supervisorDoc.data();
        final supervisorId = supervisorDoc.id;
        final fcmToken = supervisorData['fcmToken'] as String?;

        // Guardar en pendingNotifications
        await _firestore.collection('pendingNotifications').add({
          'userId': supervisorId,
          'type': 'maintenance_completed',
          'title': '✅ Mantenimiento Completado',
          'message': message,
          'data': {
            'maintenanceId': maintenanceId,
            'equipmentName': equipmentName,
            'completedBy': completedBy,
            'completionPercentage': completionPercentage,
          },
          'status': 'pending',
          'severity': 'baja',
          'createdAt': Timestamp.now(),
        });

        // Enviar push notification si tiene token
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _sendSingleNotification(
            fcmToken,
            '✅ Mantenimiento Completado',
            '$equipmentName - $completionPercentage%',
            {
              'type': 'maintenance_completed',
              'maintenanceId': maintenanceId,
              'equipmentName': equipmentName,
            },
          );
        }
      }

      print('✅ Notificaciones de completado enviadas');
    } catch (e) {
      print('❌ Error enviando notificación de completado: $e');
    }
  }

  /// ⭐ VERSIÓN MEJORADA: Asignación con datos del equipo
  Future<void> sendMaintenanceAssignedNotificationWithEquipment({
    required String technicianId,
    required String maintenanceId,
    required String equipmentName,
    required DateTime scheduledDate,
  }) async {
    try {
      final techDoc =
          await _firestore.collection('users').doc(technicianId).get();
      if (!techDoc.exists) return;

      final techData = techDoc.data()!;
      final fcmToken = techData['fcmToken'] as String?;

      String message = '''📋 NUEVO MANTENIMIENTO ASIGNADO
Equipo: $equipmentName
Fecha programada: ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledDate)}
ID: $maintenanceId''';

      await _firestore.collection('pendingNotifications').add({
        'userId': technicianId,
        'type': 'maintenance_assigned',
        'title': '🔧 Nuevo Mantenimiento',
        'message': message,
        'data': {
          'maintenanceId': maintenanceId,
          'equipmentName': equipmentName,
          'scheduledDate': Timestamp.fromDate(scheduledDate),
        },
        'status': 'pending',
        'severity': 'media',
        'createdAt': Timestamp.now(),
      });

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _sendSingleNotification(
          fcmToken,
          '🔧 Nuevo Mantenimiento',
          'Se te ha asignado: $equipmentName',
          {
            'type': 'maintenance_assigned',
            'maintenanceId': maintenanceId,
          },
        );
      }

      print('✅ Notificación enviada');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // ============================================
  // MÉTODOS AUXILIARES (Ya existentes)
  // ============================================

  Future<void> _sendBatchNotifications(
    List<String> tokens,
    String title,
    String body,
    Map<String, String> data,
  ) async {
    try {
      await _firestore.collection('batchNotifications').add({
        'tokens': tokens,
        'title': title,
        'body': body,
        'data': data,
        'createdAt': Timestamp.now(),
        'status': 'pending',
      });

      for (String token in tokens.take(5)) {
        try {
          await _sendSingleNotification(token, title, body, data);
        } catch (e) {
          print('Error enviando a token individual: $e');
        }
      }
    } catch (e) {
      print('Error en batch notifications: $e');
    }
  }

  Future<void> _sendSingleNotification(
    String token,
    String title,
    String body,
    Map<String, String> data,
  ) async {
    try {
      await _firestore.collection('sentNotifications').add({
        'token': token,
        'title': title,
        'body': body,
        'data': data,
        'sentAt': Timestamp.now(),
        'status': 'sent',
      });
    } catch (e) {
      print('Error enviando notificación individual: $e');
    }
  }

  // ============================================
  // CONFIGURACIÓN Y PERMISOS (Ya existentes)
  // ============================================

  Future<void> updateUserFCMToken(String userId) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': Timestamp.now(),
        });
        print('Token FCM actualizado para usuario: $userId');
      }
    } catch (e) {
      print('Error actualizando token FCM: $e');
    }
  }

  void setupMessageListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Mensaje recibido en primer plano: ${message.notification?.title}');

      final messageType = message.data['type'];

      if (messageType == 'fault_report') {
        print('Es un reporte de falla: ${message.data['reportId']}');
      } else if (messageType == 'maintenance_assigned') {
        print('Nuevo mantenimiento asignado: ${message.data['maintenanceId']}');
      } else if (messageType == 'maintenance_completed') {
        print('Mantenimiento completado: ${message.data['maintenanceId']}');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notificación clickeada: ${message.data}');

      final messageType = message.data['type'];

      if (messageType == 'fault_report') {
        String reportId = message.data['reportId'] ?? '';
        String equipmentId = message.data['equipmentId'] ?? '';
        print('Navegar a reporte: $reportId, equipo: $equipmentId');
      } else if (messageType == 'maintenance_assigned' ||
          messageType == 'maintenance_completed') {
        String maintenanceId = message.data['maintenanceId'] ?? '';
        print('Navegar a mantenimiento: $maintenanceId');
      }
    });
  }

  Future<void> requestNotificationPermissions() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('Usuario autorizó notificaciones');
      } else {
        print('Usuario denegó notificaciones');
      }
    } catch (e) {
      print('Error solicitando permisos: $e');
    }
  }
}
