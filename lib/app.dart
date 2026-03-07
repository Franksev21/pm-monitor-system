import 'package:flutter/material.dart';
import 'package:pm_monitor/features/auth/widgets/global_alert_listener.dart';
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'PANDA',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es'),
          Locale('en'),
        ],
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/admin-dashboard': (context) => const AdminDashboard(),
          '/technician-dashboard': (context) => const TechnicianDashboard(),
          '/client-dashboard': (context) => const ClientDashboard(),
          '/unified-maintenance': (context) {
            final int initialTab =
                ModalRoute.of(context)?.settings.arguments as int? ?? 0;
            return UnifiedMaintenanceScreen(initialTab: initialTab);
          }
        },
      ),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      authProvider.initializeAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const SplashScreen();
        }

        if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
          return const LoginScreen();
        }

        final user = authProvider.currentUser!;
        switch (user.role) {
          case UserRole.admin:
          case UserRole.supervisor:
            return const AdminDashboard();
          case UserRole.technician:
            return const GlobalAlertListener(child: TechnicianDashboard());
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Logo Panda
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ✅ Título
              const Text(
                'PANDA',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),

              // ✅ Subtítulo
              const Text(
                'Sistema de Mantenimiento Preventivo',
                style: TextStyle(
                  fontSize: 15,
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
