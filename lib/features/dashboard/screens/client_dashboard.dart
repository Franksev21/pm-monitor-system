import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/features/auth/screens/survey_history_screen.dart';
import 'package:pm_monitor/features/client/screens/client_equipment_inventory.screen.dart';
import 'package:pm_monitor/features/client/screens/client_fault_report_screen.dart';
import 'package:pm_monitor/features/client/screens/client_faults_history_screen.dart';
import 'package:pm_monitor/features/client/screens/customer_survey_screen.dart';
import 'package:pm_monitor/features/others/screens/qr_scanner_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _userData;
  Map<String, dynamic> _metrics = {
    'totalEquipments': 0,
    'activeEquipments': 0,
    'maintenancesDue': 0,
    'efficiency': 0.0,
    'satisfaction': 0.0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _showLogoutDialog(BuildContext context) {
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
              Navigator.pop(context); // Cerrar diálogo
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
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

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Obtener datos del usuario
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      _userData = userDoc.data();
      final clientName = _userData?['name'] ?? '';

      if (clientName.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Obtener todos los equipos del cliente (case-insensitive)
      final equipmentsSnapshot =
          await _firestore.collection('equipments').get();

      // Filtrar equipos que pertenecen al cliente
      final clientEquipments = equipmentsSnapshot.docs.where((doc) {
        final data = doc.data();
        final equipmentBranch = (data['branch'] ?? '').toString().toLowerCase();
        return equipmentBranch == clientName.toLowerCase();
      }).toList();

      // Calcular métricas
      final totalEquipments = clientEquipments.length;
      final activeEquipments = clientEquipments.where((doc) {
        final status = (doc.data()['status'] ?? '').toString().toLowerCase();
        return status == 'operativo';
      }).length;

      // Contar mantenimientos vencidos o próximos
      int maintenancesDue = 0;
      for (var doc in clientEquipments) {
        final data = doc.data();
        final nextMaintenanceDate = data['nextMaintenanceDate'];
        if (nextMaintenanceDate != null) {
          DateTime nextDate;
          if (nextMaintenanceDate is Timestamp) {
            nextDate = nextMaintenanceDate.toDate();
          } else if (nextMaintenanceDate is String) {
            nextDate = DateTime.parse(nextMaintenanceDate);
          } else {
            continue;
          }

          final daysUntil = nextDate.difference(DateTime.now()).inDays;
          if (daysUntil <= 7) {
            maintenancesDue++;
          }
        }
      }

      // Calcular eficiencia promedio
      double totalEfficiency = 0;
      int equipmentsWithEfficiency = 0;
      for (var doc in clientEquipments) {
        final data = doc.data();
        final efficiency = data['maintenanceEfficiency'];
        if (efficiency != null) {
          totalEfficiency += (efficiency is int
              ? efficiency.toDouble()
              : efficiency as double);
          equipmentsWithEfficiency++;
        }
      }
      final averageEfficiency = equipmentsWithEfficiency > 0
          ? totalEfficiency / equipmentsWithEfficiency
          : 0.0;

      // Obtener nivel de satisfacción (de encuestas)
      final satisfactionSnapshot = await _firestore
          .collection('customerSurveys')
          .where('clientId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      double averageSatisfaction = 0.0;
      if (satisfactionSnapshot.docs.isNotEmpty) {
        double totalRating = 0;
        for (var doc in satisfactionSnapshot.docs) {
          final rating = doc.data()['averageRating'];
          if (rating != null) {
            totalRating +=
                (rating is int ? rating.toDouble() : rating as double);
          }
        }
        averageSatisfaction = totalRating / satisfactionSnapshot.docs.length;
      }
    if (!mounted) return;
      setState(() {
        _metrics = {
          'totalEquipments': totalEquipments,
          'activeEquipments': activeEquipments,
          'maintenancesDue': maintenancesDue,
          'efficiency': averageEfficiency,
          'satisfaction': averageSatisfaction,
        };
        _isLoading = false;
      });

      print('✅ Métricas cargadas: $_metrics');
    } catch (e) {
      print('❌ Error cargando dashboard: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Dashboard Cliente'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Actualizar',
          ),
          IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _showLogoutDialog(context),
          tooltip: 'Cerrar Sesión',
        ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 24),
                    const Text(
                      'Indicadores Principales',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMetricsGrid(),
                    const SizedBox(height: 24),
                    _buildSatisfactionCard(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    final clientName = _userData?['name'] ?? 'Cliente';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4285F4).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.business,
              color: Colors.white,
              size: 32,
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  clientName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Estado de tus equipos',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2, // ← CAMBIADO de 1.3 a 1.2 para más altura
      children: [
        _buildMetricCard(
          title: 'Mis Equipos',
          value: '${_metrics['totalEquipments']}',
          icon: Icons.devices_other,
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ClientEquipmentInventoryScreen(),
              ),
            );
          },
        ),
        _buildMetricCard(
          title: 'Activos',
          value: '${_metrics['activeEquipments']}',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _buildMetricCard(
          title: 'Mantenimiento',
          value: '${_metrics['maintenancesDue']}',
          icon: Icons.build_circle,
          color: Colors.orange,
          subtitle: '7 días', // ← ACORTADO
        ),
        _buildMetricCard(
          title: 'Eficiencia',
          value: '${_metrics['efficiency'].toStringAsFixed(0)}%',
          icon: Icons.trending_up,
          color: _metrics['efficiency'] >= 80 ? Colors.green : Colors.orange,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSatisfactionCard() {
    final satisfaction = _metrics['satisfaction'] as double;
    final stars = satisfaction.round();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SurveysHistoryScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
          // ... resto del código igual
          ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _buildActionButton(
              icon: Icons.qr_code_scanner,
              label: 'Escanear QR',
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QRScannerScreen(),
                  ),
                );
              },
            ),
            _buildActionButton(
              icon: Icons.warning,
              label: 'Reportar Falla',
              color: Colors.red,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClientFaultReportScreen(),
                  ),
                );
                if (result == true && mounted) {
                  _loadDashboardData();
                }
              },
            ),
            _buildActionButton(
              icon: Icons.rate_review,
              label: 'Evaluar Servicio',
              color: Colors.amber,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerSurveyScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Botón de historial de fallas
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClientFaultsHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history),
            label: const Text('Ver Historial de Fallas'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
