import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/maintenance_task_template.dart';
import 'package:pm_monitor/core/services/task_template_service.dart';

class AddEditTaskTemplateScreen extends StatefulWidget {
  final MaintenanceTaskTemplate? template;

  const AddEditTaskTemplateScreen({
    Key? key,
    this.template,
  }) : super(key: key);

  @override
  State<AddEditTaskTemplateScreen> createState() =>
      _AddEditTaskTemplateScreenState();
}

class _AddEditTaskTemplateScreenState extends State<AddEditTaskTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _minutesController = TextEditingController();

  final TaskTemplateService _service = TaskTemplateService();

  String _selectedType = 'preventive';
  List<String> _selectedEquipmentTypes = [];
  bool _isActive = true;
  bool _isSaving = false;

  final List<String> _availableEquipmentTypes = [
    'Aire Acondicionado',
    'Panel Eléctrico',
    'UPS',
    'Generador',
  ];

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadTemplate();
    }
  }

  void _loadTemplate() {
    final template = widget.template!;
    _nameController.text = template.name;
    _descriptionController.text = template.description;
    _minutesController.text = template.estimatedMinutes.toString();
    _selectedType = template.type;
    _selectedEquipmentTypes = List.from(template.equipmentTypes);
    _isActive = template.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Tarea' : 'Nueva Tarea'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 16),
            _buildTypeSection(),
            const SizedBox(height: 16),
            _buildEquipmentTypesSection(),
            const SizedBox(height: 16),
            _buildTimeSection(),
            const SizedBox(height: 16),
            _buildStatusSection(),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información Básica',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la tarea *',
                hintText: 'Ej: Limpieza de filtros',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
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
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción *',
                hintText: 'Describe los detalles de la tarea...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La descripción es requerida';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSection() {
    final types = [
      {'value': 'preventive', 'label': 'Preventivo', 'icon': Icons.build},
      {
        'value': 'corrective',
        'label': 'Correctivo',
        'icon': Icons.build_circle
      },
      {'value': 'emergency', 'label': 'Emergencia', 'icon': Icons.warning},
      {'value': 'inspection', 'label': 'Inspección', 'icon': Icons.search},
      {
        'value': 'technicalAssistance',
        'label': 'Asistencia Técnica',
        'icon': Icons.support_agent
      },
    ];

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
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: types.map((type) {
                return DropdownMenuItem(
                  value: type['value'] as String,
                  child: Row(
                    children: [
                      Icon(type['icon'] as IconData, size: 20),
                      const SizedBox(width: 12),
                      Text(type['label'] as String),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentTypesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aplica para Equipos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona los tipos de equipo donde aplica esta tarea',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableEquipmentTypes.map((equipment) {
                final isSelected = _selectedEquipmentTypes.contains(equipment);
                return FilterChip(
                  label: Text(equipment),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedEquipmentTypes.add(equipment);
                      } else {
                        _selectedEquipmentTypes.remove(equipment);
                      }
                    });
                  },
                  selectedColor: Colors.blue.withOpacity(0.2),
                  checkmarkColor: Colors.blue,
                );
              }).toList(),
            ),
            if (_selectedEquipmentTypes.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Selecciona al menos un tipo de equipo',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tiempo Estimado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutos *',
                hintText: 'Ej: 30',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
                suffixText: 'min',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El tiempo es requerido';
                }
                final minutes = int.tryParse(value);
                if (minutes == null || minutes <= 0) {
                  return 'Ingresa un número válido mayor a 0';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Tarea activa'),
              subtitle: Text(
                _isActive
                    ? 'Esta tarea aparecerá al crear mantenimientos'
                    : 'Esta tarea estará oculta',
                style: const TextStyle(fontSize: 13),
              ),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveTemplate,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                  Text(_isEditing ? 'Actualizar Tarea' : 'Guardar Tarea'),
                ],
              ),
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedEquipmentTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un tipo de equipo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final template = MaintenanceTaskTemplate(
        id: _isEditing ? widget.template!.id : null,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        equipmentTypes: _selectedEquipmentTypes,
        estimatedMinutes: int.parse(_minutesController.text),
        isActive: _isActive,
        order: _isEditing ? widget.template!.order : 0,
        createdAt: _isEditing ? widget.template!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: _isEditing ? widget.template!.createdBy : 'admin',
      );

      if (_isEditing) {
        await _service.updateTemplate(template.id!, template);
      } else {
        // Obtener el siguiente orden
        final nextOrder = await _service.getNextOrder(_selectedType);
        final templateWithOrder = template.copyWith(order: nextOrder);
        await _service.createTemplate(templateWithOrder);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Tarea actualizada correctamente'
                  : 'Tarea creada correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
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
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
