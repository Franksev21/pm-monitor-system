import 'package:flutter/material.dart';
import 'package:pm_monitor/features/maintenance/screens/unified_maintenance_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/providers/auth_provider.dart';
import 'core/models/user_model.dart';
import 'config/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/admin_dashboard.dart';
import 'features/dashboard/screens/technician_dashboard.dart';
import 'features/dashboard/screens/client_dashboard.dart';

class PMMonitorApp extends StatelessWidget {
  const PMMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PM Monitor',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,

      // Configuración de localización para español
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'), // Español simplificado
        Locale('en'), // Inglés como fallback
      ],

      home: const AuthWrapper(),
      routes: {
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/technician-dashboard': (context) => TechnicianDashboard(),
        '/client-dashboard': (context) => const ClientDashboard(),
        '/unified-maintenance': (context) {
          final int initialTab =
              ModalRoute.of(context)?.settings.arguments as int? ?? 0;
          return UnifiedMaintenanceScreen(initialTab: initialTab);
        }
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Inicializar autenticación al cargar la app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initializeAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Mostrar splash screen mientras se carga
        if (authProvider.isLoading) {
          return const SplashScreen();
        }

        // Si no está autenticado, mostrar login
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        // Si está autenticado, redirigir al dashboard apropiado
        final user = authProvider.currentUser!;
        switch (user.role) {
          case UserRole.admin:
          case UserRole.supervisor:
            return const AdminDashboard();
          case UserRole.technician:
            return TechnicianDashboard();
          case UserRole.client:
            return const ClientDashboard();
        }
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.build_rounded,
                  size: 60,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'PM Monitor',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sistema de Mantenimiento Preventivo',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
