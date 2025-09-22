import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/core/providers/equipment_provider.dart';
import 'package:pm_monitor/core/providers/auth_provider.dart';
import 'package:pm_monitor/core/models/client_model.dart';

class AddEquipmentScreen extends StatefulWidget {
  final ClientModel client;

  const AddEquipmentScreen({
    Key? key,
    required this.client,
  }) : super(key: key);

  @override
  State<AddEquipmentScreen> createState() => _AddEquipmentScreenState();
}

class _AddEquipmentScreenState extends State<AddEquipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Controllers para los campos de texto
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

  // Timer para debounce en validación
  Timer? _debounceTimer;

  // Variables para dropdowns y selecciones
  String _selectedCategory = 'AC - Split Pared';
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

  // Listas para los dropdowns - Categorías detalladas
  final List<String> _categories = [
    // Aire Acondicionado
    'AC - Split Pared',
    'AC - Split Piso/Techo',
    'AC - Cassette',
    'AC - Ducto',
    'AC - Ventana',
    'AC - Portátil',
    'AC - Chiller',
    'AC - Fan Coil',
    'AC - Manejadora de Aire',
    'AC - Unidad Condensadora',
    // Paneles Eléctricos
    'Panel - Principal',
    'Panel - Distribución',
    'Panel - Control',
    'Panel - Transferencia',
    'Panel - Medición',
    // Generadores
    'Generador - Diésel',
    'Generador - Gas',
    'Generador - Gasolina',
    'Generador - Emergencia',
    'Generador - Standby',
    // UPS
    'UPS - Línea Interactiva',
    'UPS - Online',
    'UPS - Offline',
    'UPS - Modular',
    // Facilidades
    'Facilidad - Bomba de Agua',
    'Facilidad - Sistema de Incendio',
    'Facilidad - Ascensor',
    'Facilidad - Portón Automático',
    'Facilidad - Sistema de Acceso',
    'Facilidad - Cámaras de Seguridad',
    'Facilidad - Iluminación',
    'Facilidad - Ventilación',
    'Otro'
  ];

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

  // Sucursal seleccionada (si el cliente tiene múltiples sucursales)
  BranchModel? _selectedBranch;

  @override
  void initState() {
    super.initState();
    _generateEquipmentNumber();
    _initializeClientData();
  }

  void _initializeClientData() {
    // Configurar datos iniciales basados en el cliente
    _branchController.text = widget.client.name;
    _addressController.text = widget.client.mainAddress.fullAddress;

    // Si el cliente tiene sucursales, usar la primera como predeterminada
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
      // Scroll to the first error
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

    // Calcular próxima fecha de mantenimiento
    DateTime nextMaintenanceDate =
        DateTime.now().add(Duration(days: _selectedFrequencyDays));

    // Obtener información de ubicación
    String branchName = _selectedBranch?.name ?? widget.client.name;
    String fullAddress = _selectedBranch?.address.fullAddress ??
        widget.client.mainAddress.fullAddress;
    String country =
        _selectedBranch?.address.country ?? widget.client.mainAddress.country;
    String region =
        _selectedBranch?.address.state ?? widget.client.mainAddress.state;

    // Crear el equipo
    Equipment newEquipment = Equipment(
      clientId: widget.client.id,
      equipmentNumber: _equipmentNumberController.text.trim(),
      rfidTag: _rfidController.text.trim().isEmpty
          ? _equipmentNumberController.text.trim()
          : _rfidController.text.trim(),
      qrCode: _equipmentNumberController.text.trim(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      brand: _brandController.text.trim(),
      model: _modelController.text.trim(),
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
      currency: _selectedCurrency,
      maintenanceFrequency: _selectedMaintenanceFrequency.toLowerCase(),
      frequencyDays: _selectedFrequencyDays,
      nextMaintenanceDate: nextMaintenanceDate,
      estimatedMaintenanceHours:
          int.tryParse(_estimatedHoursController.text.trim()) ?? 2,
      hasTemperatureMonitoring: _hasTemperatureMonitoring,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: authProvider.currentUser?.id ?? '',
      enableMaintenanceAlerts: _enableMaintenanceAlerts,
      enableFailureAlerts: _enableFailureAlerts,
      enableTemperatureAlerts: _enableTemperatureAlerts,
    );

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      bool success = await equipmentProvider.createEquipment(newEquipment);

      // Cerrar loading
      if (mounted) Navigator.of(context).pop();

      if (success) {
        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Equipo agregado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );

          // Regresar a la pantalla anterior
          Navigator.of(context).pop(true);
        }
      } else {
        // Mostrar error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  equipmentProvider.errorMessage ?? 'Error al agregar equipo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar loading
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
        title: const Text('Agregar Equipo'),
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
              // Información del Cliente
              _buildSectionHeader('Cliente'),
              _buildClientInfoCard(),
              const SizedBox(height: 24),

              // Información Básica del Equipo
              _buildSectionHeader('Información Básica'),
              _buildBasicInfoSection(),
              const SizedBox(height: 24),

              // Especificaciones Técnicas
              _buildSectionHeader('Especificaciones Técnicas'),
              _buildTechnicalSpecsSection(),
              const SizedBox(height: 24),

              // Ubicación
              _buildSectionHeader('Ubicación'),
              _buildLocationSection(),
              const SizedBox(height: 24),

              // Estado y Condición
              _buildSectionHeader('Estado y Condición'),
              _buildStatusSection(),
              const SizedBox(height: 24),

              // Mantenimiento
              _buildSectionHeader('Programación de Mantenimiento'),
              _buildMaintenanceSection(),
              const SizedBox(height: 24),

              // Configuración de Alertas
              _buildSectionHeader('Configuración de Alertas'),
              _buildAlertsSection(),
              const SizedBox(height: 24),

              // Botón de Guardar
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
                      if (widget.client.email.isNotEmpty)
                        Text(
                          widget.client.email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
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
            if (widget.client.totalBranches > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.client.totalBranches} sucursal${widget.client.totalBranches > 1 ? 'es' : ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.contacts, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.client.totalContacts} contacto${widget.client.totalContacts > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
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
            // Número de Equipo (generado automáticamente)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _equipmentNumberController,
                    decoration: InputDecoration(
                      labelText: 'Número de Equipo *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.tag),
                      suffixIcon: _isGeneratingNumber
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _generateEquipmentNumber,
                              tooltip: 'Generar nuevo número',
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                    ),
                    readOnly: true, // Solo lectura, se genera automáticamente
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // RFID Tag (opcional)
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

            // Nombre del Equipo
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

            // Descripción
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
            // Marca y Modelo
            Column(
              children: [
                // Marca
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(
                      labelText: 'Marca *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La marca es requerida';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Modelo
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Modelo *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.model_training),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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

            // Categoría
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoría *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                isExpanded: true,
                items: _categories.map((category) {
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

            // Capacidad y Unidad
            Column(
              children: [
                // Capacidad
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _capacityController,
                    decoration: const InputDecoration(
                      labelText: 'Capacidad *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.power),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                const SizedBox(height: 16),
                // Unidad de Capacidad
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCapacityUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unidad de Capacidad',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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

            // Número de Serie
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: _serialNumberController,
                decoration: const InputDecoration(
                  labelText: 'Número de Serie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
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
            // Selector de Sucursal (si el cliente tiene múltiples)
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
              // Sucursal (solo texto si no hay múltiples sucursales)
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

            // Ubicación específica
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

            // Dirección (prellenada)
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
            // Condición y Estado
            Column(
              children: [
                // Condición
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCondition,
                    decoration: const InputDecoration(
                      labelText: 'Condición *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.health_and_safety),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    isExpanded: true,
                    items: _conditions.map((condition) {
                      return DropdownMenuItem(
                        value: condition,
                        child: Text(condition),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCondition = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Estado
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Estado *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.settings),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    isExpanded: true,
                    items: _statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
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

            // Escala de Vida Útil
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
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4.0,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16.0),
                    ),
                    child: Slider(
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Costo del Equipo y Moneda
            Column(
              children: [
                // Costo del Equipo
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _equipmentCostController,
                    decoration: const InputDecoration(
                      labelText: 'Costo del Equipo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 16),
                // Moneda
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Moneda',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    isExpanded: true,
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
            // Frecuencia y Días
            Column(
              children: [
                // Frecuencia de Mantenimiento
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _selectedMaintenanceFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Frecuencia *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    isExpanded: true,
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
                const SizedBox(height: 16),
                // Días
                SizedBox(
                  width: double.infinity,
                  child: TextFormField(
                    initialValue: _selectedFrequencyDays.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Días',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Horas Estimadas por Mantenimiento
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: _estimatedHoursController,
                decoration: const InputDecoration(
                  labelText: 'Horas Estimadas por Mantenimiento *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time),
                  hintText: '2',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
            // Alertas de Mantenimiento
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

            // Alertas de Fallas
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

            // Monitoreo de Temperatura
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
                : const Icon(Icons.save),
            label: Text(
              equipmentProvider.isCreating ? 'Guardando...' : 'Guardar Equipo',
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
