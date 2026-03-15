import 'package:flutter/material.dart';
import 'package:pm_monitor/features/maintenance/screens/completed_maintenance_screen.dart';
import 'package:pm_monitor/features/maintenance/screens/inprogress_maintenance_screen.dart';
import 'package:pm_monitor/features/maintenance/screens/pending_maintenances_screen.dart';
import 'package:pm_monitor/features/technician/screens/technician_alerts_screen.dart';
import 'package:pm_monitor/features/technician/screens/technician_equipment_list_screen.dart';
import 'package:pm_monitor/features/technician/screens/technician_faults_screen.dart';
import 'package:pm_monitor/features/technician/screens/technician_notification_screen.dart';
import 'package:pm_monitor/features/technician/screens/technician_profile_screen.dart';
import 'package:pm_monitor/features/technician/screens/technician_calendar_list_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int pendingCount = 0;
  int completedCount = 0;
  int inProgressCount = 0;
  int emergenciesCount = 0;
  int completedTodayCount = 0;
  int pendingTodayCount = 0;
  int totalEquipments = 0;
  int notificationCount = 0;

  // ✅ Foto asignada por el admin
  String? technicianPhotoUrl;

  bool isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _loadMaintenanceCounts();
    _loadEquipmentCount();
    _loadNotifications();
    _loadTechnicianPhoto();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ✅ NUEVO: Cargar foto asignada por el admin desde Firestore
  Future<void> _loadTechnicianPhoto() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        // ✅ Leer 'photoUrl' (campo guardado por el admin) con fallback a 'profileImageUrl'
        final photo = data?['photoUrl'] ?? data?['profileImageUrl'];
        setState(() {
          technicianPhotoUrl = photo;
        });
      }
    } catch (e) {
      debugPrint('❌ Error cargando foto del técnico: $e');
    }
  }

  Future<void> _loadMaintenanceCounts() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final allMaintenances = await _firestore
          .collection('maintenanceSchedules')
          .where('technicianId', isEqualTo: currentUserId)
          .get();

      int pending = 0;
      int completed = 0;
      int inProgress = 0;
      int emergencies = 0;
      int completedToday = 0;
      int pendingToday = 0;

      for (var doc in allMaintenances.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        final type = data['type'] ?? '';

        if (status == 'executed' || status == 'completed') {
          completed++;
          DateTime? completedDate;
          if (data['completedAt'] != null) {
            completedDate = (data['completedAt'] as Timestamp).toDate();
          } else if (data['updatedAt'] != null) {
            completedDate = (data['updatedAt'] as Timestamp).toDate();
          }
          if (completedDate != null &&
              completedDate.isAfter(startOfDay) &&
              completedDate.isBefore(endOfDay)) {
            completedToday++;
          }
        } else if (status == 'assigned') {
          final hasStarted = data['startedAt'] != null;
          final hasCompleted = data['completedAt'] != null;

          if (hasStarted && !hasCompleted) {
            inProgress++;
          } else {
            pending++;
            if (data['scheduledDate'] != null) {
              final scheduledDate =
                  (data['scheduledDate'] as Timestamp).toDate();
              if (scheduledDate.isAfter(startOfDay) &&
                  scheduledDate.isBefore(endOfDay)) {
                pendingToday++;
              }
            }
          }
        }

        if (type == 'emergency' &&
            (status == 'assigned' || status == 'generated')) {
          emergencies++;
        }
      }

      if (mounted) {
        setState(() {
          pendingCount = pending;
          completedCount = completed;
          inProgressCount = inProgress;
          emergenciesCount = emergencies;
          completedTodayCount = completedToday;
          pendingTodayCount = pendingToday;
          isLoadingCounts = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error cargando conteos: $e');
      if (mounted) setState(() => isLoadingCounts = false);
    }
  }

  Future<void> _loadEquipmentCount() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final equipments = await _firestore
          .collection('equipments')
          .where('assignedTechnicianId', isEqualTo: currentUserId)
          .get();

      if (mounted) setState(() => totalEquipments = equipments.docs.length);
    } catch (e) {
      debugPrint('❌ Error cargando equipos: $e');
    }
  }
