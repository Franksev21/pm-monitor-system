import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pm_monitor/core/models/user_management_model.dart';
import 'package:pm_monitor/core/providers/auth_provider.dart';
import 'package:pm_monitor/core/services/user_management_service.dart';
import 'package:pm_monitor/core/services/technician_availability_service.dart';
import 'package:pm_monitor/core/services/workload_calculator.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_management_screen.dart';
import 'package:pm_monitor/features/client/screens/client_list_screen.dart';
import 'package:pm_monitor/features/maintenance/screens/global_Equipment_Inventory_Screen.dart';
import 'package:pm_monitor/features/others/backup_management_screen.dart';
import 'package:pm_monitor/features/others/screens/kpi_indicators_screen.dart';
import 'package:pm_monitor/features/others/screens/task_template_screen.dart';
import 'package:pm_monitor/features/technician/screens/tecnician_list_screen.dart';
import 'package:pm_monitor/features/auth/screens/user_managament_screen.dart';
import 'package:provider/provider.dart';
import 'package:pm_monitor/shared/widgets/liquid_glass_background.dart';

/// Inicio operativo del supervisor con los accesos administrativos existentes.
class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final UserManagementService _userService = UserManagementService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<_SupervisorOverview> _overviewFuture;

  static const _primary = Color(0xFF1976D2);
  static const _maxWeeklyHours = TechnicianAvailabilityService.MAX_WEEKLY_HOURS;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _loadOverview();
  }

  Future<_SupervisorOverview> _loadOverview() async {
    final supervisorId = FirebaseAuth.instance.currentUser?.uid;
    if (supervisorId == null) {
      throw StateError('No hay una sesión activa.');
    }

    final technicians = (await _userService
            .getTechniciansBySupervisor(supervisorId))
        .where((technician) => technician.isActive)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (technicians.isEmpty) {
      return _SupervisorOverview(technicians: const [], maintenances: const []);
    }

    // Limita las lecturas al equipo del supervisor y a una ventana útil para
    // el resumen: 30 días anteriores y 30 días próximos.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rangeStart = DateTime(today.year, today.month, today.day - 30);
    final rangeEnd = DateTime(today.year, today.month, today.day + 31);

    final maintenanceGroups = await Future.wait(
      technicians.map((technician) async {
        final snapshot = await _firestore
            .collection('maintenanceSchedules')
            .where('technicianId', isEqualTo: technician.id)
            .where('scheduledDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
            .where('scheduledDate', isLessThan: Timestamp.fromDate(rangeEnd))
            .orderBy('scheduledDate')
            .get();
        return snapshot.docs
            .map(_SupervisorMaintenance.fromDocument)
            .whereType<_SupervisorMaintenance>()
            .toList();
      }),
    );

    return _SupervisorOverview(
      technicians: technicians,
      maintenances: maintenanceGroups.expand((group) => group).toList(),
    );
  }

  Future<void> _refresh() async {
    final future = _loadOverview();
    setState(() {
      _overviewFuture = future;
    });
    await future;
  }

  Future<void> _openTool(_AdminTool tool) async {
    final page = tool.page;
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Configuración estará disponible pronto.')),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => page,
    ));
    if (mounted) _refresh();
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final background = colorScheme.surface;
    final name =
        user?.name.trim().isNotEmpty == true ? user!.name : 'Supervisor';
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 4
        : width >= 650
            ? 3
            : 2;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainer,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Panel de supervisor',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: LiquidGlassBackground(
        backgroundColor: background,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<_SupervisorOverview>(
            future: _overviewFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 100),
                    const Icon(Icons.cloud_off,
                        size: 44, color: Colors.blueGrey),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudo cargar el resumen del equipo.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Intentar de nuevo'),
                    ),
                  ],
                );
              }

              final overview = snapshot.data ??
                  _SupervisorOverview(
                      technicians: const [], maintenances: const []);
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  _buildGreeting(name),
                  const SizedBox(height: 18),
                  _buildSummaryCards(overview),
                  const SizedBox(height: 22),
                  _buildAttentionCard(overview),
                  const SizedBox(height: 22),
                  _buildSectionHeader(
                      'Agenda de hoy', 'Ver agenda', _adminTools[1]),
                  const SizedBox(height: 10),
                  _buildTodayAgenda(overview),
                  const SizedBox(height: 22),
                  _buildSectionHeader(
                      'Mi equipo', 'Ver técnicos', _adminTools[3]),
                  const SizedBox(height: 10),
                  _buildTeamList(overview),
                  const SizedBox(height: 26),
                  const Text(
                    'Herramientas de administración',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _adminTools.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: width < 400 ? 1.18 : 1.35,
                    ),
                    itemBuilder: (context, index) =>
                        _buildToolCard(_adminTools[index]),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.8), width: 1)),
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: _primary,
              unselectedItemColor: Colors.blueGrey,
              currentIndex: 0,
              onTap: (index) {
                switch (index) {
                  case 1:
                    _openTool(_adminTools[0]);
                    break;
                  case 2:
                    _openTool(_adminTools[1]);
                    break;
                  case 3:
                    _openTool(_adminTools[3]);
                    break;
                  case 4:
                    _openTool(_adminTools[5]);
                    break;
                }
              },
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_outlined), label: 'Inicio'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.precision_manufacturing_outlined),
                    label: 'Equipos'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.build_circle_outlined), label: 'Agenda'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.engineering_outlined), label: 'Técnicos'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.manage_accounts_outlined),
                    label: 'Usuarios'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(String name) {
    final firstName = name.split(' ').first;
    final today = DateFormat('EEEE d MMMM', 'es_ES').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFF34A853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white,
            child: Icon(Icons.supervisor_account, color: _primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hola, $firstName',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${_capitalize(today)} · Supervisión de operaciones',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(_SupervisorOverview overview) {
    final values = [
      _SummaryValue(
        'Pendientes',
        '${overview.pendingCount}',
        Icons.pending_actions,
        const Color(0xFF1976D2),
      ),
      _SummaryValue(
        'En proceso',
        '${overview.inProgressCount}',
        Icons.handyman_outlined,
        const Color(0xFF00897B),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.35,
      ),
      itemBuilder: (context, index) {
        final value = values[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0D172B4D),
                  blurRadius: 10,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: value.color.withValues(alpha: 0.12),
                child: Icon(value.icon, color: value.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value.count,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(value.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttentionCard(_SupervisorOverview overview) {
    final overloaded = overview.technicians
        .where((technician) =>
            overview.hoursByTechnician[technician.id]! >= _maxWeeklyHours)
        .length;
    final nearLimit = overview.technicians.where((technician) {
      final hours = overview.hoursByTechnician[technician.id]!;
      return hours >= _maxWeeklyHours * 0.9 && hours < _maxWeeklyHours;
    }).length;

    final messages = <String>[];
    if (overview.overdueCount > 0) {
      messages.add(
          '${overview.overdueCount} mantenimiento${overview.overdueCount == 1 ? '' : 's'} vencido${overview.overdueCount == 1 ? '' : 's'} en los últimos 30 días.');
    }
    if (overloaded > 0) {
      messages.add(
          '$overloaded técnico${overloaded == 1 ? '' : 's'} supera${overloaded == 1 ? '' : 'n'} las 44 horas esta semana.');
    } else if (nearLimit > 0) {
      messages.add(
          '$nearLimit técnico${nearLimit == 1 ? '' : 's'} cerca${nearLimit == 1 ? '' : 'n'} del límite semanal.');
    }

    final hasAlerts = messages.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasAlerts ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasAlerts ? const Color(0xFFFFE082) : const Color(0xFFA5D6A7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasAlerts
                ? Icons.notifications_active_outlined
                : Icons.check_circle_outline,
            color: hasAlerts ? const Color(0xFFEF8C00) : Colors.green[700],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasAlerts ? 'Atención requerida' : 'Todo en orden',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  hasAlerts
                      ? messages.join(' ')
                      : 'No hay mantenimientos vencidos ni técnicos cerca del límite semanal.',
                  style: const TextStyle(fontSize: 13),
                ),
                if (overview.overdueCount > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                        'Los vencidos se cuentan en una ventana de 30 días.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, String action, _AdminTool destination) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () => _openTool(destination),
          child: Text(action),
        ),
      ],
    );
  }

  Widget _buildTodayAgenda(_SupervisorOverview overview) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = todayStart.add(const Duration(days: 1));
    final todayItems = overview.maintenances
        .where((item) =>
            !item.scheduledDate.isBefore(todayStart) &&
            item.scheduledDate.isBefore(tomorrow) &&
            item.isActive)
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    if (todayItems.isEmpty) {
      return _emptyCard(
          'No hay mantenimientos del equipo programados para hoy.');
    }

    return Container(
      decoration: _cardDecoration,
      child: Column(
        children: [
          for (final item in todayItems.take(5)) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _primary.withValues(alpha: 0.1),
                child: Text(DateFormat('HH:mm').format(item.scheduledDate),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _primary)),
              ),
              title: Text(item.equipmentName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${item.technicianName} · ${item.clientName}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: _statusChip(item),
              dense: true,
            ),
            if (item != todayItems.take(5).last)
              const Divider(height: 1, indent: 64, endIndent: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamList(_SupervisorOverview overview) {
    if (overview.technicians.isEmpty) {
      return _emptyCard(
        'Todavía no tienes técnicos activos asignados. Puedes consultar el directorio en Técnicos.',
      );
    }

    return Container(
      decoration: _cardDecoration,
      child: Column(
        children: [
          for (var index = 0; index < overview.technicians.length; index++)
            _buildTechnicianRow(overview, overview.technicians[index], index),
        ],
      ),
    );
  }

  Widget _buildTechnicianRow(
    _SupervisorOverview overview,
    UserManagementModel technician,
    int index,
  ) {
    final hours = overview.hoursByTechnician[technician.id] ?? 0;
    final ratio = (hours / _maxWeeklyHours).clamp(0.0, 1.0);
    final activeCount = overview.activeCountByTechnician[technician.id] ?? 0;
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: _primary.withValues(alpha: 0.12),
            backgroundImage: technician.photoUrl?.isNotEmpty == true
                ? NetworkImage(technician.photoUrl!)
                : null,
            child: technician.photoUrl?.isNotEmpty == true
                ? null
                : Text(technician.initials,
                    style: const TextStyle(
                        color: _primary, fontWeight: FontWeight.bold)),
          ),
          title: Text(technician.name),
          subtitle: Text(
              '$activeCount activos · ${hours.toStringAsFixed(1)} h esta semana'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openTool(_adminTools[3]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: hours >= _maxWeeklyHours
                  ? Colors.red
                  : hours >= _maxWeeklyHours * 0.9
                      ? Colors.orange
                      : Colors.green,
            ),
          ),
        ),
        if (index < overview.technicians.length - 1)
          const Divider(height: 1, indent: 72, endIndent: 12),
      ],
    );
  }

  Widget _buildToolCard(_AdminTool tool) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openTool(tool),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tool.icon, color: tool.color, size: 27),
              const SizedBox(height: 8),
              Text(tool.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(_SupervisorMaintenance item) {
    final inProgress = item.isInProgress;
    final overdue = item.isOverdue;
    final color = overdue
        ? Colors.red
        : inProgress
            ? Colors.teal
            : _primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
          overdue
              ? 'Vencido'
              : inProgress
                  ? 'En proceso'
                  : 'Pendiente',
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyCard(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration,
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13)),
      );

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D172B4D), blurRadius: 10, offset: Offset(0, 3)),
        ],
      );

  String _capitalize(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  static const _adminTools = <_AdminTool>[
    _AdminTool('Equipos', Icons.precision_manufacturing, Colors.blue,
        GlobalEquipmentInventoryScreen()),
    _AdminTool('Mantenimientos', Icons.build_circle, Colors.green,
        MaintenanceManagementScreen()),
    _AdminTool(
        'Plantillas', Icons.checklist, Colors.teal, TaskTemplatesScreen()),
    _AdminTool(
        'Técnicos', Icons.engineering, Colors.orange, TechniciansListScreen()),
    _AdminTool('Clientes', Icons.business, Colors.purple, ClientListScreen()),
    _AdminTool('Gestión de usuarios', Icons.manage_accounts, Colors.teal,
        UserManagementScreen()),
    _AdminTool(
        'Indicadores', Icons.analytics, Colors.indigo, KPIIndicatorsScreen()),
    _AdminTool(
        'Backup', Icons.backup, Colors.deepOrange, BackupManagementScreen()),
    _AdminTool('Configuración', Icons.settings, Colors.blueGrey, null),
  ];
}

