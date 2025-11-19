import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pm_monitor/core/services/maintenance_schedule_service.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_model.dart';
import 'package:pm_monitor/features/maintenance/screens/maintenance_execution_screen.dart';

class TechnicianCalendarScreen extends StatefulWidget {
  const TechnicianCalendarScreen({super.key});

  @override
  _TechnicianCalendarScreenState createState() =>
      _TechnicianCalendarScreenState();
}

class _TechnicianCalendarScreenState extends State<TechnicianCalendarScreen> {
  final MaintenanceScheduleService _maintenanceService =
      MaintenanceScheduleService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  final PageController _pageController = PageController(initialPage: 1000);

  final Map<DateTime, List<MaintenanceSchedule>> _events = {};
  List<MaintenanceSchedule> _selectedDayEvents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMaintenances();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadMaintenances() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Cargar mantenimientos del mes actual y siguiente
      final startDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final endDate = DateTime(_currentMonth.year, _currentMonth.month + 2, 0);

      debugPrint('=== DEBUG CALENDARIO TÉCNICO ===');
      debugPrint('User ID: ${user.uid}');
      debugPrint('Rango de fechas: $startDate - $endDate');

      // ✅ CORREGIDO: Usar getFilteredMaintenances con technicianId
      final maintenances = await _maintenanceService.getFilteredMaintenances(
        startDate: startDate,
        endDate: endDate,
        technicianId: user.uid, // ✅ Solo mantenimientos del técnico actual
      );

      debugPrint('Mantenimientos encontrados: ${maintenances.length}');

      _events.clear();
      for (var maintenance in maintenances) {
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
      debugPrint('Error cargando mantenimientos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando mantenimientos: $e'),
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
        title: const Text('Mi Calendario'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMaintenances,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          _buildCalendarGrid(),
          _buildSelectedDayEvents(),
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
    final startingWeekday = firstDayOfMonth.weekday % 7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.0,
        ),
        itemCount: 42,
        itemBuilder: (context, index) {
          if (index < startingWeekday) {
            final prevMonth =
                DateTime(_currentMonth.year, _currentMonth.month - 1);
            final daysInPrevMonth = _getDaysInMonth(prevMonth);
            final day = daysInPrevMonth - (startingWeekday - index - 1);
            final date = DateTime(prevMonth.year, prevMonth.month, day);

            return _buildCalendarDay(date: date, isCurrentMonth: false);
          } else if (index >= startingWeekday + daysInMonth) {
            final nextMonth =
                DateTime(_currentMonth.year, _currentMonth.month + 1);
            final day = index - startingWeekday - daysInMonth + 1;
            final date = DateTime(nextMonth.year, nextMonth.month, day);

            return _buildCalendarDay(date: date, isCurrentMonth: false);
          } else {
            final day = index - startingWeekday + 1;
            final date = DateTime(_currentMonth.year, _currentMonth.month, day);

            return _buildCalendarDay(date: date, isCurrentMonth: true);
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
    final realEventCount = _selectedDayEvents.length;

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
              child: Row(
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
            'No tienes mantenimientos programados',
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
        ],
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

  Widget _buildEventCard(MaintenanceSchedule maintenance) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getEventColor(maintenance).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showMaintenanceDetails(maintenance),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getEventColor(maintenance),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maintenance.equipmentName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          maintenance.clientName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          maintenance.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getEventColor(maintenance).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          MaintenanceSchedule.getStatusDisplayName(
                              maintenance.status), // ✅ CORREGIDO
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getEventColor(maintenance),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${maintenance.estimatedHours ?? 0}h', // ✅ CORREGIDO
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMaintenanceDetails(MaintenanceSchedule maintenance) {
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
              _buildDetailRow(
                'Estado',
                MaintenanceSchedule.getStatusDisplayName(
                    maintenance.status), // ✅ CORREGIDO
              ),
              _buildDetailRow(
                'Fecha',
                DateFormat('dd/MM/yyyy HH:mm')
                    .format(maintenance.scheduledDate),
              ),
              _buildDetailRow(
                'Duración estimada',
                '${maintenance.estimatedHours ?? 0} horas', // ✅ CORREGIDO
              ),
              if (maintenance.frequency != null)
                _buildDetailRow(
                  'Frecuencia',
                  MaintenanceSchedule.getFrequencyDisplayName(
                      maintenance.frequency!), // ✅ CORREGIDO
                ),
              _buildDetailRow('Ubicación', maintenance.location),
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
          // ✅ CORREGIDO: Solo mostrar botón "Iniciar" si está ASIGNADO
          if (maintenance.status == MaintenanceStatus.assigned)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);

                // Navegar a MaintenanceExecutionScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MaintenanceExecutionScreen(
                      maintenance: {
                        'id': maintenance.id,
                        'equipmentName': maintenance.equipmentName,
                        'equipmentId': maintenance.equipmentId,
                        'clientName': maintenance.clientName,
                        'clientId': maintenance.clientId,
                        'location': maintenance.location,
                        'scheduledDate': maintenance.scheduledDate,
                        'type': maintenance.type.toString().split('.').last,
                        'status': maintenance.status.toString().split('.').last,
                        'tasks': maintenance.tasks,
                        'estimatedHours': maintenance.estimatedHours,
                        'technicianId': maintenance.technicianId,
                        'technicianName': maintenance.technicianName,
                      },
                    ),
                  ),
                ).then((value) {
                  if (value == true) {
                    _loadMaintenances();
                  }
                });
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
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

  // ✅ CORREGIDO: Actualizar colores para nuevos estados
  Color _getEventColor(MaintenanceSchedule maintenance) {
    switch (maintenance.status) {
      case MaintenanceStatus.generated:
        return Colors.grey[400]!;
      case MaintenanceStatus.assigned:
        return Colors.orange[600]!;
      case MaintenanceStatus.executed:
        return Colors.green[600]!;
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }
}
