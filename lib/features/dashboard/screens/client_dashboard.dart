import 'package:flutter/material.dart';
import 'package:pm_monitor/features/client/screens/client_equipment_inventory.screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../core/providers/auth_provider.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // 5 Indicadores principales
  int totalEquipments = 0;
  int activeEquipments = 0;
  int upcomingMaintenances = 0;
  double customerSatisfaction = 0.0;
  double systemEfficiency = 0.0;

  // Datos adicionales
  int pendingFaults = 0;
  String clientName = '';
  bool isLoadingData = true;

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
    _loadClientData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadClientData() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Obtener datos del cliente
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        clientName = userData?['name'] ?? 'Cliente';
      }

      // Obtener equipos del cliente
      final equipments = await _firestore
          .collection('equipments')
          .where('clientId', isEqualTo: currentUserId)
          .get();

      final activeEquips = equipments.docs
          .where((doc) => doc.data()['status'] == 'Operativo')
          .length;

      // Obtener mantenimientos próximos (próximos 30 días)
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 30));

      final maintenances = await _firestore
          .collection('maintenanceSchedules')
          .where('clientId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'scheduled')
          .where('scheduledDate', isGreaterThan: Timestamp.fromDate(now))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(futureDate))
          .get();

      // Calcular eficiencia del sistema
      final allMaintenances = await _firestore
          .collection('maintenanceSchedules')
          .where('clientId', isEqualTo: currentUserId)
          .get();

      final completed = allMaintenances.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;

      final efficiency = allMaintenances.docs.isNotEmpty
          ? (completed / allMaintenances.docs.length) * 100
          : 0.0;

      // Obtener satisfacción del cliente (de encuestas)
      final surveys = await _firestore
          .collection('customerSurveys')
          .where('clientId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      double satisfaction = 0.0;
      if (surveys.docs.isNotEmpty) {
        final surveyData = surveys.docs.first.data();
        satisfaction = (surveyData['averageRating'] ?? 0.0).toDouble();
      }

      // Obtener fallas pendientes
      final faults = await _firestore
          .collection('faultReports')
          .where('clientId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'reportada')
          .get();

      if (mounted) {
        setState(() {
          totalEquipments = equipments.docs.length;
          activeEquipments = activeEquips;
          upcomingMaintenances = maintenances.docs.length;
          systemEfficiency = efficiency;
          customerSatisfaction = satisfaction;
          pendingFaults = faults.docs.length;
          isLoadingData = false;
        });
      }
    } catch (e) {
      print('Error cargando datos del cliente: $e');
      if (mounted) {
        setState(() {
          isLoadingData = false;
        });
      }
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
          onRefresh: _loadClientData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClientHeader(),
                const SizedBox(height: 24),
                _buildMainIndicators(),
                const SizedBox(height: 24),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildUpcomingSection(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Dashboard Cliente'),
      backgroundColor: const Color(0xFF4285F4),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _showLogoutConfirmation(),
        ),
      ],
    );
  }

  Widget _buildClientHeader() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;

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
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.business,
                  size: 32,
                  color: Color(0xFF4285F4),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Empresa',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      user?.name ?? clientName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Estado de tus equipos',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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

  Widget _buildMainIndicators() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Indicadores Principales',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Primera fila: Equipos y Activos
        Row(
          children: [
            Expanded(
              child: _buildIndicatorCard(
                icon: Icons.devices,
                label: 'Mis Equipos',
                value: isLoadingData ? '-' : '$totalEquipments',
                color: const Color(0xFF4285F4),
                onTap: () => _navigateToEquipments(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIndicatorCard(
                icon: Icons.check_circle,
                label: 'Activos',
                value: isLoadingData ? '-' : '$activeEquipments',
                color: Colors.green,
                onTap: () => _navigateToEquipments(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Segunda fila: Mantenimiento y Eficiencia
        Row(
          children: [
            Expanded(
              child: _buildIndicatorCard(
                icon: Icons.build_circle,
                label: 'Mantenimiento',
                value: isLoadingData ? '-' : '$upcomingMaintenances',
                color: Colors.orange,
                onTap: () => _navigateToMaintenances(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIndicatorCard(
                icon: Icons.trending_up,
                label: 'Eficiencia',
                value: isLoadingData ? '-' : '${systemEfficiency.toInt()}%',
                color: Colors.purple,
                onTap: () => _showEfficiencyDetails(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Tercera fila: Satisfacción (completa)
        _buildSatisfactionCard(),
      ],
    );
  }

  Widget _buildIndicatorCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSatisfactionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToSurvey(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nivel de Satisfacción',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < customerSatisfaction
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${customerSatisfaction.toStringAsFixed(1)}/5.0',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acciones Rápidas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.qr_code_scanner,
                    label: 'Escanear QR',
                    color: const Color(0xFF4285F4),
                    onTap: () => _scanQRCode(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.report_problem,
                    label: 'Reportar Falla',
                    color: Colors.red,
                    badge: pendingFaults > 0 ? '$pendingFaults' : null,
                    onTap: () => _navigateToReportFault(),
                  ),
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
    String? badge,
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
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  if (badge != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Próximos Mantenimientos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToMaintenances(),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (upcomingMaintenances > 0)
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_today, color: Colors.orange),
              ),
              title: Text('$upcomingMaintenances mantenimientos programados'),
              subtitle: const Text('Próximos 30 días'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigateToMaintenances(),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle,
                        size: 48, color: Colors.green[300]),
                    const SizedBox(height: 8),
                    const Text(
                      'No hay mantenimientos próximos',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
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
          icon: Icon(Icons.devices),
          label: 'Equipos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'Historial',
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
            _navigateToEquipments();
            break;
          case 2:
            _navigateToHistory();
            break;
          case 3:
            _navigateToProfile();
            break;
        }
      },
    );
  }

  // Métodos de navegación
  void _navigateToEquipments() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ClientEquipmentInventoryScreen(),
        ),
      );
    }
  }

  void _navigateToMaintenances() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navegando a mantenimientos...')),
    );
    // TODO: Implementar navegación
  }

  void _navigateToHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navegando a historial...')),
    );
    // TODO: Implementar navegación
  }

  void _navigateToProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navegando a perfil...')),
    );
    // TODO: Implementar navegación
  }

  void _navigateToSurvey() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abriendo encuesta de satisfacción...')),
    );
    // TODO: Implementar navegación a encuesta
  }

  void _navigateToReportFault() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Abriendo formulario de reporte de fallas...')),
    );
    // TODO: Implementar navegación a reporte de fallas
  }

  void _scanQRCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abriendo escáner QR...')),
    );
    // TODO: Implementar escáner QR
  }

  void _showEfficiencyDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eficiencia del Sistema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${systemEfficiency.toInt()}%',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: systemEfficiency >= 80 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'La eficiencia se calcula en base al porcentaje de mantenimientos completados exitosamente.',
              textAlign: TextAlign.center,
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

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}
