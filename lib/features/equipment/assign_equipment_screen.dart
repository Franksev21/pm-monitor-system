import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/user_management_model.dart';
import 'package:provider/provider.dart';
import '../../core/models/equipment_model.dart';
import '../../core/providers/equipment_provider.dart';
import '../../core/providers/auth_provider.dart';

class AssignEquipmentScreen extends StatefulWidget {
  final UserManagementModel technician;

  const AssignEquipmentScreen({
    Key? key,
    required this.technician,
  }) : super(key: key);

  @override
  State<AssignEquipmentScreen> createState() => _AssignEquipmentScreenState();
}

class _AssignEquipmentScreenState extends State<AssignEquipmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  List<Equipment> _selectedEquipments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  Future<void> _loadEquipments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final equipmentProvider =
          Provider.of<EquipmentProvider>(context, listen: false);
      equipmentProvider.loadAllEquipments();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Equipment> _getUnassignedEquipments(List<Equipment> allEquipments) {
    return allEquipments
        .where((equipment) =>
            equipment.isActive &&
            (equipment.assignedTechnicianId == null ||
                equipment.assignedTechnicianId!.isEmpty))
        .toList();
  }

  List<Equipment> _getAssignedEquipments(List<Equipment> allEquipments) {
    return allEquipments
        .where((equipment) =>
            equipment.isActive &&
            equipment.assignedTechnicianId == widget.technician.id)
        .toList();
  }

  List<Equipment> _filterEquipments(List<Equipment> equipments) {
    if (_searchQuery.isEmpty) return equipments;

    final query = _searchQuery.toLowerCase();
    return equipments
        .where((equipment) =>
            equipment.name.toLowerCase().contains(query) ||
            equipment.brand.toLowerCase().contains(query) ||
            equipment.model.toLowerCase().contains(query) ||
            equipment.equipmentNumber.toLowerCase().contains(query) ||
            equipment.location.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _assignSelectedEquipments() async {
    if (_selectedEquipments.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final equipmentProvider =
          Provider.of<EquipmentProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      int successCount = 0;

      for (Equipment equipment in _selectedEquipments) {
        bool success = await equipmentProvider.assignTechnician(
          equipment.id!,
          widget.technician.id,
          widget.technician.name,
          authProvider.currentUser?.id ?? '',
          equipment.clientId,
        );
        if (success) successCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount equipos asignados correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _selectedEquipments.clear();
        });

        _loadEquipments();

        // Notificar al padre para refrescar estadísticas
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al asignar equipos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unassignEquipment(Equipment equipment) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desasignar Equipo'),
        content:
            Text('¿Desasignar ${equipment.name} de ${widget.technician.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              setState(() {
                _isLoading = true;
              });

              try {
                final equipmentProvider =
                    Provider.of<EquipmentProvider>(context, listen: false);
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);

                bool success = await equipmentProvider.assignTechnician(
                  equipment.id!,
                  '', // ID vacío para desasignar
                  '', // Nombre vacío para desasignar
                  authProvider.currentUser?.id ?? '',
                  equipment.clientId,
                );

                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Equipo desasignado correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadEquipments();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al desasignar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desasignar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Asignar Equipos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.technician.name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_selectedEquipments.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: _isLoading ? null : _assignSelectedEquipments,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.add_circle_outline),
              text: 'Disponibles',
            ),
            Tab(
              icon: Icon(Icons.assignment),
              text: 'Asignados',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          _buildSearchBar(),

          // Contador de seleccionados
          if (_selectedEquipments.isNotEmpty) _buildSelectionCounter(),

          // Contenido de las pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAvailableEquipmentsTab(),
                _buildAssignedEquipmentsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedEquipments.isNotEmpty && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _assignSelectedEquipments,
              backgroundColor: const Color(0xFF2196F3),
              icon: const Icon(Icons.assignment_turned_in),
              label: Text('Asignar ${_selectedEquipments.length}'),
            )
          : null,
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
          hintText: 'Buscar equipos...',
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCounter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: const Color(0xFF2196F3),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedEquipments.length} equipos seleccionados',
            style: const TextStyle(
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedEquipments.clear();
              });
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableEquipmentsTab() {
    return Consumer<EquipmentProvider>(
      builder: (context, equipmentProvider, child) {
        if (equipmentProvider.isLoading || _isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (equipmentProvider.errorMessage != null) {
          return _buildErrorWidget(equipmentProvider.errorMessage!);
        }

        final unassignedEquipments =
            _getUnassignedEquipments(equipmentProvider.allEquipments);
        final filteredEquipments = _filterEquipments(unassignedEquipments);

        if (filteredEquipments.isEmpty) {
          return _buildEmptyWidget(
            'No hay equipos disponibles',
            'Todos los equipos están asignados a técnicos',
            Icons.assignment_turned_in,
          );
        }

        return RefreshIndicator(
          onRefresh: _loadEquipments,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredEquipments.length,
            itemBuilder: (context, index) {
              final equipment = filteredEquipments[index];
              final isSelected =
                  _selectedEquipments.any((e) => e.id == equipment.id);

              return _buildEquipmentCard(
                equipment,
                isSelected: isSelected,
                onTap: () => _toggleEquipmentSelection(equipment),
                showAssignButton: true,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAssignedEquipmentsTab() {
    return Consumer<EquipmentProvider>(
      builder: (context, equipmentProvider, child) {
        if (equipmentProvider.isLoading || _isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (equipmentProvider.errorMessage != null) {
          return _buildErrorWidget(equipmentProvider.errorMessage!);
        }

        final assignedEquipments =
            _getAssignedEquipments(equipmentProvider.allEquipments);
        final filteredEquipments = _filterEquipments(assignedEquipments);

        if (filteredEquipments.isEmpty) {
          return _buildEmptyWidget(
            'No hay equipos asignados',
            'Este técnico no tiene equipos asignados aún',
            Icons.assignment,
          );
        }

        return RefreshIndicator(
          onRefresh: _loadEquipments,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredEquipments.length,
            itemBuilder: (context, index) {
              final equipment = filteredEquipments[index];

              return _buildEquipmentCard(
                equipment,
                onTap: () => _showEquipmentDetails(equipment),
                showUnassignButton: true,
              );
            },
          ),
        );
      },
    );
  }

  void _toggleEquipmentSelection(Equipment equipment) {
    setState(() {
      final index = _selectedEquipments.indexWhere((e) => e.id == equipment.id);
      if (index >= 0) {
        _selectedEquipments.removeAt(index);
      } else {
        _selectedEquipments.add(equipment);
      }
    });
  }

  Widget _buildEquipmentCard(
    Equipment equipment, {
    bool isSelected = false,
    VoidCallback? onTap,
    bool showAssignButton = false,
    bool showUnassignButton = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isSelected ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? const BorderSide(color: Color(0xFF2196F3), width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icono del equipo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        _getEquipmentColor(equipment.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getEquipmentIcon(equipment.category),
                    color: _getEquipmentColor(equipment.category),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // Información del equipo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              equipment.equipmentNumber,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
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
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        equipment.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${equipment.brand} ${equipment.model}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${equipment.location}, ${equipment.branch}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (equipment.nextMaintenanceDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: equipment.needsMaintenance
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Próximo: ${_formatDate(equipment.nextMaintenanceDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: equipment.needsMaintenance
                                    ? Colors.orange
                                    : Colors.grey,
                                fontWeight: equipment.needsMaintenance
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Botones de acción
                if (showUnassignButton)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _unassignEquipment(equipment),
                    tooltip: 'Desasignar',
                  ),

                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF2196F3),
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar equipos',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: TextStyle(color: Colors.red[400]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadEquipments,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showEquipmentDetails(Equipment equipment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(equipment.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Número:', equipment.equipmentNumber),
              _buildDetailRow('Marca:', equipment.brand),
              _buildDetailRow('Modelo:', equipment.model),
              _buildDetailRow(
                  'Ubicación:', '${equipment.location}, ${equipment.branch}'),
              _buildDetailRow('Estado:', equipment.status),
              _buildDetailRow('Condición:', equipment.condition),
              if (equipment.nextMaintenanceDate != null)
                _buildDetailRow('Próximo mantenimiento:',
                    _formatDate(equipment.nextMaintenanceDate!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Color _getEquipmentColor(String category) {
    String cat = category.toLowerCase();
    if (cat.contains('ac') || cat.contains('aire')) {
      return Colors.blue;
    } else if (cat.contains('panel') || cat.contains('eléctrico')) {
      return Colors.orange;
    } else if (cat.contains('generador')) {
      return Colors.red;
    } else if (cat.contains('ups')) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }

  IconData _getEquipmentIcon(String category) {
    String cat = category.toLowerCase();
    if (cat.contains('ac') || cat.contains('aire')) {
      return Icons.ac_unit;
    } else if (cat.contains('panel') || cat.contains('eléctrico')) {
      return Icons.electrical_services;
    } else if (cat.contains('generador')) {
      return Icons.power;
    } else if (cat.contains('ups')) {
      return Icons.battery_charging_full;
    } else {
      return Icons.build;
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference < -7) {
      return 'Vencido hace ${(-difference)} días';
    } else if (difference < 0) {
      return 'Vencido';
    } else if (difference == 0) {
      return 'Hoy';
    } else if (difference == 1) {
      return 'Mañana';
    } else if (difference <= 7) {
      return 'En $difference días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
