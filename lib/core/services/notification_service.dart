import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

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

    // Crear notificación en pendingNotifications (como ya lo tienes funcionando)
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

  Future<void> _sendBatchNotifications(
    List<String> tokens,
    String title,
    String body,
    Map<String, String> data,
  ) async {
    try {
      // Guardar para procesamiento por Cloud Function o procesamiento local
      await _firestore.collection('batchNotifications').add({
        'tokens': tokens,
        'title': title,
        'body': body,
        'data': data,
        'createdAt': Timestamp.now(),
        'status': 'pending',
      });

      // Envío directo para tokens individuales (alternativa)
      for (String token in tokens.take(5)) {
        // Limitar a 5 para evitar rate limits
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
      // Usar HTTP API directamente si es necesario
      // Por ahora solo guardamos el log
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

  // Actualizar token FCM del usuario
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

  // Configurar listeners de mensajes
  void setupMessageListeners() {
    // Mensajes en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Mensaje recibido en primer plano: ${message.notification?.title}');

      if (message.data['type'] == 'fault_report') {
        print('Es un reporte de falla: ${message.data['reportId']}');
        // Aquí puedes mostrar una notificación local o actualizar la UI
      }
    });

    // Click en notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notificación clickeada: ${message.data}');

      if (message.data['type'] == 'fault_report') {
        String reportId = message.data['reportId'] ?? '';
        String equipmentId = message.data['equipmentId'] ?? '';

        print('Navegar a reporte: $reportId, equipo: $equipmentId');
        // Aquí implementar navegación usando tu sistema de rutas
      }
    });
  }

  // Solicitar permisos de notificación
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
