import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/maintenance_task_template.dart';
import 'package:pm_monitor/core/services/task_template_service.dart';
import 'package:pm_monitor/features/others/screens/add_edit_task_template_screen.dart';

class TaskTemplatesScreen extends StatefulWidget {
  const TaskTemplatesScreen({super.key});

  @override
  State<TaskTemplatesScreen> createState() => _TaskTemplatesScreenState();
}

class _TaskTemplatesScreenState extends State<TaskTemplatesScreen> {
  final TaskTemplateService _service = TaskTemplateService();
  String _selectedFilter = 'all';
  String _searchQuery = '';
  List<MaintenanceTaskTemplate> _allTemplates = [];
  List<MaintenanceTaskTemplate> _filteredTemplates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    _service.getAllTemplates().listen((templates) {
      if (mounted) {
        setState(() {
          _allTemplates = templates.cast<MaintenanceTaskTemplate>();
          _applyFilters();
          _isLoading = false;
        });
      }
    });
  }

  void _applyFilters() {
    var filtered = _allTemplates;

    // Filtrar por tipo
    if (_selectedFilter != 'all') {
      filtered = filtered.where((t) => t.type == _selectedFilter).toList();
    }

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        return t.name.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredTemplates = filtered;
    });
  }

  Map<String, List<MaintenanceTaskTemplate>> _groupByType() {
    final grouped = <String, List<MaintenanceTaskTemplate>>{};

    for (var template in _filteredTemplates) {
      if (!grouped.containsKey(template.type)) {
        grouped[template.type] = [];
      }
      grouped[template.type]!.add(template);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates de Tareas'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTemplates.isEmpty
                    ? _buildEmptyState()
                    : _buildTaskList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEdit(),
        backgroundColor: const Color(0xFF2196F3),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Tarea'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Buscar tareas...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _applyFilters();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'value': 'all', 'label': 'Todas', 'color': Colors.grey},
      {'value': 'preventive', 'label': 'Preventivo', 'color': Colors.green},
      {'value': 'corrective', 'label': 'Correctivo', 'color': Colors.orange},
      {'value': 'emergency', 'label': 'Emergencia', 'color': Colors.red},
      {'value': 'inspection', 'label': 'Inspección', 'color': Colors.blue},
      {
        'value': 'technicalAssistance',
        'label': 'Asistencia',
        'color': Colors.purple
      },
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['value'];

          return FilterChip(
            label: Text(filter['label'] as String),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedFilter = filter['value'] as String;
                _applyFilters();
              });
            },
            backgroundColor: Colors.white,
            selectedColor: (filter['color'] as Color).withOpacity(0.2),
            checkmarkColor: filter['color'] as Color,
            side: BorderSide(
              color: isSelected
                  ? (filter['color'] as Color)
                  : Colors.grey.shade300,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskList() {
    final grouped = _groupByType();
    final sortedTypes = grouped.keys.toList()
      ..sort((a, b) {
        const order = [
          'preventive',
          'corrective',
          'emergency',
          'inspection',
          'technicalAssistance'
        ];
        return order.indexOf(a).compareTo(order.indexOf(b));
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedTypes.length,
      itemBuilder: (context, index) {
        final type = sortedTypes[index];
        final templates = grouped[type]!;

        return _buildTypeSection(type, templates);
      },
    );
  }

  Widget _buildTypeSection(
      String type, List<MaintenanceTaskTemplate> templates) {
    final typeNames = {
      'preventive': 'Preventivo',
      'corrective': 'Correctivo',
      'emergency': 'Emergencia',
      'inspection': 'Inspección',
      'technicalAssistance': 'Asistencia Técnica',
    };

    final typeColors = {
      'preventive': Colors.green,
      'corrective': Colors.orange,
      'emergency': Colors.red,
      'inspection': Colors.blue,
      'technicalAssistance': Colors.purple,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: typeColors[type],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                typeNames[type] ?? type,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: typeColors[type],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColors[type]!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${templates.length} tareas',
                  style: TextStyle(
                    fontSize: 12,
                    color: typeColors[type],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...templates.map((template) => _buildTaskCard(template)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTaskCard(MaintenanceTaskTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: template.isActive ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToAddEdit(template: template),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: template.isActive ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                  if (!template.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'INACTIVO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) => _handleMenuAction(value, template),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              template.isActive
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(template.isActive ? 'Desactivar' : 'Activar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                template.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    icon: Icons.schedule,
                    label: template.estimatedTimeFormatted,
                    color: Colors.blue,
                  ),
                  ...template.equipmentTypes.map(
                    (eq) => _buildInfoChip(
                      icon: Icons.ac_unit,
                      label: eq,
                      color: Colors.grey,
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay tareas',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primera tarea',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, MaintenanceTaskTemplate template) {
    switch (action) {
      case 'edit':
        _navigateToAddEdit(template: template);
        break;
      case 'toggle':
        _toggleTemplateStatus(template);
        break;
      case 'delete':
        _confirmDelete(template);
        break;
    }
  }

  Future<void> _toggleTemplateStatus(MaintenanceTaskTemplate template) async {
    try {
      await _service.toggleTemplateStatus(template.id!, !template.isActive);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            template.isActive ? 'Tarea desactivada' : 'Tarea activada',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDelete(MaintenanceTaskTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Estás seguro de eliminar "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTemplate(template);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTemplate(MaintenanceTaskTemplate template) async {
    try {
      await _service.deleteTemplate(template.id!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarea eliminada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateToAddEdit({MaintenanceTaskTemplate? template}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTaskTemplateScreen(template: template),
      ),
    );

    if (result == true) {
      // Recargar las tareas
    }
  }
}
