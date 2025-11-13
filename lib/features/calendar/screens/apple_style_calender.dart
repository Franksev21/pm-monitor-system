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
    extends State<AppleStyleMaintenanceCalendar> {
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

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadClients();
    _loadMaintenances();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Calendario'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Mostrar rol en debug
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
          : Column(
              children: [
                _buildMonthSelector(),

                // Indicador de filtros activos
                if ([
                  _selectedClientId != null,
                  _selectedBranchId != null,
                  _selectedEquipmentType != null,
                  _selectedMaintenanceType != null,
                ].any((f) => f))
                  _buildActiveFiltersBar(),

                _buildCalendarGrid(),
                _buildSelectedDayEvents(),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
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

                    // Filtros
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          // Filtro de Cliente
                          _buildFilterCard(
                            title: 'Cliente',
                            icon: Icons.business,
                            child: DropdownButtonFormField<String>(
                              value: _selectedClientId,
                              decoration: const InputDecoration(
                                hintText: 'Seleccionar cliente',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Todos los clientes'),
                                ),
                                ..._clients.map((client) {
                                  return DropdownMenuItem(
                                    value: client.id,
                                    child: Text(client.name),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setModalState(() {
                                  _selectedClientId = value;
                                  _selectedBranchId = null;
                                  _branches = value != null
                                      ? _clients
                                          .firstWhere((c) => c.id == value)
                                          .branches
                                      : [];
                                });
                                setState(() {});
                                _loadMaintenances();
                              },
                            ),
                          ),

                          // Filtro de Sucursal
                          if (_selectedClientId != null && _branches.isNotEmpty)
                            _buildFilterCard(
                              title: 'Sucursal',
                              icon: Icons.store,
                              child: DropdownButtonFormField<String>(
                                value: _selectedBranchId,
                                decoration: const InputDecoration(
                                  hintText: 'Seleccionar sucursal',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Todas las sucursales'),
                                  ),
                                  ..._branches.map((branch) {
                                    return DropdownMenuItem(
                                      value: branch.id,
                                      child: Text(branch.name),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setModalState(() {
                                    _selectedBranchId = value;
                                  });
                                  setState(() {});
                                  _loadMaintenances();
                                },
                              ),
                            ),

                          // Filtro de Tipo de Equipo
                          _buildFilterCard(
                            title: 'Tipo de Equipo',
                            icon: Icons.ac_unit,
                            child: DropdownButtonFormField<String>(
                              value: _selectedEquipmentType,
                              decoration: const InputDecoration(
                                hintText: 'Seleccionar tipo',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Todos los tipos'),
                                ),
                                ..._equipmentTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setModalState(() {
                                  _selectedEquipmentType = value;
                                });
                                setState(() {});
                                _loadMaintenances();
                              },
                            ),
                          ),

                          // Filtro de Tipo de Mantenimiento
                          _buildFilterCard(
                            title: 'Tipo de Mantenimiento',
                            icon: Icons.build,
                            child: Wrap(
                              spacing: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              child: const Icon(Icons.chevron_left, color: Colors.grey),
            ),
          ),
          Text(
            DateFormat('MMMM yyyy', 'es').format(_currentMonth),
            style: const TextStyle(
              fontSize: 22,
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
              child: const Icon(Icons.chevron_right, color: Colors.grey),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays.map((day) {
          return Text(
            day,
            style: TextStyle(
              fontSize: 14,
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
    final startingWeekday = firstDayOfMonth.weekday % 7; // Domingo = 0

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.0,
        ),
        itemCount: 42, // 6 semanas x 7 días
        itemBuilder: (context, index) {
          if (index < startingWeekday) {
            // Días del mes anterior
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
            // Días del mes siguiente
            final nextMonth =
                DateTime(_currentMonth.year, _currentMonth.month + 1);
            final day = index - startingWeekday - daysInMonth + 1;
            final date = DateTime(nextMonth.year, nextMonth.month, day);

            return _buildCalendarDay(
              date: date,
              isCurrentMonth: false,
            );
          } else {
            // Días del mes actual
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
        margin: const EdgeInsets.all(2),
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
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isToday && !isSelected ? Colors.red : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(
                  date.day.toString(),
                  style: TextStyle(
                    fontSize: 16,
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
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: events.take(3).map((event) {
                  return Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: _getEventColor(event),
                      borderRadius: BorderRadius.circular(2),
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
    // Calcular conteos reales
    final completedEvents = _selectedDayEvents
        .where((e) => e.status == MaintenanceStatus.completed)
        .toList();
    final isAdmin = _userRole == 'admin';
    final realEventCount = _selectedDayEvents.length; // Conteo real

    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('d', 'es').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 32,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            DateFormat('MMMM yyyy', 'es').format(_selectedDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (realEventCount > 0) // Usar conteo real
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '$realEventCount evento${realEventCount != 1 ? 's' : ''}', // Conteo real
                            style: const TextStyle(
                              color: Color(0xFF007AFF),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // SECCIÓN PDF PARA ADMINISTRADORES
                  if (isAdmin && _selectedDayEvents.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
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
                                  color: Colors.blue[700], size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Opciones de Administrador',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _generateDayReport(_selectedDayEvents),
                                  icon: const Icon(Icons.picture_as_pdf,
                                      size: 14),
                                  label: Text(
                                    'PDF Día (${_selectedDayEvents.length})',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                  ),
                                ),
                              ),
                              if (completedEvents.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _generateCompletedReport(
                                        completedEvents),
                                    icon: const Icon(Icons.check_circle,
                                        size: 14),
                                    label: Text(
                                      'PDF Completados (${completedEvents.length})',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedDayEvents.isEmpty
                      ? _buildEmptyState()
                      : _buildEventsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Programar Mantenimiento'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    // Agrupar eventos por hora
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              time,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: events.map((event) => _buildEventCard(event)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TARJETA DE MANTENIMIENTO MEJORADA
  // ==========================================

  Widget _buildEventCard(MaintenanceSchedule maintenance) {
    final isAdmin = _userRole == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getEventColor(maintenance).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _getEventColor(maintenance).withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showMaintenanceDetails(maintenance),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con equipo y estado
              Row(
                children: [
                  // Barra de color
                  Container(
                    width: 5,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _getEventColor(maintenance),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del equipo
                        Text(
                          maintenance.equipmentName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Cliente
                        Row(
                          children: [
                            Icon(Icons.business,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                maintenance.clientName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // Sucursal (si existe)
                        if (maintenance.branchName != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.store,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  maintenance.branchName!,
                                  style: TextStyle(
                                    fontSize: 12,
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

                  // Estado
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getEventColor(maintenance).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getEventColor(maintenance).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          maintenance.statusDisplayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getEventColor(maintenance),
                          ),
                        ),
                      ),

                      // PDF button para admin
                      if (isAdmin &&
                          maintenance.status ==
                              MaintenanceStatus.completed) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _generateIndividualPDF(maintenance),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf,
                              size: 18,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Divider
              Divider(color: Colors.grey[200], height: 1),
              const SizedBox(height: 12),

              // Info adicional
              Row(
                children: [
                  // Tipo de mantenimiento
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.build,
                      label: _getMaintenanceTypeName(maintenance.type),
                      color: _getMaintenanceTypeColor(maintenance.type),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Frecuencia (si aplica)
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

              const SizedBox(height: 8),

              // Técnico asignado
              if (maintenance.technicianName != null)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.blue[100],
                      child:
                          Icon(Icons.person, size: 14, color: Colors.blue[700]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        maintenance.technicianName!,
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

              // Número de tareas
              if (maintenance.tasks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.checklist, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${maintenance.tasks.length} tarea${maintenance.tasks.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    const Spacer(),
                    if (maintenance.completionPercentage != null &&
                        maintenance.completionPercentage! > 0)
                      Text(
                        '${maintenance.completionPercentage}% completado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],

              // Notas (preview)
              if (maintenance.notes != null &&
                  maintenance.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          maintenance.notes!,
                          style: TextStyle(
                            fontSize: 12,
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

  // Helper para chips de información
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
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

  // ==========================================
  // MÉTODOS PDF (SIN CAMBIOS - CONSERVADOS)
  // ==========================================

  Future<void> _generateDayReport(
      List<MaintenanceSchedule> maintenances) async {
    try {
      _showLoadingDialog();

      final reportDate = _selectedDate;
      final maintenancesData =
          maintenances.map((m) => m.toFirestore()).toList();

      final pdfData = await MaintenancePDFService.generateDailyReportPDF(
        maintenancesData,
        reportDate,
      );

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
      Navigator.pop(context);
      _showErrorSnackBar('Error generando reporte diario: $e');
    }
  }

  Future<void> _generateCompletedReport(
      List<MaintenanceSchedule> completedMaintenances) async {
    try {
      _showLoadingDialog();

      final reportDate = _selectedDate;
      final dateString = DateFormat('yyyy-MM-dd').format(reportDate);
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return [
              _buildCompletedReportHeader(
                  reportDate, completedMaintenances.length),
              pw.SizedBox(height: 20),
              _buildCompletedSummary(completedMaintenances),
              pw.SizedBox(height: 20),
              _buildCompletedMaintenancesList(completedMaintenances),
              pw.SizedBox(height: 20),
              _buildEfficiencyMetrics(completedMaintenances),
              pw.SizedBox(height: 30),
              _buildReportFooter(),
            ];
          },
        ),
      );

      Navigator.pop(context);

      _showPDFOptionsDialog(
        title: 'Mantenimientos Completados',
        subtitle:
            '${DateFormat('dd/MM/yyyy').format(reportDate)} - ${completedMaintenances.length} completados',
        pdfData: await pdf.save(),
        fileName: 'Mantenimientos_Completados_$dateString.pdf',
      );
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('Error generando reporte de completados: $e');
    }
  }

  Future<void> _generateIndividualPDF(MaintenanceSchedule maintenance) async {
    try {
      _showLoadingDialog();

      final pdfData = await MaintenancePDFService.generateMaintenancePDF(
        maintenance.toFirestore(),
      );

      Navigator.pop(context);

      _showPDFOptionsDialog(
        title: 'Mantenimiento Individual',
        subtitle: '${maintenance.equipmentName} - ${maintenance.clientName}',
        pdfData: pdfData,
        fileName:
            'Mantenimiento_${maintenance.equipmentName}_${DateFormat('yyyy-MM-dd').format(maintenance.scheduledDate)}.pdf',
      );
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('Error generando PDF individual: $e');
    }
  }

  void _showPDFOptionsDialog({
    required String title,
    required String subtitle,
    required Uint8List pdfData,
    required String fileName,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            const Text('¿Qué deseas hacer con el reporte?'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _viewPDF(pdfData, fileName);
            },
            icon: const Icon(Icons.visibility),
            label: const Text('Ver'),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _sharePDF(pdfData, fileName, subtitle);
            },
            icon: const Icon(Icons.share),
            label: const Text('Compartir'),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _savePDF(pdfData, fileName);
            },
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _viewPDF(Uint8List pdfData, String fileName) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdfData,
        name: fileName,
      );
    } catch (e) {
      _showErrorSnackBar('Error visualizando PDF: $e');
    }
  }

  Future<void> _sharePDF(
      Uint8List pdfData, String fileName, String description) async {
    try {
      final maintenance = _selectedDayEvents.first.toFirestore();
      await MaintenancePDFService.shareMaintenancePDF(maintenance);
      _showSuccessSnackBar('PDF compartido exitosamente');
    } catch (e) {
      _showErrorSnackBar('Error compartiendo PDF: $e');
    }
  }

  Future<void> _savePDF(Uint8List pdfData, String fileName) async {
    try {
      final maintenance = _selectedDayEvents.first.toFirestore();
      final file = await MaintenancePDFService.saveMaintenancePDF(maintenance);
      if (file != null) {
        _showSuccessSnackBar('PDF guardado en: ${file.path}');
      } else {
        _showErrorSnackBar('Error guardando PDF');
      }
    } catch (e) {
      _showErrorSnackBar('Error guardando PDF: $e');
    }
  }

  pw.Widget _buildCompletedReportHeader(DateTime date, int count) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.green700, PdfColors.green500],
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PM MONITOR',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            'Reporte de Mantenimientos Completados',
            style: pw.TextStyle(
              fontSize: 16,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '${DateFormat('EEEE, dd MMMM yyyy', 'es').format(date)}',
            style: pw.TextStyle(
              fontSize: 14,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            '$count mantenimiento${count != 1 ? 's' : ''} completado${count != 1 ? 's' : ''}',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCompletedSummary(List<MaintenanceSchedule> maintenances) {
    final avgCompletion = maintenances.isNotEmpty
        ? maintenances.fold<int>(
                0, (sum, m) => sum + (m.completionPercentage ?? 0)) /
            maintenances.length
        : 0;
    final technicianCount = maintenances
        .map((m) => m.technicianId)
        .where((id) => id != null)
        .toSet()
        .length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Resumen Ejecutivo',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryCard('Completados', maintenances.length.toString(),
                  PdfColors.green),
              _buildSummaryCard(
                  'Técnicos', technicianCount.toString(), PdfColors.blue),
              _buildSummaryCard('Promedio',
                  '${avgCompletion.toStringAsFixed(1)}%', PdfColors.purple),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryCard(String title, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCompletedMaintenancesList(
      List<MaintenanceSchedule> maintenances) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detalle de Mantenimientos Completados',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green700,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.green100),
              children: [
                _buildTableHeader('Equipo'),
                _buildTableHeader('Cliente'),
                _buildTableHeader('Hora'),
                _buildTableHeader('Técnico'),
                _buildTableHeader('Progreso'),
              ],
            ),
            ...maintenances.map((maintenance) => pw.TableRow(
                  children: [
                    _buildTableCell(maintenance.equipmentName),
                    _buildTableCell(maintenance.clientName),
                    _buildTableCell(
                        DateFormat('HH:mm').format(maintenance.scheduledDate)),
                    _buildTableCell(
                        maintenance.technicianName ?? 'No asignado'),
                    _buildTableCell(
                        '${maintenance.completionPercentage ?? 0}%'),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildEfficiencyMetrics(List<MaintenanceSchedule> maintenances) {
    final technicianPerformance = <String, Map<String, dynamic>>{};

    for (final maintenance in maintenances) {
      final techName = maintenance.technicianName ?? 'Sin asignar';
      if (!technicianPerformance.containsKey(techName)) {
        technicianPerformance[techName] = {
          'count': 0,
          'avgCompletion': 0.0,
        };
      }

      technicianPerformance[techName]!['count'] += 1;
      final currentAvg =
          technicianPerformance[techName]!['avgCompletion'] as double;
      final newCompletion = maintenance.completionPercentage ?? 0;
      technicianPerformance[techName]!['avgCompletion'] =
          (currentAvg * (technicianPerformance[techName]!['count'] - 1) +
                  newCompletion) /
              technicianPerformance[techName]!['count'];
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Métricas de Eficiencia por Técnico',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue700,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.blue100),
              children: [
                _buildTableHeader('Técnico'),
                _buildTableHeader('Completados'),
                _buildTableHeader('Eficiencia Prom.'),
              ],
            ),
            ...technicianPerformance.entries.map((entry) => pw.TableRow(
                  children: [
                    _buildTableCell(entry.key),
                    _buildTableCell(entry.value['count'].toString()),
                    _buildTableCell(
                        '${(entry.value['avgCompletion'] as double).toStringAsFixed(1)}%'),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9),
      ),
    );
  }

  pw.Widget _buildReportFooter() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'PM MONITOR - Sistema de Mantenimiento Preventivo',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Reporte generado automáticamente el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generando reporte PDF...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
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
