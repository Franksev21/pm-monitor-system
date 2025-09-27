import 'package:flutter/material.dart';
import 'package:pm_monitor/features/maintenance/screens/completed_maintenance_screen.dart';
import 'package:pm_monitor/features/maintenance/screens/pending_maintenances_screen.dart';
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

  // Conteos dinámicos
  int pendingCount = 0;
  int completedCount = 0;
  int inProgressCount = 0;
  int emergenciesCount = 0;
  int completedTodayCount = 0;
  int pendingTodayCount = 0;
  int totalEquipments = 0;
  int notificationCount = 0;

  bool isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    print('=== DASHBOARD TÉCNICO INICIADO ===');

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
    _loadMaintenanceCounts();
    _loadEquipmentCount();
    _loadNotifications();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMaintenanceCounts() async {
    print('Iniciando carga de conteos...');
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      print('No hay usuario autenticado');
      return;
    }

    print('Usuario ID: $currentUserId');

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final allMaintenances = await _firestore
          .collection('maintenanceSchedules')
          .where('technicianId', isEqualTo: currentUserId)
          .get();

      print('Total mantenimientos encontrados: ${allMaintenances.docs.length}');

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

        print('Doc: ${doc.id}, Status: $status, Type: $type');

        switch (status) {
          case 'scheduled':
          case 'pending':
            pending++;
            if (data['scheduledDate'] != null) {
              final scheduledDate =
                  (data['scheduledDate'] as Timestamp).toDate();
              if (scheduledDate.isAfter(startOfDay) &&
                  scheduledDate.isBefore(endOfDay)) {
                pendingToday++;
              }
            }
            break;
          case 'completed':
            completed++;
            DateTime? completedDate;
            if (data['completedAt'] != null) {
              completedDate = (data['completedAt'] as Timestamp).toDate();
            } else if (data['startedAt'] != null) {
              completedDate = (data['startedAt'] as Timestamp).toDate();
            }

            if (completedDate != null &&
                completedDate.isAfter(startOfDay) &&
                completedDate.isBefore(endOfDay)) {
              completedToday++;
            }
            break;
          case 'in_progress':
            inProgress++;
            break;
        }

        if (type == 'emergency' &&
            (status == 'scheduled' || status == 'in_progress')) {
          emergencies++;
        }
      }

      print('RESULTADOS:');
      print('- Pendientes: $pending (Hoy: $pendingToday)');
      print('- Completados: $completed (Hoy: $completedToday)');
      print('- En progreso: $inProgress');
      print('- Emergencias: $emergencies');

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
      print('Error cargando conteos: $e');
      if (mounted) {
        setState(() {
          isLoadingCounts = false;
        });
      }
    }
  }

  Future<void> _loadEquipmentCount() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final equipments = await _firestore
          .collection('equipments')
          .where('assignedTechnician', isEqualTo: currentUserId)
          .get();

      if (mounted) {
        setState(() {
          totalEquipments = equipments.docs.length;
        });
      }
    } catch (e) {
      print('Error cargando equipos: $e');
    }
  }

  Future<void> _loadNotifications() async {
    // Simulación de notificaciones pendientes
    // En producción, esto vendría de Firestore
    if (mounted) {
      setState(() {
        notificationCount = 3;
      });
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
      title: const Text('Dashboard'),
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
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
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
            await _loadMaintenanceCounts();
            await _loadEquipmentCount();
          },
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
                'Cargando información del usuario...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        // Calculate efficiency (simplified)
        final efficiency = completedCount > 0
            ? ((completedCount / (completedCount + pendingCount)) * 100).toInt()
            : 0;

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
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
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
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Técnico Senior ⚡ $efficiency%',
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
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildActionButton(
                  icon: Icons.qr_code_scanner,
                  label: 'Escanear QR',
                  color: Colors.purple,
                  onTap: () => _navigateToQRScanner(context),
                ),
                _buildActionButton(
                  icon: Icons.calendar_today,
                  label: 'Mi Calendario',
                  color: Colors.blue,
                  onTap: () => _navigateToCalendar(context),
                ),
                _buildActionButton(
                  icon: Icons.inventory_2,
                  label: 'Mis Equipos',
                  color: Colors.green,
                  onTap: () => _navigateToEquipments(context),
                ),
                _buildActionButton(
                  icon: Icons.warning_amber,
                  label: 'Reportar Falla',
                  color: Colors.red,
                  onTap: () => _reportFailure(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
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
                'Ver todo →',
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
                subtitle: isLoadingCounts ? 'Cargando...' : 'Total',
                onTap: () => _navigateToPending(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTaskCard(
                context,
                'Completados',
                Icons.check_circle,
                isLoadingCounts ? '-' : '$completedCount',
                Colors.green,
                subtitle: isLoadingCounts ? 'Cargando...' : 'Total',
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
                Colors.blue,
                subtitle: 'Asignados',
                onTap: () => _navigateToEquipments(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTaskCard(
                context,
                'Emergencias',
                Icons.warning,
                isLoadingCounts ? '-' : '$emergenciesCount',
                emergenciesCount > 0 ? Colors.red : Colors.grey,
                subtitle: emergenciesCount > 0 ? 'Urgente' : 'Sin emergencias',
                onTap: emergenciesCount > 0
                    ? () => _navigateToEmergencies(context)
                    : null,
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = (pendingTodayCount + completedTodayCount) > 0
        ? completedTodayCount / (pendingTodayCount + completedTodayCount)
        : 0.0;

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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
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
                      ? 'Cargando mantenimientos...'
                      : '$completedTodayCount de ${pendingTodayCount + completedTodayCount} mantenimientos',
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
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'Tareas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.devices),
          label: 'Equipos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            // Ya estamos en inicio
            break;
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

  // Navigation methods
  void _navigateToQRScanner(BuildContext context) {
    // Si existe la pantalla de QR Scanner
    Navigator.pushNamed(context, '/qr-scanner').catchError((e) {
      _showComingSoon(context, 'Scanner QR');
    });
  }

  void _navigateToCalendar(BuildContext context) {
    // Navegar al calendario con filtro para técnico
    Navigator.pushNamed(
      context,
      '/calendar',
      arguments: {
        'filterByUser': true,
        'userId': _auth.currentUser?.uid,
      },
    ).catchError((e) {
      _showComingSoon(context, 'Calendario');
    });
  }

  void _navigateToEquipments(BuildContext context) {
    // Navegar a equipos con filtro para técnico
    Navigator.pushNamed(
      context,
      '/equipment-list',
      arguments: {
        'onlyAssigned': true,
        'technicianId': _auth.currentUser?.uid,
      },
    ).catchError((e) {
      _showComingSoon(context, 'Mis Equipos');
    });
  }

  void _reportFailure(BuildContext context) {
    Navigator.pushNamed(context, '/report-failure').catchError((e) {
      _showComingSoon(context, 'Reportar Falla');
    });
  }

  void _navigateToEmergencies(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/pending-maintenances',
      arguments: {'filterEmergencies': true},
    ).catchError((e) {
      _showComingSoon(context, 'Emergencias');
    });
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.pushNamed(context, '/profile').catchError((e) {
      _showComingSoon(context, 'Perfil');
    });
  }

  void _showNotifications(BuildContext context) {
    Navigator.pushNamed(context, '/notifications').catchError((e) {
      _showComingSoon(context, 'Notificaciones');
    });
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
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.blue),
              title: const Text('Registrar Nuevo Equipo'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/add-equipment').catchError((e) {
                  _showComingSoon(context, 'Registrar Equipo');
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('Reportar Falla Urgente'),
              onTap: () {
                Navigator.pop(context);
                _reportFailure(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Tomar Evidencia'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon(context, 'Captura de Evidencia');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature estará disponible pronto'),
        backgroundColor: const Color(0xFF4285F4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _navigateToCompleted(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompletedMaintenancesScreen(),
      ),
    );
  }

  void _navigateToPending(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PendingMaintenancesScreen(),
      ),
    );
  }
}
