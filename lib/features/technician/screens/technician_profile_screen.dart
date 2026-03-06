import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../core/providers/auth_provider.dart';

class TechnicianProfileScreen extends StatefulWidget {
  const TechnicianProfileScreen({super.key});

  @override
  State<TechnicianProfileScreen> createState() =>
      _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int totalMaintenances = 0;
  int completedMaintenances = 0;
  int totalEquipments = 0;
  double efficiency = 0.0;
  double rating = 0.0;
  String technicianType = '';
  double hourlyRate = 0.0;
  String? photoUrl;
  bool isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadTechnicianStats();
  }

  Future<void> _loadTechnicianStats() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        technicianType = userData?['technicianType'] ?? 'General';
        rating = (userData?['rating'] ?? 0.0).toDouble();
        hourlyRate = (userData?['hourlyRate'] ?? 0.0).toDouble();
        // ✅ Leer photoUrl asignada por el admin
        photoUrl = userData?['photoUrl'] ?? userData?['profileImageUrl'];
      }

      final maintenances = await _firestore
          .collection('maintenanceSchedules')
          .where('technicianId', isEqualTo: currentUserId)
          .get();

      final completed = maintenances.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;

      final equipments = await _firestore
          .collection('equipments')
          .where('assignedTechnicianId', isEqualTo: currentUserId)
          .get();

      final efficiencyValue = maintenances.docs.isNotEmpty
          ? (completed / maintenances.docs.length) * 100
          : 0.0;

      if (mounted) {
        setState(() {
          totalMaintenances = maintenances.docs.length;
          completedMaintenances = completed;
          totalEquipments = equipments.docs.length;
          efficiency = efficiencyValue;
          isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;

          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _loadTechnicianStats,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildProfileHeader(user),
                  const SizedBox(height: 20),
                  _buildStatsSection(),
                  const SizedBox(height: 20),
                  _buildPersonalInfoSection(user),
                  const SizedBox(height: 20),
                  _buildOptionsSection(context),
                  const SizedBox(height: 20),
                  _buildLogoutButton(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(user) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4285F4), Color(0xFF34A853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          // ✅ Avatar solo lectura — sin botón de cámara
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                  ? NetworkImage(photoUrl!)
                  : null,
              child: photoUrl == null || photoUrl!.isEmpty
                  ? Text(
                      user.initials,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4285F4),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.email,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.engineering, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  user.roleDisplayName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart, color: Color(0xFF4285F4), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Estadísticas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (isLoadingStats)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Column(
                  children: [
                    _buildStatItem(
                      icon: Icons.star,
                      label: 'Valoración',
                      value: '${rating.toStringAsFixed(1)} ⭐',
                      color: rating >= 4.5
                          ? Colors.green
                          : rating >= 3.5
                              ? Colors.orange
                              : Colors.red,
                    ),
                    const Divider(height: 24),
                    _buildStatItem(
                      icon: Icons.trending_up,
                      label: 'Eficiencia',
                      value: '${efficiency.toInt()}%',
                      color: efficiency >= 80
                          ? Colors.green
                          : efficiency >= 60
                              ? Colors.orange
                              : Colors.red,
                    ),
                    const Divider(height: 24),
                    _buildStatItem(
                      icon: Icons.build,
                      label: 'Total Mantenimientos',
                      value: '$totalMaintenances',
                      color: const Color(0xFF4285F4),
                    ),
                    const Divider(height: 24),
                    _buildStatItem(
                      icon: Icons.check_circle,
                      label: 'Completados',
                      value: '$completedMaintenances',
                      color: Colors.green,
                    ),
                    const Divider(height: 24),
                    _buildStatItem(
                      icon: Icons.devices,
                      label: 'Equipos Asignados',
                      value: '$totalEquipments',
                      color: Colors.purple,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection(user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person, color: Color(0xFF4285F4), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Información Personal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildInfoRow(
                icon: Icons.badge,
                label: 'Nombre Completo',
                value: user.name,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.email,
                label: 'Correo Electrónico',
                value: user.email,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.work,
                label: 'Rol',
                value: user.roleDisplayName,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.engineering,
                label: 'Tipo de Técnico',
                value: technicianType.isNotEmpty ? technicianType : 'General',
              ),
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.attach_money,
                label: 'Tarifa por Hora',
                value: hourlyRate > 0
                    ? '\$${hourlyRate.toStringAsFixed(2)}/hr'
                    : 'No definida',
              ),
              if (user.phone != null && user.phone.isNotEmpty) ...[
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.phone,
                  label: 'Teléfono',
                  value: user.phone,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildOptionTile(
              icon: Icons.settings,
              title: 'Configuración',
              subtitle: 'Ajustes de la aplicación',
              onTap: () => _showComingSoon(context, 'Configuración'),
            ),
            const Divider(height: 1),
            _buildOptionTile(
              icon: Icons.notifications,
              title: 'Notificaciones',
              subtitle: 'Gestionar alertas y avisos',
              onTap: () => _showComingSoon(context, 'Notificaciones'),
            ),
            const Divider(height: 1),
            _buildOptionTile(
              icon: Icons.help,
              title: 'Ayuda y Soporte',
              subtitle: '¿Necesitas asistencia?',
              onTap: () => _showComingSoon(context, 'Ayuda'),
            ),
            const Divider(height: 1),
            _buildOptionTile(
              icon: Icons.info,
              title: 'Acerca de',
              subtitle: 'Versión 1.0.0',
              onTap: () => _showAboutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF4285F4).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF4285F4), size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => _showLogoutConfirmation(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 8),
              Text(
                'Cerrar Sesión',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Cerrar Sesión'),
          ],
        ),
        content: const Text(
          '¿Estás seguro que deseas cerrar sesión?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature estará disponible pronto'),
        backgroundColor: const Color(0xFF4285F4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info, color: Color(0xFF4285F4)),
            SizedBox(width: 12),
            Text('Acerca de'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PANDA MT',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Versión 1.0.0'),
            const SizedBox(height: 16),
            Text(
              'Sistema de gestión de mantenimiento preventivo para técnicos y clientes.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              '© 2025 Cold Systems Company. Todos los derechos reservados.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
