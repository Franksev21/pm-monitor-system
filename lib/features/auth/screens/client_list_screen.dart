import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/client_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/client_model.dart';
import '../../../config/theme/app_theme.dart';
import 'add_client_screen.dart';
import 'client_detail_screen.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Cargar clientes al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientProvider>().loadClients();
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
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'create_mock') {
                _createMockClients();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'create_mock',
                child: Row(
                  children: [
                    Icon(Icons.add_box),
                    SizedBox(width: 8),
                    Text('Crear datos de prueba'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          _buildStatsRow(),
          Expanded(
            child: Consumer<ClientProvider>(
              builder: (context, clientProvider, child) {
                if (clientProvider.isLoading &&
                    clientProvider.clients.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (clientProvider.clients.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildClientList(clientProvider.clients);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddClientScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        children: [
          // Barra de búsqueda
          TextFormField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar clientes...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        context.read<ClientProvider>().setSearchQuery('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              context.read<ClientProvider>().setSearchQuery(value);
            },
          ),

          const SizedBox(height: 12),

          // Filtros - VERSIÓN CORREGIDA
          Column(
            children: [
              Consumer<ClientProvider>(
                builder: (context, clientProvider, child) {
                  return DropdownButtonFormField<ClientStatus?>(
                    value: clientProvider.statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por Estado',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<ClientStatus?>(
                        value: null,
                        child: Text('Todos los estados'),
                      ),
                      ...ClientStatus.values.map((status) {
                        return DropdownMenuItem<ClientStatus?>(
                          value: status,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getStatusColor(status),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(status.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (status) {
                      clientProvider.setStatusFilter(status);
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Consumer<ClientProvider>(
                builder: (context, clientProvider, child) {
                  return DropdownButtonFormField<ClientType?>(
                    value: clientProvider.typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por Tipo',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<ClientType?>(
                        value: null,
                        child: Text('Todos los tipos'),
                      ),
                      ...ClientType.values.map((type) {
                        return DropdownMenuItem<ClientType?>(
                          value: type,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getTypeIcon(type),
                                  size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Text(type.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (type) {
                      clientProvider.setTypeFilter(type);
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Consumer<ClientProvider>(
      builder: (context, clientProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              _buildStatChip(
                  'Total', clientProvider.totalClients, AppTheme.primaryColor),
              const SizedBox(width: 8),
              _buildStatChip('Activos', clientProvider.activeClients,
                  AppTheme.successColor),
              const SizedBox(width: 8),
              _buildStatChip(
                  'Prospectos', clientProvider.prospectClients, Colors.blue),
              const Spacer(),
              Text(
                '${clientProvider.clients.length} resultados',
                style: AppTheme.bodySmall.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: AppTheme.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientList(List<ClientModel> clients) {
    return ListView.builder(
      itemCount: clients.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final client = clients[index];
        return _buildClientCard(client);
      },
    );
  }

  Widget _buildClientCard(ClientModel client) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showClientDetails(client),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar con inicial
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      client.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Información principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: AppTheme.headingSmall,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(_getTypeIcon(client.type),
                                size: 16, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              client.type.displayName,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: client.statusColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              client.status.displayName,
                              style: AppTheme.bodySmall.copyWith(
                                color: client.statusColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Botón de opciones
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleClientAction(value, client),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility),
                            SizedBox(width: 8),
                            Text('Ver detalles'),
                          ],
                        ),
                      ),
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
                            Text('Eliminar',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Información de contacto
              Row(
                children: [
                  Icon(Icons.email, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      client.email,
                      style: AppTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    client.phone,
                    style: AppTheme.bodyMedium,
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${client.mainAddress.city}, ${client.mainAddress.state}',
                      style: AppTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Información adicional
              if (client.totalBranches > 0 || client.totalContacts > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (client.totalBranches > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${client.totalBranches} sucursales',
                          style:
                              AppTheme.bodySmall.copyWith(color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (client.totalContacts > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${client.totalContacts} contactos',
                          style:
                              AppTheme.bodySmall.copyWith(color: Colors.green),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay clientes registrados',
              style: AppTheme.headingMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega tu primer cliente para comenzar',
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddClientScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Agregar Cliente'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _createMockClients(),
              icon: const Icon(Icons.data_usage),
              label: const Text('Crear datos de prueba'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClientDetails(ClientModel client) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClientDetailScreen(client: client),
      ),
    );
  }

  void _handleClientAction(String action, ClientModel client) {
    switch (action) {
      case 'view':
        _showClientDetails(client);
        break;
      case 'edit':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddClientScreen(client: client),
          ),
        );
        break;
      case 'delete':
        _showDeleteDialog(client);
        break;
    }
  }

  void _showDeleteDialog(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content:
            Text('¿Estás seguro de que quieres eliminar a ${client.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success =
                  await context.read<ClientProvider>().deleteClient(client.id);
              if (success && context.mounted) {
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

  Future<void> _createMockClients() async {
    final authProvider = context.read<AuthProvider>();
    final clientProvider = context.read<ClientProvider>();

    final success =
        await clientProvider.createMockClients(authProvider.currentUser!.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clientes de prueba creados exitosamente'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
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

  Color _getStatusColor(ClientStatus status) {
    switch (status) {
      case ClientStatus.active:
        return AppTheme.successColor;
      case ClientStatus.inactive:
        return Colors.grey;
      case ClientStatus.prospect:
        return AppTheme.primaryColor;
      case ClientStatus.suspended:
        return AppTheme.errorColor;
    }
  }
}
