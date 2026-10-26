import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/client_model.dart';
import 'package:pm_monitor/core/models/user_management_model.dart';
import 'package:pm_monitor/core/services/user_management_service.dart';
import 'package:pm_monitor/features/auth/screens/admin_add_user_screen.dart';
import 'package:pm_monitor/features/equipment/assign_equipment_screen.dart';
import 'package:pm_monitor/features/auth/widgets/technician_equipment_count.dart';
import 'package:pm_monitor/features/client/screens/add_client_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserManagementService _userService = UserManagementService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final Map<String, Map<String, int>> _statsCache = {};
  final Map<String, Stream<List<UserManagementModel>>> _userStreams = {};
  final Map<String, List<UserManagementModel>> _usersCache = {};
  List<ClientModel>? _clientsCache;
  late final Stream<List<ClientModel>> _clientsStream;

  final List<Map<String, dynamic>> _tabs = [
    {
      'role': 'technician',
      'title': 'Técnicos',
      'icon': Icons.engineering,
      'color': Colors.orange,
    },
    {
      'role': 'supervisor',
      'title': 'Supervisores',
      'icon': Icons.supervisor_account,
      'color': Colors.blue,
    },
    {
      'role': 'client',
      'title': 'Clientes',
      'icon': Icons.business,
      'color': Colors.purple,
    },
    {
      'role': 'admin',
      'title': 'Administradores',
      'icon': Icons.admin_panel_settings,
      'color': Colors.red,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _clientsStream = _userService.getClients();
    for (final tab in _tabs.where((item) => item['role'] != 'client')) {
      final role = tab['role'] as String;
      _userStreams[role] = _userService.getUsersByRole(role);
    }
    _loadAllStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllStats() async {
    final entries = await Future.wait(_tabs.map((tab) async {
      final role = tab['role'] as String;
      try {
        return MapEntry(role, await _userService.getStatsByRole(role));
      } catch (e) {
        debugPrint('Error loading stats for $role: $e');
        return null;
      }
    }));
    if (!mounted) return;
    setState(() {
      for (final entry
          in entries.whereType<MapEntry<String, Map<String, int>>>()) {
        _statsCache[entry.key] = entry.value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Gestión de Usuarios',
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllStats,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs
              .map((tab) => Tab(
                    icon: Icon(tab['icon']),
                    text: tab['title'],
                  ))
              .toList(),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) => _buildUserTab(tab)).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUserDialog(),
        backgroundColor: const Color(0xFF2196F3),
        child: const Icon(Icons.add),
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
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Buscar usuarios...',
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
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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

  Widget _buildUserTab(Map<String, dynamic> tabData) {
    final role = tabData['role'] as String;
    final color = tabData['color'] as Color;

    return Column(
      children: [
        if (_statsCache.containsKey(role))
          _buildStatsRow(_statsCache[role]!, color),
        Expanded(
          child: role == 'client'
              ? _buildClientsTab()
              : StreamBuilder<List<UserManagementModel>>(
                  stream: _userStreams[role],
                  initialData: _usersCache[role],
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildErrorWidget(snapshot.error.toString());
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final users = snapshot.data ?? _usersCache[role] ?? [];
                    if (snapshot.hasData) _usersCache[role] = users;
                    final filteredUsers = _searchQuery.isEmpty
                        ? users
                        : users
                            .where((user) =>
                                user.name
                                    .toLowerCase()
                                    .contains(_searchQuery) ||
                                user.email.toLowerCase().contains(_searchQuery))
                            .toList();

                    if (filteredUsers.isEmpty) {
                      return _buildEmptyWidget(role, tabData['title']);
                    }

                    return RefreshIndicator(
                      onRefresh: _loadAllStats,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          return _buildUserCard(filteredUsers[index]);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(Map<String, int> stats, Color color) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
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
          _buildStatItem('Total', stats['total'] ?? 0, color),
          _buildStatItem('Activos', stats['active'] ?? 0, Colors.green),
          _buildStatItem(
              'Con Asign.', stats['withAssignments'] ?? 0, Colors.orange),
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
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // ✅ FIX: Corregidos RIGHT overflow y HT overflow en _buildUserCard
  Widget _buildUserCard(UserManagementModel user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showUserDetails(user),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 25,
                  backgroundColor: user.isActive ? user.roleColor : Colors.grey,
                  child: user.photoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: Image.network(
                            user.photoUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                user.initials,
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
                          user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const SizedBox(width: 12),

                // ✅ FIX: Expanded previene RIGHT overflow
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ FIX: nombre con Expanded + badge con Flexible
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // ✅ FIX: Flexible en el badge evita que empuje al texto
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    user.isActive ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                user.statusText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // ✅ FIX: email con ellipsis
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // ✅ FIX: Expanded en la fila de asignaciones
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: user.roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user.roleInSpanish,
                              style: TextStyle(
                                fontSize: 11,
                                color: user.roleColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: user.role == 'technician'
                                ? TechnicianEquipmentCount(
                                    technicianId: user.id,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  )
                                : user.assignmentsText.isNotEmpty
                                    ? Text(
                                        user.assignmentsText,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Menú de opciones
                PopupMenuButton<String>(
                  onSelected: (value) => _handleUserAction(value, user),
                  itemBuilder: (context) => _buildUserMenuItems(user),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildUserMenuItems(UserManagementModel user) {
    final baseItems = <PopupMenuEntry<String>>[
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
              user.isActive ? Icons.block : Icons.check_circle,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(user.isActive ? 'Desactivar' : 'Activar'),
          ],
        ),
      ),
    ];

    if (user.role == 'technician') {
      baseItems.addAll([
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
          value: 'assign_supervisor',
          child: Row(
            children: [
              Icon(Icons.supervisor_account, size: 18),
              SizedBox(width: 8),
              Text('Asignar Supervisor'),
            ],
          ),
        ),
      ]);
    } else if (user.role == 'supervisor') {
      baseItems.addAll([
        const PopupMenuItem(
          value: 'assign_technicians',
          child: Row(
            children: [
              Icon(Icons.group, size: 18),
              SizedBox(width: 8),
              Text('Asignar Técnicos'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'view_details',
          child: Row(
            children: [
              Icon(Icons.visibility, size: 18),
              SizedBox(width: 8),
              Text('Ver Detalles'),
            ],
          ),
        ),
      ]);
    } else if (user.role == 'client') {
      baseItems.add(
        const PopupMenuItem(
          value: 'assign_locations',
          child: Row(
            children: [
              Icon(Icons.location_on, size: 18),
              SizedBox(width: 8),
              Text('Asignar Ubicaciones'),
            ],
          ),
        ),
      );
    }

    if (user.role == 'technician' || user.role == 'supervisor') {
      baseItems.add(
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
      );
    }

    return baseItems;
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Error: $error',
            style: TextStyle(fontSize: 16, color: Colors.red[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAllStats,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String role, String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getIconForRole(role),
              size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'No hay ${title.toLowerCase()} registrados',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddUserDialog(role: role),
            icon: const Icon(Icons.add),
            label: Text('Agregar ${_getRoleInSpanish(role)}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForRole(String role) {
    switch (role) {
      case 'technician':
        return Icons.engineering;
      case 'supervisor':
        return Icons.supervisor_account;
      case 'client':
        return Icons.business;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  String _getRoleInSpanish(String role) {
    switch (role) {
      case 'technician':
        return 'Técnico';
      case 'supervisor':
        return 'Supervisor';
      case 'client':
        return 'Cliente';
      case 'admin':
        return 'Administrador';
      default:
        return 'Usuario';
    }
  }

  void _showUserDetails(UserManagementModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email:', user.email),
              _buildDetailRow('Teléfono:', user.phone),
              _buildDetailRow('Rol:', user.roleInSpanish),
              _buildDetailRow('Estado:', user.statusText),
              if (user.role == 'technician')
                _buildDetailRowWithWidget(
                  'Asignaciones:',
                  TechnicianEquipmentCount(
                    technicianId: user.id,
                    style: const TextStyle(fontSize: 14),
                  ),
                )
              else if (user.assignmentsText.isNotEmpty)
                _buildDetailRow('Asignaciones:', user.assignmentsText),
              if (user.hourlyRate != null)
                _buildDetailRow(
                  'Tarifa/Hora:',
                  '\$${user.hourlyRate!.toStringAsFixed(2)}',
                ),
              _buildDetailRow('Registrado:', user.formattedCreatedDate),
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

  Widget _buildClientsTab() {
    return StreamBuilder<List<ClientModel>>(
      stream: _clientsStream,
      initialData: _clientsCache,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final clients = snapshot.data ?? _clientsCache ?? [];
        if (snapshot.hasData) _clientsCache = clients;
        final filteredClients = _searchQuery.isEmpty
            ? clients
            : clients
                .where((client) =>
                    client.name.toLowerCase().contains(_searchQuery) ||
                    client.email.toLowerCase().contains(_searchQuery))
                .toList();

        if (filteredClients.isEmpty) {
          return _buildEmptyWidget('client', 'Clientes');
        }

        return RefreshIndicator(
          onRefresh: _loadAllStats,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredClients.length,
            itemBuilder: (context, index) {
              return _buildClientCard(filteredClients[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildClientCard(ClientModel client) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showClientDetails(client),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: client.statusColor,
                  child: Text(
                    client.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              client.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: client.statusColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                client.status.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        client.email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              client.type.displayName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.purple,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (client.totalBranches > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '🏢 ${client.totalBranches} sucursal(es)',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Acciones de ${client.name}',
                  onSelected: (action) {
                    if (action == 'edit') _editClient(client);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Editar compañía'),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }

  void _showAddUserDialog({String? role}) async {
    final selectedRole = role ?? _tabs[_tabController.index]['role'] as String;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAddUserScreen(preSelectedRole: selectedRole),
      ),
    );

    if (result == true) {
      _loadAllStats();
    }
  }

  void _showClientDetails(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(client.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email:', client.email),
              _buildDetailRow('Teléfono:', client.phone),
              _buildDetailRow('Tipo:', client.type.displayName),
              _buildDetailRow('Estado:', client.status.displayName),
              _buildDetailRow('RNC:', client.taxId),
              _buildDetailRow('Dirección:', client.fullAddress),
              if (client.website != null)
                _buildDetailRow('Website:', client.website!),
              _buildDetailRow('Sucursales:', '${client.totalBranches}'),
              _buildDetailRow('Contactos:', '${client.totalContacts}'),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.edit),
            label: const Text('Editar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    ).then((shouldEdit) {
      if (shouldEdit == true && mounted) _editClient(client);
    });
  }

  Future<void> _editClient(ClientModel client) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddClientScreen(client: client)),
    );
    if (updated == true) _loadAllStats();
  }

  void _handleUserAction(String action, UserManagementModel user) {
    switch (action) {
      case 'edit':
        _editUser(user);
        break;
      case 'toggle_status':
        _toggleUserStatus(user);
        break;
      case 'assign_equipment':
        _assignEquipment(user);
        break;
      case 'assign_supervisor':
        _assignSupervisor(user);
        break;
      case 'assign_locations':
        _assignLocations(user);
        break;
      case 'update_rate':
        _updateRate(user);
        break;
    }
  }

  void _editUser(UserManagementModel user) {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    var selectedRole = user.role;
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Editar ${user.roleInSpanish}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'El nombre es requerido'
                        : null,
                  ),
                  TextFormField(
                    initialValue: user.email,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      helperText:
                          'El correo de acceso no se puede cambiar aquí.',
                    ),
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: const [
                      DropdownMenuItem(
                          value: 'technician', child: Text('Técnico')),
                      DropdownMenuItem(
                          value: 'supervisor', child: Text('Supervisor')),
                      DropdownMenuItem(
                          value: 'admin', child: Text('Administrador')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _userService.updateUserProfile(
                    user.id,
                    name: nameController.text,
                    phone: phoneController.text,
                    role: selectedRole,
                  );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text('Usuario actualizado correctamente')),
                    );
                    _loadAllStats();
                  }
                } catch (error) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('No se pudo actualizar: $error')),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
    });
  }

  void _toggleUserStatus(UserManagementModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user.isActive ? 'Desactivar' : 'Activar'} Usuario'),
        content: Text(
            '¿Estás seguro de que deseas ${user.isActive ? 'desactivar' : 'activar'} a ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _userService.toggleUserStatus(user.id, !user.isActive);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Usuario ${!user.isActive ? 'activado' : 'desactivado'} correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                _loadAllStats();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isActive ? Colors.red : Colors.green,
            ),
            child: Text(user.isActive ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
  }

  void _assignEquipment(UserManagementModel user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignEquipmentScreen(technician: user),
      ),
    );
    if (result == true) _loadAllStats();
  }

  void _assignSupervisor(UserManagementModel user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Asignar supervisor a ${user.name} - Por implementar'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _assignLocations(UserManagementModel user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Asignar ubicaciones a ${user.name} - Por implementar'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _updateRate(UserManagementModel user) {
    final rateController =
        TextEditingController(text: user.hourlyRate?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Actualizar Tarifa - ${user.name}'),
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
                  try {
                    await _userService.updateHourlyRate(user.id, rate);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tarifa actualizada correctamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    _loadAllStats();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red),
                      );
                    }
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
}
