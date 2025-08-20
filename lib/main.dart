import 'package:flutter/material.dart';
import 'package:pm_monitor/core/providers/client_provider.dart';
import 'package:pm_monitor/core/providers/equipment_provider.dart';
import 'package:pm_monitor/core/providers/tecnician_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/providers/auth_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print(e);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ClientProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => EquipmentProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => TechnicianProvider()),
      ],
      child: const PMMonitorApp(),
    ),
  );
}
