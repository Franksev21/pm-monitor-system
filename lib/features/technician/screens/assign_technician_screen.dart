import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/user_management_model.dart';
import 'package:pm_monitor/core/services/user_management_service.dart';

class AssignTechnicianScreen extends StatefulWidget {
  final UserManagementModel supervisor;

  const AssignTechnicianScreen({
    Key? key,
    required this.supervisor,
  }) : super(key: key);

  @override
  State<AssignTechnicianScreen> createState() => _AssignTechnicianScreenState();
}

class _AssignTechnicianScreenState extends State<AssignTechnicianScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final UserManagementService _userService = UserManagementService();

  String _searchQuery = '';
  List<UserManagementModel> _selectedTechnicians = [];
  List<UserManagementModel> _allTechnicians = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTechnicians();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTechnicians() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final technicians = await _userService.getActiveTechnicians();
      setState(() {
        _allTechnicians = technicians;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar técnicos: $e'),
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

  List<UserManagementModel> _getUnassignedTechnicians(
      List<UserManagementModel> allTechnicians) {
    return allTechnicians
        .where((technician) =>
            technician.isActive &&
            (technician.supervisorId == null ||
                technician.supervisorId!.isEmpty))
        .toList();
  }

  List<UserManagementModel> _getAssignedTechnicians(
      List<UserManagementModel> allTechnicians) {
    return allTechnicians
        .where((technician) =>
            technician.isActive &&
            technician.supervisorId == widget.supervisor.id)
        .toList();
  }

  List<UserManagementModel> _filterTechnicians(
      List<UserManagementModel> technicians) {
    if (_searchQuery.isEmpty) return technicians;

    final query = _searchQuery.toLowerCase();
    return technicians
        .where((technician) =>
            technician.name.toLowerCase().contains(query) ||
            technician.email.toLowerCase().contains(query) ||
            technician.phone.toLowerCase().contains(query) ||
            (technician.specialization?.toLowerCase().contains(query) ?? false))
        .toList();
  }

  Future<void> _assignSelectedTechnicians() async {
    if (_selectedTechnicians.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener técnicos ya asignados al supervisor
      final currentAssigned = widget.supervisor.assignedTechnicians;
      final newTechnicianIds = _selectedTechnicians.map((t) => t.id).toList();
      final allAssignedIds = [...currentAssigned, ...newTechnicianIds];

      await _userService.assignTechniciansToSupervisor(
        widget.supervisor.id,
        allAssignedIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_selectedTechnicians.length} técnicos asignados correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _selectedTechnicians.clear();
        });

        await _loadTechnicians();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al asignar técnicos: $e'),
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

  Future<void> _unassignTechnician(UserManagementModel technician) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desasignar Técnico'),
        content: Text(
            '¿Desasignar ${technician.name} de ${widget.supervisor.name}?'),
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
                await _userService.removeTechnicianFromSupervisor(
                  widget.supervisor.id,
                  technician.id,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Técnico desasignado correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await _loadTechnicians();
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
              'Asignar Técnicos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.supervisor.name,
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
          if (_selectedTechnicians.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: _isLoading ? null : _assignSelectedTechnicians,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.person_add),
              text: 'Disponibles',
            ),
            Tab(
              icon: Icon(Icons.group),
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
          if (_selectedTechnicians.isNotEmpty) _buildSelectionCounter(),

          // Contenido de las pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAvailableTechniciansTab(),
                _buildAssignedTechniciansTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTechnicians.isNotEmpty && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _assignSelectedTechnicians,
              backgroundColor: const Color(0xFF2196F3),
              icon: const Icon(Icons.supervisor_account),
              label: Text('Asignar ${_selectedTechnicians.length}'),
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
          hintText: 'Buscar técnicos...',
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
          const Icon(
            Icons.check_circle,
            color: Color(0xFF2196F3),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedTechnicians.length} técnicos seleccionados',
            style: const TextStyle(
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedTechnicians.clear();
              });
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableTechniciansTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final unassignedTechnicians = _getUnassignedTechnicians(_allTechnicians);
    final filteredTechnicians = _filterTechnicians(unassignedTechnicians);

    if (filteredTechnicians.isEmpty) {
      return _buildEmptyWidget(
        'No hay técnicos disponibles',
        'Todos los técnicos están asignados a supervisores',
        Icons.group,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTechnicians,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredTechnicians.length,
        itemBuilder: (context, index) {
          final technician = filteredTechnicians[index];
          final isSelected =
              _selectedTechnicians.any((t) => t.id == technician.id);

          return _buildTechnicianCard(
            technician,
            isSelected: isSelected,
            onTap: () => _toggleTechnicianSelection(technician),
            showAssignButton: true,
          );
        },
      ),
    );
  }

  Widget _buildAssignedTechniciansTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final assignedTechnicians = _getAssignedTechnicians(_allTechnicians);
    final filteredTechnicians = _filterTechnicians(assignedTechnicians);

    if (filteredTechnicians.isEmpty) {
      return _buildEmptyWidget(
        'No hay técnicos asignados',
        'Este supervisor no tiene técnicos asignados aún',
        Icons.person,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTechnicians,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredTechnicians.length,
        itemBuilder: (context, index) {
          final technician = filteredTechnicians[index];

          return _buildTechnicianCard(
            technician,
            onTap: () => _showTechnicianDetails(technician),
            showUnassignButton: true,
          );
        },
      ),
    );
  }

  void _toggleTechnicianSelection(UserManagementModel technician) {
    setState(() {
      final index =
          _selectedTechnicians.indexWhere((t) => t.id == technician.id);
      if (index >= 0) {
        _selectedTechnicians.removeAt(index);
      } else {
        _selectedTechnicians.add(technician);
      }
    });
  }

  Widget _buildTechnicianCard(
    UserManagementModel technician, {
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
                // Avatar del técnico
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getTechnicianColor(
                      technician.specialization ?? 'General'),
                  child: Text(
                    _getInitials(technician.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Información del técnico
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              technician.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: technician.isActive
                                  ? Colors.green
                                  : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              technician.statusText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        technician.specialization ?? 'Especialización general',
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
                            Icons.email,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              technician.email,
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
                      if (technician.phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              technician.phone,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                      Row(
                        children: [
                          const Icon(
                            Icons.build,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${technician.assignedEquipments.length} equipos',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Botones de acción
                if (showUnassignButton)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _unassignTechnician(technician),
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

  void _showTechnicianDetails(UserManagementModel technician) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(technician.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email:', technician.email),
              _buildDetailRow(
                  'Teléfono:',
                  technician.phone.isNotEmpty
                      ? technician.phone
                      : 'No disponible'),
              _buildDetailRow(
                  'Especialización:', technician.specialization ?? 'General'),
              _buildDetailRow('Equipos asignados:',
                  '${technician.assignedEquipments.length}'),
              _buildDetailRow('Tarifa/hora:',
                  '\$${technician.hourlyRate?.toStringAsFixed(2) ?? "0.00"}'),
              _buildDetailRow('Estado:', technician.statusText),
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
            width: 100,
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

  Color _getTechnicianColor(String specialization) {
    String spec = specialization.toLowerCase();
    if (spec.contains('aire') || spec.contains('hvac')) {
      return Colors.blue;
    } else if (spec.contains('eléctrico') || spec.contains('electrical')) {
      return Colors.orange;
    } else if (spec.contains('general') || spec.contains('mantenimiento')) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'T';
  }
}
