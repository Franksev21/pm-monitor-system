import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/core/providers/equipment_provider.dart';
import 'package:pm_monitor/core/providers/auth_provider.dart';
import 'package:pm_monitor/core/models/client_model.dart';

class AddEquipmentScreen extends StatefulWidget {
  final ClientModel client;
  final Equipment? equipment;

  const AddEquipmentScreen({
    Key? key,
    required this.client,
    this.equipment,
  }) : super(key: key);

  @override
  State<AddEquipmentScreen> createState() => _AddEquipmentScreenState();
}

class _AddEquipmentScreenState extends State<AddEquipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _capacityController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _locationController = TextEditingController();
  final _branchController = TextEditingController();
  final _addressController = TextEditingController();
  final _equipmentCostController = TextEditingController();
  final _estimatedHoursController = TextEditingController();
  final _equipmentNumberController = TextEditingController();
  final _rfidController = TextEditingController();

  Timer? _debounceTimer;

  String _selectedTipo = EquipmentTypes.climatizacion;
  String _selectedCategory = 'Split Pared';
  List<String> _availableCategories = EquipmentCategories.climatizacion;
  String _selectedCapacityUnit = 'BTU';
  String _selectedCondition = 'Bueno';
  String _selectedStatus = 'Operativo';
  String _selectedCurrency = 'USD';
  String _selectedMaintenanceFrequency = 'Mensual';
  int _selectedLifeScale = 5;
  int _selectedFrequencyDays = 30;
  bool _enableMaintenanceAlerts = true;
  bool _enableFailureAlerts = true;
  bool _enableTemperatureAlerts = false;
  bool _hasTemperatureMonitoring = false;
  bool _isGeneratingNumber = false;
  bool _isEditing = false;

  final List<String> _capacityUnits = ['BTU', 'KW', 'HP', 'Ton', 'Otro'];
  final List<String> _conditions = ['Excelente', 'Bueno', 'Regular', 'Malo'];
  final List<String> _statuses = [
    'Operativo',
    'En mantenimiento',
    'Fuera de servicio'
  ];
  final List<String> _currencies = ['USD', 'DOP', 'EUR'];
  final List<String> _frequencies = [
    'Semanal',
    'Mensual',
    'Bimensual',
    'Trimestral',
    'Semestral',
    'Anual'
  ];

  final Map<String, int> _frequencyDaysMap = {
    'Semanal': 7,
    'Mensual': 30,
    'Bimensual': 60,
    'Trimestral': 90,
    'Semestral': 180,
    'Anual': 365,
  };

  BranchModel? _selectedBranch;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.equipment != null;

    if (_isEditing) {
      _loadEquipmentData();
    } else {
      _generateEquipmentNumber();
      _initializeClientData();
    }
  }

  void _loadEquipmentData() {
    final eq = widget.equipment!;

    _equipmentNumberController.text = eq.equipmentNumber;
    _rfidController.text = eq.rfidTag;
    _nameController.text = eq.name;
    _descriptionController.text = eq.description;
    _brandController.text = eq.brand;
    _modelController.text = eq.model;
    _capacityController.text = eq.capacity.toString();
    _serialNumberController.text = eq.serialNumber;
    _locationController.text = eq.location;
    _branchController.text = eq.branch;
    _addressController.text = eq.address;
    _equipmentCostController.text = eq.equipmentCost.toString();
    _estimatedHoursController.text = eq.estimatedMaintenanceHours.toString();

    _selectedTipo = eq.tipo;
    _availableCategories = EquipmentCategories.all[eq.tipo] ?? [];

    String cleanCategory = eq.category
        .replaceAll('AC - ', '')
        .replaceAll('Panel - ', '')
        .replaceAll('Generador - ', '')
        .replaceAll('UPS - ', '')
        .replaceAll('Facilidad - ', '')
        .trim();

    if (_availableCategories.contains(cleanCategory)) {
      _selectedCategory = cleanCategory;
    } else if (_availableCategories.contains(eq.category)) {
      _selectedCategory = eq.category;
    } else if (_availableCategories.isNotEmpty) {
      _selectedCategory = _availableCategories.first;
    }

    _selectedCapacityUnit = eq.capacityUnit;
    _selectedCondition = eq.condition;
    _selectedStatus = eq.status;
    _selectedCurrency = eq.currency;
    _selectedMaintenanceFrequency = _capitalizeFirst(eq.maintenanceFrequency);
    _selectedLifeScale = eq.lifeScale;
    _selectedFrequencyDays = eq.frequencyDays;
    _enableMaintenanceAlerts = eq.enableMaintenanceAlerts;
    _enableFailureAlerts = eq.enableFailureAlerts;
    _enableTemperatureAlerts = eq.enableTemperatureAlerts;
    _hasTemperatureMonitoring = eq.hasTemperatureMonitoring;

    if (eq.branchId != null && widget.client.branches.isNotEmpty) {
      try {
        _selectedBranch = widget.client.branches.firstWhere(
          (b) => b.id == eq.branchId,
        );
      } catch (e) {
        _selectedBranch = null;
      }
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void _initializeClientData() {
    _branchController.text = widget.client.name;
    _addressController.text = widget.client.mainAddress.fullAddress;

    if (widget.client.branches.isNotEmpty) {
      _selectedBranch = widget.client.branches.first;
      _branchController.text = _selectedBranch!.name;
      _addressController.text = _selectedBranch!.address.fullAddress;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _capacityController.dispose();
    _serialNumberController.dispose();
    _locationController.dispose();
    _branchController.dispose();
    _addressController.dispose();
    _equipmentCostController.dispose();
    _estimatedHoursController.dispose();
    _equipmentNumberController.dispose();
    _rfidController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateEquipmentNumber() async {
    setState(() {
      _isGeneratingNumber = true;
    });

    final equipmentProvider =
        Provider.of<EquipmentProvider>(context, listen: false);
    String generatedNumber =
        await equipmentProvider.generateEquipmentNumber(widget.client.id);

    setState(() {
      _equipmentNumberController.text = generatedNumber;
      _isGeneratingNumber = false;
    });
  }

  void _onTipoChanged(String? newTipo) {
    if (newTipo == null) return;

    setState(() {
      _selectedTipo = newTipo;
      _availableCategories = EquipmentCategories.all[newTipo] ?? [];

      if (_availableCategories.isNotEmpty) {
        _selectedCategory = _availableCategories.first;
      }
    });
  }

  void _updateFrequencyDays(String frequency) {
    setState(() {
      _selectedMaintenanceFrequency = frequency;
      _selectedFrequencyDays = _frequencyDaysMap[frequency] ?? 30;
    });
  }

  void _onBranchChanged(BranchModel? branch) {
    setState(() {
      _selectedBranch = branch;
      if (branch != null) {
        _branchController.text = branch.name;
        _addressController.text = branch.address.fullAddress;
      } else {
        _branchController.text = widget.client.name;
        _addressController.text = widget.client.mainAddress.fullAddress;
      }
    });
  }

  Future<void> _saveEquipment() async {
    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final equipmentProvider =
        Provider.of<EquipmentProvider>(context, listen: false);

    DateTime nextMaintenanceDate =
        DateTime.now().add(Duration(days: _selectedFrequencyDays));

    String branchName = _selectedBranch?.name ?? widget.client.name;
    String? branchId = _selectedBranch?.id;
    String fullAddress = _selectedBranch?.address.fullAddress ??
        widget.client.mainAddress.fullAddress;
    String country =
        _selectedBranch?.address.country ?? widget.client.mainAddress.country;
    String region =
        _selectedBranch?.address.state ?? widget.client.mainAddress.state;

    Equipment equipment = Equipment(
      id: _isEditing ? widget.equipment!.id : null,
      clientId: widget.client.id,
      branchId: branchId,
      equipmentNumber: _equipmentNumberController.text.trim(),
      rfidTag: _rfidController.text.trim().isEmpty
          ? _equipmentNumberController.text.trim()
          : _rfidController.text.trim(),
      qrCode: _equipmentNumberController.text.trim(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      brand: _brandController.text.trim(),
      model: _modelController.text.trim(),
      tipo: _selectedTipo,
      category: _selectedCategory,
      capacity: double.tryParse(_capacityController.text.trim()) ?? 0.0,
      capacityUnit: _selectedCapacityUnit,
      serialNumber: _serialNumberController.text.trim(),
      location: _locationController.text.trim(),
      branch: branchName,
      country: country,
      region: region,
      address: fullAddress,
      condition: _selectedCondition,
      lifeScale: _selectedLifeScale,
      isActive: true,
      status: _selectedStatus,
      equipmentCost:
          double.tryParse(_equipmentCostController.text.trim()) ?? 0.0,
      totalPmCost: _isEditing ? widget.equipment!.totalPmCost : 0.0,
      totalCmCost: _isEditing ? widget.equipment!.totalCmCost : 0.0,
      currency: _selectedCurrency,
      maintenanceFrequency: _selectedMaintenanceFrequency.toLowerCase(),
      frequencyDays: _selectedFrequencyDays,
      lastMaintenanceDate:
          _isEditing ? widget.equipment!.lastMaintenanceDate : null,
      nextMaintenanceDate: nextMaintenanceDate,
      estimatedMaintenanceHours:
          int.tryParse(_estimatedHoursController.text.trim()) ?? 2,
      assignedTechnicianId:
          _isEditing ? widget.equipment!.assignedTechnicianId : null,
      assignedTechnicianName:
          _isEditing ? widget.equipment!.assignedTechnicianName : null,
      assignedSupervisorId:
          _isEditing ? widget.equipment!.assignedSupervisorId : null,
      assignedSupervisorName:
          _isEditing ? widget.equipment!.assignedSupervisorName : null,
      photoUrls: _isEditing ? widget.equipment!.photoUrls : [],
      documentUrls: _isEditing ? widget.equipment!.documentUrls : [],
      hasTemperatureMonitoring: _hasTemperatureMonitoring,
      totalMaintenances: _isEditing ? widget.equipment!.totalMaintenances : 0,
      totalFailures: _isEditing ? widget.equipment!.totalFailures : 0,
      averageResponseTime:
          _isEditing ? widget.equipment!.averageResponseTime : 0.0,
      maintenanceEfficiency:
          _isEditing ? widget.equipment!.maintenanceEfficiency : 0.0,
      createdAt: _isEditing ? widget.equipment!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: _isEditing
          ? widget.equipment!.createdBy
          : (authProvider.currentUser?.id ?? ''),
      updatedBy: _isEditing ? (authProvider.currentUser?.id ?? '') : null,
      enableMaintenanceAlerts: _enableMaintenanceAlerts,
      enableFailureAlerts: _enableFailureAlerts,
      enableTemperatureAlerts: _enableTemperatureAlerts,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      bool success;
      if (_isEditing) {
        success = await equipmentProvider.updateEquipment(equipment);
      } else {
        success = await equipmentProvider.createEquipment(equipment);
      }

      if (mounted) Navigator.of(context).pop();

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing
                  ? 'Equipo actualizado exitosamente'
                  : 'Equipo agregado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(equipmentProvider.errorMessage ??
                  (_isEditing
                      ? 'Error al actualizar equipo'
                      : 'Error al agregar equipo')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Equipo' : 'Agregar Equipo'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveEquipment,
            child: const Text(
              'GUARDAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Cliente'),
              _buildClientInfoCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('Información Básica'),
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildSectionHeader('Especificaciones Técnicas'),
              _buildTechnicalSpecsSection(),
              const SizedBox(height: 24),
              _buildSectionHeader('Ubicación'),
              _buildLocationSection(),
              const SizedBox(height: 24),
              _buildSectionHeader('Estado y Condición'),
              _buildStatusSection(),
              const SizedBox(height: 24),
              _buildSectionHeader('Programación de Mantenimiento'),
              _buildMaintenanceSection(),
              const SizedBox(height: 24),
              _buildSectionHeader('Configuración de Alertas'),
              _buildAlertsSection(),
              const SizedBox(height: 24),
              _buildSaveButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2196F3),
        ),
      ),
    );
  }

  Widget _buildClientInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.client.statusColor,
                  child: Text(
                    widget.client.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.client.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.client.type.displayName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.client.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.client.status.displayName,
                    style: TextStyle(
                      color: widget.client.statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _equipmentNumberController,
                    decoration: InputDecoration(
                      labelText: 'Número de Equipo *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.tag),
                      suffixIcon: _isEditing
                          ? null
                          : (_isGeneratingNumber
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _generateEquipmentNumber,
                                  tooltip: 'Generar nuevo número',
                                )),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                    ),
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rfidController,
              decoration: const InputDecoration(
                labelText: 'RFID Tag (Opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.nfc),
                hintText: 'Escanear o introducir manualmente',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Equipo *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.build),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalSpecsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                value: _selectedTipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Equipo *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                isExpanded: true,
                items: EquipmentTypes.all.map((tipo) {
                  return DropdownMenuItem(
                    value: tipo,
                    child: Text(
                      tipo,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: _onTipoChanged,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoría *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.devices),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                isExpanded: true,
                items: _availableCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(
                      category,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(
                      labelText: 'Marca *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La marca es requerida';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Modelo *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.model_training),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El modelo es requerido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _capacityController,
                    decoration: const InputDecoration(
                      labelText: 'Capacidad *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.power),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La capacidad es requerida';
                      }
                      if (double.tryParse(value.trim()) == null) {
                        return 'Ingrese un número válido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCapacityUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unidad',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: _capacityUnits.map((unit) {
                      return DropdownMenuItem(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCapacityUnit = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serialNumberController,
              decoration: const InputDecoration(
                labelText: 'Número de Serie',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.client.branches.isNotEmpty) ...[
              DropdownButtonFormField<BranchModel?>(
                value: _selectedBranch,
                decoration: const InputDecoration(
                  labelText: 'Sucursal *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business_center),
                ),
                items: [
                  DropdownMenuItem<BranchModel?>(
                    value: null,
                    child: Text('Oficina Principal - ${widget.client.name}'),
                  ),
                  ...widget.client.branches
                      .where((b) => b.isActive)
                      .map((branch) {
                    return DropdownMenuItem<BranchModel?>(
                      value: branch,
                      child: Text(branch.name),
                    );
                  }).toList(),
                ],
                onChanged: _onBranchChanged,
              ),
              const SizedBox(height: 16),
            ] else ...[
              TextFormField(
                controller: _branchController,
                decoration: const InputDecoration(
                  labelText: 'Sucursal *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business_center),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Ubicación Específica *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
                hintText: 'Ej: Oficina 1, Sala de servidores',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La ubicación es requerida';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
              readOnly: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ FIX: Row con Expanded para evitar overflow
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCondition,
                    decoration: const InputDecoration(
                      labelText: 'Condición *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.health_and_safety),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                    isExpanded: true,
                    items: _conditions.map((condition) {
                      return DropdownMenuItem(
                        value: condition,
                        child: Text(
                          condition,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCondition = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Estado *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.settings),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                    isExpanded: true,
                    items: _statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(
                          status,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vida Útil (Escala 1-10): $_selectedLifeScale',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _selectedLifeScale.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: _selectedLifeScale.toString(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLifeScale = value.round();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _equipmentCostController,
                    decoration: const InputDecoration(
                      labelText: 'Costo del Equipo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Moneda',
                      border: OutlineInputBorder(),
                    ),
                    items: _currencies.map((currency) {
                      return DropdownMenuItem(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCurrency = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedMaintenanceFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Frecuencia *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    items: _frequencies.map((frequency) {
                      return DropdownMenuItem(
                        value: frequency,
                        child: Text(frequency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      _updateFrequencyDays(value!);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _selectedFrequencyDays.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Días',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _estimatedHoursController,
              decoration: const InputDecoration(
                labelText: 'Horas Estimadas por Mantenimiento *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
                hintText: '2',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Las horas estimadas son requeridas';
                }
                if (int.tryParse(value.trim()) == null) {
                  return 'Ingrese un número válido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Alertas de Mantenimiento'),
              subtitle:
                  const Text('Notificaciones para mantenimientos programados'),
              value: _enableMaintenanceAlerts,
              onChanged: (value) {
                setState(() {
                  _enableMaintenanceAlerts = value;
                });
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Alertas de Fallas'),
              subtitle: const Text('Notificaciones para reportes de fallas'),
              value: _enableFailureAlerts,
              onChanged: (value) {
                setState(() {
                  _enableFailureAlerts = value;
                });
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Monitoreo de Temperatura'),
              subtitle:
                  const Text('Habilitar monitoreo automático de temperatura'),
              value: _hasTemperatureMonitoring,
              onChanged: (value) {
                setState(() {
                  _hasTemperatureMonitoring = value;
                  if (value) {
                    _enableTemperatureAlerts = true;
                  } else {
                    _enableTemperatureAlerts = false;
                  }
                });
              },
            ),
            if (_hasTemperatureMonitoring) ...[
              const Divider(),
              SwitchListTile(
                title: const Text('Alertas de Temperatura'),
                subtitle:
                    const Text('Notificaciones por variaciones de temperatura'),
                value: _enableTemperatureAlerts,
                onChanged: (value) {
                  setState(() {
                    _enableTemperatureAlerts = value;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Consumer<EquipmentProvider>(
      builder: (context, equipmentProvider, child) {
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: equipmentProvider.isCreating ? null : _saveEquipment,
            icon: equipmentProvider.isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(_isEditing ? Icons.save : Icons.add),
            label: Text(
              equipmentProvider.isCreating
                  ? 'Guardando...'
                  : (_isEditing ? 'Actualizar Equipo' : 'Guardar Equipo'),
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      },
    );
  }
}
