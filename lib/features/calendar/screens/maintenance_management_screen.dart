import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pm_monitor/core/services/maintenance_schedule_service.dart';
import 'package:pm_monitor/core/models/client_model.dart';
import 'package:pm_monitor/core/services/client_service.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_model.dart';
import 'package:pm_monitor/features/maintenance/screens/add_maintenance_screen.dart';

class MaintenanceManagementScreen extends StatefulWidget {
  const MaintenanceManagementScreen({Key? key}) : super(key: key);

  @override
  State<MaintenanceManagementScreen> createState() =>
      _MaintenanceManagementScreenState();
}

class _MaintenanceManagementScreenState
    extends State<MaintenanceManagementScreen> {
  final MaintenanceScheduleService _maintenanceService =
      MaintenanceScheduleService();
  final ClientService _clientService = ClientService();

  // Lista de mantenimientos
  List<MaintenanceSchedule> _allMaintenances = []; // ✅ CORREGIDO
  List<MaintenanceSchedule> _filteredMaintenances = [];
  bool _isLoading = true;

  // Selección
  final Set<String> _selectedIds = {};
  bool _selectAll = false;

  // Filtros
  String? _selectedClientId;
  String? _selectedBranchId;
  String? _selectedEquipmentType;
  MaintenanceType? _selectedMaintenanceType;
  MaintenanceStatus? _selectedStatus;
  String? _selectedTechnicianId;
  String _assignmentFilter = 'all'; // all, assigned, unassigned
  DateTime? _startDate;
  DateTime? _endDate;

  // Datos para filtros
  List<ClientModel> _clients = [];
  List<BranchModel> _branches = [];
  final List<String> _equipmentTypes = [
    'Climatización',
    'Equipos Eléctricos',
    'Paneles Eléctricos',
    'Generadores',
    'UPS',
    'Equipos de Cocina',
    'Facilidades',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _loadClients();
    _loadMaintenances();
  }

  Future<void> _loadClients() async {
    try {
      final clients = await _clientService.getClients().first;
      setState(() {
        _clients = clients;
      });
    } catch (e) {
      debugPrint('Error cargando clientes: $e');
    }
  }

  Future<void> _loadMaintenances() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ CAMBIO: Cargar últimos 30 días + próximos 30 días
      final now = DateTime.now();
      final startDate = _startDate ?? now.subtract(const Duration(days: 30));
      final endDate = _endDate ?? now.add(const Duration(days: 30));

      debugPrint('🔍 Cargando mantenimientos...');
      debugPrint('   Rango: $startDate → $endDate');

      final maintenances = await _maintenanceService.getFilteredMaintenances(
        startDate: startDate,
        endDate: endDate,
      );

      debugPrint('✅ Mantenimientos encontrados: ${maintenances.length}');

      // Debug: Mostrar estados
      final statusCounts = <String, int>{};
      for (var m in maintenances) {
        final status = m.status.toString().split('.').last;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
      debugPrint('📊 Estados: $statusCounts');

      setState(() {
        _allMaintenances = maintenances;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error cargando mantenimientos: $e');
    }
  }

  void _applyFilters() {
    var filtered = _allMaintenances;

    // Filtro por cliente
    if (_selectedClientId != null) {
      filtered =
          filtered.where((m) => m.clientId == _selectedClientId).toList();
    }

    // Filtro por sucursal
    if (_selectedBranchId != null) {
      filtered =
          filtered.where((m) => m.branchId == _selectedBranchId).toList();
    }

    // Filtro por tipo de mantenimiento
    if (_selectedMaintenanceType != null) {
      filtered =
          filtered.where((m) => m.type == _selectedMaintenanceType).toList();
    }

    // Filtro por estado
    if (_selectedStatus != null) {
      filtered = filtered.where((m) => m.status == _selectedStatus).toList();
    }

    if (_assignmentFilter == 'assigned') {
      filtered = filtered.where((m) => m.technicianId != null).toList();
    } else if (_assignmentFilter == 'unassigned') {
      filtered = filtered.where((m) => m.technicianId == null).toList();
    }

    // Filtro por técnico específico
    if (_selectedTechnicianId != null) {
      filtered = filtered
          .where((m) => m.technicianId == _selectedTechnicianId)
          .toList();
    }

    setState(() {
      _filteredMaintenances = filtered;

      // Limpiar selecciones que ya no están en la lista filtrada
      _selectedIds.removeWhere((id) => !filtered.any((m) => m.id == id));
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _selectAll = _selectedIds.length == _filteredMaintenances.length;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedIds.clear();
        _selectAll = false;
      } else {
        _selectedIds.addAll(_filteredMaintenances.map((m) => m.id));
        _selectAll = true;
      }
    });
  }

  List<MaintenanceSchedule> get _selectedMaintenances {
    return _filteredMaintenances
        .where((m) => _selectedIds.contains(m.id))
        .toList();
  }

  double get _totalSelectedHours {
    return _selectedMaintenances.fold(
      0.0,
      (sum, m) => sum + (m.estimatedHours ?? 0.0).toInt(), // ✅ CORREGIDO
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFiltersCount = [
      _selectedClientId != null,
      _selectedBranchId != null,
      _selectedEquipmentType != null,
      _selectedMaintenanceType != null,
      _selectedStatus != null,
      _selectedTechnicianId != null,
      _assignmentFilter != 'all',
      _startDate != null || _endDate != null,
    ].where((f) => f).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Gestión de Mantenimientos'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddMaintenanceScreen(),
                  ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de filtros rápidos
          _buildQuickFiltersBar(activeFiltersCount),

          // Checkbox "Seleccionar todos"
          if (_filteredMaintenances.isNotEmpty) _buildSelectAllBar(),

          // Lista de mantenimientos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMaintenances.isEmpty
                    ? _buildEmptyState()
                    : _buildMaintenancesList(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  Widget _buildQuickFiltersBar(int activeFiltersCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showFiltersBottomSheet,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.filter_list, size: 20),
                  if (activeFiltersCount > 0)
                    Positioned(
                      right: -8,
                      top: -8,
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
                          '$activeFiltersCount',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: Text(
                activeFiltersCount > 0
                    ? 'Filtros ($activeFiltersCount)'
                    : 'Filtros',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    activeFiltersCount > 0 ? Colors.orange : Colors.blue,
                side: BorderSide(
                  color: activeFiltersCount > 0 ? Colors.orange : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDateRangeButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeButton() {
    String label;
    if (_startDate != null && _endDate != null) {
      label =
          '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}';
    } else {
      label = 'Próximos 30 días';
    }

    return OutlinedButton.icon(
      onPressed: _showDateRangePicker,
      icon: const Icon(Icons.calendar_today, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildSelectAllBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Checkbox(
            value: _selectAll,
            onChanged: (_) => _toggleSelectAll(),
            activeColor: const Color(0xFF007AFF),
          ),
          const SizedBox(width: 8),
          Text(
            _selectAll
                ? 'Deseleccionar todos'
                : 'Seleccionar todos (${_filteredMaintenances.length})',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (_selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedIds.length} seleccionados',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMaintenancesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredMaintenances.length,
      itemBuilder: (context, index) {
        final maintenance = _filteredMaintenances[index];
        final isSelected = _selectedIds.contains(maintenance.id);

        return _buildMaintenanceCard(maintenance, isSelected);
      },
    );
  }

  Widget _buildMaintenanceCard(
    MaintenanceSchedule maintenance,
    bool isSelected,
  ) {
    // ✅ CORREGIDO: Usar helpers estáticos del modelo
    final statusColor = MaintenanceSchedule.getStatusColor(maintenance.status);
    final statusIcon = MaintenanceSchedule.getStatusIcon(maintenance.status);
    final statusName =
        MaintenanceSchedule.getStatusDisplayName(maintenance.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: () => _showMaintenanceDetails(maintenance),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(maintenance.id),
                activeColor: const Color(0xFF007AFF),
              ),

              // Barra de estado
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            maintenance.equipmentName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.business, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            maintenance.clientName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(maintenance.scheduledDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${maintenance.estimatedHours ?? 0} hrs', // ✅ CORREGIDO
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildTypeChip(maintenance.type),
                        const SizedBox(width: 6),
                        if (maintenance.technicianName != null) ...[
                          Icon(Icons.person, size: 12, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              maintenance.technicianName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else ...[
                          Icon(Icons.warning_amber,
                              size: 12, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Sin asignar',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Estado badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusName, // ✅ CORREGIDO
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(MaintenanceType type) {
    // ✅ CORREGIDO: Usar helpers estáticos del modelo
    final color = _getMaintenanceTypeColor(type);
    final name = MaintenanceSchedule.getTypeDisplayName(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No hay mantenimientos',
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajusta los filtros o crea uno nuevo',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActions() {
    if (_selectedIds.isEmpty) return null;

    return FloatingActionButton.extended(
      onPressed: _showTechnicianAssignment,
      backgroundColor: const Color(0xFF007AFF),
      icon: const Icon(Icons.person_add),
      label: Text('Asignar ${_selectedIds.length}'),
    );
  }

  // MÉTODOS AUXILIARES

  Color _getMaintenanceTypeColor(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.preventive:
        return Colors.blue;
      case MaintenanceType.corrective:
        return Colors.orange;
      case MaintenanceType.emergency:
        return Colors.red;
      case MaintenanceType.inspection:
        return Colors.purple;
      case MaintenanceType.technicalAssistance:
        return Colors.green;
    }
  }

  void _showFiltersBottomSheet() {
    // Variables locales para el bottom sheet
    String? tempClientId = _selectedClientId;
    String? tempBranchId = _selectedBranchId;
    String? tempEquipmentType = _selectedEquipmentType;
    MaintenanceType? tempMaintenanceType = _selectedMaintenanceType;
    MaintenanceStatus? tempStatus = _selectedStatus;
    String tempAssignmentFilter = _assignmentFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Filtros',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempClientId = null;
                            tempBranchId = null;
                            tempEquipmentType = null;
                            tempMaintenanceType = null;
                            tempStatus = null;
                            tempAssignmentFilter = 'all';
                          });
                        },
                        child: const Text('Limpiar'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Filtros
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cliente
                        const Text(
                          'Cliente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: tempClientId,
                              hint: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Todos los clientes'),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Todos los clientes'),
                                ),
                                ..._clients.map((client) {
                                  return DropdownMenuItem<String>(
                                    value: client.id,
                                    child: Text(client.name),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setModalState(() {
                                  tempClientId = value;
                                  tempBranchId = null; // Reset sucursal
                                  if (value != null) {
                                    // Cargar sucursales del cliente
                                    final client = _clients.firstWhere(
                                      (c) => c.id == value,
                                    );
                                    _branches = client.branches;
                                  }
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Sucursal
                        if (tempClientId != null) ...[
                          const Text(
                            'Sucursal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: tempBranchId,
                                hint: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Todas las sucursales'),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Todas las sucursales'),
                                  ),
                                  ..._branches.map((branch) {
                                    return DropdownMenuItem<String>(
                                      value: branch.id,
                                      child: Text(branch.name),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setModalState(() {
                                    tempBranchId = value;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Tipo de Mantenimiento
                        const Text(
                          'Tipo de Mantenimiento',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<MaintenanceType?>(
                              isExpanded: true,
                              value: tempMaintenanceType,
                              hint: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Todos los tipos'),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              items: [
                                const DropdownMenuItem<MaintenanceType?>(
                                  value: null,
                                  child: Text('Todos los tipos'),
                                ),
                                ...MaintenanceType.values.map((type) {
                                  return DropdownMenuItem<MaintenanceType>(
                                    value: type,
                                    child: Text(
                                      MaintenanceSchedule.getTypeDisplayName(
                                          type),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setModalState(() {
                                  tempMaintenanceType = value;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Estado
                        const Text(
                          'Estado',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<MaintenanceStatus?>(
                              isExpanded: true,
                              value: tempStatus,
                              hint: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Todos los estados'),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              items: [
                                const DropdownMenuItem<MaintenanceStatus?>(
                                  value: null,
                                  child: Text('Todos los estados'),
                                ),
                                ...MaintenanceStatus.values.map((status) {
                                  return DropdownMenuItem<MaintenanceStatus>(
                                    value: status,
                                    child: Text(
                                      MaintenanceSchedule.getStatusDisplayName(
                                          status),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setModalState(() {
                                  tempStatus = value;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Asignación
                        const Text(
                          'Asignación',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Todos'),
                              selected: tempAssignmentFilter == 'all',
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    tempAssignmentFilter = 'all';
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Asignados'),
                              selected: tempAssignmentFilter == 'assigned',
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    tempAssignmentFilter = 'assigned';
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Sin asignar'),
                              selected: tempAssignmentFilter == 'unassigned',
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    tempAssignmentFilter = 'unassigned';
                                  });
                                }
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Tipo de Equipo
                        const Text(
                          'Tipo de Equipo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: tempEquipmentType,
                              hint: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Todos los equipos'),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Todos los equipos'),
                                ),
                                ..._equipmentTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setModalState(() {
                                  tempEquipmentType = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Botón Aplicar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedClientId = tempClientId;
                          _selectedBranchId = tempBranchId;
                          _selectedEquipmentType = tempEquipmentType;
                          _selectedMaintenanceType = tempMaintenanceType;
                          _selectedStatus = tempStatus;
                          _assignmentFilter = tempAssignmentFilter;
                          _applyFilters();
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Aplicar Filtros',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDateRangePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Seleccionar Período',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Opciones predefinidas
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Esta semana'),
              onTap: () {
                final now = DateTime.now();
                final startOfWeek =
                    now.subtract(Duration(days: now.weekday - 1));
                final endOfWeek = startOfWeek.add(const Duration(days: 6));

                setState(() {
                  _startDate = DateTime(
                      startOfWeek.year, startOfWeek.month, startOfWeek.day);
                  _endDate = DateTime(endOfWeek.year, endOfWeek.month,
                      endOfWeek.day, 23, 59, 59);
                  _loadMaintenances();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Este mes'),
              onTap: () {
                final now = DateTime.now();
                final startOfMonth = DateTime(now.year, now.month, 1);
                final endOfMonth =
                    DateTime(now.year, now.month + 1, 0, 23, 59, 59);

                setState(() {
                  _startDate = startOfMonth;
                  _endDate = endOfMonth;
                  _loadMaintenances();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Próximos 7 días'),
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _startDate = DateTime(now.year, now.month, now.day);
                  _endDate = now.add(const Duration(days: 7));
                  _loadMaintenances();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Próximos 30 días'),
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _startDate = DateTime(now.year, now.month, now.day);
                  _endDate = now.add(const Duration(days: 30));
                  _loadMaintenances();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month),
              title: const Text('Últimos 30 días'),
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _startDate = now.subtract(const Duration(days: 30));
                  _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                  _loadMaintenances();
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Personalizado'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(context);

                // Mostrar selector de rango personalizado
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange: _startDate != null && _endDate != null
                      ? DateTimeRange(start: _startDate!, end: _endDate!)
                      : null,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF007AFF),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (picked != null) {
                  setState(() {
                    _startDate = picked.start;
                    _endDate = DateTime(
                      picked.end.year,
                      picked.end.month,
                      picked.end.day,
                      23,
                      59,
                      59,
                    );
                    _loadMaintenances();
                  });
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceDetails(MaintenanceSchedule maintenance) {
    // TODO: Implementar pantalla de detalles
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Detalles: ${maintenance.equipmentName}')),
    );
  }

  void _showTechnicianAssignment() {
    // TODO: Implementar bottom sheet de asignación de técnicos
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Asignar ${_selectedIds.length} mantenimientos (${_totalSelectedHours.toStringAsFixed(1)} hrs)',
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