Future<void> _loadNotifications() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final notifications = await _firestore
          .collection('alerts')
          .where('technicianId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      if (mounted) {
        setState(() => notificationCount = notifications.docs.length);
      }
    } catch (e) {
      debugPrint('❌ Error cargando notificaciones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadMaintenanceCounts();
            await _loadEquipmentCount();
            await _loadNotifications();
            await _loadTechnicianPhoto();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Datos actualizados'),
                  duration: Duration(seconds: 1),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTechnicianHeader(context),
                const SizedBox(height: 20),
                _buildQuickStats(),
                const SizedBox(height: 20),
                _buildQuickActions(context),
                const SizedBox(height: 20),
                _buildMaintenanceStats(context),
                const SizedBox(height: 20),
                _buildProgressCard(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFAB(context),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Dashboard Técnico'),
      backgroundColor: const Color(0xFF4285F4),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => _showNotifications(context),
            ),
            if (notificationCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () async {
            setState(() => isLoadingCounts = true);
            await _loadMaintenanceCounts();
            await _loadEquipmentCount();
            await _loadNotifications();
            await _loadTechnicianPhoto();
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'logout') _showLogoutConfirmation(context);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTechnicianHeader(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;

        if (user == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4285F4), Color(0xFF34A853)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Cargando...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final efficiency = (completedCount + pendingCount) > 0
            ? ((completedCount / (completedCount + pendingCount)) * 100).toInt()
            : 100;

        // ✅ Prioridad: foto cargada de Firestore → foto en AuthProvider → iniciales
        final photoToShow = technicianPhotoUrl ??
            (user.profileImageUrl?.isNotEmpty == true
                ? user.profileImageUrl
                : null);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4285F4), Color(0xFF34A853)],
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
              // ✅ Avatar solo lectura — sin botón de cámara
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                backgroundImage:
                    photoToShow != null ? NetworkImage(photoToShow) : null,
                onBackgroundImageError: photoToShow != null ? (_, __) {} : null,
                child: photoToShow == null
                    ? Text(
                        user.initials,
                        style: const TextStyle(
                          color: Color(0xFF4285F4),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Técnico · $efficiency% eficiencia',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: isLoadingCounts ? '-' : '$pendingTodayCount',
            label: 'Pendientes Hoy',
            color: Colors.orange,
            icon: Icons.pending_actions,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: isLoadingCounts ? '-' : '$inProgressCount',
            label: 'En Proceso',
            color: Colors.blue,
            icon: Icons.engineering,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: isLoadingCounts ? '-' : '$completedTodayCount',
            label: 'Completados',
            color: Colors.green,
            icon: Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acciones Principales',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.calendar_today,
                    label: 'Mi Calendario',
                    subtitle: 'Ver agenda',
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TechnicianCalendarScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.build_circle,
                    label: 'Mis Equipos',
                    subtitle: 'Asignados',
                    color: Colors.purple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const TechnicianEquipmentListScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaintenanceStats(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Resumen de Mantenimientos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            GestureDetector(
              onTap: () => _navigateToPending(context),
              child: const Text(
                'Ver todo',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTaskCard(
                context,
                'Pendientes',
                Icons.pending_actions,
                isLoadingCounts ? '-' : '$pendingCount',
                Colors.orange,
                subtitle: 'Total',
                onTap: () => _navigateToPending(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTaskCard(
                context,
                'En Proceso',
                Icons.engineering,
                isLoadingCounts ? '-' : '$inProgressCount',
                Colors.blue,
                subtitle: 'Total',
                onTap: () => _navigateToInProgress(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTaskCard(
                context,
                'Completados',
                Icons.check_circle,
                isLoadingCounts ? '-' : '$completedCount',
                Colors.green,
                subtitle: 'Total',
                onTap: () => _navigateToCompleted(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTaskCard(
                context,
                'Equipos',
                Icons.devices,
                isLoadingCounts ? '-' : '$totalEquipments',
                Colors.purple,
                subtitle: 'Asignados',
                onTap: () => _navigateToEquipments(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTaskCard(
                context,
                'Fallas',
                Icons.warning,
                isLoadingCounts ? '-' : '$emergenciesCount',
                Colors.red,
                subtitle: 'Reportes activos',
                onTap: () => _navigateToTheFaultsReportScreen(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    String title,
    IconData icon,
    String count,
    Color color, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                count,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final totalToday = pendingTodayCount + completedTodayCount;
    final progress = totalToday > 0 ? completedTodayCount / totalToday : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Progreso del Día',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: progress > 0.7
                        ? Colors.green
                        : progress > 0.4
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 0.7
                      ? Colors.green
                      : progress > 0.4
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isLoadingCounts
                      ? 'Cargando...'
                      : '$completedTodayCount de $totalToday mantenimientos',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  isLoadingCounts ? '' : '$pendingTodayCount restantes',
                  style: TextStyle(
                    fontSize: 12,
                    color: pendingTodayCount > 0 ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showQuickActionMenu(context),
      backgroundColor: const Color(0xFF4285F4),
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      selectedItemColor: const Color(0xFF4285F4),
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Tareas'),
        BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Equipos'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
      onTap: (index) {
        switch (index) {
          case 1:
            _navigateToPending(context);
            break;
          case 2:
            _navigateToEquipments(context);
            break;
          case 3:
            _navigateToProfile(context);
            break;
        }
      },
    );
  }

  void _navigateToPending(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PendingMaintenancesScreen()),
      );

  void _navigateToInProgress(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InProgressMaintenancesScreen()),
      );

  void _navigateToCompleted(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CompletedMaintenancesScreen()),
      );

  void _navigateToEquipments(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const TechnicianEquipmentListScreen()),
      );

  void _navigateToTheFaultsReportScreen(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TechnicianFaultsScreen()),
      );

  void _navigateToProfile(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TechnicianProfileScreen()),
      );

  void _showNotifications(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const TechnicianAlertsScreen()),
      );

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Cerrar Sesión'),
          ],
        ),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
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
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  void _showQuickActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.blue),
              title: const Text('Ver Mi Calendario'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TechnicianCalendarScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.build_circle, color: Colors.purple),
              title: const Text('Ver Mis Equipos'),
              onTap: () {
                Navigator.pop(context);
                _navigateToEquipments(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('Reportar Falla'),
              onTap: () {
                Navigator.pop(context);
                _navigateToTheFaultsReportScreen(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Ver Completados'),
              onTap: () {
                Navigator.pop(context);
                _navigateToCompleted(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
