import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pm_monitor/core/models/maintenance_calendar_model.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/core/services/equipment_service.dart';
import 'package:pm_monitor/core/services/maintenance_schedule_service.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final MaintenanceSchedule? maintenance;
  final String? preselectedEquipmentId;

  const AddMaintenanceScreen({
    Key? key,
    this.maintenance,
    this.preselectedEquipmentId,
  }) : super(key: key);

  @override
  _AddMaintenanceScreenState createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _notesController = TextEditingController();
  final _locationController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _durationController = TextEditingController();

  // Form data
  String? _selectedEquipmentId;
  String? _selectedTechnicianId;
  String? _selectedSupervisorId;
  DateTime _scheduledDate = DateTime.now();
  TimeOfDay _scheduledTime = TimeOfDay.now();
  MaintenanceType _selectedType = MaintenanceType.preventive;
  FrequencyType _selectedFrequency = FrequencyType.monthly;
  List<String> _selectedTasks = [];
  bool _isRecurring = false;
  bool _isSaving = false; // Prevenir doble guardado

  // Available options - ahora se cargarán desde Firebase usando tu servicio existente
  List<Equipment> _equipments = [];
  List<Map<String, dynamic>> _technicians = [];
  List<Map<String, dynamic>> _supervisors = [];
  bool _isLoadingData = false;
  final EquipmentService _equipmentService = EquipmentService();
  final MaintenanceScheduleService _maintenanceService =
      MaintenanceScheduleService();
  List<String> _availableTasks = [
    'Limpieza de filtros',
    'Revisión de gas refrigerante',
    'Inspección de componentes eléctricos',
    'Lubricación de partes móviles',
    'Verificación de temperaturas',
    'Limpieza de serpentines',
    'Revisión de drenajes',
    'Inspección de aislamiento',
    'Prueba de funcionamiento',
    'Verificación de controles',
  ];

  bool get _isEditing => widget.maintenance != null;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initializeForm();
  }

  void _loadData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      // Cargar equipos usando tu servicio existente (Stream a Future)
      final equipmentStream = _equipmentService.getAllEquipments();
      final equipments = await equipmentStream.first;

      // Para técnicos y supervisores, necesitarías crear servicios similares
      // Por ahora usaré datos simulados, pero deberías crear UserService
      final technicians = await _loadTechnicians();
      final supervisors = await _loadSupervisors();

      setState(() {
        _equipments = equipments;
        _technicians = technicians;
        _supervisors = supervisors;
        _isLoadingData = false;
      });

      // Debug: Mostrar equipos cargados
      debugPrint('Equipos cargados: ${_equipments.length}');
      for (var equipment in _equipments) {
        debugPrint('- ${equipment.name} (${equipment.branch})');
      }
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });

      // En caso de error, mostrar un mensaje
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // Usar datos de respaldo vacíos para evitar errores
      _equipments = [];
      _technicians = [];
      _supervisors = [];
    }
  }

  // Método temporal para cargar técnicos (deberías crear un UserService)
  Future<List<Map<String, dynamic>>> _loadTechnicians() async {
    // Simulando datos por ahora - reemplazar con servicio real
    return [
      {'id': 'tech1', 'name': 'Juan Técnico'},
      {'id': 'tech2', 'name': 'Francisco Severino'},
    ];
  }

  // Método temporal para cargar supervisores (deberías crear un UserService)
  Future<List<Map<String, dynamic>>> _loadSupervisors() async {
    // Simulando datos por ahora - reemplazar con servicio real
    return [
      {'id': 'sup1', 'name': 'Karen Supervisor'},
    ];
  }

  void _initializeForm() {
    if (_isEditing) {
      final maintenance = widget.maintenance!;
      _selectedEquipmentId = maintenance.equipmentId;
      _selectedTechnicianId = maintenance.technicianId;
      _selectedSupervisorId = maintenance.supervisorId;
      _scheduledDate = maintenance.scheduledDate;
      _scheduledTime = TimeOfDay.fromDateTime(maintenance.scheduledDate);
      _selectedType = maintenance.type;
      _selectedFrequency = maintenance.frequency;
      _selectedTasks = List.from(maintenance.tasks);
      _notesController.text = maintenance.notes ?? '';
      _locationController.text = maintenance.location ?? '';
      _estimatedCostController.text =
          maintenance.estimatedCost?.toString() ?? '';
      _durationController.text =
          maintenance.estimatedDurationMinutes.toString();
    } else {
      _selectedEquipmentId = widget.preselectedEquipmentId;
      _durationController.text = '60';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _locationController.dispose();
    _estimatedCostController.dispose();
    _durationController.dispose();
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
        actions: [
          TextButton(
            onPressed: _isLoadingData ? null : _saveMaintenance,
            child: const Text(
              'Guardar',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildEquipmentSelection(),
                  const SizedBox(height: 16),
                  _buildDateTimeSelection(),
                  const SizedBox(height: 16),
                  _buildTypeAndFrequency(),
                  const SizedBox(height: 16),
                  _buildAssignmentSection(),
                  const SizedBox(height: 16),
                  _buildTasksSection(),
                  const SizedBox(height: 16),
                  _buildDetailsSection(),
                  const SizedBox(height: 16),
                  _buildRecurringSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildEquipmentSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Equipo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedEquipmentId,
              decoration: const InputDecoration(
                labelText: 'Seleccionar equipo',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: _equipments.map((equipment) {
                return DropdownMenuItem(
                  value: equipment.id,
                  child: Text(
                    '${equipment.name} - ${equipment.branch}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedEquipmentId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Por favor selecciona un equipo';
                }
                return null;
              },
            ),
          ],
        ),
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

  Widget _buildTypeAndFrequency() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipo y Frecuencia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MaintenanceType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipo de mantenimiento',
                border: OutlineInputBorder(),
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
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FrequencyType>(
              value: _selectedFrequency,
              decoration: const InputDecoration(
                labelText: 'Frecuencia',
                border: OutlineInputBorder(),
              ),
              items: FrequencyType.values.map((frequency) {
                return DropdownMenuItem(
                  value: frequency,
                  child: Text(_getFrequencyDisplayName(frequency)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFrequency = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Asignación',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTechnicianId,
              decoration: const InputDecoration(
                labelText: 'Técnico asignado',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Sin asignar'),
                ),
                ..._technicians.map((technician) {
                  return DropdownMenuItem(
                    value: technician['id'],
                    child: Text(technician['name']!),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedTechnicianId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSupervisorId,
              decoration: const InputDecoration(
                labelText: 'Supervisor asignado',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Sin asignar'),
                ),
                ..._supervisors.map((supervisor) {
                  return DropdownMenuItem(
                    value: supervisor['id'],
                    child: Text(supervisor['name']!),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedSupervisorId = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tareas a realizar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._availableTasks.map((task) {
              return CheckboxListTile(
                title: Text(task),
                value: _selectedTasks.contains(task),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedTasks.add(task);
                    } else {
                      _selectedTasks.remove(task);
                    }
                  });
                },
                dense: true,
              );
            }),
            if (_selectedTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Selecciona al menos una tarea',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Ubicación',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duración (minutos)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa la duración';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Ingresa un número válido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _estimatedCostController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Costo estimado',
                      border: OutlineInputBorder(),
                      prefixText: '\$',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas adicionales',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Programación Recurrente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Crear mantenimientos recurrentes'),
              subtitle:
                  const Text('Programa automáticamente mantenimientos futuros'),
              value: _isRecurring,
              onChanged: (value) {
                setState(() {
                  _isRecurring = value;
                });
              },
            ),
            if (_isRecurring) ...[
              const SizedBox(height: 12),
              const Text(
                'Se crearán mantenimientos automáticamente según la frecuencia seleccionada durante los próximos 12 meses.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF2196F3),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _scheduledDate) {
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF2196F3),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _scheduledTime) {
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
    }
  }

  String _getFrequencyDisplayName(FrequencyType frequency) {
    switch (frequency) {
      case FrequencyType.weekly:
        return 'Semanal';
      case FrequencyType.biweekly:
        return 'Bi-semanal';
      case FrequencyType.monthly:
        return 'Mensual';
      case FrequencyType.quarterly:
        return 'Trimestral';
      case FrequencyType.biannual:
        return 'Semestral';
      case FrequencyType.annual:
        return 'Anual';
      case FrequencyType.custom:
        return 'Personalizado';
    }
  }

  void _saveMaintenance() async {
    // Prevenir múltiples clics
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
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

    setState(() {
      _isSaving = true;
    });

    try {
      // Combinar fecha y hora
      final scheduledDateTime = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );

      // Obtener información del equipo seleccionado
      final selectedEquipment = _equipments.firstWhere(
        (eq) => eq.id == _selectedEquipmentId,
      );

      // Obtener nombres de técnico y supervisor si están seleccionados
      String? technicianName;
      String? supervisorName;

      if (_selectedTechnicianId != null) {
        final technician = _technicians.firstWhere(
          (tech) => tech['id'] == _selectedTechnicianId,
        );
        technicianName = technician['name'];
      }

      if (_selectedSupervisorId != null) {
        final supervisor = _supervisors.firstWhere(
          (sup) => sup['id'] == _selectedSupervisorId,
        );
        supervisorName = supervisor['name'];
      }

      final maintenance = MaintenanceSchedule(
        id: _isEditing ? widget.maintenance!.id : '',
        equipmentId: _selectedEquipmentId!,
        equipmentName: selectedEquipment.name,
        clientId: selectedEquipment.clientId,
        clientName:
            selectedEquipment.branch, // Usando branch como nombre del cliente
        technicianId: _selectedTechnicianId,
        technicianName: technicianName,
        supervisorId: _selectedSupervisorId,
        supervisorName: supervisorName,
        scheduledDate: scheduledDateTime,
        status: _isEditing
            ? widget.maintenance!.status
            : MaintenanceStatus.scheduled,
        type: _selectedType,
        frequency: _selectedFrequency,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        tasks: _selectedTasks,
        estimatedDurationMinutes: int.parse(_durationController.text),
        estimatedCost: _estimatedCostController.text.isEmpty
            ? null
            : double.tryParse(_estimatedCostController.text),
        location: _locationController.text.isEmpty
            ? selectedEquipment.location
            : _locationController.text,
        photoUrls: _isEditing ? widget.maintenance!.photoUrls : [],
        createdAt: _isEditing ? widget.maintenance!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy:
            _isEditing ? widget.maintenance!.createdBy : 'current_user_id',
        completedBy: _isEditing ? widget.maintenance!.completedBy : null,
        completionPercentage:
            _isEditing ? widget.maintenance!.completionPercentage : 0,
        taskCompletion: _isEditing ? widget.maintenance!.taskCompletion : null,
      );

      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Guardando mantenimiento...'),
            ],
          ),
        ),
      );

      String? maintenanceId;

      if (_isEditing) {
        // Actualizar mantenimiento existente
        final success =
            await _maintenanceService.updateMaintenance(maintenance);
        if (success) {
          maintenanceId = maintenance.id;
        }
      } else {
        // Crear nuevo mantenimiento
        maintenanceId =
            await _maintenanceService.createMaintenance(maintenance);
      }

      // SOLO si es recurrente y no es edición, crear mantenimientos futuros
      if (_isRecurring && !_isEditing && maintenanceId != null) {
        debugPrint('Creando mantenimientos recurrentes...');
        await _maintenanceService.scheduleRecurringMaintenances(
          equipmentId: _selectedEquipmentId!,
          equipmentName: selectedEquipment.name,
          clientId: selectedEquipment.clientId,
          clientName: selectedEquipment.branch,
          frequency: _selectedFrequency,
          startDate: scheduledDateTime
              .add(Duration(days: _getFrequencyDays(_selectedFrequency))),
          durationMonths: 12,
          tasks: _selectedTasks,
          estimatedDurationMinutes: int.parse(_durationController.text),
          technicianId: _selectedTechnicianId,
          technicianName: technicianName,
          supervisorId: _selectedSupervisorId,
          supervisorName: supervisorName,
          estimatedCost: double.tryParse(_estimatedCostController.text),
          location: _locationController.text.isEmpty
              ? selectedEquipment.location
              : _locationController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          createdBy:
              'current_user_id', // En producción, usar el ID del usuario actual
        );
      }

      // Cerrar loading
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Mostrar éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? 'Mantenimiento actualizado correctamente'
              : _isRecurring
                  ? 'Mantenimientos programados correctamente'
                  : 'Mantenimiento creado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Volver a la pantalla anterior
      Navigator.of(context).pop(true);
    } catch (e) {
      // Mostrar error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Cerrar loading y resetear estado
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      setState(() {
        _isSaving = false;
      });
    }
  }

  int _getFrequencyDays(FrequencyType frequency) {
    switch (frequency) {
      case FrequencyType.weekly:
        return 7;
      case FrequencyType.biweekly:
        return 14;
      case FrequencyType.monthly:
        return 30;
      case FrequencyType.quarterly:
        return 90;
      case FrequencyType.biannual:
        return 180;
      case FrequencyType.annual:
        return 365;
      case FrequencyType.custom:
        return 30; // Por defecto mensual
    }
  }
}
