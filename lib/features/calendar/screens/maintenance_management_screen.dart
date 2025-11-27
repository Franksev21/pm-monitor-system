import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pm_monitor/core/services/equipment_type_service.dart';
import 'package:pm_monitor/core/services/maintenance_schedule_service.dart';
import 'package:pm_monitor/core/models/client_model.dart';
import 'package:pm_monitor/core/services/client_service.dart';
import 'package:pm_monitor/core/services/technician_availability_service.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_model.dart';
import 'package:pm_monitor/features/equipment/screens/equipment_type_management_dialog.dart';
import 'package:pm_monitor/features/maintenance/screens/add_maintenance_screen.dart';
import 'package:pm_monitor/features/technician/screens/technician_availability_model.dart';
import 'package:pm_monitor/shared/widgets/client_search_dialog_widget.dart';

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
  final TechnicianAvailabilityService _technicianAvailabilityService =
      TechnicianAvailabilityService();

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
  String _assignmentFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  // Datos para filtros
  List<ClientModel> _clients = [];
  List<BranchModel> _branches = [];
// ✨ TIPOS DINÁMICOS DESDE FIREBASE
  List<String> _equipmentTypes = [];
  final EquipmentTypeService _equipmentTypeService = EquipmentTypeService();

  @override
  void initState() {
    super.initState();
    _loadClients();
    _loadEquipmentTypes(); 
    _technicianAvailabilityService.getTechniciansAvailability();
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

  Future<void> _loadEquipmentTypes() async {
    try {
      final types = await _equipmentTypeService.getEquipmentTypes();
      setState(() {
        _equipmentTypes = types.map((t) => t.name).toList();
      });
    } catch (e) {
      debugPrint('Error cargando tipos de equipos: $e');
    }
  }

  /// ⭐ Stream configurado con filtros de fecha
  Stream<List<MaintenanceSchedule>> _getMaintenancesStream() {
    final now = DateTime.now();
    final startDate = _startDate ?? now.subtract(const Duration(days: 30));
    final endDate = _endDate ?? now.add(const Duration(days: 30));

    debugPrint('🔍 Stream: $startDate → $endDate');

    return _maintenanceService.getMaintenancesStream(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// ⭐ Aplicar filtros locales a la lista
  List<MaintenanceSchedule> _applyLocalFilters(
      List<MaintenanceSchedule> maintenances) {
    var filtered = maintenances;

    if (_selectedClientId != null) {
      filtered =
          filtered.where((m) => m.clientId == _selectedClientId).toList();
    }

    if (_selectedBranchId != null) {
      filtered =
          filtered.where((m) => m.branchId == _selectedBranchId).toList();
    }

    if (_selectedEquipmentType != null) {
      filtered = filtered
          .where((m) => m.equipmentName == _selectedEquipmentType)
          .toList();
    }

    if (_selectedMaintenanceType != null) {
      filtered =
          filtered.where((m) => m.type == _selectedMaintenanceType).toList();
    }

    if (_selectedStatus != null) {
      filtered = filtered.where((m) => m.status == _selectedStatus).toList();
    }

    if (_assignmentFilter == 'assigned') {
      filtered = filtered.where((m) => m.technicianId != null).toList();
    } else if (_assignmentFilter == 'unassigned') {
      filtered = filtered.where((m) => m.technicianId == null).toList();
    }

    if (_selectedTechnicianId != null) {
      filtered = filtered
          .where((m) => m.technicianId == _selectedTechnicianId)
          .toList();
    }

    // Limpiar selecciones que ya no están en la lista filtrada
    _selectedIds.removeWhere((id) => !filtered.any((m) => m.id == id));

    return filtered;
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<MaintenanceSchedule> maintenances) {
    setState(() {
      if (_selectAll) {
        _selectedIds.clear();
        _selectAll = false;
      } else {
        _selectedIds.addAll(maintenances.map((m) => m.id));
        _selectAll = true;
      }
    });
  }

  double get _totalSelectedHours {
    return _selectedIds.length * 2.0;
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
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddMaintenanceScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickFiltersBar(activeFiltersCount),
          Expanded(
            child: StreamBuilder<List<MaintenanceSchedule>>(
              stream: _getMaintenancesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('❌ Error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text('Error al cargar'),
                        SizedBox(height: 8),
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final allMaintenances = snapshot.data!;
                final filteredMaintenances =
                    _applyLocalFilters(allMaintenances);

                debugPrint(
                    '✅ ${filteredMaintenances.length} mantenimientos mostrados');

                return Column(
                  children: [
                    if (filteredMaintenances.isNotEmpty)
                      _buildSelectAllBar(filteredMaintenances),
                    Expanded(
                      child: _buildMaintenancesList(filteredMaintenances),
                    ),
                  ],
                );
              },
            ),
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

  Widget _buildSelectAllBar(List<MaintenanceSchedule> maintenances) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Checkbox(
            value: _selectAll,
            onChanged: (_) => _toggleSelectAll(maintenances),
            activeColor: const Color(0xFF007AFF),
          ),
          const SizedBox(width: 8),
          Text(
            _selectAll
                ? 'Deseleccionar todos'
                : 'Seleccionar todos (${maintenances.length})',
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

  Widget _buildMaintenancesList(List<MaintenanceSchedule> maintenances) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: maintenances.length,
      itemBuilder: (context, index) {
        final maintenance = maintenances[index];
        final isSelected = _selectedIds.contains(maintenance.id);

        return _buildMaintenanceCard(maintenance, isSelected);
      },
    );
  }

  Widget _buildMaintenanceCard(
    MaintenanceSchedule maintenance,
    bool isSelected,
  ) {
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
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(maintenance.id!),
                activeColor: const Color(0xFF007AFF),
              ),
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
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
                          '${maintenance.estimatedHours ?? 0} hrs',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddMaintenanceScreen(),
                      ),
                    );
                  } else if (value == 'delete') {
                    _confirmDeleteMaintenance(maintenance.id!);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(MaintenanceType type) {
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
    String? tempClientId = _selectedClientId;
    String? tempBranchId = _selectedBranchId;
    String? tempEquipmentType = _selectedEquipmentType;
    String? tempCustomEquipmentType;
    MaintenanceType? tempMaintenanceType = _selectedMaintenanceType;
    MaintenanceStatus? tempStatus =
        _selectedStatus; // ✨ Mantenemos pero no se muestra
    String tempAssignmentFilter = _assignmentFilter;
    String? tempTechnicianId = _selectedTechnicianId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // ✨ Auto-calcular estado basado en asignación
          MaintenanceStatus? calculatedStatus;
          if (tempAssignmentFilter == 'generated') {
            calculatedStatus = MaintenanceStatus.generated;
          } else if (tempAssignmentFilter == 'assigned') {
            calculatedStatus = MaintenanceStatus.assigned;
          } else if (tempAssignmentFilter == 'executed') {
            calculatedStatus = MaintenanceStatus.executed;
          }

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
                // ==================== HEADER ====================
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
                            tempCustomEquipmentType = null;
                            tempMaintenanceType = null;
                            tempStatus = null;
                            tempAssignmentFilter = 'all';
                            tempTechnicianId = null;
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

                // ==================== CONTENIDO ====================
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ==================== CLIENTE ====================
                        const Text(
                          'Cliente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final selectedClientId =
                                await _showClientSearchDialog();
                            if (selectedClientId != null) {
                              setModalState(() {
                                tempClientId = selectedClientId;
                                final client = _clients.firstWhere(
                                  (c) => c.id == selectedClientId,
                                );
                                _branches = client.branches;
                                tempBranchId = 'principal';
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: tempClientId != null
                                  ? Colors.blue[50]
                                  : Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: tempClientId != null
                                      ? Colors.blue[700]
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tempClientId != null
                                        ? _clients
                                            .firstWhere(
                                                (c) => c.id == tempClientId)
                                            .name
                                        : 'Todos los clientes',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: tempClientId != null
                                          ? Colors.blue[700]
                                          : Colors.grey[700],
                                      fontWeight: tempClientId != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (tempClientId != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      setModalState(() {
                                        tempClientId = null;
                                        tempBranchId = null;
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                else
                                  Icon(Icons.search, color: Colors.grey[600]),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ==================== SUCURSAL ====================
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
                                  DropdownMenuItem<String>(
                                    value: 'principal',
                                    child: Row(
                                      children: [
                                        Icon(Icons.home,
                                            size: 16, color: Colors.blue[700]),
                                        const SizedBox(width: 8),
                                        const Text('Principal'),
                                      ],
                                    ),
                                  ),
                                  ..._branches.map((branch) {
                                    return DropdownMenuItem<String>(
                                      value: branch.id,
                                      child: Row(
                                        children: [
                                          Icon(Icons.store,
                                              size: 16,
                                              color: Colors.orange[700]),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              branch.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
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

                        // ==================== TIPO DE MANTENIMIENTO ====================
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

                        // ==================== ASIGNACIÓN (ANTES ESTABA ESTADO) ====================
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
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Todos'),
                              selected: tempAssignmentFilter == 'all',
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    tempAssignmentFilter = 'all';
                                    tempTechnicianId = null; // Limpiar técnico
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Generados'),
                              selected: tempAssignmentFilter == 'generated',
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    tempAssignmentFilter = 'generated';
                                    tempTechnicianId = null; // Limpiar técnico
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
                              label: const Text('Ejecutados'),
                              selected: tempAssignmentFilter == 'executed',
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    tempAssignmentFilter = 'executed';
                                  });
                                }
                              },
                            ),
                          ],
                        ),

                        // ✨ FILTRO DE TÉCNICO (SOLO SI ESTÁ ASIGNADO O EJECUTADO)
                        if (tempAssignmentFilter == 'assigned' ||
                            tempAssignmentFilter == 'executed') ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Técnico',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<TechnicianAvailability>>(
                            future: _technicianAvailabilityService
                                .getTechniciansAvailability(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final technicians = snapshot.data!;

                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    isExpanded: true,
                                    value: tempTechnicianId,
                                    hint: const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('Todos los técnicos'),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Todos los técnicos'),
                                      ),
                                      ...technicians.map((tech) {
                                        return DropdownMenuItem<String>(
                                          value: tech.id,
                                          child: Row(
                                            children: [
                                              Icon(Icons.person,
                                                  size: 16,
                                                  color: Colors.blue[700]),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  tech.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (value) {
                                      setModalState(() {
                                        tempTechnicianId = value;
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ],

                        const SizedBox(height: 16),

                        // ==================== TIPO DE EQUIPO CON GESTIONAR ====================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tipo de Equipo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                // Cerrar modal de filtros
                                Navigator.pop(context);

                                // Abrir diálogo de gestión
                                await showDialog(
                                  context: context,
                                  builder: (context) =>
                                      const EquipmentTypeManagementDialog(),
                                );

                                // Recargar tipos
                                await _loadEquipmentTypes();

                                // Reabrir modal de filtros
                                _showFiltersBottomSheet();
                              },
                              icon: const Icon(Icons.settings, size: 16),
                              label: const Text(
                                'Gestionar',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  setModalState(() {
                                    tempEquipmentType = null;
                                    tempCustomEquipmentType = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tempEquipmentType == null
                                        ? Colors.blue[50]
                                        : Colors.white,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      topRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        tempEquipmentType == null
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: tempEquipmentType == null
                                            ? Colors.blue[700]
                                            : Colors.grey[400],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Todos los equipos',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: tempEquipmentType == null
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: tempEquipmentType == null
                                              ? Colors.blue[700]
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ..._equipmentTypes.map((type) {
                                final isSelected = tempEquipmentType == type;
                                return InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      tempEquipmentType = type;
                                      tempCustomEquipmentType = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue[50]
                                          : Colors.white,
                                      border: Border(
                                        top: BorderSide(
                                            color: Colors.grey[300]!),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          color: isSelected
                                              ? Colors.blue[700]
                                              : Colors.grey[400],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          type,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? Colors.blue[700]
                                                : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              InkWell(
                                onTap: () {
                                  setModalState(() {
                                    tempEquipmentType = 'Otro';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tempEquipmentType == 'Otro'
                                        ? Colors.blue[50]
                                        : Colors.white,
                                    border: Border(
                                      top: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        tempEquipmentType == 'Otro'
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: tempEquipmentType == 'Otro'
                                            ? Colors.blue[700]
                                            : Colors.grey[400],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Otro (Especificar)',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight:
                                              tempEquipmentType == 'Otro'
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                          color: tempEquipmentType == 'Otro'
                                              ? Colors.blue[700]
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (tempEquipmentType == 'Otro') ...[
                          const SizedBox(height: 12),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Escribir tipo de equipo...',
                              prefixIcon: const Icon(Icons.edit),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.blue[50],
                            ),
                            onChanged: (value) {
                              tempCustomEquipmentType = value;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ==================== BOTÓN APLICAR ====================
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
                          if (tempEquipmentType == 'Otro' &&
                              tempCustomEquipmentType != null &&
                              tempCustomEquipmentType!.isNotEmpty) {
                            _selectedEquipmentType = tempCustomEquipmentType;
                          } else {
                            _selectedEquipmentType = tempEquipmentType;
                          }
                          _selectedMaintenanceType = tempMaintenanceType;
                          _selectedStatus =
                              calculatedStatus; // ✨ Auto-calculado
                          _assignmentFilter = tempAssignmentFilter;
                          _selectedTechnicianId = tempTechnicianId;
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

  Future<String?> _showClientSearchDialog() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => ClientSearchDialog(
        clients: _clients,
        returnFullModel: false,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Detalles: ${maintenance.equipmentName}')),
    );
  }

  void _confirmDeleteMaintenance(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Mantenimiento'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await _maintenanceService.deleteMaintenance(id);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mantenimiento eliminado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showTechnicianAssignment() async {
    final availabilityService = TechnicianAvailabilityService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder<List<TechnicianAvailability>>(
        future: availabilityService.getTechniciansAvailability(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 400,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Container(
              height: 400,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No hay técnicos disponibles',
                      style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            );
          }

          return _buildTechnicianAssignmentSheet(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildTechnicianAssignmentSheet(
    List<TechnicianAvailability> technicians,
  ) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Asignar Técnico',
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
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedIds.length} mantenimiento${_selectedIds.length != 1 ? 's' : ''} • ${_totalSelectedHours.toStringAsFixed(1)} hrs',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: technicians.length,
              itemBuilder: (context, index) {
                final tech = technicians[index];
                return _buildTechnicianCard(tech);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianCard(TechnicianAvailability tech) {
    final canAccept = tech.canAcceptHours(_totalSelectedHours);
    final utilizationColor = tech.isOverloaded
        ? Colors.red
        : tech.isNearLimit
            ? Colors.orange
            : tech.assignedHours > tech.regularHours
                ? Colors.amber
                : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canAccept ? Colors.grey[300]! : Colors.red[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: canAccept
            ? () => _confirmAssignment(tech)
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${tech.name} no tiene suficiente disponibilidad',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: utilizationColor.withOpacity(0.2),
                    child: Text(
                      tech.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: utilizationColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tech.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tech.activeMaintenances} activo${tech.activeMaintenances != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: utilizationColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tech.availabilityStatus,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: utilizationColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${tech.assignedHours.toStringAsFixed(1)} / ${tech.maxWeeklyHours.toStringAsFixed(0)} hrs',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${tech.utilizationPercentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: utilizationColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: tech.utilizationPercentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          AlwaysStoppedAnimation<Color>(utilizationColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              if (!canAccept) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber,
                          size: 16, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Insuficiente disponibilidad',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAssignment(TechnicianAvailability tech) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Asignación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '¿Asignar ${_selectedIds.length} mantenimiento${_selectedIds.length != 1 ? 's' : ''} a:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tech.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Horas actuales: ${tech.assignedHours.toStringAsFixed(1)} hrs'),
                  Text(
                      'Horas a agregar: ${_totalSelectedHours.toStringAsFixed(1)} hrs'),
                  const Divider(),
                  Text(
                    'Total: ${(tech.assignedHours + _totalSelectedHours).toStringAsFixed(1)} hrs',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              await _performAssignment(tech);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAssignment(TechnicianAvailability tech) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Asignando mantenimientos...'),
                ],
              ),
            ),
          ),
        ),
      );

      await _maintenanceService.assignTechnicianToMaintenances(
        maintenanceIds: _selectedIds.toList(),
        technicianId: tech.id,
        technicianName: tech.name,
      );

      Navigator.pop(context);

      setState(() {
        _selectedIds.clear();
        _selectAll = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Mantenimientos asignados a ${tech.name}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
