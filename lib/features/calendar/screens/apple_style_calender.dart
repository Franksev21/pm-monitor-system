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

  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  PageController _pageController = PageController(initialPage: 1000);

  Map<DateTime, List<MaintenanceSchedule>> _events = {};
  List<MaintenanceSchedule> _selectedDayEvents = [];
  bool _isLoading = false;
  String? _userRole;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
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

  void _loadMaintenances() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar mantenimientos del mes actual y siguiente
      final startDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final endDate = DateTime(_currentMonth.year, _currentMonth.month + 2, 0);

      final maintenances = await _maintenanceService.getMaintenancesByDateRange(
          startDate, endDate);

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

  Widget _buildEventCard(MaintenanceSchedule maintenance) {
    final isAdmin = _userRole == 'admin';

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
                        if (maintenance.technicianName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            maintenance.technicianName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getEventColor(maintenance).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          maintenance.statusDisplayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getEventColor(maintenance),
                          ),
                        ),
                      ),
                      // REMOVIDO: Text con estimatedDurationMinutes
                      // Botón PDF individual para administradores en mantenimientos completados
                      if (isAdmin &&
                          maintenance.status ==
                              MaintenanceStatus.completed) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _generateIndividualPDF(maintenance),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(4),
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
            ],
          ),
        ),
      ),
    );
  }

  // MÉTODOS PDF CON INTEGRACIÓN REAL

  Future<void> _generateDayReport(
      List<MaintenanceSchedule> maintenances) async {
    try {
      _showLoadingDialog();

      final reportDate = _selectedDate;

      // Convertir mantenimientos a formato compatible con el servicio
      final maintenancesData =
          maintenances.map((m) => m.toFirestore()).toList();

      // Generar PDF usando el servicio real
      final pdfData = await MaintenancePDFService.generateDailyReportPDF(
        maintenancesData,
        reportDate,
      );

      Navigator.pop(context); // Cerrar loading

      // Mostrar opciones del PDF
      _showPDFOptionsDialog(
        title: 'Reporte del Día',
        subtitle:
            '${DateFormat('dd/MM/yyyy').format(reportDate)} - ${maintenances.length} mantenimientos',
        pdfData: pdfData,
        fileName:
            'Reporte_Diario_${DateFormat('yyyy-MM-dd').format(reportDate)}.pdf',
      );
    } catch (e) {
      Navigator.pop(context); // Cerrar loading
      _showErrorSnackBar('Error generando reporte diario: $e');
    }
  }

  Future<void> _generateCompletedReport(
      List<MaintenanceSchedule> completedMaintenances) async {
    try {
      _showLoadingDialog();

      final reportDate = _selectedDate;
      final dateString = DateFormat('yyyy-MM-dd').format(reportDate);

      // Crear PDF personalizado para mantenimientos completados usando el servicio
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return [
              // Header especializado
              _buildCompletedReportHeader(
                  reportDate, completedMaintenances.length),
              pw.SizedBox(height: 20),

              // Resumen de completados
              _buildCompletedSummary(completedMaintenances),
              pw.SizedBox(height: 20),

              // Lista detallada
              _buildCompletedMaintenancesList(completedMaintenances),
              pw.SizedBox(height: 20),

              // Métricas de eficiencia
              _buildEfficiencyMetrics(completedMaintenances),
              pw.SizedBox(height: 30),

              // Footer
              _buildReportFooter(),
            ];
          },
        ),
      );

      Navigator.pop(context); // Cerrar loading

      // Mostrar opciones del PDF
      _showPDFOptionsDialog(
        title: 'Mantenimientos Completados',
        subtitle:
            '${DateFormat('dd/MM/yyyy').format(reportDate)} - ${completedMaintenances.length} completados',
        pdfData: await pdf.save(),
        fileName: 'Mantenimientos_Completados_$dateString.pdf',
      );
    } catch (e) {
      Navigator.pop(context); // Cerrar loading
      _showErrorSnackBar('Error generando reporte de completados: $e');
    }
  }

  Future<void> _generateIndividualPDF(MaintenanceSchedule maintenance) async {
    try {
      _showLoadingDialog();

      // Usar el servicio real para generar PDF individual
      final pdfData = await MaintenancePDFService.generateMaintenancePDF(
        maintenance.toFirestore(),
      );

      Navigator.pop(context); // Cerrar loading

      // Mostrar opciones del PDF
      _showPDFOptionsDialog(
        title: 'Mantenimiento Individual',
        subtitle: '${maintenance.equipmentName} - ${maintenance.clientName}',
        pdfData: pdfData,
        fileName:
            'Mantenimiento_${maintenance.equipmentName}_${DateFormat('yyyy-MM-dd').format(maintenance.scheduledDate)}.pdf',
      );
    } catch (e) {
      Navigator.pop(context); // Cerrar loading
      _showErrorSnackBar('Error generando PDF individual: $e');
    }
  }

  // Diálogo para mostrar opciones del PDF generado
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

  // Métodos para manejar PDFs
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
      // Usando el método del servicio para compartir
      final maintenance = _selectedDayEvents.first.toFirestore();
      await MaintenancePDFService.shareMaintenancePDF(maintenance);
      _showSuccessSnackBar('PDF compartido exitosamente');
    } catch (e) {
      _showErrorSnackBar('Error compartiendo PDF: $e');
    }
  }

  Future<void> _savePDF(Uint8List pdfData, String fileName) async {
    try {
      // Usando el método del servicio para guardar
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

  // MÉTODOS AUXILIARES PARA PDF PERSONALIZADO

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
    // REMOVIDO: Cálculo de totalDuration
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
              // REMOVIDO: Card de tiempo total
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
            // REMOVIDO: Columna de Duración
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.green100),
              children: [
                _buildTableHeader('Equipo'),
                _buildTableHeader('Cliente'),
                _buildTableHeader('Hora'),
                _buildTableHeader('Técnico'),
                // REMOVIDO: Header de Duración
                _buildTableHeader('Progreso'),
              ],
            ),

            // Filas de datos
            ...maintenances.map((maintenance) => pw.TableRow(
                  children: [
                    _buildTableCell(maintenance.equipmentName),
                    _buildTableCell(maintenance.clientName),
                    _buildTableCell(
                        DateFormat('HH:mm').format(maintenance.scheduledDate)),
                    _buildTableCell(
                        maintenance.technicianName ?? 'No asignado'),
                    // REMOVIDO: Cell de estimatedDurationMinutes
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
    // Calcular métricas de eficiencia
    final technicianPerformance = <String, Map<String, dynamic>>{};

    for (final maintenance in maintenances) {
      final techName = maintenance.technicianName ?? 'Sin asignar';
      if (!technicianPerformance.containsKey(techName)) {
        technicianPerformance[techName] = {
          'count': 0,
          // REMOVIDO: totalTime
          'avgCompletion': 0.0,
        };
      }

      technicianPerformance[techName]!['count'] += 1;
      // REMOVIDO: totalTime calculation
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
            // REMOVIDO: Columna de tiempo total
            2: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.blue100),
              children: [
                _buildTableHeader('Técnico'),
                _buildTableHeader('Completados'),
                // REMOVIDO: Header de tiempo total
                _buildTableHeader('Eficiencia Prom.'),
              ],
            ),

            // Filas de datos
            ...technicianPerformance.entries.map((entry) => pw.TableRow(
                  children: [
                    _buildTableCell(entry.key),
                    _buildTableCell(entry.value['count'].toString()),
                    // REMOVIDO: Cell de tiempo total
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

  // UI HELPERS

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
              // REMOVIDO: Row de duración
              // REMOVIDO: Row de costo estimado
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
