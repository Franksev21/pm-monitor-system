import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/tecnician_model.dart';
import 'package:pm_monitor/core/models/user_management_model.dart';
import 'package:pm_monitor/core/providers/tecnician_provider.dart';
import 'package:pm_monitor/features/auth/screens/assign_equipment_screen.dart';
import 'package:pm_monitor/features/auth/widgets/technician_equipment_count.dart';
import 'package:provider/provider.dart';

class TechniciansListScreen extends StatefulWidget {
  const TechniciansListScreen({Key? key}) : super(key: key);

  @override
  State<TechniciansListScreen> createState() => _TechniciansListScreenState();
}

class _TechniciansListScreenState extends State<TechniciansListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TechnicianProvider>(context, listen: false);
      provider.initializeTechniciansListener();
      provider.loadStats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Técnicos',
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
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddTechnicianDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              Provider.of<TechnicianProvider>(context, listen: false).refresh();
            },
          ),
        ],
      ),
      body: Consumer<TechnicianProvider>(
        builder: (context, technicianProvider, child) {
          return Column(
            children: [
              if (technicianProvider.stats.isNotEmpty)
                _buildStatsRow(technicianProvider.stats),
              _buildSearchBar(technicianProvider),
              Expanded(
                child: _buildTechniciansList(technicianProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(Map<String, int> stats) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', stats['total'] ?? 0, Colors.blue),
          _buildStatItem('Activos', stats['active'] ?? 0, Colors.green),
          _buildStatItem(
              'Con Equipos', stats['withEquipments'] ?? 0, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(TechnicianProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => provider.searchTechnicians(value),
        decoration: InputDecoration(
          hintText: 'Buscar técnicos...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    provider.clearSearch();
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

  Widget _buildTechniciansList(TechnicianProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
        ),
      );
    }

    if (provider.errorMessage.isNotEmpty) {
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
              'Error: ${provider.errorMessage}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.red[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.refresh(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final technicians = provider.searchQuery.isEmpty
        ? provider.technicians
        : provider.filteredTechnicians;

    if (technicians.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.engineering,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              provider.searchQuery.isEmpty
                  ? 'No hay técnicos registrados'
                  : 'No se encontraron técnicos',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (provider.searchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddTechnicianDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar Técnico'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: technicians.length,
        itemBuilder: (context, index) {
          final technician = technicians[index];
          return _buildTechnicianCard(technician, provider);
        },
      ),
    );
  }

  Widget _buildTechnicianCard(
      TechnicianModel technician, TechnicianProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showTechnicianDetails(technician),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: technician.isActive
                      ? const Color(0xFF2196F3)
                      : Colors.grey,
                  child: technician.profileImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: Image.network(
                            technician.profileImageUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                technician.initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        )
                      : Text(
                          technician.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              technician.fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              technician.statusText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.email, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              technician.email,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      if (technician.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              technician.phone,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.build, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          TechnicianEquipmentCount(
                            technicianId: technician.id!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          if (technician.hourlyRate != null) ...[
                            const Text(' • ',
                                style: TextStyle(color: Colors.grey)),
                            Text(
                              '\$${technician.hourlyRate!.toStringAsFixed(2)}/hr',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      _handleMenuAction(value, technician, provider),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            technician.isActive
                                ? Icons.block
                                : Icons.check_circle,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(technician.isActive ? 'Desactivar' : 'Activar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'assign_equipment',
                      child: Row(
                        children: [
                          Icon(Icons.precision_manufacturing, size: 18),
                          SizedBox(width: 8),
                          Text('Asignar Equipos'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'update_rate',
                      child: Row(
                        children: [
                          Icon(Icons.attach_money, size: 18),
                          SizedBox(width: 8),
                          Text('Actualizar Tarifa'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'view_assignments',
                      child: Row(
                        children: [
                          Icon(Icons.list, size: 18),
                          SizedBox(width: 8),
                          Text('Ver Asignaciones'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(
      String action, TechnicianModel technician, TechnicianProvider provider) {
    switch (action) {
      case 'edit':
        _editTechnician(technician, provider);
        break;
      case 'toggle_status':
        _toggleTechnicianStatus(technician, provider);
        break;
      case 'assign_equipment':
        _assignEquipment(technician, provider);
        break;
      case 'update_rate':
        _updateTechnicianRate(technician, provider);
        break;
      case 'view_assignments':
        _viewAssignments(technician);
        break;
    }
  }

  void _showTechnicianDetails(TechnicianModel technician) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(technician.fullName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email:', technician.email),
              _buildDetailRow('Teléfono:', technician.phone),
              _buildDetailRow('Estado:', technician.statusText),
              _buildDetailRowWithWidget(
                  'Equipos Asignados:',
                  TechnicianEquipmentCount(
                    technicianId: technician.id!,
                    style: const TextStyle(fontSize: 14),
                  )),
              if (technician.hourlyRate != null)
                _buildDetailRow('Tarifa/Hora:',
                    '\$${technician.hourlyRate!.toStringAsFixed(2)}'),
              if (technician.specialization != null)
                _buildDetailRow('Especialización:', technician.specialization!),
              _buildDetailRow('Registrado:', technician.formattedCreatedDate),
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
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithWidget(String label, Widget valueWidget) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }

  void _showAddTechnicianDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redirigir a pantalla de registro de técnico'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _editTechnician(
      TechnicianModel technician, TechnicianProvider provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editar técnico: ${technician.fullName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _toggleTechnicianStatus(
      TechnicianModel technician, TechnicianProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('${technician.isActive ? 'Desactivar' : 'Activar'} Técnico'),
        content: Text(
            '¿Estás seguro de que deseas ${technician.isActive ? 'desactivar' : 'activar'} a ${technician.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await provider.toggleTechnicianStatus(
                  technician.id, !technician.isActive);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Técnico ${!technician.isActive ? 'activado' : 'desactivado'} correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: technician.isActive ? Colors.red : Colors.green,
            ),
            child: Text(technician.isActive ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
  }

  // MÉTODO ACTUALIZADO: Ahora navega a AssignEquipmentScreen igual que en UserManagementScreen
  void _assignEquipment(
      TechnicianModel technician, TechnicianProvider provider) async {
    // Convertir TechnicianModel a UserManagementModel para compatibilidad
    final userModel = UserManagementModel(
      id: technician.id!,
      name: technician.fullName,
      email: technician.email,
      phone: technician.phone,
      role: 'technician',
      isActive: technician.isActive,
      hourlyRate: technician.hourlyRate,
      createdAt: technician.createdAt,
      photoUrl: technician.profileImageUrl,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignEquipmentScreen(technician: userModel),
      ),
    );

    // Si se asignaron equipos, refrescar la lista
    if (result == true) {
      provider.refresh();
      provider.loadStats();
    }
  }

  void _updateTechnicianRate(
      TechnicianModel technician, TechnicianProvider provider) {
    final rateController =
        TextEditingController(text: technician.hourlyRate?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Actualizar Tarifa - ${technician.fullName}'),
        content: TextField(
          controller: rateController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Tarifa por Hora (\$)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final rateText = rateController.text.trim();
              if (rateText.isNotEmpty) {
                final rate = double.tryParse(rateText);
                if (rate != null && rate > 0) {
                  Navigator.of(context).pop();
                  final success =
                      await provider.updateTechnicianRate(technician.id, rate);

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tarifa actualizada correctamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa una tarifa válida'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _viewAssignments(TechnicianModel technician) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ver asignaciones de: ${technician.fullName}'),
        backgroundColor: Colors.purple,
      ),
    );
  }
}
