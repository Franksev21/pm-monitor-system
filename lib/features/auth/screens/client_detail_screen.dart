import 'package:flutter/material.dart';
import 'package:pm_monitor/features/auth/widgets/apple_style_calender.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/client_provider.dart';
import '../../../core/providers/equipment_provider.dart'; // ✅ Agregado
import '../../../core/models/client_model.dart';
import '../../../config/theme/app_theme.dart';
import 'add_client_screen.dart';
import 'add_equipment_screen.dart';
import 'equipment_list_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  // ✅ Cambiado a StatefulWidget
  final ClientModel client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ Cargar equipos del cliente al inicializar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final equipmentProvider =
          Provider.of<EquipmentProvider>(context, listen: false);
      equipmentProvider.loadEquipmentsByClient(widget.client.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddClientScreen(client: widget.client),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildBasicInfo(),
            _buildAddressInfo(),
            if (widget.client.branches.isNotEmpty) _buildBranchesInfo(),
            if (widget.client.contacts.isNotEmpty) _buildContactsInfo(),
            if (widget.client.notes.isNotEmpty) _buildNotesInfo(),
            _buildActions(context),
            const SizedBox(height: 100), // Espacio para FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // ✅ Navegar y esperar resultado
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEquipmentScreen(
                client: widget.client,
              ),
            ),
          );

          // ✅ Si se agregó un equipo, recargar la lista
          if (result == true && mounted) {
            final equipmentProvider =
                Provider.of<EquipmentProvider>(context, listen: false);
            equipmentProvider.loadEquipmentsByClient(widget.client.id);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Agregar Equipo'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar grande
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Text(
                widget.client.name[0].toUpperCase(),
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Nombre del cliente
            Text(
              widget.client.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Tipo y estado
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTypeIcon(widget.client.type),
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.client.type.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.client.statusColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.client.status.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ✅ Estadísticas rápidas con contador de equipos en tiempo real
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                    'Sucursales', widget.client.totalBranches.toString()),
                _buildStatItem(
                    'Contactos', widget.client.totalContacts.toString()),
                // ✅ Consumer para equipos en tiempo real
                Consumer<EquipmentProvider>(
                  builder: (context, equipmentProvider, child) {
                    int equipmentCount =
                        equipmentProvider.clientEquipments.length;
                    return GestureDetector(
                      onTap: equipmentCount > 0
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ClientEquipmentListScreen(
                                    client: widget.client,
                                  ),
                                ),
                              );
                            }
                          : () {
                              // Si no hay equipos, ir directo a agregar
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddEquipmentScreen(
                                    client: widget.client,
                                  ),
                                ),
                              ).then((result) {
                                if (result == true) {
                                  // Recargar equipos cuando regrese
                                  equipmentProvider
                                      .loadEquipmentsByClient(widget.client.id);
                                }
                              });
                            },
                      child: Column(
                        children: [
                          Text(
                            '$equipmentCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Equipos',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Método simplificado sin bordes ni subrayado
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfo() {
    return _buildSection(
      title: 'Información Básica',
      icon: Icons.business,
      child: Column(
        children: [
          _buildInfoRow(Icons.email, 'Email', widget.client.email),
          _buildInfoRow(Icons.phone, 'Teléfono', widget.client.phone),
          if (widget.client.website != null)
            _buildInfoRow(Icons.language, 'Sitio Web', widget.client.website!),
          _buildInfoRow(Icons.badge, 'RNC/Cédula', widget.client.taxId),
          _buildInfoRow(Icons.calendar_today, 'Cliente desde',
              _formatDate(widget.client.createdAt)),
        ],
      ),
    );
  }

  Widget _buildAddressInfo() {
    return _buildSection(
      title: 'Dirección Principal',
      icon: Icons.location_on,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.client.mainAddress.fullAddress,
              style: AppTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Abrir en mapas
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Próximamente: Abrir en mapas'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Ver en Mapa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Obtener direcciones
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Próximamente: Cómo llegar'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Cómo llegar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchesInfo() {
    return _buildSection(
      title: 'Sucursales (${widget.client.branches.length})',
      icon: Icons.apartment,
      child: Column(
        children: widget.client.branches
            .map((branch) => _buildBranchCard(branch))
            .toList(),
      ),
    );
  }

  Widget _buildBranchCard(BranchModel branch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.store,
                  color: branch.isActive ? AppTheme.primaryColor : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    branch.name,
                    style: AppTheme.headingSmall.copyWith(
                      color: branch.isActive ? null : Colors.grey,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: branch.isActive
                        ? AppTheme.successColor.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    branch.isActive ? 'Activa' : 'Inactiva',
                    style: AppTheme.bodySmall.copyWith(
                      color:
                          branch.isActive ? AppTheme.successColor : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    branch.address.fullAddress,
                    style: AppTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (branch.managerName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Gerente: ${branch.managerName}',
                    style: AppTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            if (branch.managerPhone != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    branch.managerPhone!,
                    style: AppTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactsInfo() {
    return _buildSection(
      title: 'Contactos (${widget.client.contacts.length})',
      icon: Icons.contacts,
      child: Column(
        children: widget.client.contacts
            .map((contact) => _buildContactCard(contact))
            .toList(),
      ),
    );
  }

  Widget _buildContactCard(ContactModel contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  contact.isPrimary ? AppTheme.primaryColor : Colors.grey[400],
              child: Text(
                contact.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.name,
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (contact.isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Principal',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    contact.position,
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          contact.email,
                          style: AppTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        contact.phone,
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () {
                    // TODO: Llamar
                  },
                  color: AppTheme.primaryColor,
                ),
                IconButton(
                  icon: const Icon(Icons.email),
                  onPressed: () {
                    // TODO: Enviar email
                  },
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesInfo() {
    return _buildSection(
      title: 'Notas',
      icon: Icons.note,
      child: Text(
        widget.client.notes,
        style: AppTheme.bodyLarge,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AppleStyleMaintenanceCalendar(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.build),
                  label: const Text('Mantenimiento'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Ver reportes
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Próximamente: Ver reportes'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('Reportes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(ClientType type) {
    switch (type) {
      case ClientType.small:
        return Icons.store;
      case ClientType.medium:
        return Icons.business;
      case ClientType.large:
        return Icons.apartment;
      case ClientType.enterprise:
        return Icons.domain;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddClientScreen(client: widget.client),
          ),
        );
        break;
      case 'delete':
        _showDeleteDialog(context);
        break;
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text(
            '¿Estás seguro de que quieres eliminar a ${widget.client.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await context
                  .read<ClientProvider>()
                  .deleteClient(widget.client.id);
              if (success && context.mounted) {
                Navigator.of(context).pop(); // Volver a la lista
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cliente eliminado exitosamente'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
