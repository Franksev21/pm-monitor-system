import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pm_monitor/core/providers/client_provider.dart';
import 'package:pm_monitor/core/providers/equipment_provider.dart';
import 'package:pm_monitor/core/providers/technician_provider.dart';
import 'package:pm_monitor/core/services/equipment_type_service.dart';
import 'package:pm_monitor/core/services/notifiication_service_web.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'core/providers/auth_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Inicializar Firebase con opciones por plataforma ──
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Error inicializando Firebase: $e');
  }

  // ── Notificaciones solo en móvil ──
  if (!kIsWeb) {
    try {
      NotificationService notificationService = NotificationService();
      notificationService.setupMessageListeners();
    } catch (e) {
      debugPrint('Error al configurar notificaciones: $e');
    }
  }

  // ── Localización ──
  try {
    await initializeDateFormatting('es_ES', null);
  } catch (e) {
    debugPrint('Error inicializando localización: $e');
  }

  // ── Tipos de equipo solo en móvil ──
  if (!kIsWeb) {
    try {
      final typeService = EquipmentTypeService();
      await typeService.initializeDefaultTypes();
    } catch (e) {
      debugPrint('❌ Error inicializando tipos: $e');
    }
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
