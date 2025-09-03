import 'package:flutter/material.dart';
import 'package:pm_monitor/features/auth/screens/add_maintenance_screen.dart';
import 'package:pm_monitor/features/auth/screens/global_Equipment_Inventory_Screen.dart';
import 'package:pm_monitor/features/auth/screens/client_list_screen.dart';
import 'package:pm_monitor/features/auth/screens/kpi_indicators_screen.dart';
import 'package:pm_monitor/features/auth/screens/tecnician_list_screen.dart';
import 'package:pm_monitor/features/auth/screens/user_managament_screen.dart';
import 'package:pm_monitor/features/auth/widgets/apple_style_calender.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../config/theme/app_theme.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Administrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeCard(user.name),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildDashboardCard(
                        'Equipos',
                        Icons.precision_manufacturing,
                        '124',
                        Colors.blue,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const GlobalEquipmentInventoryScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDashboardCard(
                        'Mantenimientos',
                        Icons.build_circle,
                        '67',
                        Colors.green,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AppleStyleMaintenanceCalendar(),
                            ),
                          );
                        },
                      ),
                      _buildDashboardCard(
                        'Técnicos',
                        Icons.engineering,
                        '12',
                        Colors.orange,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TechniciansListScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDashboardCard(
                        'Clientes',
                        Icons.business,
                        '8',
                        Colors.purple,
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ClientListScreen(),
                            ),
                          );
                        },
                      ),
                      // NUEVO BOTÓN - Gestión de Usuarios
                      _buildDashboardCard(
                        'Gestión de Usuarios',
                        Icons.manage_accounts,
                        'Todo',
                        Colors.teal,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const UserManagementScreen(),
                            ),
                          );
                        },
                      ),
                      // Espacio para futuro botón (Indicadores, Reportes, etc.)
                      _buildDashboardCard(
                        'Indicadores',
                        Icons.analytics,
                        'KPI',
                        Colors.indigo,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => KPIIndicatorsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeCard(String userName) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                userName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenido,',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    userName,
                    style: AppTheme.headingSmall,
                  ),
                  Text(
                    'Administrador del Sistema',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    String title,
    IconData icon,
    String value,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: AppTheme.headingMedium.copyWith(
                  color: color,
                ),
              ),
              Text(
                title,
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }
}