class _SummaryValue {
  final String label;
  final String count;
  final IconData icon;
  final Color color;
  const _SummaryValue(this.label, this.count, this.icon, this.color);
}

class _AdminTool {
  final String label;
  final IconData icon;
  final Color color;
  final Widget? page;
  const _AdminTool(this.label, this.icon, this.color, this.page);
}

class _SupervisorOverview {
  final List<UserManagementModel> technicians;
  final List<_SupervisorMaintenance> maintenances;
  final Map<String, double> hoursByTechnician;
  final Map<String, int> activeCountByTechnician;

  _SupervisorOverview({
    required this.technicians,
    required this.maintenances,
  })  : hoursByTechnician = _calculateHours(technicians, maintenances),
        activeCountByTechnician =
            _calculateActiveCounts(technicians, maintenances);

  int get pendingCount => maintenances.where((item) => item.isPending).length;
  int get inProgressCount =>
      maintenances.where((item) => item.isInProgress).length;
  int get overdueCount => maintenances.where((item) => item.isOverdue).length;

  static Map<String, double> _calculateHours(
    List<UserManagementModel> technicians,
    List<_SupervisorMaintenance> maintenances,
  ) {
    final currentDate = DateTime.now();
    final weekStart = WorkloadCalculator.weekStartOf(currentDate);
    final nextWeek =
        DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    final calculator = WorkloadCalculator();
    final hours = {for (final technician in technicians) technician.id: 0.0};
    for (final maintenance in maintenances) {
      if (!maintenance.isActive ||
          maintenance.scheduledDate.isBefore(weekStart) ||
          !maintenance.scheduledDate.isBefore(nextWeek)) {
        continue;
      }
      hours[maintenance.technicianId] = (hours[maintenance.technicianId] ?? 0) +
          calculator
              .calculateMaintenanceHours(
                maintenance.scheduledDate,
                maintenance.estimatedHours,
              )
              .total;
    }
    return hours;
  }

