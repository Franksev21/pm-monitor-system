import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_model.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/core/models/client_model.dart';
import 'package:pm_monitor/core/services/equipment_service.dart';
import 'package:pm_monitor/core/services/maintenance_schedule_service.dart';
import 'package:pm_monitor/core/services/client_service.dart';
import 'package:pm_monitor/shared/widgets/client_search_dialog_widget.dart';
import 'dart:async';

import 'package:pm_monitor/core/services/task_template_service.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final MaintenanceSchedule? maintenance;
  final String? preselectedEquipmentId;

  const AddMaintenanceScreen({
    super.key,
    this.maintenance,
    this.preselectedEquipmentId,
  });

  @override
  _AddMaintenanceScreenState createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  // Estado local
  final Map<String, FrequencyType> _taskFrequencies = {};
  String? _selectedBranchId;
  BranchModel? _selectedBranch;
  List<BranchModel> _availableBranches = [];

  // Archivos adjuntos
  final List<PlatformFile> _attachedFiles = [];
  final bool _isUploadingFiles = false;

  // Form data
  ClientModel? _selectedClient;
  Equipment? _selectedEquipment;
  DateTime _scheduledDate = DateTime.now();
  TimeOfDay _scheduledTime = TimeOfDay.now();
  MaintenanceType _selectedType = MaintenanceType.preventive;
  List<String> _selectedTasks = [];
  List<String> _availableTasks = [];
  bool _isSaving = false;

  // Available options
  List<ClientModel> _clients = [];
  List<Equipment> _clientEquipments = [];
  List<Equipment> _branchEquipments = [];
  bool _isLoadingData = false;

  final TaskTemplateService _taskTemplateService = TaskTemplateService();
  bool _isLoadingTasks = false;
  StreamSubscription? _tasksSubscription;

  final EquipmentService _equipmentService = EquipmentService();
  final MaintenanceScheduleService _maintenanceService =
      MaintenanceScheduleService();
  final ClientService _clientService = ClientService();

  bool get _isEditing => widget.maintenance != null;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _updateAvailableTasks();
    _initializeForm();
  }

  void _loadClients() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      _clientService.getClients().listen((clients) {
        if (mounted) {
          setState(() {
            _clients = clients;
            _isLoadingData = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar clientes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadEquipmentsForClient(ClientModel client) async {
    try {
      final equipments = await _equipmentService.getAllEquipments().first;

      final clientEquipments = equipments.where((equipment) {
        return equipment.branch.toLowerCase() == client.name.toLowerCase() ||
            equipment.clientId == client.id;
      }).toList();

      setState(() {
        _clientEquipments = clientEquipments;
        _availableBranches = client.branches;
        _selectedBranchId = 'principal';
        _selectedBranch = null;
        _branchEquipments = clientEquipments.where((eq) {
          return eq.branchId == null || eq.branchId!.isEmpty;
        }).toList();
      });
    } catch (e) {
      debugPrint('❌ Error cargando equipos: $e');
    }
  }

  void _filterEquipmentsByBranch() {
    if (_selectedClient == null) return;

    if (_selectedBranchId == null || _selectedBranchId == 'principal') {
      // Mostrar equipos de dirección principal
      setState(() {
        _branchEquipments = _clientEquipments.where((eq) {
          return eq.branchId == null || eq.branchId!.isEmpty;
        }).toList();
      });
    } else {
      // Filtrar por sucursal seleccionada
      setState(() {
        _branchEquipments = _clientEquipments.where((eq) {
          return eq.branchId == _selectedBranchId;
        }).toList();
      });
    }
  }

  // ← NUEVO: Método helper para convertir enum a string
  String _getMaintenanceTypeString(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.preventive:
        return 'preventive';
      case MaintenanceType.corrective:
        return 'corrective';
      case MaintenanceType.emergency:
        return 'emergency';
      case MaintenanceType.inspection:
        return 'inspection';
      case MaintenanceType.technicalAssistance:
        return 'technicalAssistance';
    }
  }

  // ← MODIFICADO: Ahora carga desde Firebase
  void _updateAvailableTasks() {
    setState(() {
      _isLoadingTasks = true;
    });

    // Cancelar suscripción anterior si existe
    _tasksSubscription?.cancel();

    final typeString = _getMaintenanceTypeString(_selectedType);

    // Escuchar cambios en tiempo real desde Firebase
    _tasksSubscription = _taskTemplateService
        .getActiveTemplatesByType(typeString)
        .listen((templates) {
      if (mounted) {
        setState(() {
          _availableTasks = templates.map((t) => t.name.toString()).toList();
          _isLoadingTasks = false;
          _selectedTasks = _selectedTasks
              .where((task) => _availableTasks.contains(task))
              .toList();
        });
      }
    }, onError: (error) {
      debugPrint('❌ Error cargando tareas: $error');
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando tareas: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _initializeForm() {
    if (_isEditing) {
      final maintenance = widget.maintenance!;
      _selectedType = maintenance.type;
      _scheduledDate = maintenance.scheduledDate;
      _scheduledTime = TimeOfDay.fromDateTime(maintenance.scheduledDate);
      _selectedTasks = List.from(maintenance.tasks);
      _notesController.text = maintenance.notes ?? '';

      if (MaintenanceSchedule.requiresFrequency(maintenance.type)) {
        if (maintenance.taskFrequencies != null &&
            maintenance.taskFrequencies!.isNotEmpty) {
          // Cargar frecuencias guardadas
          for (var entry in maintenance.taskFrequencies!.entries) {
            final frequencyEnum = FrequencyType.values.firstWhere(
              (e) => e.toString().split('.').last == entry.value,
              orElse: () => FrequencyType.monthly,
            );
            _taskFrequencies[entry.key] = frequencyEnum;
          }
          debugPrint('✅ Frecuencias cargadas desde BD: $_taskFrequencies');
        } else if (maintenance.frequency != null) {
          // Fallback: usar frecuencia general para todas las tareas
          for (var task in _selectedTasks) {
            _taskFrequencies[task] = maintenance.frequency!;
          }
          debugPrint('⚠️ Usando frecuencia general para todas las tareas');
        }
      }

      _updateAvailableTasks();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tasksSubscription?.cancel(); // ← NUEVO: Cancelar suscripción
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isEditing ? 'Editar Mantenimiento' : 'Nuevo Mantenimiento'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: _isLoadingData
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando datos...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 100,
                    ),
                    children: [
                      _buildClientSelection(),
                      const SizedBox(height: 16),
                      if (_selectedClient != null) ...[
                        _buildBranchSelection(),
                        const SizedBox(height: 16),
                      ],
                      if (_selectedBranchId != null) ...[
                        _buildEquipmentSelection(),
                        const SizedBox(height: 16),
                      ],
                      _buildDateTimeSelection(),
                      const SizedBox(height: 16),
                      _buildType(),
                      const SizedBox(height: 16),
                      _buildTasksSection(),
                      const SizedBox(height: 16),
                      _buildNotesSection(),
                      const SizedBox(height: 16),
                    ],
                  ),

                  // Botón flotante
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveMaintenance,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Guardando...'),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.save),
                                      const SizedBox(width: 8),
                                      Text(_isEditing
                                          ? 'Actualizar'
                                          : 'Guardar Mantenimiento'),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildClientSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Cliente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showClientSearchDialog(),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Seleccionar cliente *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedClient != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedClient = null;
                              _selectedBranchId = null;
                              _selectedBranch = null;
                              _selectedEquipment = null;
                              _clientEquipments = [];
                              _branchEquipments = [];
                            });
                          },
                        ),
                      const Icon(Icons.search),
                    ],
                  ),
                ),
                child: Text(
                  _selectedClient == null
                      ? 'Toca para buscar...'
                      : _selectedClient!.displayName,
                  style: TextStyle(
                    color: _selectedClient == null
                        ? Colors.grey[600]
                        : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClientSearchDialog() async {
    final selectedClient = await showDialog<ClientModel>(
      context: context,
      builder: (context) =>
          ClientSearchDialog(clients: _clients, returnFullModel: true),
    );

    if (selectedClient != null && mounted) {
      setState(() {
        _selectedClient = selectedClient;
        _selectedBranchId = null;
        _selectedBranch = null;
        _selectedEquipment = null;
        _clientEquipments = [];
        _branchEquipments = [];
      });
      await _loadEquipmentsForClient(selectedClient);
    }
  }

  Widget _buildBranchSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '2. Sucursal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedBranchId,
              decoration: const InputDecoration(
                labelText: 'Seleccionar sucursal *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              isExpanded: true,
              items: [
                DropdownMenuItem<String>(
                  value: 'principal',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Principal - ${_selectedClient!.mainAddress.city}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._availableBranches.map((branch) {
                  return DropdownMenuItem<String>(
                    value: branch.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.store, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${branch.name} - ${branch.address.city}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedBranchId = value;
                  if (value == 'principal') {
                    _selectedBranch = null;
                  } else {
                    _selectedBranch = _availableBranches.firstWhere(
                      (b) => b.id == value,
                    );
                  }
                  _selectedEquipment = null;
                });
                _filterEquipmentsByBranch();
              },
            ),
            if (_selectedBranchId != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getSelectedBranchAddress(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getSelectedBranchAddress() {
    if (_selectedBranchId == 'principal') {
      return '${_selectedClient!.mainAddress.street}, ${_selectedClient!.mainAddress.city}, ${_selectedClient!.mainAddress.state}';
    } else if (_selectedBranch != null) {
      return '${_selectedBranch!.address.street}, ${_selectedBranch!.address.city}, ${_selectedBranch!.address.state}';
    }
    return '';
  }

  Widget _buildEquipmentSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '3. Equipo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_branchEquipments.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No hay equipos en esta sucursal',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              InkWell(
                onTap: () => _showEquipmentSearchDialog(),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Seleccionar equipo *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.ac_unit),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedEquipment != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _selectedEquipment = null;
                              });
                            },
                          ),
                        const Icon(Icons.search),
                      ],
                    ),
                  ),
                  child: Text(
                    _selectedEquipment == null
                        ? 'Toca para buscar...'
                        : '${_selectedEquipment!.name} - ${_selectedEquipment!.location}',
                    style: TextStyle(
                      color: _selectedEquipment == null
                          ? Colors.grey[600]
                          : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEquipmentSearchDialog() {
    String searchQuery = '';
    List<Equipment> filteredEquipments = _branchEquipments;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void filterEquipments(String query) {
            setDialogState(() {
              searchQuery = query;
              if (query.isEmpty) {
                filteredEquipments = _branchEquipments;
              } else {
                final queryLower = query.toLowerCase();
                filteredEquipments = _branchEquipments.where((equipment) {
                  return equipment.name.toLowerCase().contains(queryLower) ||
                      equipment.equipmentNumber
                          .toLowerCase()
                          .contains(queryLower) ||
                      equipment.brand.toLowerCase().contains(queryLower) ||
                      equipment.model.toLowerCase().contains(queryLower) ||
                      equipment.location.toLowerCase().contains(queryLower);
                }).toList();
              }
            });
          }

          return Dialog(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Seleccionar Equipo',
                        style: TextStyle(
                          fontSize: 18,
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
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, marca, ubicación...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => filterEquipments(''),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: filterEquipments,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${filteredEquipments.length} equipos encontrados',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredEquipments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text('No se encontraron equipos',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredEquipments.length,
                            itemBuilder: (context, index) {
                              final equipment = filteredEquipments[index];
                              final isSelected =
                                  equipment.id == _selectedEquipment?.id;

                              return Card(
                                color: isSelected ? Colors.blue[50] : null,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        isSelected ? Colors.blue : Colors.grey,
                                    child: const Icon(
                                      Icons.ac_unit,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(equipment.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('N°: ${equipment.equipmentNumber}'),
                                      Text(
                                          '${equipment.brand} ${equipment.model}'),
                                      Text('📍 ${equipment.location}'),
                                    ],
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.blue)
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedEquipment = equipment;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateTimeSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fecha y Hora',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        border: OutlineInputBorder(),
                      ),
                      child:
                          Text(DateFormat('dd/MM/yyyy').format(_scheduledDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hora',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_scheduledTime.format(context)),
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

  Widget _buildType() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipo de Mantenimiento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MaintenanceType>(
              value: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.build),
              ),
              items: MaintenanceType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getMaintenanceTypeDisplayName(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                  _updateAvailableTasks();
                });
              },
            ),
            if (!MaintenanceSchedule.requiresFrequency(_selectedType)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Este tipo no requiere frecuencia',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection() {
    // Solo mostrar frecuencias si el tipo de mantenimiento las requiere
    final showFrequencies =
        MaintenanceSchedule.requiresFrequency(_selectedType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Tareas a Realizar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_selectedTasks.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_selectedTasks.length} seleccionadas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // ← NUEVO: Mostrar loading mientras se cargan tareas
            if (_isLoadingTasks) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Cargando tareas desde Firebase...'),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ..._availableTasks.map((task) {
                final isSelected = _selectedTasks.contains(task);
                final frequency =
                    _taskFrequencies[task] ?? FrequencyType.monthly;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? Colors.blue[50] : Colors.white,
                  ),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: Text(
                          task,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedTasks.add(task);
                              // Inicializar frecuencia por defecto
                              if (showFrequencies &&
                                  !_taskFrequencies.containsKey(task)) {
                                _taskFrequencies[task] = FrequencyType.monthly;
                              }
                            } else {
                              _selectedTasks.remove(task);
                              _taskFrequencies.remove(task);
                            }
                          });
                        },
                      ),

                      // Mostrar selector de frecuencia solo si:
                      // 1. La tarea está seleccionada
                      // 2. El tipo de mantenimiento requiere frecuencia
                      if (isSelected && showFrequencies) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Frecuencia:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<FrequencyType>(
                                  value: frequency,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: FrequencyType.values.map((freq) {
                                    return DropdownMenuItem(
                                      value: freq,
                                      child: Text(
                                        _getFrequencyDisplayName(freq),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _taskFrequencies[task] = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
            if (_selectedTasks.isEmpty && !_isLoadingTasks)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Selecciona al menos una tarea'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalles Adicionales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Notas adicionales
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas adicionales',
                border: OutlineInputBorder(),
                hintText: 'Instrucciones especiales, observaciones...',
                prefixIcon: Icon(Icons.note),
              ),
            ),

            const SizedBox(height: 16),

            // Archivos adjuntos
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.attach_file, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Archivos Adjuntos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _isUploadingFiles ? null : _pickFiles,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Adjuntar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sube imágenes o PDFs con instrucciones del mantenimiento',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (_attachedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attachedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _attachedFiles[index];
                      return _buildFileItem(file, index);
                    },
                  ),
                ],
                if (_attachedFiles.isEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No hay archivos adjuntos',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: true,
        withData: true, // ✅ CRÍTICO: Necesario para obtener bytes en web
      );

      if (result != null && result.files.isNotEmpty) {
        // ✅ Validar que los archivos tengan bytes
        final validFiles = result.files.where((file) {
          if (file.bytes == null) {
            debugPrint('⚠️ Archivo sin bytes: ${file.name}');
            return false;
          }
          return true;
        }).toList();

        if (validFiles.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Los archivos no se pudieron cargar correctamente'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _attachedFiles.addAll(validFiles);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${validFiles.length} archivo(s) adjuntado(s)'),
              backgroundColor: Colors.green,
            ),
          );
        }

        debugPrint('✅ ${validFiles.length} archivos añadidos con bytes');
        for (var file in validFiles) {
          debugPrint(
              '  - ${file.name}: ${(file.size / 1024).toStringAsFixed(1)} KB');
        }
      }
    } catch (e) {
      debugPrint('❌ Error seleccionando archivos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar archivos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Archivo eliminado'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFileItem(PlatformFile file, int index) {
    final extension = file.extension?.toLowerCase() ?? '';
    IconData fileIcon;
    Color fileColor;

    switch (extension) {
      case 'pdf':
        fileIcon = Icons.picture_as_pdf;
        fileColor = Colors.red;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        fileIcon = Icons.image;
        fileColor = Colors.blue;
        break;
      case 'doc':
      case 'docx':
        fileIcon = Icons.description;
        fileColor = Colors.blue[800]!;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
        fileColor = Colors.grey;
    }

    final fileSize = file.size / 1024; // KB
    final fileSizeText = fileSize < 1024
        ? '${fileSize.toStringAsFixed(1)} KB'
        : '${(fileSize / 1024).toStringAsFixed(1)} MB';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: fileColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(fileIcon, color: fileColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  fileSizeText,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: Colors.red,
            onPressed: () => _removeFile(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
      });
    }
  }

  String _getMaintenanceTypeDisplayName(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.preventive:
        return 'Preventivo';
      case MaintenanceType.corrective:
        return 'Correctivo';
      case MaintenanceType.emergency:
        return 'Emergencia';
      case MaintenanceType.inspection:
        return 'Inspección';
      case MaintenanceType.technicalAssistance:
        return 'Asistencia Técnica';
    }
  }

  String _getFrequencyDisplayName(FrequencyType frequency) {
    switch (frequency) {
      case FrequencyType.weekly:
        return 'Semanal';
      case FrequencyType.biweekly:
        return 'C/2 Semanas';
      case FrequencyType.monthly:
        return 'Mensual';
      case FrequencyType.bimonthly:
        return 'C/2 Meses';
      case FrequencyType.quarterly:
        return 'C/3 Meses';
      case FrequencyType.quadrimestral:
        return 'C/4 Meses';
      case FrequencyType.biannual:
        return 'C/6 Meses';
      case FrequencyType.annual:
        return 'Anual';
    }
  }

  void _saveMaintenance() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un cliente'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una sucursal'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedEquipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un equipo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar que el equipo tenga ID
    if (_selectedEquipment!.id == null || _selectedEquipment!.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El equipo seleccionado no tiene un ID válido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona al menos una tarea'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar que las tareas que requieren frecuencia la tengan asignada
    if (MaintenanceSchedule.requiresFrequency(_selectedType)) {
      final tasksWithoutFrequency = _selectedTasks.where((task) {
        return !_taskFrequencies.containsKey(task);
      }).toList();

      if (tasksWithoutFrequency.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Asigna una frecuencia a todas las tareas: ${tasksWithoutFrequency.join(", ")}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final scheduledDateTime = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );

      String branchName;
      String branchAddress;
      String? branchId;

      if (_selectedBranchId == 'principal') {
        branchName = 'Dirección Principal';
        branchAddress =
            '${_selectedClient!.mainAddress.street}, ${_selectedClient!.mainAddress.city}';
        branchId = null;
      } else {
        branchName = _selectedBranch!.name;
        branchAddress =
            '${_selectedBranch!.address.street}, ${_selectedBranch!.address.city}';
        branchId = _selectedBranch!.id;
      }

     List<String> uploadedFileUrls = [];
      if (_attachedFiles.isNotEmpty) {
        debugPrint('📤 Subiendo ${_attachedFiles.length} archivos...');

        for (int i = 0; i < _attachedFiles.length; i++) {
          final file = _attachedFiles[i];
          try {
            // Mostrar progreso
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Subiendo archivo ${i + 1}/${_attachedFiles.length}...'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }

            final fileUrl = await _uploadFileToStorage(file);
            if (fileUrl != null) {
              uploadedFileUrls.add(fileUrl);
              debugPrint('✅ Archivo subido: ${file.name}');
            }
          } catch (e) {
            debugPrint('❌ Error subiendo archivo ${file.name}: $e');
            // Continuar con los demás archivos
          }
        }

        debugPrint(
            '✅ ${uploadedFileUrls.length}/${_attachedFiles.length} archivos subidos');
      }

      // Para mantenimientos que requieren frecuencia, usar la frecuencia más común
      FrequencyType? mainFrequency;
      if (MaintenanceSchedule.requiresFrequency(_selectedType) &&
          _taskFrequencies.isNotEmpty) {
        final frequencyCount = <FrequencyType, int>{};
        for (var freq in _taskFrequencies.values) {
          frequencyCount[freq] = (frequencyCount[freq] ?? 0) + 1;
        }
        mainFrequency = frequencyCount.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      debugPrint('📝 Preparando datos del mantenimiento...');
      debugPrint(
          '  Cliente: ${_selectedClient!.name} (${_selectedClient!.id})');
      debugPrint('  Sucursal: $branchName ($branchId)');
      debugPrint(
          '  Equipo: ${_selectedEquipment!.name} (${_selectedEquipment!.id})');
      debugPrint('  Tipo: ${_selectedType.toString()}');
      debugPrint(
          '  Frecuencia principal: ${mainFrequency?.toString() ?? "N/A"}');
      debugPrint('  Tareas seleccionadas: ${_selectedTasks.length}');
      debugPrint('  Frecuencias por tarea: $_taskFrequencies');
      debugPrint('  Archivos adjuntos: ${uploadedFileUrls.length}');

      // Convertir Map<String, FrequencyType> a Map<String, String> para Firestore
      Map<String, String>? taskFrequenciesForFirestore;
      if (_taskFrequencies.isNotEmpty) {
        taskFrequenciesForFirestore = _taskFrequencies.map(
          (key, value) => MapEntry(key, value.toString().split('.').last),
        );
      }

      final maintenance = MaintenanceSchedule(
        id: _isEditing ? widget.maintenance!.id : '',
        equipmentId: _selectedEquipment!.id ?? '',
        equipmentName: _selectedEquipment!.name,
        clientId: _selectedClient!.id,
        clientName: _selectedClient!.name,
        branchId: branchId,
        branchName: branchName,
        technicianId: null,
        technicianName: null,
        supervisorId: null,
        supervisorName: null,
        scheduledDate: scheduledDateTime,
        status: _isEditing
            ? widget.maintenance!.status
            : MaintenanceStatus.generated,
        type: _selectedType,
        frequency: mainFrequency,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        tasks: _selectedTasks,
        location: branchAddress,
        photoUrls: uploadedFileUrls, // NUEVO: URLs de archivos subidos
        createdAt: _isEditing ? widget.maintenance!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy:
            _isEditing ? widget.maintenance!.createdBy : 'current_user_id',
        completedBy: _isEditing ? widget.maintenance!.completedBy : null,
        completionPercentage:
            _isEditing ? widget.maintenance!.completionPercentage : 0,
        taskCompletion: _isEditing ? widget.maintenance!.taskCompletion : null,
        taskFrequencies: taskFrequenciesForFirestore, // NUEVO
      );

      if (_isEditing) {
        await _maintenanceService.updateMaintenance(maintenance);
      } else {
        await _maintenanceService.createMaintenance(maintenance);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Mantenimiento actualizado'
                : 'Mantenimiento creado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error guardando mantenimiento: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // NUEVO: Método para subir archivos a Firebase Storage
  Future<String?> _uploadFileToStorage(PlatformFile file) async {
    try {
      if (file.bytes == null) {
        debugPrint('⚠️ Archivo sin bytes: ${file.name}');
        return null;
      }

      // Crear referencia única en Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${file.name}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('maintenance_attachments')
          .child(fileName);

      // Subir archivo
      final uploadTask = await storageRef.putData(
        file.bytes!,
        SettableMetadata(
          contentType: _getContentType(file.extension),
        ),
      );

      // Obtener URL de descarga
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error subiendo archivo a Storage: $e');
      return null;
    }
  }

  // Helper para obtener content type
  String _getContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}
