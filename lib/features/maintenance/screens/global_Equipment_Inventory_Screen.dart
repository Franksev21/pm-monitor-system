import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/client_model.dart';
import 'package:pm_monitor/core/providers/client_provider.dart';
import 'package:pm_monitor/features/equipment/add_equipment_screen.dart';
import 'package:pm_monitor/features/equipment/equipment_detail_screen.dart';
import 'package:pm_monitor/features/others/screens/fault_report_screen.dart';
import 'package:pm_monitor/features/others/screens/qr_display_screen.dart';
import 'package:pm_monitor/shared/widgets/client_search_dialog_widget.dart';
import 'package:provider/provider.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/core/providers/equipment_provider.dart';

class GlobalEquipmentInventoryScreen extends StatefulWidget {
  const GlobalEquipmentInventoryScreen({Key? key}) : super(key: key);

  @override
  State<GlobalEquipmentInventoryScreen> createState() =>
      _GlobalEquipmentInventoryScreenState();
}

class _GlobalEquipmentInventoryScreenState
    extends State<GlobalEquipmentInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Filtros del checklist
  String _selectedClient = 'Todos';
  String _selectedBranch = 'Todas';
  String _selectedCountry = 'Todos';
  String _selectedRegion = 'Todas';
  String _selectedTipo = 'Todos'; // ← NUEVO
  String _selectedCategory = 'Todas';
  String _selectedStatus = 'Todos';
  String _selectedCondition = 'Todas';
  String _selectedAssignment = 'Todos';
  String _searchQuery = '';

  // Vista actual
  String _currentView = 'cards'; // cards, table, map

  // Estadísticas
  Map<String, int> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEquipments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadEquipments() {
    final equipmentProvider =
        Provider.of<EquipmentProvider>(context, listen: false);
    equipmentProvider.loadAllEquipments();
  }

  // Obtener listas únicas para filtros
  List<String> _getUniqueClients(List<Equipment> equipments) {
    Set<String> clients = {'Todos'};
    Map<String, String> clientNames = {
      'client1': 'Xpertcode',
      'client2': 'SoftTech',
      'client3': 'TechCorp',
      'client4': 'InnovateLab',
      'client5': 'DataSolutions',
    };

    for (var equipment in equipments) {
      String clientName = clientNames[equipment.clientId] ??
          'Cliente ${equipment.clientId.substring(0, 3).toUpperCase()}';
      clients.add(clientName);
    }
    return clients.toList();
  }

  List<String> _getUniqueBranches(List<Equipment> equipments) {
    Set<String> branches = {'Todas'};
    branches.addAll(equipments.map((e) => e.branch));
    return branches.toList();
  }

  List<String> _getUniqueCountries(List<Equipment> equipments) {
    Set<String> countries = {'Todos'};
    countries.addAll(equipments.map((e) => e.country));
    return countries.toList();
  }

  List<String> _getUniqueRegions(List<Equipment> equipments) {
    Set<String> regions = {'Todas'};
    regions.addAll(equipments.map((e) => e.region));
    return regions.toList();
  }

  // ← NUEVO: Obtener tipos únicos
  List<String> _getUniqueTipos(List<Equipment> equipments) {
    Set<String> tipos = {'Todos'};
    tipos.addAll(equipments.map((e) => e.tipo));
    return tipos.toList();
  }

  List<String> _getUniqueCategories(List<Equipment> equipments) {
    Set<String> categories = {'Todas'};
    categories.addAll(equipments.map((e) => e.category));
    return categories.toList();
  }

  String _getClientName(String clientId) {
    Map<String, String> clientNames = {
      'client1': 'Xpertcode',
      'client2': 'SoftTech',
      'client3': 'TechCorp',
      'client4': 'InnovateLab',
      'client5': 'DataSolutions',
    };
    return clientNames[clientId] ??
        'Cliente ${clientId.substring(0, 3).toUpperCase()}';
  }

  // Aplicar filtros avanzados
  List<Equipment> _applyAdvancedFilters(List<Equipment> equipments) {
    List<Equipment> filtered = List.from(equipments);

    // Filtro por búsqueda
    if (_searchQuery.isNotEmpty) {
      String query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((equipment) =>
              equipment.name.toLowerCase().contains(query) ||
              equipment.brand.toLowerCase().contains(query) ||
              equipment.model.toLowerCase().contains(query) ||
              equipment.equipmentNumber.toLowerCase().contains(query) ||
              equipment.tipo.toLowerCase().contains(query) || // ← NUEVO
              equipment.location.toLowerCase().contains(query) ||
              equipment.branch.toLowerCase().contains(query) ||
              equipment.country.toLowerCase().contains(query) ||
              equipment.region.toLowerCase().contains(query))
          .toList();
    }

    // Filtro por cliente
    if (_selectedClient != 'Todos') {
      filtered = filtered
          .where((e) => _getClientName(e.clientId) == _selectedClient)
          .toList();
    }

    // Filtro por sucursal
    if (_selectedBranch != 'Todas') {
      filtered = filtered.where((e) => e.branch == _selectedBranch).toList();
    }

    // Filtro por país
    if (_selectedCountry != 'Todos') {
      filtered = filtered.where((e) => e.country == _selectedCountry).toList();
    }

    // Filtro por región
    if (_selectedRegion != 'Todas') {
      filtered = filtered.where((e) => e.region == _selectedRegion).toList();
    }

    // ← NUEVO: Filtro por tipo
    if (_selectedTipo != 'Todos') {
      filtered = filtered.where((e) => e.tipo == _selectedTipo).toList();
    }

    // Filtro por categoría
    if (_selectedCategory != 'Todas') {
      filtered =
          filtered.where((e) => e.category == _selectedCategory).toList();
    }

    // Filtro por estado
    if (_selectedStatus != 'Todos') {
      filtered = filtered.where((e) => e.status == _selectedStatus).toList();
    }

    // Filtro por condición
    if (_selectedCondition != 'Todas') {
      filtered =
          filtered.where((e) => e.condition == _selectedCondition).toList();
    }

    // Filtro por asignación
    switch (_selectedAssignment) {
      case 'Asignados':
        filtered = filtered
            .where((e) =>
                e.assignedTechnicianId != null &&
                e.assignedTechnicianId!.isNotEmpty)
            .toList();
        break;
      case 'Sin asignar':
        filtered = filtered
            .where((e) =>
                e.assignedTechnicianId == null ||
                e.assignedTechnicianId!.isEmpty)
            .toList();
        break;
      case 'Necesitan mantenimiento':
        filtered = filtered.where((e) => e.needsMaintenance).toList();
        break;
      case 'Vencidos':
        filtered = filtered.where((e) => e.isOverdue).toList();
        break;
    }

    return filtered;
  }

  // Calcular estadísticas
  void _calculateStats(List<Equipment> equipments) {
    _stats = {
      'total': equipments.length,
      'activos': equipments.where((e) => e.isActive).length,
      'operativos': equipments.where((e) => e.status == 'Operativo').length,
      'mantenimiento':
          equipments.where((e) => e.status == 'En mantenimiento').length,
      'fuera_servicio':
          equipments.where((e) => e.status == 'Fuera de servicio').length,
      'asignados': equipments
          .where((e) =>
              e.assignedTechnicianId != null &&
              e.assignedTechnicianId!.isNotEmpty)
          .length,
      'sin_asignar': equipments
          .where((e) =>
              e.assignedTechnicianId == null || e.assignedTechnicianId!.isEmpty)
          .length,
      'necesitan_mantenimiento':
          equipments.where((e) => e.needsMaintenance).length,
      'vencidos': equipments.where((e) => e.isOverdue).length,
    };
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Inventario Global de Equipos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _currentView == 'cards'
                  ? Icons.view_list
                  : _currentView == 'table'
                      ? Icons.map
                      : Icons.view_module,
              color: Colors.white,
            ),
            onPressed: _toggleView,
            tooltip: 'Cambiar vista',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showAdvancedFilters,
            tooltip: 'Filtros avanzados',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadEquipments,
            tooltip: 'Actualizar',
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.inventory), text: 'Inventario'),
            Tab(icon: Icon(Icons.analytics), text: 'Estadísticas'),
            Tab(icon: Icon(Icons.location_on), text: 'Ubicaciones'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildActiveFiltersChips(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInventoryTab(),
                _buildStatisticsTab(),
                _buildLocationsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEquipmentDialog,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar Equipo'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText:
              'Buscar por nombre, marca, modelo, número, tipo, ubicación...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    List<Widget> chips = [];

    if (_selectedClient != 'Todos') {
      chips.add(_buildFilterChip('Cliente: $_selectedClient', () {
        setState(() {
          _selectedClient = 'Todos';
        });
      }));
    }
    if (_selectedBranch != 'Todas') {
      chips.add(_buildFilterChip('Sucursal: $_selectedBranch', () {
        setState(() {
          _selectedBranch = 'Todas';
        });
      }));
    }
    if (_selectedCountry != 'Todos') {
      chips.add(_buildFilterChip('País: $_selectedCountry', () {
        setState(() {
          _selectedCountry = 'Todos';
        });
      }));
    }
    if (_selectedRegion != 'Todas') {
      chips.add(_buildFilterChip('Región: $_selectedRegion', () {
        setState(() {
          _selectedRegion = 'Todas';
        });
      }));
    }
    // ← NUEVO: Chip de tipo
    if (_selectedTipo != 'Todos') {
      chips.add(_buildFilterChip('Tipo: $_selectedTipo', () {
        setState(() {
          _selectedTipo = 'Todos';
        });
      }));
    }
    if (_selectedCategory != 'Todas') {
      chips.add(_buildFilterChip('Categoría: $_selectedCategory', () {
        setState(() {
          _selectedCategory = 'Todas';
        });
      }));
    }
    if (_selectedStatus != 'Todos') {
      chips.add(_buildFilterChip('Estado: $_selectedStatus', () {
        setState(() {
          _selectedStatus = 'Todos';
        });
      }));
    }
    if (_selectedCondition != 'Todas') {
      chips.add(_buildFilterChip('Condición: $_selectedCondition', () {
        setState(() {
          _selectedCondition = 'Todas';
        });
      }));
    }
    if (_selectedAssignment != 'Todos') {
      chips.add(_buildFilterChip('Asignación: $_selectedAssignment', () {
        setState(() {
          _selectedAssignment = 'Todos';
        });
      }));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...chips,
          if (chips.length > 1)
            ActionChip(
              label: const Text('Limpiar todo'),
              onPressed: _clearAllFilters,
              backgroundColor: Colors.red[50],
              labelStyle: const TextStyle(color: Colors.red),
              side: const BorderSide(color: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 18),
      backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
      labelStyle: const TextStyle(color: Color(0xFF2196F3)),
      side: const BorderSide(color: Color(0xFF2196F3)),
    );
  }

  Widget _buildInventoryTab() {
    return Consumer<EquipmentProvider>(
      builder: (context, equipmentProvider, child) {
        if (equipmentProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (equipmentProvider.errorMessage != null) {
          return _buildErrorWidget(equipmentProvider.errorMessage!);
        }

        List<Equipment> filteredEquipments =
            _applyAdvancedFilters(equipmentProvider.allEquipments);
        _calculateStats(filteredEquipments);

        if (filteredEquipments.isEmpty) {
          return _buildEmptyWidget();
        }

        return RefreshIndicator(
          onRefresh: () async => _loadEquipments(),
          child: Column(
            children: [
              _buildStatsRow(),
              Expanded(
                child: _buildEquipmentsList(filteredEquipments),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total',
              _stats['total'] ?? 0,
              Icons.inventory,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Operativos',
              _stats['operativos'] ?? 0,
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Asignados',
              _stats['asignados'] ?? 0,
              Icons.person,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Vencidos',
              _stats['vencidos'] ?? 0,
              Icons.warning,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentsList(List<Equipment> equipments) {
    switch (_currentView) {
      case 'table':
        return _buildTableView(equipments);
      case 'map':
        return _buildMapView(equipments);
      default:
        return _buildCardsView(equipments);
    }
  }

  Widget _buildCardsView(List<Equipment> equipments) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: equipments.length,
      itemBuilder: (context, index) {
        final equipment = equipments[index];
        return _buildEquipmentCard(equipment);
      },
    );
  }

  Widget _buildTableView(List<Equipment> equipments) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Número')),
          DataColumn(label: Text('Nombre')),
          DataColumn(label: Text('Tipo')), // ← NUEVO
          DataColumn(label: Text('Cliente')),
          DataColumn(label: Text('Sucursal')),
          DataColumn(label: Text('País')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Técnico')),
        ],
        rows: equipments.map((equipment) {
          return DataRow(
            onSelectChanged: (_) => _showEquipmentDetail(equipment),
            cells: [
              DataCell(Text(equipment.equipmentNumber)),
              DataCell(Text(equipment.name)),
              DataCell(Text(equipment.tipo)), // ← NUEVO
              DataCell(Text(_getClientName(equipment.clientId))),
              DataCell(Text(equipment.branch)),
              DataCell(Text(equipment.country)),
              DataCell(
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              DataCell(Text(equipment.assignedTechnicianName ?? 'Sin asignar')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMapView(List<Equipment> equipments) {
    // Agrupar equipos por ubicación
    Map<String, List<Equipment>> groupedByLocation = {};
    for (var equipment in equipments) {
      String key =
          '${equipment.country} - ${equipment.region} - ${equipment.branch}';
      groupedByLocation.putIfAbsent(key, () => []);
      groupedByLocation[key]!.add(equipment);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedByLocation.keys.length,
      itemBuilder: (context, index) {
        String location = groupedByLocation.keys.elementAt(index);
        List<Equipment> locationEquipments = groupedByLocation[location]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: const Icon(Icons.location_on, color: Colors.blue),
            title: Text(location),
            subtitle: Text('${locationEquipments.length} equipos'),
            children: locationEquipments.map((equipment) {
              return ListTile(
                leading: Icon(_getCategoryIcon(equipment.category)),
                title: Text(equipment.name),
                subtitle: Text('${equipment.brand} ${equipment.model}'),
                trailing: Container(
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () => _showEquipmentDetail(equipment),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ← ACTUALIZADO: Tarjeta con badge de tipo
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            equipment.equipmentNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            equipment.tipo,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(equipment.status)
                              .withOpacity(0.1),
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
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        onSelected: (value) =>
                            _handleCardAction(value, equipment),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility,
                                    size: 18, color: Colors.blue),
                                SizedBox(width: 12),
                                Text('Ver detalles'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit,
                                    size: 18, color: Colors.orange),
                                SizedBox(width: 12),
                                Text('Editar equipo'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'qr',
                            child: Row(
                              children: [
                                Icon(Icons.qr_code,
                                    size: 18, color: Colors.purple),
                                SizedBox(width: 12),
                                Text('Generar QR'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.warning,
                                    size: 18, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Reportar falla'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Información principal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(equipment.category),
                      color: const Color(0xFF2196F3),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          equipment.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.business,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${_getClientName(equipment.clientId)} • ${equipment.branch}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${equipment.country}, ${equipment.region}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
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

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Técnico asignado',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      Text(
                        equipment.assignedTechnicianName ?? 'Sin asignar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: equipment.assignedTechnicianName != null
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  if (equipment.needsMaintenance)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: equipment.isOverdue
                            ? Colors.red.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            equipment.isOverdue
                                ? Icons.warning
                                : Icons.schedule,
                            size: 12,
                            color: equipment.isOverdue
                                ? Colors.red
                                : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            equipment.isOverdue ? 'Vencido' : 'Próximo',
                            style: TextStyle(
                              fontSize: 10,
                              color: equipment.isOverdue
                                  ? Colors.red
                                  : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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


  Widget _buildStatisticsTab() {
    return Consumer<EquipmentProvider>(
      builder: (context, equipmentProvider, child) {
        List<Equipment> filteredEquipments =
            _applyAdvancedFilters(equipmentProvider.allEquipments);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatisticsSection(
                  'Resumen General', _buildGeneralStats(filteredEquipments)),
              const SizedBox(height: 24),
              _buildStatisticsSection(
                  'Por Estado', _buildStatusStats(filteredEquipments)),
              const SizedBox(height: 24),
              // ← NUEVO: Estadísticas por tipo
              _buildStatisticsSection(
                  'Por Tipo', _buildTipoStats(filteredEquipments)),
              const SizedBox(height: 24),
              _buildStatisticsSection(
                  'Por Categoría', _buildCategoryStats(filteredEquipments)),
              const SizedBox(height: 24),
              _buildStatisticsSection(
                  'Por Ubicación', _buildLocationStats(filteredEquipments)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationsTab() {
    return Consumer<EquipmentProvider>(
      builder: (context, equipmentProvider, child) {
        List<Equipment> filteredEquipments =
            _applyAdvancedFilters(equipmentProvider.allEquipments);

        // Agrupar por país y región
        Map<String, Map<String, List<Equipment>>> locationGroups = {};

        for (var equipment in filteredEquipments) {
          locationGroups.putIfAbsent(equipment.country, () => {});
          locationGroups[equipment.country]!
              .putIfAbsent(equipment.region, () => []);
          locationGroups[equipment.country]![equipment.region]!.add(equipment);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: locationGroups.keys.length,
          itemBuilder: (context, index) {
            String country = locationGroups.keys.elementAt(index);
            Map<String, List<Equipment>> regions = locationGroups[country]!;
            int totalEquipments = regions.values
                .fold(0, (sum, equipments) => sum + equipments.length);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: const Icon(Icons.flag, color: Colors.blue),
                title: Text(country),
                subtitle: Text(
                    '${regions.length} región${regions.length != 1 ? 'es' : ''} • $totalEquipments equipos'),
                initiallyExpanded: locationGroups.keys.length <=
                    3, // Auto-expandir si hay pocos países
                children: regions.entries.map((regionEntry) {
                  String region = regionEntry.key;
                  List<Equipment> equipments = regionEntry.value;

                  // Agrupar por sucursal dentro de la región
                  Map<String, List<Equipment>> branchGroups = {};
                  for (var equipment in equipments) {
                    branchGroups.putIfAbsent(equipment.branch, () => []);
                    branchGroups[equipment.branch]!.add(equipment);
                  }

                  return ExpansionTile(
                    leading:
                        const Icon(Icons.location_city, color: Colors.green),
                    title: Text(region),
                    subtitle: Text(
                        '${branchGroups.length} sucursal${branchGroups.length != 1 ? 'es' : ''} • ${equipments.length} equipos'),
                    children: branchGroups.entries.map((branchEntry) {
                      String branch = branchEntry.key;
                      List<Equipment> branchEquipments = branchEntry.value;

                      return ExpansionTile(
                        leading:
                            const Icon(Icons.business, color: Colors.orange),
                        title: Text(branch),
                        subtitle: Text('${branchEquipments.length} equipos'),
                        children: branchEquipments.map((equipment) {
                          return ListTile(
                            leading: Icon(_getCategoryIcon(equipment.category),
                                size: 20),
                            title: Text(equipment.name),
                            subtitle: Text(
                                '${equipment.brand} ${equipment.model} • ${equipment.location}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(equipment.status)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                equipment.status,
                                style: TextStyle(
                                  color: _getStatusColor(equipment.status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            onTap: () => _showEquipmentDetail(equipment),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatisticsSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2196F3),
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildGeneralStats(List<Equipment> equipments) {
    int total = equipments.length;
    int activos = equipments.where((e) => e.isActive).length;
    int asignados = equipments
        .where((e) =>
            e.assignedTechnicianId != null &&
            e.assignedTechnicianId!.isNotEmpty)
        .length;
    int vencidos = equipments.where((e) => e.isOverdue).length;

    // Usar valores dummy hasta que tengamos datos reales
    double totalCost = equipments.length * 15000.0; // $15K por equipo promedio
    double pmCost = equipments.length * 2500.0; // $2.5K PM por equipo
    double cmCost = equipments.length * 1800.0; // $1.8K CM por equipo

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _buildStatCard(
                        'Total Equipos', total, Icons.inventory, Colors.blue)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatCard(
                        'Activos', activos, Icons.check_circle, Colors.green)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatCard(
                        'Asignados', asignados, Icons.person, Colors.orange)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatCard(
                        'Vencidos', vencidos, Icons.warning, Colors.red)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '\$${_formatCurrency(totalCost)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue),
                      ),
                      const Text('Costo Total',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '\$${_formatCurrency(pmCost)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      const Text('Costo PM',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '\$${_formatCurrency(cmCost)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange),
                      ),
                      const Text('Costo CM',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStats(List<Equipment> equipments) {
    Map<String, int> statusCount = {};
    for (var equipment in equipments) {
      statusCount[equipment.status] = (statusCount[equipment.status] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: statusCount.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(entry.key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(entry.key),
                    ],
                  ),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ← NUEVO: Estadísticas por tipo
  Widget _buildTipoStats(List<Equipment> equipments) {
    Map<String, int> tipoCount = {};
    for (var equipment in equipments) {
      tipoCount[equipment.tipo] = (tipoCount[equipment.tipo] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: tipoCount.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(_getTipoIcon(entry.key),
                          size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(entry.key),
                    ],
                  ),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryStats(List<Equipment> equipments) {
    Map<String, int> categoryCount = {};
    for (var equipment in equipments) {
      categoryCount[equipment.category] =
          (categoryCount[equipment.category] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: categoryCount.entries.take(10).map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(_getCategoryIcon(entry.key),
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(entry.key),
                    ],
                  ),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLocationStats(List<Equipment> equipments) {
    Map<String, int> countryCount = {};
    for (var equipment in equipments) {
      countryCount[equipment.country] =
          (countryCount[equipment.country] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: countryCount.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flag, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(entry.key),
                    ],
                  ),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text('Error al cargar equipos',
              style: TextStyle(fontSize: 18, color: Colors.red[600])),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(error,
                style: TextStyle(color: Colors.red[400]),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _loadEquipments, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No se encontraron equipos',
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          const Text('Intenta ajustar los filtros de búsqueda',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _toggleView() {
    setState(() {
      switch (_currentView) {
        case 'cards':
          _currentView = 'table';
          break;
        case 'table':
          _currentView = 'map';
          break;
        default:
          _currentView = 'cards';
      }
    });
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildAdvancedFiltersSheet(),
    );
  }

  Widget _buildAdvancedFiltersSheet() {
    return Consumer<EquipmentProvider>(
      builder: (context, equipmentProvider, child) {
        List<Equipment> allEquipments = equipmentProvider.allEquipments;

        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Filtros Avanzados',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          TextButton(
                              onPressed: _clearAllFilters,
                              child: const Text('Limpiar Todo')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            _buildFilterSection('Cliente', _selectedClient,
                                _getUniqueClients(allEquipments), (value) {
                              setState(() {
                                _selectedClient = value;
                              });
                              setModalState(() {});
                            }),
                            _buildFilterSection('Sucursal', _selectedBranch,
                                _getUniqueBranches(allEquipments), (value) {
                              setState(() {
                                _selectedBranch = value;
                              });
                              setModalState(() {});
                            }),
                            _buildFilterSection('País', _selectedCountry,
                                _getUniqueCountries(allEquipments), (value) {
                              setState(() {
                                _selectedCountry = value;
                              });
                              setModalState(() {});
                            }),
                            _buildFilterSection('Región', _selectedRegion,
                                _getUniqueRegions(allEquipments), (value) {
                              setState(() {
                                _selectedRegion = value;
                              });
                              setModalState(() {});
                            }),
                            // ← NUEVO: Filtro de tipo
                            _buildFilterSection('Tipo', _selectedTipo,
                                _getUniqueTipos(allEquipments), (value) {
                              setState(() {
                                _selectedTipo = value;
                              });
                              setModalState(() {});
                            }),
                            _buildFilterSection('Categoría', _selectedCategory,
                                _getUniqueCategories(allEquipments), (value) {
                              setState(() {
                                _selectedCategory = value;
                              });
                              setModalState(() {});
                            }),
                            _buildFilterSection('Estado', _selectedStatus, [
                              'Todos',
                              'Operativo',
                              'En mantenimiento',
                              'Fuera de servicio'
                            ], (value) {
                              setState(() {
                                _selectedStatus = value;
                              });
                              setModalState(() {});
                            }),
                            _buildFilterSection(
                                'Condición', _selectedCondition, [
                              'Todas',
                              'Excelente',
                              'Bueno',
                              'Regular',
                              'Malo'
                            ], (value) {
                              setState(() {
                                _selectedCondition = value;
                              });
                              setModalState(() {});
                            }),
                            _buildFilterSection(
                                'Asignación', _selectedAssignment, [
                              'Todos',
                              'Asignados',
                              'Sin asignar',
                              'Necesitan mantenimiento',
                              'Vencidos'
                            ], (value) {
                              setState(() {
                                _selectedAssignment = value;
                              });
                              setModalState(() {});
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Aplicar Filtros'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection(String title, String selectedValue,
      List<String> options, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedValue,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          isExpanded: true,
          items: options.map((option) {
            return DropdownMenuItem(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (value) => onChanged(value!),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedClient = 'Todos';
      _selectedBranch = 'Todas';
      _selectedCountry = 'Todos';
      _selectedRegion = 'Todas';
      _selectedTipo = 'Todos'; // ← NUEVO
      _selectedCategory = 'Todas';
      _selectedStatus = 'Todos';
      _selectedCondition = 'Todas';
      _selectedAssignment = 'Todos';
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _showEquipmentDetail(Equipment equipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EquipmentDetailScreen(equipment: equipment)),
    );
  }

  void _handleCardAction(String action, Equipment equipment) {
    switch (action) {
      case 'view':
        _showEquipmentDetail(equipment);
        break;
      case 'edit':
        _navigateToEditEquipment(equipment);
        break;
      case 'qr':
        _generateQRCode(equipment);
        break;
      case 'report':
        _reportFailure(equipment);
        break;
    }
  }

  Future<void> _navigateToEditEquipment(Equipment equipment) async {
    try {
      final clientProvider =
          Provider.of<ClientProvider>(context, listen: false);

      if (clientProvider.clients.isEmpty) {
        clientProvider.loadClients();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final client = clientProvider.clients.firstWhere(
        (c) => c.id == equipment.clientId,
        orElse: () => throw Exception('Cliente no encontrado'),
      );

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEquipmentScreen(
            client: client,
            equipment: equipment,
          ),
        ),
      );

      if (result == true && mounted) {
        _loadEquipments();
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
  }

  void _generateQRCode(Equipment equipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRDisplayScreen(equipment: equipment),
      ),
    );
  }

  void _reportFailure(Equipment equipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaultReportScreen(equipment: equipment),
      ),
    );
  }

  void _showAddEquipmentDialog() async {
    // Cargar clientes
    final clientProvider = Provider.of<ClientProvider>(context, listen: false);

    if (clientProvider.clients.isEmpty) {
      clientProvider.loadClients();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;

    // Mostrar diálogo de búsqueda de clientes
    final selectedClient = await showDialog<ClientModel>(
      context: context,
      builder: (context) => ClientSearchDialog(
        clients: clientProvider.clients,
      ),
    );

    if (selectedClient != null && mounted) {
      // Navegar a agregar equipo con el cliente seleccionado
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEquipmentScreen(client: selectedClient),
        ),
      );

      if (result == true && mounted) {
        _loadEquipments(); // Recargar inventario
      }
    }
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

  // ← NUEVO: Iconos por tipo
  IconData _getTipoIcon(String tipo) {
    switch (tipo) {
      case 'Climatización':
        return Icons.ac_unit;
      case 'Equipos Eléctricos':
        return Icons.electrical_services;
      case 'Paneles Eléctricos':
        return Icons.electric_bolt;
      case 'Generadores':
        return Icons.power;
      case 'UPS':
        return Icons.battery_charging_full;
      case 'Equipos de Cocina':
        return Icons.kitchen;
      case 'Facilidades':
        return Icons.build;
      default:
        return Icons.devices;
    }
  }

  IconData _getCategoryIcon(String category) {
    String cat = category.toLowerCase();

    // Climatización
    if (cat.contains('split') ||
        cat.contains('cassette') ||
        cat.contains('ducto') ||
        cat.contains('piso') ||
        cat.contains('ventana') ||
        cat.contains('portátil')) {
      return Icons.ac_unit;
    }

    // Equipos Eléctricos
    if (cat.contains('transformador') ||
        cat.contains('tablero') ||
        cat.contains('breaker') ||
        cat.contains('contactor')) {
      return Icons.electrical_services;
    }

    // Paneles
    if (cat.contains('panel')) {
      return Icons.electric_bolt;
    }

    // Generadores
    if (cat.contains('generador') ||
        cat.contains('diésel') ||
        cat.contains('gas') ||
        cat.contains('gasolina')) {
      return Icons.power;
    }

    // UPS
    if (cat.contains('ups') ||
        cat.contains('línea interactiva') ||
        cat.contains('online') ||
        cat.contains('offline')) {
      return Icons.battery_charging_full;
    }

    // Cocina
    if (cat.contains('refrigerador') ||
        cat.contains('estufa') ||
        cat.contains('horno') ||
        cat.contains('microondas') ||
        cat.contains('lavavajillas') ||
        cat.contains('campana')) {
      return Icons.kitchen;
    }

    // Facilidades
    if (cat.contains('bomba')) return Icons.water_drop;
    if (cat.contains('ascensor')) return Icons.elevator;
    if (cat.contains('portón')) return Icons.door_sliding;
    if (cat.contains('cámara')) return Icons.videocam;
    if (cat.contains('iluminación')) return Icons.lightbulb;
    if (cat.contains('ventilación')) return Icons.air;
    if (cat.contains('sistema')) return Icons.settings_applications;

    return Icons.build;
  }
}
