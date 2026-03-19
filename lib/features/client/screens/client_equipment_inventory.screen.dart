import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/features/equipment/equipment_detail_screen.dart';
import 'package:pm_monitor/features/others/screens/qr_scanner_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ClientEquipmentInventoryScreen extends StatefulWidget {
  const ClientEquipmentInventoryScreen({super.key});

  @override
  State<ClientEquipmentInventoryScreen> createState() =>
      _ClientEquipmentInventoryScreenState();
}

class _ClientEquipmentInventoryScreenState
    extends State<ClientEquipmentInventoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedBranch = 'Todos';
  String _selectedCategory = 'Todos';
  String _selectedDepartment = 'Todos';

  List<String> _branches = ['Todos'];
  List<String> _categories = ['Todos'];
  List<String> _departments = ['Todos'];

  String _clientName = '';
  bool _filtersExpanded = true;
  bool _loadingFilters = true;

  static const Map<String, IconData> _categoryIcons = {
    'Aire Acondicionado': Icons.ac_unit,
    'Panel Eléctrico': Icons.electrical_services,
    'Generador': Icons.power,
    'UPS': Icons.battery_charging_full,
    'Facilidades': Icons.build,
    'Ascensor': Icons.elevator,
    'Cámara': Icons.videocam,
    'Iluminación': Icons.lightbulb,
    'Ventilación': Icons.air,
    'Otros': Icons.settings,
  };

  @override
  void initState() {
    super.initState();
    _loadClientAndFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClientAndFilters() async {
    setState(() => _loadingFilters = true);

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      setState(() => _loadingFilters = false);
      return;
    }

    try {
      // 1. Obtener nombre del cliente desde users collection
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final userData = userDoc.data();
      final clientName = (userData?['name'] ?? '').toString().trim();

      if (clientName.isEmpty) {
        setState(() => _loadingFilters = false);
        return;
      }

      setState(() => _clientName = clientName);

      // 2. Obtener todos los equipos y filtrar por cliente
      final snapshot = await _firestore.collection('equipments').get();

      final clientDocs = snapshot.docs.where((doc) {
        final d = doc.data();
        final branch = (d['branch'] ?? '').toString().trim();
        final cName = (d['clientName'] ?? '').toString().trim();
        return branch.toLowerCase() == clientName.toLowerCase() ||
            cName.toLowerCase() == clientName.toLowerCase();
      }).toList();

      // 3. Recolectar valores únicos para cada filtro
      final branchSet = <String>{};
      final categorySet = <String>{};
      final departmentSet = <String>{};

      for (final doc in clientDocs) {
        final d = doc.data();
        final b = (d['branchName'] ?? d['branch'] ?? '').toString().trim();
        final c = (d['category'] ?? '').toString().trim();
        final dep = (d['location'] ?? '').toString().trim();

        if (b.isNotEmpty) branchSet.add(b);
        if (c.isNotEmpty) categorySet.add(c);
        if (dep.isNotEmpty) departmentSet.add(dep);
      }

      if (mounted) {
        final sortedBranches = branchSet.toList()..sort();

        // Seleccionar por defecto la sucursal principal:
        // primero busca una que contenga "principal", si no hay toma la primera
        String defaultBranch = 'Todos';
        if (sortedBranches.isNotEmpty) {
          final principal = sortedBranches.firstWhere(
            (b) => b.toLowerCase().contains('principal'),
            orElse: () => sortedBranches.first,
          );
          defaultBranch = principal;
        }

        setState(() {
          _branches = ['Todos', ...sortedBranches];
          _categories = ['Todos', ...categorySet.toList()..sort()];
          _departments = ['Todos', ...departmentSet.toList()..sort()];
          _selectedBranch = defaultBranch;
          _loadingFilters = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando filtros: $e');
      setState(() => _loadingFilters = false);
    }
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedBranch != 'Todos') count++;
    if (_selectedCategory != 'Todos') count++;
    if (_selectedDepartment != 'Todos') count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _selectedBranch = 'Todos';
      _selectedCategory = 'Todos';
      _selectedDepartment = 'Todos';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  // ─────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Mis Equipos'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_activeFilterCount > 0)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off,
                  color: Colors.white70, size: 18),
              label: Text(
                'Limpiar ($_activeFilterCount)',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear QR',
            onPressed: _scanQRCode,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersPanel(),
          Expanded(child: _buildEquipmentList()),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  PANEL DE FILTROS — 3 DROPDOWNS SIEMPRE VISIBLES
  // ─────────────────────────────────────────────────────
  Widget _buildFiltersPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header colapsable
          InkWell(
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 17, color: Color(0xFF4285F4)),
                  const SizedBox(width: 8),
                  const Text(
                    'Filtros',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                  if (_activeFilterCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4285F4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_activeFilterCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    _filtersExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          if (_filtersExpanded) ...[
            if (_loadingFilters)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF4285F4)),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. SUCURSAL ──
                    _buildDropdownField(
                      label: 'Sucursal',
                      icon: Icons.store_outlined,
                      value: _selectedBranch,
                      items: _branches,
                      activeColor: const Color(0xFF1976D2),
                      onChanged: (v) => setState(() => _selectedBranch = v!),
                    ),
                    const SizedBox(height: 10),

                    // ── 2. DEPARTAMENTO ──
                    _buildDropdownField(
                      label: 'Departamento',
                      icon: Icons.meeting_room_outlined,
                      value: _selectedDepartment,
                      items: _departments,
                      activeColor: Colors.teal,
                      onChanged: (v) =>
                          setState(() => _selectedDepartment = v!),
                    ),
                    const SizedBox(height: 10),

                    // ── 3. TIPO DE EQUIPO ──
                    _buildDropdownField(
                      label: 'Tipo de Equipo',
                      icon: Icons.category_outlined,
                      value: _selectedCategory,
                      items: _categories,
                      activeColor: Colors.purple,
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                    const SizedBox(height: 10),

                    // ── 4. BUSCADOR ──
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o número...',
                        hintStyle:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.grey, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.grey, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF4285F4), width: 1.5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required Color activeColor,
    required ValueChanged<String?> onChanged,
  }) {
    final isActive = value != 'Todos';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Icon(icon, size: 13, color: Colors.grey[600]),
            const SizedBox(width: 5),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Dropdown container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withOpacity(0.06)
                : const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? activeColor.withOpacity(0.5)
                  : Colors.grey.shade300,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : 'Todos',
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: isActive ? activeColor : Colors.grey,
              ),
              style: TextStyle(
                fontSize: 14,
                color: isActive ? activeColor : Colors.black87,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              items: items.map((item) {
                final isSelected = item == value;
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      if (item != 'Todos') ...[
                        Icon(
                          icon,
                          size: 15,
                          color: isSelected ? activeColor : Colors.grey[400],
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 14,
                            color: item == 'Todos'
                                ? Colors.grey[600]
                                : (isSelected ? activeColor : Colors.black87),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  //  LISTA DE EQUIPOS
  // ─────────────────────────────────────────────────────
  Widget _buildEquipmentList() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Center(child: Text('Usuario no autenticado'));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(currentUserId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (userSnapshot.hasError || !userSnapshot.hasData) {
          return const Center(child: Text('Error cargando datos del cliente'));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final clientName = (userData?['name'] ?? '').toString().trim();
        if (clientName.isEmpty) {
          return const Center(
              child: Text('Tu perfil no tiene un nombre asignado'));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('equipments').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Error al cargar equipos'),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center),
                  ],
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Filtrar por cliente
            var equipments = snapshot.data?.docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final branch = (d['branch'] ?? '').toString().trim();
                  final cName = (d['clientName'] ?? '').toString().trim();
                  return branch.toLowerCase() == clientName.toLowerCase() ||
                      cName.toLowerCase() == clientName.toLowerCase();
                }).toList() ??
                [];

            // Aplicar filtros
            equipments = equipments.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final name = (d['name'] ?? '').toString().toLowerCase();
              final number =
                  (d['equipmentNumber'] ?? '').toString().toLowerCase();
              final branch =
                  (d['branchName'] ?? d['branch'] ?? '').toString().trim();
              final category = (d['category'] ?? '').toString().trim();
              final department = (d['location'] ?? '').toString().trim();

              if (_searchQuery.isNotEmpty) {
                if (!name.contains(_searchQuery) &&
                    !number.contains(_searchQuery)) {
                  return false;
                }
              }
              if (_selectedBranch != 'Todos' && branch != _selectedBranch)
                return false;
              if (_selectedCategory != 'Todos' && category != _selectedCategory)
                return false;
              if (_selectedDepartment != 'Todos' &&
                  department != _selectedDepartment) return false;

              return true;
            }).toList();

            if (equipments.isEmpty) return _buildEmptyState();

            return RefreshIndicator(
              onRefresh: () async {
                await _loadClientAndFilters();
                setState(() {});
              },
              color: const Color(0xFF4285F4),
              child: Column(
                children: [
                  // Contador
                  Container(
                    color: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          '${equipments.length} equipo${equipments.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500),
                        ),
                        if (_activeFilterCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4285F4).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_activeFilterCount filtro${_activeFilterCount != 1 ? 's' : ''} activo${_activeFilterCount != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4285F4),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: equipments.length,
                      itemBuilder: (context, index) {
                        final doc = equipments[index];
                        final d = doc.data() as Map<String, dynamic>;
                        return _buildEquipmentCard(
                          equipmentId: doc.id,
                          data: d,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────
  //  TARJETA DE EQUIPO
  // ─────────────────────────────────────────────────────
  Widget _buildEquipmentCard({
    required String equipmentId,
    required Map<String, dynamic> data,
  }) {
    final equipmentNumber = (data['equipmentNumber'] ?? 'N/A').toString();
    final name = (data['name'] ?? 'Sin nombre').toString();
    final brand = (data['brand'] ?? '').toString();
    final model = (data['model'] ?? '').toString();
    final department = (data['location'] ?? '').toString();
    final branch = (data['branchName'] ?? data['branch'] ?? '').toString();
    final status = (data['status'] ?? 'Desconocido').toString();
    final condition = (data['condition'] ?? 'N/A').toString();
    final category = (data['category'] ?? '').toString();

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Operativo':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'En mantenimiento':
      case 'Mantenimiento':
        statusColor = Colors.orange;
        statusIcon = Icons.build_circle;
        break;
      case 'Fuera de servicio':
      case 'Inactivo':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    Color conditionColor;
    switch (condition.toLowerCase()) {
      case 'excelente':
        conditionColor = Colors.green;
        break;
      case 'bueno':
        conditionColor = Colors.blue;
        break;
      case 'regular':
        conditionColor = Colors.orange;
        break;
      case 'crítico':
        conditionColor = Colors.deepOrange;
        break;
      case 'malo':
        conditionColor = Colors.red;
        break;
      default:
        conditionColor = Colors.grey;
    }

    IconData categoryIcon = Icons.settings;
    for (final entry in _categoryIcons.entries) {
      if (category.toLowerCase().contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(category.toLowerCase())) {
        categoryIcon = entry.value;
        break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToEquipmentDetail(equipmentId),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(categoryIcon,
                        color: const Color(0xFF4285F4), size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(equipmentNumber,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (brand.isNotEmpty || model.isNotEmpty)
                          Text('$brand $model'.trim(),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code,
                        color: Color(0xFF4285F4), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showQRCode(equipmentNumber, name),
                    tooltip: 'Ver QR',
                  ),
                ],
              ),

              const Divider(height: 16),

              // Sucursal
              if (branch.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.store_outlined,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 5),
                      Text(branch,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),

              // Departamento
              if (department.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade100, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.meeting_room_outlined,
                          size: 15, color: Colors.teal.shade700),
                      const SizedBox(width: 6),
                      Text('Departamento: ',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w500)),
                      Expanded(
                        child: Text(department,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.teal.shade900,
                                fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),

              // Estado + Condición
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                        icon: statusIcon, label: status, color: statusColor),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: conditionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: conditionColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_outline,
                            size: 13, color: conditionColor),
                        const SizedBox(width: 4),
                        Text(condition,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: conditionColor)),
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

  Widget _buildInfoChip(
      {required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _searchQuery.isNotEmpty || _activeFilterCount > 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasFilters ? Icons.search_off : Icons.devices_other,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No se encontraron equipos\ncon estos filtros'
                  : 'No tienes equipos registrados',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Limpiar filtros'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  QR DIALOG
  // ─────────────────────────────────────────────────────
  void _showQRCode(String equipmentNumber, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Código QR del Equipo',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 20),
              Container(
                width: 220,
                height: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF4285F4).withOpacity(0.3),
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: QrImageView(
                  data: equipmentNumber,
                  version: QrVersions.auto,
                  size: 196,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  embeddedImage: const AssetImage('assets/images/csc-logo.png'),
                  embeddedImageStyle:
                      const QrEmbeddedImageStyle(size: Size(36, 36)),
                ),
              ),
              const SizedBox(height: 16),
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF4285F4).withOpacity(0.3)),
                ),
                child: Text(equipmentNumber,
                    style: const TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToEquipmentDetail(String equipmentId) async {
    try {
      final doc =
          await _firestore.collection('equipments').doc(equipmentId).get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Equipo no encontrado'),
                backgroundColor: Colors.red),
          );
        }
        return;
      }
      final equipment = Equipment.fromFirestore(doc);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  EquipmentDetailScreen(equipment: equipment)),
        );
      }
    } catch (e) {
      debugPrint('Error navegando al detalle: $e');
    }
  }

  void _scanQRCode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
  }
}
