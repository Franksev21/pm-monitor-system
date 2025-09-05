import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseConfig {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
    await _configureMessaging();
  }

  static Future<void> _configureMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Solicitar permisos
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configurar handler para mensajes en background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    print('Firebase Messaging configurado');
  }
}

// Handler para mensajes en background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Mensaje en background: ${message.messageId}");

  // Procesar la notificación en background si es necesario
  if (message.data['type'] == 'fault_report') {
    print('Reporte de falla en background: ${message.data['reportId']}');
    // Aquí puedes actualizar datos locales, etc.
  }
}
