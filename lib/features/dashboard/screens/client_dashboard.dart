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
  Map<String, dynamic>? _clientData;
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
  Map<String, dynamic>? _nextMaintenance;
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
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
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

      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      _userData = userDoc.data();
      final clientName = (_userData?['name'] ?? '').toString().trim();

      final clientQuery = await _firestore
          .collection('clients')
          .where('name', isEqualTo: clientName)
          .limit(1)
          .get();

      if (clientQuery.docs.isNotEmpty) {
        _clientData = clientQuery.docs.first.data();
      } else {
        final clientDoc =
            await _firestore.collection('clients').doc(currentUserId).get();
        if (clientDoc.exists) _clientData = clientDoc.data();
      }

      if (clientName.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

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

      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);

      final maintenancesSnapshot = await _firestore
          .collection('maintenanceSchedules')
          .where('clientId', isEqualTo: currentUserId)
          .get();

      final allMaintenances = maintenancesSnapshot.docs;

      final executedPM = allMaintenances.where((doc) {
        final data = doc.data();
        final status = data['status'] ?? '';
        final completedAt = data['completedAt'];
        if (status != 'executed' || completedAt == null) return false;
        if (completedAt is Timestamp) {
          return completedAt.toDate().isAfter(startOfYear);
        }
        return false;
      }).length;

      final scheduledPM = allMaintenances.where((doc) {
        final data = doc.data();
        final scheduledDate = data['scheduledDate'];
        if (scheduledDate == null) return false;
        if (scheduledDate is Timestamp) {
          final date = scheduledDate.toDate();
          return date.isAfter(startOfYear) &&
              date.isBefore(DateTime(now.year + 1, 1, 1));
        }
        return false;
      }).length;

      double pmCost = 0.0;
      double cmCost = 0.0;
      for (var doc in allMaintenances) {
        final data = doc.data();
        if (data['status'] == 'executed') {
          final cost = data['estimatedCost'];
          if (cost != null) {
            pmCost += (cost is int ? cost.toDouble() : cost as double);
          }
        }
      }

      // CM Cost desde faultReports
      final faultSnapshot = await _firestore
          .collection('faultReports')
          .where('clientId', isEqualTo: currentUserId)
          .get();
      for (var doc in faultSnapshot.docs) {
        final cost = doc.data()['repairCost'];
        if (cost != null) {
          cmCost += (cost is int ? cost.toDouble() : cost as double);
        }
      }

      final upcomingDocs = allMaintenances.where((doc) {
        final data = doc.data();
        if (data['status'] == 'executed') return false;
        final scheduledDate = data['scheduledDate'];
        if (scheduledDate == null) return false;
        if (scheduledDate is Timestamp) {
          return scheduledDate.toDate().isAfter(now);
        }
        return false;
      }).toList();

      upcomingDocs.sort((a, b) {
        final aDate = (a.data()['scheduledDate'] as Timestamp).toDate();
        final bDate = (b.data()['scheduledDate'] as Timestamp).toDate();
        return aDate.compareTo(bDate);
      });

      _nextMaintenance =
          upcomingDocs.isNotEmpty ? upcomingDocs.first.data() : null;

      final executedDocs = allMaintenances
          .where((doc) => (doc.data()['status'] ?? '') == 'executed')
          .toList();

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

      int maintenancesDue = 0;
      for (var doc in clientEquipments) {
        final data = doc.data();
        final nextDate = data['nextMaintenanceDate'];
        if (nextDate != null && nextDate is Timestamp) {
          if (nextDate.toDate().difference(now).inDays <= 7) maintenancesDue++;
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
          'cmCost': cmCost,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando dashboard: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Dashboard Cliente'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadDashboardData),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showLogoutDialog(context)),
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
                    const SizedBox(height: 16),
                    _buildKpiGrid(),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                    const SizedBox(height: 16),
                    if (_nextMaintenance != null) ...[
                      _buildNextMaintenanceCard(),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HEADER CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    final companyName = (_userData?['name'] ?? 'Empresa').toString();
    // Pascal Case
    final pascalName = companyName
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
            : '')
        .join(' ');

    final contacts = _clientData?['contacts'] as List<dynamic>? ?? [];
    String repName = '';
    String repPosition = '';
    if (contacts.isNotEmpty) {
      final primary = contacts.firstWhere(
        (c) => c['isPrimary'] == true,
        orElse: () => contacts.first,
      );
      repName = (primary['name'] ?? '').toString();
      repPosition = (primary['position'] ?? '').toString();
    }

    final logoUrl = (_clientData?['logoUrl'] ?? '').toString();
    final repPhotoUrl = (_clientData?['repPhotoUrl'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          // ── Fila: Foto Rep + Nombre+Cargo | Logo ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Foto representante
              _buildRepPhoto(repPhotoUrl),
              const SizedBox(width: 14),

              // Nombre + cargo en columna
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (repName.isNotEmpty)
                      Text(
                        repName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (repPosition.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          repPosition,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 14),
              // Logo empresa
              _buildLogoWidget(logoUrl),
            ],
          ),

          const SizedBox(height: 18),

          // ── Nombre empresa centrado, Pascal Case ──
          Text(
            pascalName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRepPhoto(String url) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: url.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.person,
                    color: Colors.white.withOpacity(0.8), size: 38),
              ),
            )
          : Icon(Icons.person, color: Colors.white.withOpacity(0.8), size: 38),
    );
  }

  Widget _buildLogoWidget(String url) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: url.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.business, color: Colors.white, size: 34),
              ),
            )
          : const Icon(Icons.business, color: Colors.white, size: 34),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  6 KPI CARDS — grid 2 columnas, icono + número grande centrado
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildKpiGrid() {
    final efficiency = (_metrics['efficiency'] ?? 0.0) as double;
    final satisfaction = (_metrics['satisfaction'] ?? 0.0) as double;
    final pmCost = (_metrics['pmCost'] ?? 0.0) as double;
    final executed = (_metrics['executedPM'] ?? 0) as int;
    final scheduled = (_metrics['scheduledPM'] ?? 0) as int;
    final execPercent =
        scheduled > 0 ? ((executed / scheduled) * 100).round() : 0;

    final effColor = efficiency >= 85
        ? const Color(0xFF2E7D32)
        : efficiency >= 50
            ? Colors.orange[700]!
            : Colors.red[700]!;

    final execColor = execPercent >= 80
        ? const Color(0xFF2E7D32)
        : execPercent >= 50
            ? Colors.orange[700]!
            : Colors.red[700]!;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      childAspectRatio: 0.95,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildKpiCard(
          icon: Icons.trending_up_rounded,
          label: 'Eficiencia',
          value: '${efficiency.toStringAsFixed(0)}%',
          color: effColor,
          onTap: () {},
        ),
        _buildKpiCard(
          icon: Icons.star_rounded,
          label: 'Satisfacción',
          value: '${satisfaction.toStringAsFixed(1)}/5',
          color: const Color(0xFFF57F17),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SurveysHistoryScreen())),
        ),
        _buildKpiCard(
          icon: Icons.build_circle_outlined,
          label: 'Costo PM',
          value: '\$${_formatCost(pmCost)}',
          color: const Color(0xFF1565C0),
          onTap: () {},
        ),
        _buildKpiCard(
          icon: Icons.bar_chart_rounded,
          label: 'Ejecución del Año',
          value: '$execPercent%',
          color: execColor,
          onTap: () {},
        ),
        _buildKpiCard(
          icon: Icons.analytics_outlined,
          label: 'Indicador 5',
          value: '5',
          color: Colors.deepPurple,
          onTap: () {},
        ),
        _buildKpiCard(
          icon: Icons.warning_amber_rounded,
          label: 'Reportar Falla',
          value: 'Reportar',
          color: Colors.red[700]!,
          isAction: true,
          onTap: () async {
            final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ClientFaultReportScreen()));
            if (result == true && mounted) _loadDashboardData();
          },
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
    bool isAction = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isAction ? 20 : 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BOTONES DE ACCIÓN — ancho completo, apilados verticalmente
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    final satisfaction = (_metrics['satisfaction'] ?? 0.0) as double;
    final stars = satisfaction.round();
    final totalEquipments = (_metrics['totalEquipments'] ?? 0) as int;

    return Column(
      children: [
        // 1. Escanear QR
        _buildActionFullCard(
          icon: Icons.qr_code_scanner,
          label: 'Escanear QR',
          color: Colors.purple,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const QRScannerScreen())),
        ),
        const SizedBox(height: 12),

        // 2. Evaluar Servicio
        _buildActionFullCard(
          icon: Icons.rate_review_rounded,
          label: 'Evaluar Servicio',
          color: Colors.amber[700]!,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CustomerSurveyScreen())),
        ),
        const SizedBox(height: 12),

        // 3. Mis Equipos
        _buildActionFullCard(
          icon: Icons.devices_other_rounded,
          label: 'Activos ($totalEquipments)',
          color: const Color(0xFF1976D2),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ClientEquipmentInventoryScreen())),
        ),
        const SizedBox(height: 12),

        // 4. Historial de Fallas
        _buildActionFullCard(
          icon: Icons.history_rounded,
          label: 'Historial de Fallas',
          color: Colors.deepOrange,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ClientFaultsHistoryScreen())),
        ),
        const SizedBox(height: 12),

        // 5. Nivel de Satisfacción — con estrellas
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SurveysHistoryScreen())),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nivel de Satisfacción',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < stars
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: Colors.amber,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${satisfaction.toStringAsFixed(1)}/5.0',
                              style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
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
          ),
        ),
      ],
    );
  }

  Widget _buildActionFullCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PRÓXIMO MANTENIMIENTO
  // ─────────────────────────────────────────────────────────────────────────
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
              offset: const Offset(0, 4)),
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
            child: const Icon(Icons.event, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
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
                          ? 'En $daysUntil días'
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('dd MMM yyyy', 'es').format(scheduledDate)}  •  $frequency  •  $location',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              DateFormat('dd\nMMM', 'es').format(scheduledDate),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  String _formatCost(double cost) {
    if (cost >= 1000000) return '${(cost / 1000000).toStringAsFixed(1)}M';
    if (cost >= 1000) return '${(cost / 1000).toStringAsFixed(1)}K';
    return cost.toStringAsFixed(0);
  }
}
