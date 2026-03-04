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
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/providers/auth_provider.dart';
import '../../../config/theme/app_theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  String? _photoUrl;

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
      setState(() {
        _photoUrl = doc.data()?['profileImageUrl'];
      });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Subiendo foto...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );

      final fileName =
          'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('profile_images/$fileName');
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(uid).update({
        'profileImageUrl': url,
      });

      if (mounted) {
        setState(() => _photoUrl = url);
        Navigator.pop(context);

        await context.read<AuthProvider>().refreshCurrentUser();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil actualizada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
                        const Color(0xFF4CAF50),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const MaintenanceManagementScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDashboardCard(
                        'Templates',
                        Icons.checklist,
                        'Tareas',
                        Colors.teal,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TaskTemplatesScreen(),
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
                      _buildDashboardCard(
                        'Indicadores',
                        Icons.analytics,
                        'KPI',
                        Colors.indigo,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const KPIIndicatorsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDashboardCard(
                        'Backup & Respaldo',
                        Icons.backup,
                        'Datos',
                        Colors.deepOrange,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const BackupManagementScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDashboardCard(
                        'Configuración',
                        Icons.settings,
                        'Sistema',
                        Colors.blueGrey,
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Configuración del sistema - Próximamente'),
                              backgroundColor: Colors.blueGrey,
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
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 13,
                    ),
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
                const Text(
                  'Bienvenido,',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Administrador del Sistema',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: AppTheme.headingMedium.copyWith(color: color),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: AppTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
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
