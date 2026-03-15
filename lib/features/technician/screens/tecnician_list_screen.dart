import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/technician_model.dart';
import 'package:pm_monitor/core/models/user_management_model.dart';
import 'package:pm_monitor/core/providers/technician_provider.dart';
import 'package:pm_monitor/core/services/alert_service.dart';
import 'package:pm_monitor/features/equipment/assign_equipment_screen.dart';
import 'package:pm_monitor/features/auth/widgets/technician_equipment_count.dart';
import 'package:pm_monitor/features/technician/screens/alert_history_screen.dart';
import 'package:provider/provider.dart';

class TechniciansListScreen extends StatefulWidget {
  const TechniciansListScreen({super.key});

  @override
  State<TechniciansListScreen> createState() => _TechniciansListScreenState();
}

class _TechniciansListScreenState extends State<TechniciansListScreen> {
  final TextEditingController _searchController = TextEditingController();

  void _showAlertHistory(TechnicianModel technician) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlertHistoryScreen(
          technicianId: technician.id,
          technicianName: technician.fullName,
        ),
      ),
    );
  }

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
        title: const Text('Técnicos',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600)),
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
            onPressed: () =>
                Provider.of<TechnicianProvider>(context, listen: false)
                    .refresh(),
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
              Expanded(child: _buildTechniciansList(technicianProvider)),
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
              offset: const Offset(0, 2))
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
        Text('$value',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTechniciansList(TechnicianProvider provider) {
    if (provider.isLoading) {
      return const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3))));
    }
    if (provider.errorMessage.isNotEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text('Error: ${provider.errorMessage}',
              style: TextStyle(fontSize: 16, color: Colors.red[600]),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: () => provider.refresh(),
              child: const Text('Reintentar')),
        ]),
      );
    }
    final technicians = provider.searchQuery.isEmpty
        ? provider.technicians
        : provider.filteredTechnicians;
    if (technicians.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.engineering, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            provider.searchQuery.isEmpty
                ? 'No hay técnicos registrados'
                : 'No se encontraron técnicos',
            style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500),
          ),
          if (provider.searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddTechnicianDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar Técnico'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3)),
            ),
          ],
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: technicians.length,
        itemBuilder: (context, index) =>
            _buildTechnicianCard(technicians[index], provider),
      ),
    );
  }

  Widget _buildTechnicianCard(
      TechnicianModel technician, TechnicianProvider provider) {
    final isUploadingPhoto = provider.uploadingPhotoForId == technician.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showTechnicianDetails(technician),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: () => _uploadPhotoForTechnician(technician, provider),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: technician.isActive
                            ? const Color(0xFF2196F3)
                            : Colors.grey,
                        child: isUploadingPhoto
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white)))
                            : technician.profileImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: Image.network(
                                        technician.profileImageUrl!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Text(technician.initials,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold))),
                                  )
                                : Text(technician.initials,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                      ),
                      if (!isUploadingPhoto)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                                color: const Color(0xFF2196F3),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 1.5)),
                            child: const Icon(Icons.camera_alt,
                                size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(technician.fullName,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: technician.isActive
                                  ? Colors.green
                                  : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(technician.statusText,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.email, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(technician.email,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                                overflow: TextOverflow.ellipsis)),
                      ]),
                      if (technician.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(technician.phone,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey)),
                        ]),
                      ],
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.build, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        TechnicianEquipmentCount(
                            technicianId: technician.id,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        if (technician.hourlyRate != null) ...[
                          const Text(' • ',
                              style: TextStyle(color: Colors.grey)),
                          Text(
                              '\$${technician.hourlyRate!.toStringAsFixed(2)}/hr',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ]),
                    ],
                  ),
                ),

                // ✅ Botón alerta + menú
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 🚨 Botón de alerta rojo
                    GestureDetector(
                      onTap: () => _showSendAlertDialog(technician),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Icon(Icons.campaign,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Menú opciones
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) =>
                          _handleMenuAction(value, technician, provider),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Editar')
                            ])),
                        const PopupMenuItem(
                            value: 'upload_photo',
                            child: Row(children: [
                              Icon(Icons.photo_camera, size: 18),
                              SizedBox(width: 8),
                              Text('Cambiar Foto')
                            ])),
                        PopupMenuItem(
                            value: 'toggle_status',
                            child: Row(children: [
                              Icon(
                                  technician.isActive
                                      ? Icons.block
                                      : Icons.check_circle,
                                  size: 18),
                              const SizedBox(width: 8),
                              Text(technician.isActive
                                  ? 'Desactivar'
                                  : 'Activar'),
                            ])),
                        const PopupMenuItem(
                            value: 'assign_equipment',
                            child: Row(children: [
                              Icon(Icons.precision_manufacturing, size: 18),
                              SizedBox(width: 8),
                              Text('Asignar Equipos')
                            ])),
                        const PopupMenuItem(
                            value: 'update_rate',
                            child: Row(children: [
                              Icon(Icons.attach_money, size: 18),
                              SizedBox(width: 8),
                              Text('Actualizar Tarifa')
                            ])),
                        const PopupMenuItem(
                            value: 'view_assignments',
                            child: Row(children: [
                              Icon(Icons.list, size: 18),
                              SizedBox(width: 8),
                              Text('Ver Asignaciones')
                            ])),
                        const PopupMenuItem(
                            value: 'send_alert',
                            child: Row(children: [
                              Icon(Icons.campaign, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Enviar Alerta',
                                  style: TextStyle(color: Colors.red)),
                            ])),
                            const PopupMenuItem(
                            value: 'alert_history',
                            child: Row(children: [
                              Icon(Icons.history,
                                  size: 18, color: Colors.deepPurple),
                              SizedBox(width: 8),
                              Text('Historial de Alertas',
                                  style: TextStyle(color: Colors.deepPurple)),
                            ])),
                      ],
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

  // ✅ Dialog para componer la alerta
  void _showSendAlertDialog(TechnicianModel technician) {
    final messageController = TextEditingController();
    String selectedPriority = 'high';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.red[50], shape: BoxShape.circle),
                child: Icon(Icons.campaign, color: Colors.red[600], size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Enviar Alerta',
                          style: TextStyle(fontSize: 16)),
                      Text(technician.fullName,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.normal)),
                    ]),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Prioridad:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _priorityChip(
                      'normal',
                      'Normal',
                      Colors.blue,
                      selectedPriority,
                      setStateDialog,
                      (v) => selectedPriority = v),
                  const SizedBox(width: 8),
                  _priorityChip('high', 'Alta', Colors.orange, selectedPriority,
                      setStateDialog, (v) => selectedPriority = v),
                  const SizedBox(width: 8),
                  _priorityChip(
                      'critical',
                      'Crítica',
                      Colors.red,
                      selectedPriority,
                      setStateDialog,
                      (v) => selectedPriority = v),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 4,
                maxLength: 300,
                decoration: InputDecoration(
                  hintText: 'Escribe el mensaje de alerta...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: () async {
                final message = messageController.text.trim();
                if (message.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Escribe un mensaje antes de enviar'),
                      backgroundColor: Colors.orange));
                  return;
                }
                Navigator.of(context).pop();
                final success = await AlertService.sendAlertToTechnician(
                  technicianId: technician.id,
                  technicianName: technician.fullName,
                  message: message,
                  priority: selectedPriority,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success
                        ? '🚨 Alerta enviada a ${technician.fullName}'
                        : '❌ Error al enviar la alerta'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ));
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('Enviar Alerta'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityChip(String value, String label, Color color, String selected,
      StateSetter setStateDialog, Function(String) onSelect) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => setStateDialog(() => onSelect(value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : color)),
      ),
    );
  }

  Future<void> _uploadPhotoForTechnician(
      TechnicianModel technician, TechnicianProvider provider) async {
    final success = await provider.uploadTechnicianPhoto(technician.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? '✅ Foto actualizada para ${technician.fullName}'
            : '❌ No se pudo actualizar la foto'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  void _handleMenuAction(
      String action, TechnicianModel technician, TechnicianProvider provider) {
    switch (action) {
      case 'edit':
        _editTechnician(technician, provider);
        break;
      case 'upload_photo':
        _uploadPhotoForTechnician(technician, provider);
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
      case 'send_alert':
        _showSendAlertDialog(technician);
        break;
        case 'alert_history':
        _showAlertHistory(technician);
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
                if (technician.profileImageUrl != null)
                  Center(
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: CircleAvatar(
                              radius: 48,
                              backgroundImage:
                                  NetworkImage(technician.profileImageUrl!),
                              onBackgroundImageError: (_, __) {}))),
                _buildDetailRow('Email:', technician.email),
                _buildDetailRow('Teléfono:', technician.phone),
                _buildDetailRow('Estado:', technician.statusText),
                _buildDetailRowWithWidget(
                    'Equipos Asignados:',
                    TechnicianEquipmentCount(
                        technicianId: technician.id,
                        style: const TextStyle(fontSize: 14))),
                if (technician.hourlyRate != null)
                  _buildDetailRow('Tarifa/Hora:',
                      '\$${technician.hourlyRate!.toStringAsFixed(2)}'),
                if (technician.specialization != null)
                  _buildDetailRow(
                      'Especialización:', technician.specialization!),
                _buildDetailRow('Registrado:', technician.formattedCreatedDate),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showSendAlertDialog(technician);
            },
            icon: const Icon(Icons.campaign, size: 16),
            label: const Text('Enviar Alerta'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(value)),
      ]),
    );
  }

  Widget _buildDetailRowWithWidget(String label, Widget valueWidget) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: valueWidget),
      ]),
    );
  }

  void _showAddTechnicianDialog() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Redirigir a pantalla de registro de técnico'),
        backgroundColor: Colors.blue));
  }

  void _editTechnician(
      TechnicianModel technician, TechnicianProvider provider) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Editar técnico: ${technician.fullName}'),
        backgroundColor: Colors.blue));
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
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await provider.toggleTechnicianStatus(
                  technician.id, !technician.isActive);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Técnico ${!technician.isActive ? 'activado' : 'desactivado'} correctamente'),
                  backgroundColor: Colors.green,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    technician.isActive ? Colors.red : Colors.green),
            child: Text(technician.isActive ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
  }

  void _assignEquipment(
      TechnicianModel technician, TechnicianProvider provider) async {
    final userModel = UserManagementModel(
      id: technician.id,
      name: technician.fullName,
      email: technician.email,
      phone: technician.phone,
      role: 'technician',
      isActive: technician.isActive,
      createdAt: technician.createdAt ?? DateTime.now(),
      hourlyRate: technician.hourlyRate,
      photoUrl: technician.profileImageUrl,
    );
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                AssignEquipmentScreen(technician: userModel)));
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
                border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final rate = double.tryParse(rateController.text.trim());
              if (rate != null && rate > 0) {
                Navigator.of(context).pop();
                final success =
                    await provider.updateTechnicianRate(technician.id, rate);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Tarifa actualizada correctamente'),
                      backgroundColor: Colors.green));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Por favor ingresa una tarifa válida'),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _viewAssignments(TechnicianModel technician) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ver asignaciones de: ${technician.fullName}'),
        backgroundColor: Colors.purple));
  }
}
