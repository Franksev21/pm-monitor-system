import 'package:flutter/material.dart';
import 'package:pm_monitor/features/equipment/screens/qr_display_screen.dart';
import '../screens/fault_report_screen.dart';
import 'package:provider/provider.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/core/providers/equipment_provider.dart';
import 'package:pm_monitor/core/models/client_model.dart';
import 'add_equipment_screen.dart';
import 'equipment_detail_screen.dart';

class ClientEquipmentListScreen extends StatefulWidget {
  final ClientModel client;

  const ClientEquipmentListScreen({
    Key? key,
    required this.client,
  }) : super(key: key);

  @override
  State<ClientEquipmentListScreen> createState() =>
      _ClientEquipmentListScreenState();
}

class _ClientEquipmentListScreenState extends State<ClientEquipmentListScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'Todos';
  String _selectedSort = 'Recientes';
  bool _isLoading = false;

  final List<String> _filterOptions = [
    'Todos',
    'Operativo',
    'En mantenimiento',
    'Fuera de servicio',
    'Necesita mantenimiento',
    'Vencido'
  ];

  final List<String> _sortOptions = [
    'Recientes',
    'Alfabético',
    'Por categoría',
    'Por estado',
    'Por mantenimiento'
  ];

  @override
  void initState() {
    super.initState();
    // Usar WidgetsBinding para cargar después del build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEquipments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEquipments() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final equipmentProvider =
          Provider.of<EquipmentProvider>(context, listen: false);
      equipmentProvider.loadEquipmentsByClient(widget.client.id);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    // Aplicar debounce para evitar múltiples búsquedas
    setState(() {});
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  Future<void> _navigateToAddEquipment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEquipmentScreen(client: widget.client),
      ),
    );

    if (result == true && mounted) {
      _loadEquipments();
    }
  }

  void _showEquipmentDetail(Equipment equipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EquipmentDetailScreen(equipment: equipment),
      ),
    );
  }

  void _handleAction(BuildContext context, String action, Equipment equipment) {
    switch (action) {
      case 'report_fault':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FaultReportScreen(equipment: equipment),
          ),
        );
        break;
      case 'view_details':
        _navigateToDetails(context, equipment);
        break;
      case 'generate_qr':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRDisplayScreen(equipment: equipment),
          ),
        );
        break;
    }
  }

  void _navigateToDetails(BuildContext context, Equipment equipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EquipmentDetailScreen(equipment: equipment),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  List<Equipment> _getFilteredEquipments(List<Equipment> equipments) {
    List<Equipment> filtered = List.from(equipments);

    // Filtrar por texto de búsqueda
    if (_searchController.text.isNotEmpty) {
      String query = _searchController.text.toLowerCase();
      filtered = filtered
          .where((equipment) =>
              equipment.name.toLowerCase().contains(query) ||
              equipment.brand.toLowerCase().contains(query) ||
              equipment.model.toLowerCase().contains(query) ||
              equipment.equipmentNumber.toLowerCase().contains(query) ||
              equipment.category.toLowerCase().contains(query) ||
              equipment.location.toLowerCase().contains(query))
          .toList();
    }

    // Filtrar por estado/condición
    switch (_selectedFilter) {
      case 'Operativo':
        filtered = filtered.where((e) => e.status == 'Operativo').toList();
        break;
      case 'En mantenimiento':
        filtered =
            filtered.where((e) => e.status == 'En mantenimiento').toList();
        break;
      case 'Fuera de servicio':
        filtered =
            filtered.where((e) => e.status == 'Fuera de servicio').toList();
        break;
      case 'Necesita mantenimiento':
        filtered = filtered.where((e) => e.needsMaintenance).toList();
        break;
      case 'Vencido':
        filtered = filtered.where((e) => e.isOverdue).toList();
        break;
    }

    // Ordenar
    switch (_selectedSort) {
      case 'Alfabético':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Por categoría':
        filtered.sort((a, b) => a.category.compareTo(b.category));
        break;
      case 'Por estado':
        filtered.sort((a, b) => a.status.compareTo(b.status));
        break;
      case 'Por mantenimiento':
        filtered.sort((a, b) {
          if (a.nextMaintenanceDate == null && b.nextMaintenanceDate == null)
            return 0;
          if (a.nextMaintenanceDate == null) return 1;
          if (b.nextMaintenanceDate == null) return -1;
          return a.nextMaintenanceDate!.compareTo(b.nextMaintenanceDate!);
        });
        break;
      default: // Recientes
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Equipos'),
            Text(
              widget.client.displayName,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filtros',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadEquipments,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          _buildSearchBar(),

          // Contador y filtros rápidos
          _buildQuickFilters(),

          // Lista de equipos
          Expanded(
            child: Consumer<EquipmentProvider>(
              builder: (context, equipmentProvider, child) {
                if (equipmentProvider.isLoading || _isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (equipmentProvider.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar equipos',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            equipmentProvider.errorMessage!,
                            style: TextStyle(color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadEquipments,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                List<Equipment> filteredEquipments =
                    _getFilteredEquipments(equipmentProvider.clientEquipments);

                if (filteredEquipments.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: _loadEquipments,
                  color: const Color(0xFF1976D2),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredEquipments.length,
                    itemBuilder: (context, index) {
                      final equipment = filteredEquipments[index];
                      return _buildEquipmentCard(equipment);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddEquipment,
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar Equipo'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _onSearchChanged(),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar equipos...',
          hintStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Consumer<EquipmentProvider>(
      builder: (context, equipmentProvider, child) {
        List<Equipment> equipments = equipmentProvider.clientEquipments;
        int totalCount = equipments.length;
        int activeCount =
            equipments.where((e) => e.status == 'Operativo').length;
        int needingMaintenanceCount =
            equipments.where((e) => e.needsMaintenance).length;
        int overdueCount = equipments.where((e) => e.isOverdue).length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contador total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$totalCount equipo${totalCount != 1 ? 's' : ''} encontrado${totalCount != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  DropdownButton<String>(
                    value: _selectedSort,
                    onChanged: (value) {
                      setState(() {
                        _selectedSort = value!;
                      });
                    },
                    underline: Container(),
                    items: _sortOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Chips de filtros rápidos
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      'Todos',
                      totalCount,
                      _selectedFilter == 'Todos',
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Operativo',
                      activeCount,
                      _selectedFilter == 'Operativo',
                      Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Necesita mantenimiento',
                      needingMaintenanceCount,
                      _selectedFilter == 'Necesita mantenimiento',
                      Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Vencido',
                      overdueCount,
                      _selectedFilter == 'Vencido',
                      Colors.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
      String label, int count, bool isSelected, Color color) {
    // Simplificar etiqueta para mostrar
    String displayLabel = label;
    if (label == 'Necesita mantenimiento') {
      displayLabel = 'Mantenimiento';
    } else if (label == 'Vencido') {
      displayLabel = 'Vencidos';
    }

    return FilterChip(
      label: Text('$displayLabel ($count)'),
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(isSelected ? 'Todos' : label),
      backgroundColor: color.withOpacity(0.1),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
      ),
    );
  }

  Widget _buildEquipmentCard(Equipment equipment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showEquipmentDetail(equipment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con número y estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      equipment.equipmentNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(equipment.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      equipment.status,
                      style: TextStyle(
                        color: _getStatusColor(equipment.status),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Información principal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icono de categoría
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(equipment.category),
                      color: const Color(0xFF1976D2),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Detalles del equipo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equipment.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${equipment.brand} ${equipment.model}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.place,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                equipment.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Footer con información adicional
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Próximo mantenimiento
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Próximo mantenimiento',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          equipment.nextMaintenanceDate != null
                              ? _formatDate(equipment.nextMaintenanceDate!)
                              : 'No programado',
                          style: TextStyle(
                            fontSize: 12,
                            color: equipment.needsMaintenance
                                ? (equipment.isOverdue
                                    ? Colors.red
                                    : Colors.orange)
                                : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Condición
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Condición',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            equipment.conditionIcon,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            equipment.condition,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Alerta si necesita mantenimiento
              if (equipment.needsMaintenance) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: equipment.isOverdue
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        equipment.isOverdue ? Icons.warning : Icons.schedule,
                        size: 14,
                        color: equipment.isOverdue ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        equipment.isOverdue
                            ? 'Mantenimiento vencido'
                            : 'Mantenimiento próximo',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              equipment.isOverdue ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.w600,
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

  Widget _buildEmptyState() {
    bool hasFilters =
        _searchController.text.isNotEmpty || _selectedFilter != 'Todos';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.build_circle_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No se encontraron equipos'
                  : 'No hay equipos registrados',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Intenta con otros filtros de búsqueda'
                  : 'Agrega el primer equipo de ${widget.client.displayName}',
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedFilter = 'Todos';
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Limpiar filtros'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1976D2),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _navigateToAddEquipment,
                icon: const Icon(Icons.add),
                label: const Text('Agregar Primer Equipo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBottomSheet() {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtros y Ordenamiento',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilter = 'Todos';
                        _selectedSort = 'Recientes';
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Restablecer'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Estado del equipo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _filterOptions.map((option) {
                  bool isSelected = _selectedFilter == option;
                  return FilterChip(
                    label: Text(option),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = option;
                      });
                      setModalState(() {});
                    },
                    selectedColor: const Color(0xFF1976D2).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF1976D2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ordenar por',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sortOptions.map((option) {
                  bool isSelected = _selectedSort == option;
                  return FilterChip(
                    label: Text(option),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSort = option;
                      });
                      setModalState(() {});
                    },
                    selectedColor: const Color(0xFF1976D2).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF1976D2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'operativo':
        return Colors.green;
      case 'en mantenimiento':
        return Colors.orange;
      case 'fuera de servicio':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    String cat = category.toLowerCase();
    if (cat.contains('ac') || cat.contains('aire')) {
      return Icons.ac_unit;
    } else if (cat.contains('panel') || cat.contains('eléctrico')) {
      return Icons.electrical_services;
    } else if (cat.contains('generador')) {
      return Icons.power;
    } else if (cat.contains('ups')) {
      return Icons.battery_charging_full;
    } else if (cat.contains('facilidad') || cat.contains('bomba')) {
      return Icons.build;
    } else if (cat.contains('ascensor')) {
      return Icons.elevator;
    } else if (cat.contains('portón')) {
      return Icons.door_sliding;
    } else if (cat.contains('cámara')) {
      return Icons.videocam;
    } else if (cat.contains('iluminación')) {
      return Icons.lightbulb;
    } else if (cat.contains('ventilación')) {
      return Icons.air;
    } else {
      return Icons.settings;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference < -30) {
      return 'Vencido hace ${(-difference)} días';
    } else if (difference < -7) {
      return 'Vencido hace ${((-difference) / 7).floor()} semanas';
    } else if (difference < 0) {
      return 'Vencido hace ${(-difference)} día${(-difference) != 1 ? 's' : ''}';
    } else if (difference == 0) {
      return 'Hoy';
    } else if (difference == 1) {
      return 'Mañana';
    } else if (difference <= 7) {
      return 'En $difference días';
    } else if (difference <= 30) {
      return 'En ${(difference / 7).floor()} semanas';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
