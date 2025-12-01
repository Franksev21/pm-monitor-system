import 'package:flutter/material.dart';
import 'package:pm_monitor/config/firebase_config.dart';
import 'package:pm_monitor/core/providers/client_provider.dart';
import 'package:pm_monitor/core/providers/equipment_provider.dart';
import 'package:pm_monitor/core/providers/technician_provider.dart';
import 'package:pm_monitor/core/services/equipment_type_service.dart';
import 'package:provider/provider.dart';
import 'core/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'core/providers/auth_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FirebaseConfig.initialize();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(


        
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print('Error inicializando Firebase: $e');
  }

  try {
    await initializeDateFormatting('es_ES', null);
  } catch (e) {
    print('Error inicializando localización: $e');
  }

  try {
    NotificationService notificationService = NotificationService();
    notificationService.setupMessageListeners();
  } catch (e) {
    print('Error al enviar  notificaciones: $e');
  }


  try {
    final typeService = EquipmentTypeService();
    await typeService.initializeDefaultTypes();
    print('✅ Sistema de tipos inicializado');
  } catch (e) {
    print('❌ Error inicializando tipos: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ClientProvider()..initialize()),
        ChangeNotifierProvider(
            create: (_) => EquipmentProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => TechnicianProvider()),
      ],
      child: const PMMonitorApp(),
    ),
  );
}
