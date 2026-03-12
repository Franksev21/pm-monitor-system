import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/features/auth/screens/survey_history_screen.dart';
import 'package:pm_monitor/features/client/screens/client_equipment_inventory.screen.dart';
import 'package:pm_monitor/features/client/screens/client_fault_report_screen.dart';
import 'package:pm_monitor/features/client/screens/client_faults_history_screen.dart';
import 'package:pm_monitor/features/client/screens/customer_survey_screen.dart';
import 'package:pm_monitor/features/others/screens/qr_scanner_screen.dart';
import 'package:intl/intl.dart';

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
    'executedPM': 0,
    'scheduledPM': 0,
    'pmCost': 0.0,
    'cmCost': 0.0,
  };
  List<Map<String, dynamic>> _recentMaintenances = [];
  Map<String, dynamic>? _nextMaintenance;
  bool _isLoading = true;
  int _selectedTab = 0;

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
              Navigator.pop(context);
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
    setState(() => _isLoading = true);

    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Usuario
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      _userData = userDoc.data();
      final clientName = _userData?['name'] ?? '';
      if (clientName.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      // Equipos
      final equipmentsSnapshot =
          await _firestore.collection('equipments').get();
      final clientEquipments = equipmentsSnapshot.docs.where((doc) {
        final branch = (doc.data()['branch'] ?? '').toString().toLowerCase();
        return branch == clientName.toLowerCase();
      }).toList();

      final totalEquipments = clientEquipments.length;
      final activeEquipments = clientEquipments.where((doc) {
        final status = (doc.data()['status'] ?? '').toString().toLowerCase();
        return status == 'operativo';
      }).length;

      // Mantenimientos del cliente
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);

      final maintenancesSnapshot = await _firestore
          .collection('maintenanceSchedules')
          .where('clientId', isEqualTo: currentUserId)
          .get();

      final allMaintenances = maintenancesSnapshot.docs;

      // Ejecutados este año
      final executedPM = allMaintenances.where((doc) {
        final data = doc.data();
        final status = data['status'] ?? '';
        final completedAt = data['completedAt'];
        if (status != 'executed' || completedAt == null) return false;
        DateTime date;
        if (completedAt is Timestamp) {
          date = completedAt.toDate();
        } else {
          return false;
        }
        return date.isAfter(startOfYear);
      }).length;

      // Programados este año
      final scheduledPM = allMaintenances.where((doc) {
        final data = doc.data();
        final scheduledDate = data['scheduledDate'];
        if (scheduledDate == null) return false;
        DateTime date;
        if (scheduledDate is Timestamp) {
          date = scheduledDate.toDate();
        } else {
          return false;
        }
        return date.isAfter(startOfYear) &&
            date.isBefore(DateTime(now.year + 1, 1, 1));
      }).length;

      // Costo PM
      double pmCost = 0.0;
      for (var doc in allMaintenances) {
        final data = doc.data();
        final status = data['status'] ?? '';
        if (status == 'executed') {
          final cost = data['estimatedCost'];
          if (cost != null) {
            pmCost += (cost is int ? cost.toDouble() : cost as double);
          }
        }
      }

      // Próximo mantenimiento
      final upcomingDocs = allMaintenances.where((doc) {
        final data = doc.data();
        final status = data['status'] ?? '';
        if (status == 'executed') return false;
        final scheduledDate = data['scheduledDate'];
        if (scheduledDate == null) return false;
        DateTime date;
        if (scheduledDate is Timestamp) {
          date = scheduledDate.toDate();
        } else {
          return false;
        }
        return date.isAfter(now);
      }).toList();

      upcomingDocs.sort((a, b) {
        final aDate = (a.data()['scheduledDate'] as Timestamp).toDate();
        final bDate = (b.data()['scheduledDate'] as Timestamp).toDate();
        return aDate.compareTo(bDate);
      });

      _nextMaintenance =
          upcomingDocs.isNotEmpty ? upcomingDocs.first.data() : null;

      // Últimos 3 mantenimientos ejecutados
      final executedDocs = allMaintenances.where((doc) {
        return (doc.data()['status'] ?? '') == 'executed';
      }).toList();

      executedDocs.sort((a, b) {
        final aDate = a.data()['completedAt'];
        final bDate = b.data()['completedAt'];
        if (aDate == null || bDate == null) return 0;
        return (bDate as Timestamp).compareTo(aDate as Timestamp);
      });

      _recentMaintenances =
          executedDocs.take(3).map((doc) => doc.data()).toList();

      // Eficiencia promedio
      double totalEfficiency = 0;
      int withEff = 0;
      for (var doc in executedDocs) {
        final comp = doc.data()['completionPercentage'];
        if (comp != null && comp is num && comp > 0) {
          totalEfficiency += comp.toDouble();
          withEff++;
        }
      }
      final averageEfficiency = withEff > 0 ? totalEfficiency / withEff : 0.0;

      // Satisfacción
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

      // Próximos en 7 días
      int maintenancesDue = 0;
      for (var doc in clientEquipments) {
        final data = doc.data();
        final nextDate = data['nextMaintenanceDate'];
        if (nextDate != null) {
          DateTime date;
          if (nextDate is Timestamp) {
            date = nextDate.toDate();
          } else {
            continue;
          }
          if (date.difference(now).inDays <= 7) maintenancesDue++;
        }
      }

      if (!mounted) return;
      setState(() {
        _metrics = {
          'totalEquipments': totalEquipments,
          'activeEquipments': activeEquipments,
          'maintenancesDue': maintenancesDue,
          'efficiency': averageEfficiency,
          'satisfaction': averageSatisfaction,
          'executedPM': executedPM,
          'scheduledPM': scheduledPM,
          'pmCost': pmCost,
          'cmCost': 0.0,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error cargando dashboard: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildSliverAppBar(),
              ],
              body: RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildKPIRow(),
                      const SizedBox(height: 16),
                      _buildExecutionProgress(),
                      const SizedBox(height: 16),
                      if (_nextMaintenance != null) ...[
                        _buildNextMaintenanceCard(),
                        const SizedBox(height: 16),
                      ],
                      _buildRecentMaintenances(),
                      const SizedBox(height: 16),
                      _buildSatisfactionCard(),
                      const SizedBox(height: 16),
                      _buildQuickActions(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    final clientName = _userData?['name'] ?? 'Cliente';
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      title: Text(
        _userData?['name'] ?? 'Cliente',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      backgroundColor: const Color(0xFF1976D2),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadDashboardData,
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _showLogoutDialog(context),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: null,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1976D2), Color(0xFF00897B)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.4), width: 1.5),
                    ),
                    child: const Icon(Icons.business,
                        color: Colors.white, size: 34),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clientName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.devices_other,
                                      color: Colors.white70, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_metrics['totalEquipments']} equipos',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.greenAccent, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_metrics['activeEquipments']} activos',
                                    style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── KPI Row (4 cards en fila) ───────────────────────────────────────────
  Widget _buildKPIRow() {
    final efficiency = (_metrics['efficiency'] ?? 0.0) as double;
    final satisfaction = (_metrics['satisfaction'] ?? 0.0) as double;
    final pmCost = (_metrics['pmCost'] ?? 0.0) as double;
    final maintenancesDue = (_metrics['maintenancesDue'] ?? 0) as int;

    return Row(
      children: [
        Expanded(
          child: _buildKPICard(
            label: 'Eficiencia',
            value: '${efficiency.toStringAsFixed(0)}%',
            icon: Icons.trending_up,
            color: efficiency >= 85
                ? const Color(0xFF2E7D32)
                : efficiency >= 50
                    ? Colors.orange[700]!
                    : Colors.red[700]!,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKPICard(
            label: 'Satisfacción',
            value: '${satisfaction.toStringAsFixed(1)}/5',
            icon: Icons.star_rounded,
            color: satisfaction >= 4
                ? const Color(0xFFF57F17)
                : satisfaction >= 3
                    ? Colors.orange
                    : Colors.red,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKPICard(
            label: 'Costo PM',
            value: '\$${pmCost.toStringAsFixed(0)}',
            icon: Icons.attach_money,
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKPICard(
            label: 'Alertas',
            value: '$maintenancesDue',
            icon: Icons.notifications_active,
            color: maintenancesDue > 0 ? Colors.red[700]! : Colors.grey[400]!,
          ),
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Barra de progreso ejecución ─────────────────────────────────────────
  Widget _buildExecutionProgress() {
    final executed = (_metrics['executedPM'] ?? 0) as int;
    final scheduled = (_metrics['scheduledPM'] ?? 0) as int;
    final percent = scheduled > 0 ? (executed / scheduled) : 0.0;
    final percentInt = (percent * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart,
                        color: Color(0xFF1976D2), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '% Ejecución del Año',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: percentInt >= 80
                      ? const Color(0xFF2E7D32).withOpacity(0.1)
                      : percentInt >= 50
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percentInt%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: percentInt >= 80
                        ? const Color(0xFF2E7D32)
                        : percentInt >= 50
                            ? Colors.orange[700]
                            : Colors.red[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                percentInt >= 80
                    ? const Color(0xFF2E7D32)
                    : percentInt >= 50
                        ? Colors.orange[600]!
                        : Colors.red[600]!,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressStat(
                  '✅ Ejecutados', '$executed', const Color(0xFF2E7D32)),
              _buildProgressStat(
                  '📅 Programados', '$scheduled', const Color(0xFF1976D2)),
              _buildProgressStat(
                  '⏳ Pendientes',
                  '${(scheduled - executed).clamp(0, 999)}',
                  Colors.orange[700]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  // ─── Próximo Mantenimiento ───────────────────────────────────────────────
  Widget _buildNextMaintenanceCard() {
    if (_nextMaintenance == null) return const SizedBox.shrink();

    final data = _nextMaintenance!;
    final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();
    final daysUntil = scheduledDate.difference(DateTime.now()).inDays;
    final equipmentName = data['equipmentName'] ?? 'Equipo';
    final frequency = data['frequency'] ?? '';
    final location = data['location'] ?? '';

    final isUrgent = daysUntil <= 3;
    final color = isUrgent ? Colors.red[700]! : const Color(0xFF1976D2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isUrgent
              ? [Colors.red[700]!, Colors.red[400]!]
              : [const Color(0xFF1976D2), const Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.white70, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      isUrgent
                          ? '⚠️ En $daysUntil días'
                          : 'Próximo en $daysUntil días',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  equipmentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('dd MMM yyyy', 'es').format(scheduledDate)}  •  $frequency  •  $location',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              DateFormat('dd\nMMM', 'es').format(scheduledDate),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Últimos Mantenimientos ──────────────────────────────────────────────
  Widget _buildRecentMaintenances() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.build_circle,
                        color: Colors.green, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Últimos Mantenimientos',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  // TODO: navegar a historial completo
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1976D2),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                ),
                child:
                    const Text('Ver todos →', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentMaintenances.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('Sin mantenimientos registrados',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_recentMaintenances.length, (i) {
              return _buildMaintenanceItem(_recentMaintenances[i], i);
            }),
        ],
      ),
    );
  }

  Widget _buildMaintenanceItem(Map<String, dynamic> data, int index) {
    final equipmentName = data['equipmentName'] ?? 'Equipo';
    final completedAt = data['completedAt'];
    final completionPercentage = data['completionPercentage'] ?? 0;
    final supervisor =
        data['supervisorName'] ?? data['technicianName'] ?? 'Técnico';
    final frequency = data['frequency'] ?? '';
    final location = data['location'] ?? '';

    DateTime? date;
    if (completedAt is Timestamp) date = completedAt.toDate();

    final percent =
        completionPercentage is num ? completionPercentage.toInt() : 0;
    final Color percentColor = percent >= 85
        ? const Color(0xFF2E7D32)
        : percent >= 50
            ? Colors.orange[700]!
            : Colors.red[700]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equipmentName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 11, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text(supervisor,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 8),
                    const Icon(Icons.location_on_outlined,
                        size: 11, color: Colors.grey),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        location.isNotEmpty ? location : frequency,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: percentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                      color: percentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date != null ? DateFormat('dd MMM', 'es').format(date) : '—',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Satisfacción ────────────────────────────────────────────────────────
  Widget _buildSatisfactionCard() {
    final satisfaction = (_metrics['satisfaction'] ?? 0.0) as double;
    final stars = satisfaction.round();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SurveysHistoryScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nivel de Satisfacción',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        return Icon(
                          i < stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        '${satisfaction.toStringAsFixed(1)}/5.0',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ─── Acciones Rápidas ────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acciones Rápidas',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                icon: Icons.devices_other,
                label: 'Mis\nEquipos',
                color: const Color(0xFF1976D2),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ClientEquipmentInventoryScreen()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                icon: Icons.qr_code_scanner,
                label: 'Escanear\nQR',
                color: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                icon: Icons.warning_amber_rounded,
                label: 'Reportar\nFalla',
                color: Colors.red[700]!,
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ClientFaultReportScreen()),
                  );
                  if (result == true && mounted) _loadDashboardData();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                icon: Icons.rate_review,
                label: 'Evaluar\nServicio',
                color: Colors.amber[700]!,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomerSurveyScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ClientFaultsHistoryScreen()),
            ),
            icon: const Icon(Icons.history),
            label: const Text('Ver Historial de Fallas'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[700],
              side: BorderSide(color: Colors.red[700]!),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  height: 1.3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
