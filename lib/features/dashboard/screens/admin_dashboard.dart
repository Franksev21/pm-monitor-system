import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pm_monitor/features/maintenance/screens/global_Equipment_Inventory_Screen.dart';
import 'package:pm_monitor/features/client/screens/client_list_screen.dart';
import 'package:pm_monitor/features/others/backup_management_screen.dart';
import 'package:pm_monitor/features/others/screens/kpi_indicators_screen.dart';
import 'package:pm_monitor/features/others/screens/task_template_screen.dart';
import 'package:pm_monitor/features/technician/screens/tecnician_list_screen.dart';
import 'package:pm_monitor/features/auth/screens/user_managament_screen.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_management_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../config/theme/app_theme.dart';

// Solo importar image_picker y dart:io en móvil
import 'admin_dashboard_upload_stub.dart'
    if (dart.library.io) 'admin_dashboard_upload_mobile.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _photoUrl;
  int _selectedIndex = 0; // para el sidebar en web

  // Items del menú
  final List<_MenuItem> _menuItems = [
    _MenuItem('Dashboard', Icons.dashboard, Colors.blue),
    _MenuItem('Equipos', Icons.precision_manufacturing, Colors.blue),
    _MenuItem('Mantenimientos', Icons.build_circle, Color(0xFF4CAF50)),
    _MenuItem('Templates', Icons.checklist, Colors.teal),
    _MenuItem('Técnicos', Icons.engineering, Colors.orange),
    _MenuItem('Clientes', Icons.business, Colors.purple),
    _MenuItem('Usuarios', Icons.manage_accounts, Colors.teal),
    _MenuItem('Indicadores', Icons.analytics, Colors.indigo),
    _MenuItem('Backup', Icons.backup, Colors.deepOrange),
    _MenuItem('Configuración', Icons.settings, Colors.blueGrey),
  ];

  @override
  void initState() {
    super.initState();
    _loadPhotoUrl();
  }

  Future<void> _loadPhotoUrl() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (mounted) {
      setState(() => _photoUrl = doc.data()?['profileImageUrl']);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sube la foto desde la app móvil'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    await pickAndUploadPhotoMobile(
      context: context,
      auth: _auth,
      storage: _storage,
      firestore: _firestore,
      onSuccess: (url) {
        setState(() => _photoUrl = url);
        context.read<AuthProvider>().refreshCurrentUser();
      },
    );
  }

  void _navigateTo(int index, BuildContext context) {
    setState(() => _selectedIndex = index);
    if (!kIsWeb) Navigator.pop(context); // cierra drawer en móvil

    final routes = [
      null, // Dashboard — no navega
      () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const GlobalEquipmentInventoryScreen())),
      () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const MaintenanceManagementScreen())),
      () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const TaskTemplatesScreen())),
      () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const TechniciansListScreen())),
      () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ClientListScreen())),
      () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const UserManagementScreen())),
      () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const KPIIndicatorsScreen())),
      () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const BackupManagementScreen())),
      null, // Configuración
    ];

    if (index > 0 && routes[index] != null) {
      routes[index]!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (kIsWeb && constraints.maxWidth > 800) {
          return _buildWebLayout(context);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  WEB LAYOUT — Sidebar + Content
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // ── Sidebar ──
          Container(
            width: 240,
            color: const Color(0xFF1A1F36),
            child: Column(
              children: [
                // Logo / Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.build_circle,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'PANDA MT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),

                // Menu items
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      final isSelected = _selectedIndex == index;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(item.icon,
                              color: isSelected ? item.color : Colors.white60,
                              size: 20),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white60,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () => _navigateTo(index, context),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    },
                  ),
                ),

                // Logout
                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.logout, color: Colors.white60, size: 20),
                  title: const Text('Cerrar Sesión',
                      style: TextStyle(color: Colors.white60, fontSize: 14)),
                  onTap: () => _logout(context),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final user = authProvider.currentUser!;
                return Column(
                  children: [
                    // Top bar
                    Container(
                      height: 64,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text(
                            _menuItems[_selectedIndex].title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1F36),
                            ),
                          ),
                          const Spacer(),
                          // Avatar
                          GestureDetector(
                            onTap: _pickAndUploadPhoto,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF1976D2),
                              backgroundImage:
                                  (_photoUrl != null && _photoUrl!.isNotEmpty)
                                      ? NetworkImage(_photoUrl!)
                                      : null,
                              child: (_photoUrl == null || _photoUrl!.isEmpty)
                                  ? Text(
                                      user.name[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(user.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1F36))),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Dashboard content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWelcomeCard(user.name),
                            const SizedBox(height: 24),
                            // Grid más compacto para web
                            GridView.count(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 3.0,
                              children: _buildCards(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  MOBILE LAYOUT — igual que antes
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
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
                    children: _buildCards(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CARDS compartidas
  // ─────────────────────────────────────────────────────────────────────────
  List<Widget> _buildCards(BuildContext context) {
    return [
      _buildDashboardCard('Equipos', Icons.precision_manufacturing, '124',
          Colors.blue, () => _navigateTo(1, context)),
      _buildDashboardCard('Mantenimientos', Icons.build_circle, '67',
          const Color(0xFF4CAF50), () => _navigateTo(2, context)),
      _buildDashboardCard('Templates', Icons.checklist, 'Tareas', Colors.teal,
          () => _navigateTo(3, context)),
      _buildDashboardCard('Técnicos', Icons.engineering, '12', Colors.orange,
          () => _navigateTo(4, context)),
      _buildDashboardCard('Clientes', Icons.business, '8', Colors.purple,
          () => _navigateTo(5, context)),
      _buildDashboardCard('Gestión de Usuarios', Icons.manage_accounts, 'Todo',
          Colors.teal, () => _navigateTo(6, context)),
      _buildDashboardCard('Indicadores', Icons.analytics, 'KPI', Colors.indigo,
          () => _navigateTo(7, context)),
      _buildDashboardCard('Backup & Respaldo', Icons.backup, 'Datos',
          Colors.deepOrange, () => _navigateTo(8, context)),
      _buildDashboardCard(
          'Configuración', Icons.settings, 'Sistema', Colors.blueGrey, () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración del sistema - Próximamente'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }),
    ];
  }

  Widget _buildWelcomeCard(String userName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF34A853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickAndUploadPhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                      ? NetworkImage(_photoUrl!)
                      : null,
                  child: (_photoUrl == null || _photoUrl!.isEmpty)
                      ? Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF1976D2),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bienvenido,',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(userName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Administrador del Sistema',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(String title, IconData icon, String value,
      Color color, VoidCallback onTap) {
    if (kIsWeb) {
      return Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        title,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: AppTheme.headingMedium.copyWith(color: color)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(title,
                    style: AppTheme.bodyMedium,
                    textAlign: TextAlign.center,
                    maxLines: 2),
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

class _MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  const _MenuItem(this.title, this.icon, this.color);
}
