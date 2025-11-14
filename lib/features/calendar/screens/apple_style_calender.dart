import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_calendar_model.dart';
import 'package:pm_monitor/core/services/maintenance_schedule_service.dart';
import 'package:pm_monitor/core/services/maintenance_pdf_service.dart';
import 'package:pm_monitor/features/maintenance/screens/add_maintenance_screen.dart';
import 'package:pm_monitor/core/models/client_model.dart';
import 'package:pm_monitor/core/services/client_service.dart';

class AppleStyleMaintenanceCalendar extends StatefulWidget {
  const AppleStyleMaintenanceCalendar({Key? key}) : super(key: key);

  @override
  _AppleStyleMaintenanceCalendarState createState() =>
      _AppleStyleMaintenanceCalendarState();
}

class _AppleStyleMaintenanceCalendarState
    extends State<AppleStyleMaintenanceCalendar>
    with SingleTickerProviderStateMixin {
  final MaintenanceScheduleService _maintenanceService =
      MaintenanceScheduleService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ClientService _clientService = ClientService();

  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  PageController _pageController = PageController(initialPage: 1000);

  Map<DateTime, List<MaintenanceSchedule>> _events = {};
  List<MaintenanceSchedule> _selectedDayEvents = [];
  bool _isLoading = false;
  String? _userRole;
  bool _isLoadingRole = true;

  // FILTROS
  String? _selectedClientId;
  String? _selectedBranchId;
  String? _selectedEquipmentType;
  MaintenanceType? _selectedMaintenanceType;

  // Listas para filtros
  List<ClientModel> _clients = [];
  List<BranchModel> _branches = [];
  final List<String> _equipmentTypes = [
    'Aire Acondicionado',
    'Panel Eléctrico',
    'Generador',
    'UPS',
    'Otro'
  ];

  // BÚSQUEDA EN FILTROS
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _branchSearchController = TextEditingController();
  final TextEditingController _equipmentSearchController =
      TextEditingController();

  List<ClientModel> _filteredClients = [];
  List<BranchModel> _filteredBranches = [];
  List<String> _filteredEquipmentTypes = [];

  // CONTROL DEL PANEL DESPLEGABLE
  late AnimationController _dragController;
  late Animation<double> _dragAnimation;
  double _dragPosition = 0.6; // Posición inicial (60% de la pantalla)
  final double _minDragPosition = 0.3; // Mínimo 30%
  final double _maxDragPosition = 0.9; // Máximo 90%

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadClients();
    _loadMaintenances();

    // Inicializar listas filtradas
    _filteredClients = _clients;
    _filteredEquipmentTypes = _equipmentTypes;

    // Inicializar controlador de animación para el drag
    _dragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _dragAnimation = Tween<double>(
      begin: _dragPosition,
      end: _dragPosition,
    ).animate(CurvedAnimation(
      parent: _dragController,
      curve: Curves.easeOut,
    ));

    // Listeners para búsqueda
    _clientSearchController.addListener(_filterClients);
    _branchSearchController.addListener(_filterBranches);
    _equipmentSearchController.addListener(_filterEquipmentTypes);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _clientSearchController.dispose();
    _branchSearchController.dispose();
    _equipmentSearchController.dispose();
    _dragController.dispose();
    super.dispose();
  }

  // MÉTODOS DE FILTRADO
  void _filterClients() {
    setState(() {
      final query = _clientSearchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredClients = _clients;
      } else {
        _filteredClients = _clients
            .where((client) => client.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _filterBranches() {
    setState(() {
      final query = _branchSearchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredBranches = _branches;
      } else {
        _filteredBranches = _branches
            .where((branch) => branch.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _filterEquipmentTypes() {
    setState(() {
      final query = _equipmentSearchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredEquipmentTypes = _equipmentTypes;
      } else {
        _filteredEquipmentTypes = _equipmentTypes
            .where((type) => type.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  // MÉTODOS DE CONTROL DEL DRAG
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Calcular nueva posición basada en el delta del drag
      final screenHeight = MediaQuery.of(context).size.height;
      final delta = details.primaryDelta! / screenHeight;

      _dragPosition =
          (_dragPosition - delta).clamp(_minDragPosition, _maxDragPosition);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    // Animar a la posición más cercana (30%, 60%, o 90%)
    double targetPosition;

    if (_dragPosition < 0.45) {
      targetPosition = _minDragPosition;
    } else if (_dragPosition < 0.75) {
      targetPosition = 0.6;
    } else {
      targetPosition = _maxDragPosition;
    }

    _animateToPosition(targetPosition);
  }

  void _animateToPosition(double target) {
    _dragAnimation = Tween<double>(
      begin: _dragPosition,
      end: target,
    ).animate(CurvedAnimation(
      parent: _dragController,
      curve: Curves.easeOut,
    ));

    _dragController.forward(from: 0).then((_) {
      setState(() {
        _dragPosition = target;
      });
    });
  }

  // Cargar rol del usuario desde Firebase
  Future<void> _loadUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          _userRole = userData['role'] ?? 'technician';
        } else {
          _userRole = 'technician';
        }
      } else {
        _userRole = null;
      }
    } catch (e) {
      print('Error obteniendo rol del usuario: $e');
      _userRole = 'technician';
    } finally {
      _isLoadingRole = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  // Cargar clientes para filtros
  Future<void> _loadClients() async {
    try {
      final clients = await _clientService.getClients().first;
      setState(() {
        _clients = clients;
        _filteredClients = clients;
      });
    } catch (e) {
      print('Error cargando clientes: $e');
    }
  }

  void _loadMaintenances() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar mantenimientos del mes actual y siguiente
      final startDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final endDate = DateTime(_currentMonth.year, _currentMonth.month + 2, 0);

      final allMaintenances = await _maintenanceService
          .getMaintenancesByDateRange(startDate, endDate);

      // APLICAR FILTROS
      var filteredMaintenances = allMaintenances.where((m) {
        // Filtro por cliente
        if (_selectedClientId != null && m.clientId != _selectedClientId) {
          return false;
        }

        // Filtro por sucursal
        if (_selectedBranchId != null && m.branchId != _selectedBranchId) {
          return false;
        }

        // Filtro por tipo de mantenimiento
        if (_selectedMaintenanceType != null &&
            m.type != _selectedMaintenanceType) {
          return false;
        }

        return true;
      }).toList();

      _events.clear();
      for (var maintenance in filteredMaintenances) {
        final date = DateTime(
          maintenance.scheduledDate.year,
          maintenance.scheduledDate.month,
          maintenance.scheduledDate.day,
        );

        if (_events[date] != null) {
          _events[date]!.add(maintenance);
        } else {
          _events[date] = [maintenance];
        }
      }

      _updateSelectedDayEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando mantenimientos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateSelectedDayEvents() {
    final normalizedDate =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _selectedDayEvents = _events[normalizedDate] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Calendario'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_userRole != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  _userRole!.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAddMaintenance(),
          ),
        ],
      ),
      body: _isLoadingRole
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Calendario fijo arriba
                Column(
                  children: [
                    _buildMonthSelector(),
                    if ([
                      _selectedClientId != null,
                      _selectedBranchId != null,
                      _selectedEquipmentType != null,
                      _selectedMaintenanceType != null,
                    ].any((f) => f))
                      _buildActiveFiltersBar(),
                    _buildCalendarGrid(),
                  ],
                ),

                // Panel desplegable de eventos
                AnimatedBuilder(
                  animation: _dragAnimation,
                  builder: (context, child) {
                    final position = _dragAnimation.isAnimating
                        ? _dragAnimation.value
                        : _dragPosition;

                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: screenHeight * position,
                      child: GestureDetector(
                        onVerticalDragUpdate: _onVerticalDragUpdate,
                        onVerticalDragEnd: _onVerticalDragEnd,
                        child: _buildSelectedDayEvents(),
                      ),
                    );
                  },
                ),
              ],
            ),
      floatingActionButton: _buildFilterButton(),
    );
  }

  // ==========================================
  // BOTÓN DE FILTROS
  // ==========================================

  Widget _buildFilterButton() {
    final activeFiltersCount = [
      _selectedClientId != null,
      _selectedBranchId != null,
      _selectedEquipmentType != null,
      _selectedMaintenanceType != null,
    ].where((f) => f).length;

    return FloatingActionButton.extended(
      onPressed: () => _showFiltersBottomSheet(),
      backgroundColor:
          activeFiltersCount > 0 ? Colors.orange : const Color(0xFF007AFF),
      icon: Stack(
        children: [
          const Icon(Icons.filter_list),
          if (activeFiltersCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$activeFiltersCount',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      label: Text(
          activeFiltersCount > 0 ? 'Filtros ($activeFiltersCount)' : 'Filtros'),
    );
  }

  void _showFiltersBottomSheet() {
    // Resetear búsquedas
    _clientSearchController.clear();
    _branchSearchController.clear();
    _equipmentSearchController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Text(
                          'Filtros',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if ([
                          _selectedClientId != null,
                          _selectedBranchId != null,
                          _selectedEquipmentType != null,
                          _selectedMaintenanceType != null,
                        ].any((f) => f))
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _selectedClientId = null;
                                _selectedBranchId = null;
                                _selectedEquipmentType = null;
                                _selectedMaintenanceType = null;
                                _branches = [];
                                _clientSearchController.clear();
                                _branchSearchController.clear();
                                _equipmentSearchController.clear();
                              });
                              setState(() {});
                              _loadMaintenances();
                            },
                            child: const Text('Limpiar todo'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Filtros con búsqueda
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          // Filtro de Cliente con búsqueda
                          _buildSearchableFilterCard(
                            title: 'Cliente',
                            icon: Icons.business,
                            searchController: _clientSearchController,
                            searchHint: 'Buscar cliente...',
                            child: Column(
                              children: [
                                // Búsqueda
                                TextField(
                                  controller: _clientSearchController,
                                  decoration: InputDecoration(
                                    hintText: 'Buscar cliente...',
                                    prefixIcon:
                                        const Icon(Icons.search, size: 20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    suffixIcon: _clientSearchController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear,
                                                size: 20),
                                            onPressed: () {
                                              setModalState(() {
                                                _clientSearchController.clear();
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: (value) => setModalState(() {}),
                                ),
                                const SizedBox(height: 12),

                                // Lista de clientes
                                Container(
                                  constraints:
                                      const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListView(
                                    shrinkWrap: true,
                                    children: [
                                      RadioListTile<String?>(
                                        title: const Text('Todos los clientes'),
                                        value: null,
                                        groupValue: _selectedClientId,
                                        onChanged: (value) {
                                          setModalState(() {
                                            _selectedClientId = value;
                                            _selectedBranchId = null;
                                            _branches = [];
                                          });
                                          setState(() {});
                                          _loadMaintenances();
                                        },
                                      ),
                                      ..._filteredClients.map((client) {
                                        return RadioListTile<String>(
                                          title: Text(client.name),
                                          subtitle: Text(
                                              '${client.branches.length} sucursales'),
                                          value: client.id!,
                                          groupValue: _selectedClientId,
                                          onChanged: (value) {
                                            setModalState(() {
                                              _selectedClientId = value;
                                              _selectedBranchId = null;
                                              _branches = client.branches;
                                              _filteredBranches =
                                                  client.branches;
                                            });
                                            setState(() {});
                                            _loadMaintenances();
                                          },
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Filtro de Sucursal con búsqueda
                          if (_selectedClientId != null && _branches.isNotEmpty)
                            _buildSearchableFilterCard(
                              title: 'Sucursal',
                              icon: Icons.store,
                              searchController: _branchSearchController,
                              searchHint: 'Buscar sucursal...',
                              child: Column(
                                children: [
                                  // Búsqueda
                                  TextField(
                                    controller: _branchSearchController,
                                    decoration: InputDecoration(
                                      hintText: 'Buscar sucursal...',
                                      prefixIcon:
                                          const Icon(Icons.search, size: 20),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      suffixIcon: _branchSearchController
                                              .text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear,
                                                  size: 20),
                                              onPressed: () {
                                                setModalState(() {
                                                  _branchSearchController
                                                      .clear();
                                                });
                                              },
                                            )
                                          : null,
                                    ),
                                    onChanged: (value) => setModalState(() {}),
                                  ),
                                  const SizedBox(height: 12),

                                  // Lista de sucursales
                                  Container(
                                    constraints:
                                        const BoxConstraints(maxHeight: 200),
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: [
                                        RadioListTile<String?>(
                                          title: const Text(
                                              'Todas las sucursales'),
                                          value: null,
                                          groupValue: _selectedBranchId,
                                          onChanged: (value) {
                                            setModalState(() {
                                              _selectedBranchId = value;
                                            });
                                            setState(() {});
                                            _loadMaintenances();
                                          },
                                        ),
                                        ..._filteredBranches.map((branch) {
                                          return RadioListTile<String>(
                                            title: Text(branch.name),
                                            subtitle: branch.address != null
                                                ? Text(branch.address.toString(),
                                                    style: const TextStyle(
                                                        fontSize: 12))
                                                : null,
                                            value: branch.id!,
                                            groupValue: _selectedBranchId,
                                            onChanged: (value) {
                                              setModalState(() {
                                                _selectedBranchId = value;
                                              });
                                              setState(() {});
                                              _loadMaintenances();
                                            },
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Filtro de Tipo de Equipo con búsqueda
                          _buildSearchableFilterCard(
                            title: 'Tipo de Equipo',
                            icon: Icons.ac_unit,
                            searchController: _equipmentSearchController,
                            searchHint: 'Buscar tipo de equipo...',
                            child: Column(
                              children: [
                                // Búsqueda
                                TextField(
                                  controller: _equipmentSearchController,
                                  decoration: InputDecoration(
                                    hintText: 'Buscar tipo de equipo...',
                                    prefixIcon:
                                        const Icon(Icons.search, size: 20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    suffixIcon: _equipmentSearchController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear,
                                                size: 20),
                                            onPressed: () {
                                              setModalState(() {
                                                _equipmentSearchController
                                                    .clear();
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: (value) => setModalState(() {}),
                                ),
                                const SizedBox(height: 12),

                                // Lista de tipos
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilterChip(
                                      label: const Text('Todos'),
                                      selected: _selectedEquipmentType == null,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          _selectedEquipmentType = null;
                                        });
                                        setState(() {});
                                        _loadMaintenances();
                                      },
                                    ),
                                    ..._filteredEquipmentTypes.map((type) {
                                      return FilterChip(
                                        label: Text(type),
                                        selected:
                                            _selectedEquipmentType == type,
                                        onSelected: (selected) {
                                          setModalState(() {
                                            _selectedEquipmentType =
                                                selected ? type : null;
                                          });
                                          setState(() {});
                                          _loadMaintenances();
                                        },
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Filtro de Tipo de Mantenimiento
                          _buildFilterCard(
                            title: 'Tipo de Mantenimiento',
                            icon: Icons.build,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: MaintenanceType.values.map((type) {
                                final isSelected =
                                    _selectedMaintenanceType == type;
                                return FilterChip(
                                  label: Text(_getMaintenanceTypeName(type)),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      _selectedMaintenanceType =
                                          selected ? type : null;
                                    });
                                    setState(() {});
                                    _loadMaintenances();
                                  },
                                  selectedColor: _getMaintenanceTypeColor(type)
                                      .withOpacity(0.3),
                                  checkmarkColor:
                                      _getMaintenanceTypeColor(type),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Botón de aplicar
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Aplicar Filtros',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchableFilterCard({
    required String title,
    required IconData icon,
    required TextEditingController searchController,
    required String searchHint,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF007AFF)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF007AFF)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BARRA DE FILTROS ACTIVOS
  // ==========================================

  Widget _buildActiveFiltersBar() {
    final activeFilters = <Widget>[];

    if (_selectedClientId != null) {
      final client = _clients.firstWhere((c) => c.id == _selectedClientId);
      activeFilters.add(_buildFilterChip(
        label: client.name,
        icon: Icons.business,
        onRemove: () {
          setState(() {
            _selectedClientId = null;
            _selectedBranchId = null;
            _branches = [];
          });
          _loadMaintenances();
        },
      ));
    }

    if (_selectedBranchId != null) {
      final branch = _branches.firstWhere((b) => b.id == _selectedBranchId);
      activeFilters.add(_buildFilterChip(
        label: branch.name,
        icon: Icons.store,
        onRemove: () {
          setState(() {
            _selectedBranchId = null;
          });
          _loadMaintenances();
        },
      ));
    }

    if (_selectedEquipmentType != null) {
      activeFilters.add(_buildFilterChip(
        label: _selectedEquipmentType!,
        icon: Icons.ac_unit,
        onRemove: () {
          setState(() {
            _selectedEquipmentType = null;
          });
          _loadMaintenances();
        },
      ));
    }

    if (_selectedMaintenanceType != null) {
      activeFilters.add(_buildFilterChip(
        label: _getMaintenanceTypeName(_selectedMaintenanceType!),
        icon: Icons.build,
        color: _getMaintenanceTypeColor(_selectedMaintenanceType!),
        onRemove: () {
          setState(() {
            _selectedMaintenanceType = null;
          });
          _loadMaintenances();
        },
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: activeFilters,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedClientId = null;
                _selectedBranchId = null;
                _selectedEquipmentType = null;
                _selectedMaintenanceType = null;
                _branches = [];
              });
              _loadMaintenances();
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    Color? color,
    required VoidCallback onRemove,
  }) {
    final chipColor = color ?? const Color(0xFF007AFF);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 16,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _previousMonth,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.chevron_left, color: Colors.grey, size: 20),
            ),
          ),
          Text(
            DateFormat('MMMM yyyy', 'es').format(_currentMonth),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: _nextMonth,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildWeekdayHeaders(),
          _buildCalendarBody(),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    final weekdays = ['D', 'L', 'M', 'M', 'J', 'V', 'S'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays.map((day) {
          return Text(
            day,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarBody() {
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 0.9,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: 42,
        itemBuilder: (context, index) {
          if (index < startingWeekday) {
            final prevMonth =
                DateTime(_currentMonth.year, _currentMonth.month - 1);
            final daysInPrevMonth = _getDaysInMonth(prevMonth);
            final day = daysInPrevMonth - (startingWeekday - index - 1);
            final date = DateTime(prevMonth.year, prevMonth.month, day);

            return _buildCalendarDay(
              date: date,
              isCurrentMonth: false,
            );
          } else if (index >= startingWeekday + daysInMonth) {
            final nextMonth =
                DateTime(_currentMonth.year, _currentMonth.month + 1);
            final day = index - startingWeekday - daysInMonth + 1;
            final date = DateTime(nextMonth.year, nextMonth.month, day);

            return _buildCalendarDay(
              date: date,
              isCurrentMonth: false,
            );
          } else {
            final day = index - startingWeekday + 1;
            final date = DateTime(_currentMonth.year, _currentMonth.month, day);

            return _buildCalendarDay(
              date: date,
              isCurrentMonth: true,
            );
          }
        },
      ),
    );
  }

  Widget _buildCalendarDay({
    required DateTime date,
    required bool isCurrentMonth,
  }) {
    final isSelected = _isSameDay(date, _selectedDate);
    final isToday = _isSameDay(date, DateTime.now());
    final events = _events[date] ?? [];
    final hasEvents = events.isNotEmpty;

    return GestureDetector(
      onTap: () => _selectDate(date),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF007AFF)
              : hasEvents && isCurrentMonth
                  ? Colors.red.withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isToday && !isSelected ? Colors.red : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(
                  date.day.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : isToday
                            ? Colors.white
                            : isCurrentMonth
                                ? Colors.black
                                : Colors.grey[400],
                  ),
                ),
              ),
            ),
            if (hasEvents && isCurrentMonth) ...[
              const SizedBox(height: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: events.take(3).map((event) {
                  return Container(
                    width: 3,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: BoxDecoration(
                      color: _getEventColor(event),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayEvents() {
    final completedEvents = _selectedDayEvents
        .where((e) => e.status == MaintenanceStatus.completed)
        .toList();
    final isAdmin = _userRole == 'admin';
    final realEventCount = _selectedDayEvents.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('d', 'es').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE', 'es').format(_selectedDate),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          DateFormat('MMMM yyyy', 'es').format(_selectedDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (realEventCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$realEventCount evento${realEventCount != 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Color(0xFF007AFF),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),

                // PDF buttons for admin
                if (isAdmin && _selectedDayEvents.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings,
                                color: Colors.blue[700], size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Opciones de Administrador',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _generateDayReport(_selectedDayEvents),
                                icon:
                                    const Icon(Icons.picture_as_pdf, size: 13),
                                label: Text(
                                  'PDF Día (${_selectedDayEvents.length})',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                ),
                              ),
                            ),
                            if (completedEvents.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _generateCompletedReport(completedEvents),
                                  icon:
                                      const Icon(Icons.check_circle, size: 13),
                                  label: Text(
                                    'PDF Completados (${completedEvents.length})',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 4),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Events list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedDayEvents.isEmpty
                    ? _buildEmptyState()
                    : _buildEventsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        // FIX: Agregado ScrollView
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // FIX: Cambiar a min
          children: [
            Icon(
              Icons.event_note,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay mantenimientos programados',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'para este día',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _navigateToAddMaintenance(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Programar Mantenimiento'),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildEventsList() {
    final groupedEvents = <String, List<MaintenanceSchedule>>{};

    for (var event in _selectedDayEvents) {
      final timeKey = DateFormat('HH:mm').format(event.scheduledDate);
      if (groupedEvents[timeKey] != null) {
        groupedEvents[timeKey]!.add(event);
      } else {
        groupedEvents[timeKey] = [event];
      }
    }

    final sortedTimes = groupedEvents.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedTimes.length,
      itemBuilder: (context, index) {
        final time = sortedTimes[index];
        final events = groupedEvents[time]!;

        return _buildTimeSlot(time, events);
      },
    );
  }

  Widget _buildTimeSlot(String time, List<MaintenanceSchedule> events) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 55,
            child: Text(
              time,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: events.map((event) => _buildEventCard(event)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(MaintenanceSchedule maintenance) {
    final isAdmin = _userRole == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _getEventColor(maintenance).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _getEventColor(maintenance).withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showMaintenanceDetails(maintenance),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getEventColor(maintenance),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maintenance.equipmentName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.business,
                                size: 13, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                maintenance.clientName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (maintenance.branchName != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.store,
                                  size: 13, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  maintenance.branchName!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: _getEventColor(maintenance).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _getEventColor(maintenance).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          maintenance.statusDisplayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getEventColor(maintenance),
                          ),
                        ),
                      ),
                      if (isAdmin &&
                          maintenance.status ==
                              MaintenanceStatus.completed) ...[
                        const SizedBox(height: 5),
                        GestureDetector(
                          onTap: () => _generateIndividualPDF(maintenance),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf,
                              size: 16,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: Colors.grey[200], height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.build,
                      label: _getMaintenanceTypeName(maintenance.type),
                      color: _getMaintenanceTypeColor(maintenance.type),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (maintenance.frequency != null)
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.schedule,
                        label: maintenance.frequencyDisplayName,
                        color: Colors.blue,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (maintenance.technicianName != null)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.blue[100],
                      child:
                          Icon(Icons.person, size: 13, color: Colors.blue[700]),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        maintenance.technicianName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (maintenance.tasks.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.checklist, size: 15, color: Colors.grey[600]),
                    const SizedBox(width: 7),
                    Text(
                      '${maintenance.tasks.length} tarea${maintenance.tasks.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    const Spacer(),
                    if (maintenance.completionPercentage != null &&
                        maintenance.completionPercentage! > 0)
                      Text(
                        '${maintenance.completionPercentage}% completado',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
              if (maintenance.notes != null &&
                  maintenance.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 13, color: Colors.amber[700]),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          maintenance.notes!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[800],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // RESTO DE LOS MÉTODOS SIN CAMBIOS (PDF, navegación, etc.)
  // Por brevedad, incluyo solo las firmas de los métodos principales

 Future<void> _generateDayReport(
      List<MaintenanceSchedule> maintenances) async {
    if (maintenances.isEmpty) {
      _showErrorSnackBar('No hay mantenimientos para generar reporte');
      return;
    }

    try {
      _showLoadingDialog();

      final reportDate = _selectedDate;
      final maintenancesData =
          maintenances.map((m) => m.toFirestore()).toList();

      final pdfData = await MaintenancePDFService.generateDailyReportPDF(
        maintenancesData,
        reportDate,
      );

      if (!mounted) return;
      Navigator.pop(context);

      _showPDFOptionsDialog(
        title: 'Reporte del Día',
        subtitle:
            '${DateFormat('dd/MM/yyyy').format(reportDate)} - ${maintenances.length} mantenimientos',
        pdfData: pdfData,
        fileName:
            'Reporte_Diario_${DateFormat('yyyy-MM-dd').format(reportDate)}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackBar('Error generando reporte diario: $e');
    }
  }

  Future<void> _generateCompletedReport(
      List<MaintenanceSchedule> completedMaintenances) async {
    // [Código existente sin cambios]
  }

  Future<void> _generateIndividualPDF(MaintenanceSchedule maintenance) async {
    // [Código existente sin cambios]
  }

  void _showPDFOptionsDialog({
    required String title,
    required String subtitle,
    required Uint8List pdfData,
    required String fileName,
  }) {
    // [Código existente sin cambios]
  }

  Future<void> _viewPDF(Uint8List pdfData, String fileName) async {
    // [Código existente sin cambios]
  }

  Future<void> _sharePDF(
      Uint8List pdfData, String fileName, String description) async {
    // [Código existente sin cambios]
  }

  Future<void> _savePDF(Uint8List pdfData, String fileName) async {
    // [Código existente sin cambios]
  }

  void _showLoadingDialog() {
    // [Código existente sin cambios]
  }

  void _showErrorSnackBar(String message) {
    // [Código existente sin cambios]
  }

  void _showSuccessSnackBar(String message) {
    // [Código existente sin cambios]
  }

  Color _getEventColor(MaintenanceSchedule maintenance) {
    switch (maintenance.status) {
      case MaintenanceStatus.scheduled:
        return maintenance.isOverdue ? Colors.red : const Color(0xFF007AFF);
      case MaintenanceStatus.inProgress:
        return Colors.orange;
      case MaintenanceStatus.completed:
        return Colors.green;
      case MaintenanceStatus.overdue:
        return Colors.red;
      case MaintenanceStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getMaintenanceTypeName(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.preventive:
        return 'Preventivo';
      case MaintenanceType.corrective:
        return 'Correctivo';
      case MaintenanceType.emergency:
        return 'Emergencia';
      case MaintenanceType.inspection:
        return 'Inspección';
      case MaintenanceType.technicalAssistance:
        return 'Asistencia Técnica';
    }
  }

  Color _getMaintenanceTypeColor(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.preventive:
        return Colors.blue;
      case MaintenanceType.corrective:
        return Colors.orange;
      case MaintenanceType.emergency:
        return Colors.red;
      case MaintenanceType.inspection:
        return Colors.purple;
      case MaintenanceType.technicalAssistance:
        return Colors.green;
    }
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _updateSelectedDayEvents();
    });
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _loadMaintenances();
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _loadMaintenances();
    });
  }

  void _navigateToAddMaintenance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddMaintenanceScreen(),
      ),
    ).then((value) {
      if (value == true) {
        _loadMaintenances();
      }
    });
  }

  void _showMaintenanceDetails(MaintenanceSchedule maintenance) {
    final isAdmin = _userRole == 'admin';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(maintenance.equipmentName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Cliente', maintenance.clientName),
              _buildDetailRow('Estado', maintenance.statusDisplayName),
              _buildDetailRow(
                  'Fecha',
                  DateFormat('dd/MM/yyyy HH:mm')
                      .format(maintenance.scheduledDate)),
              _buildDetailRow('Frecuencia', maintenance.frequencyDisplayName),
              if (maintenance.technicianName != null)
                _buildDetailRow('Técnico', maintenance.technicianName!),
              if (maintenance.location != null)
                _buildDetailRow('Ubicación', maintenance.location!),
              if (maintenance.notes != null)
                _buildDetailRow('Notas', maintenance.notes!),
              if (maintenance.tasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Tareas programadas:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...maintenance.tasks.map((task) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 2),
                      child: Text('• $task'),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          if (maintenance.status == MaintenanceStatus.scheduled)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddMaintenanceScreen(maintenance: maintenance),
                  ),
                ).then((value) {
                  if (value == true) {
                    _loadMaintenances();
                  }
                });
              },
              child: const Text('Editar'),
            ),
          if (isAdmin && maintenance.status == MaintenanceStatus.completed)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _generateIndividualPDF(maintenance);
              },
              child: const Text('Generar PDF'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }
}