  static Map<String, int> _calculateActiveCounts(
    List<UserManagementModel> technicians,
    List<_SupervisorMaintenance> maintenances,
  ) {
    final counts = {for (final technician in technicians) technician.id: 0};
    for (final maintenance in maintenances.where((item) => item.isActive)) {
      counts[maintenance.technicianId] =
          (counts[maintenance.technicianId] ?? 0) + 1;
    }
    return counts;
  }
}

class _SupervisorMaintenance {
  final String technicianId;
  final String technicianName;
  final String equipmentName;
  final String clientName;
  final String status;
  final DateTime scheduledDate;
  final double estimatedHours;
  final bool hasStarted;

  const _SupervisorMaintenance({
    required this.technicianId,
    required this.technicianName,
    required this.equipmentName,
    required this.clientName,
    required this.status,
    required this.scheduledDate,
    required this.estimatedHours,
    required this.hasStarted,
  });

  bool get isActive =>
      status == 'assigned' ||
      status == 'scheduled' ||
      status == 'in_progress' ||
      status == 'inProgress' ||
      status == 'overdue';

  bool get isInProgress =>
      status == 'in_progress' || status == 'inProgress' || hasStarted;

  bool get isPending =>
      isActive &&
      !isInProgress &&
      !isOverdue &&
      scheduledDate.isAfter(DateTime.now());

  bool get isOverdue =>
      status == 'overdue' ||
      (isActive && !isInProgress && scheduledDate.isBefore(DateTime.now()));

  static _SupervisorMaintenance? fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final scheduledDate = data['scheduledDate'];
    if (scheduledDate is! Timestamp) return null;
    final hours = data['estimatedHours'] ??
        ((data['estimatedDurationMinutes'] is num)
            ? (data['estimatedDurationMinutes'] as num) / 60
            : WorkloadCalculator.defaultMaintenanceHours);
    return _SupervisorMaintenance(
      technicianId: (data['technicianId'] ?? '').toString(),
      technicianName: (data['technicianName'] ?? 'Técnico').toString(),
      equipmentName: (data['equipmentName'] ?? 'Equipo').toString(),
      clientName: (data['clientName'] ?? 'Cliente').toString(),
      status: (data['status'] ?? 'generated').toString(),
      scheduledDate: scheduledDate.toDate(),
      estimatedHours: (hours as num).toDouble(),
      hasStarted: data['startedAt'] != null || data['actualStartTime'] != null,
    );
  }
}
