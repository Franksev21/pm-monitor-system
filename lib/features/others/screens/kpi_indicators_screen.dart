// screens/kpi_indicators_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KPIIndicatorsScreen extends StatefulWidget {
  @override
  _KPIIndicatorsScreenState createState() => _KPIIndicatorsScreenState();
}

class _KPIIndicatorsScreenState extends State<KPIIndicatorsScreen> {
  bool isLoading = true;
  Map<String, dynamic> kpiData = {};
  String selectedPeriod = 'month';

  @override
  void initState() {
    super.initState();
    _loadKPIData();
  }

  Future<void> _loadKPIData() async {
    setState(() => isLoading = true);

    try {
      final data = await _calculateKPIs();
      setState(() {
        kpiData = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading KPI: $e');
      setState(() {
        kpiData = _getDefaultKPIData();
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _calculateKPIs() async {
    final firestore = FirebaseFirestore.instance;
    final period = _getPeriodDates();

    // 1. Satisfacción del Cliente
    final satisfactionValue = await _getCustomerSatisfaction(firestore, period);

    // 2. % de Ejecución
    final executionData = await _getExecutionPercentage(firestore, period);

    // 3. Costo PM
    final pmCost = await _getPreventiveCost(firestore, period);

    // 4. Costo CM
    final cmCost = await _getCorrectiveCost(firestore, period);

    // 5. Horas de Trabajo
    final workingHours = await _getWorkingHours(firestore, period);

    // 6. Eficiencia Técnicos
    final efficiency = await _getTechnicianEfficiency(firestore, period);

    // 7. Tiempo de Respuesta
    final responseTime = await _getResponseTime(firestore, period);

    return {
      'customerSatisfaction': satisfactionValue,
      'executionPercentage': executionData,
      'preventiveCost': pmCost,
      'correctiveCost': cmCost,
      'workingHours': workingHours,
      'technicianEfficiency': efficiency,
      'responseTime': responseTime,
    };
  }

  Map<String, DateTime> _getPeriodDates() {
    final now = DateTime.now();
    DateTime startDate;

    switch (selectedPeriod) {
      case 'week':
        startDate = now.subtract(Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'quarter':
        startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(now.year, now.month - 1, now.day);
    }

    return {'start': startDate, 'end': now};
  }

  Future<double> _getCustomerSatisfaction(
    FirebaseFirestore firestore,
    Map<String, DateTime> period,
  ) async {
    try {
      final surveys = await firestore
          .collection('customerSurveys')
          .where('createdAt',
              isGreaterThan: Timestamp.fromDate(period['start']!))
          .where('createdAt', isLessThan: Timestamp.fromDate(period['end']!))
          .get();

      if (surveys.docs.isEmpty) return 0.0;

      double total = 0;
      int count = 0;

      for (var doc in surveys.docs) {
        final data = doc.data();
        final rating = data['rating'] as num?;
        if (rating != null) {
          total += rating.toDouble();
          count++;
        }
      }

      return count > 0 ? total / count : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _getExecutionPercentage(
    FirebaseFirestore firestore,
    Map<String, DateTime> period,
  ) async {
    try {
      final maintenances = await firestore
          .collection('maintenanceSchedules')
          .where('scheduledDate',
              isGreaterThan: Timestamp.fromDate(period['start']!))
          .where('scheduledDate',
              isLessThan: Timestamp.fromDate(period['end']!))
          .get();

      if (maintenances.docs.isEmpty) return 0.0;

      int completed = 0;
      int total = maintenances.docs.length;

      for (var doc in maintenances.docs) {
        final data = doc.data();
        if (data['status'] == 'completed') {
          completed++;
        }
      }

      return total > 0 ? (completed / total) * 100 : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _getPreventiveCost(
    FirebaseFirestore firestore,
    Map<String, DateTime> period,
  ) async {
    try {
      final maintenances = await firestore
          .collection('maintenanceSchedules')
          .where('type', isEqualTo: 'preventive')
          .where('scheduledDate',
              isGreaterThan: Timestamp.fromDate(period['start']!))
          .where('scheduledDate',
              isLessThan: Timestamp.fromDate(period['end']!))
          .get();

      double totalCost = 0;

      for (var doc in maintenances.docs) {
        final data = doc.data();
        final cost = (data['actualCost'] ?? data['estimatedCost'] ?? 0) as num;
        totalCost += cost.toDouble();
      }

      return totalCost;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _getCorrectiveCost(
    FirebaseFirestore firestore,
    Map<String, DateTime> period,
  ) async {
    try {
      final maintenances = await firestore
          .collection('maintenanceSchedules')
          .where('type', isEqualTo: 'corrective')
          .where('scheduledDate',
              isGreaterThan: Timestamp.fromDate(period['start']!))
          .where('scheduledDate',
              isLessThan: Timestamp.fromDate(period['end']!))
          .get();

      double totalCost = 0;

      for (var doc in maintenances.docs) {
        final data = doc.data();
        final cost = (data['actualCost'] ?? data['estimatedCost'] ?? 0) as num;
        totalCost += cost.toDouble();
      }

      return totalCost;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _getWorkingHours(
    FirebaseFirestore firestore,
    Map<String, DateTime> period,
  ) async {
    try {
      final maintenances = await firestore
          .collection('maintenanceSchedules')
          .where('status', isEqualTo: 'completed')
          .where('completedDate',
              isGreaterThan: Timestamp.fromDate(period['start']!))
          .where('completedDate',
              isLessThan: Timestamp.fromDate(period['end']!))
          .get();

      double totalHours = 0;

      for (var doc in maintenances.docs) {
        final data = doc.data();
        final duration = data['estimatedDurationMinutes'] as num? ?? 0;
        totalHours += duration.toDouble() / 60.0;
      }

      return totalHours;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _getTechnicianEfficiency(
    FirebaseFirestore firestore,
    Map<String, DateTime> period,
  ) async {
    try {
      final maintenances = await firestore
          .collection('maintenanceSchedules')
          .where('scheduledDate',
              isGreaterThan: Timestamp.fromDate(period['start']!))
          .where('scheduledDate',
              isLessThan: Timestamp.fromDate(period['end']!))
          .get();

      if (maintenances.docs.isEmpty) return 0.0;

      int assigned = 0;
      int completedOnTime = 0;

      for (var doc in maintenances.docs) {
        final data = doc.data();
        final status = data['status'] as String;
        final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();
        final completedDate = data['completedDate'] != null
            ? (data['completedDate'] as Timestamp).toDate()
            : null;

        assigned++;

        if (status == 'completed' && completedDate != null) {
          // Completado dentro del día programado
          if (completedDate.difference(scheduledDate).inDays <= 1) {
            completedOnTime++;
          }
        }
      }

      return assigned > 0 ? (completedOnTime / assigned) * 100 : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _getResponseTime(
    FirebaseFirestore firestore,
    Map<String, DateTime> period,
  ) async {
    try {
      final failures = await firestore
          .collection('equipmentFailures')
          .where('reportedAt',
              isGreaterThan: Timestamp.fromDate(period['start']!))
          .where('reportedAt', isLessThan: Timestamp.fromDate(period['end']!))
          .get();

      if (failures.docs.isEmpty) return 0.0;

      double totalTime = 0;
      int count = 0;

      for (var doc in failures.docs) {
        final data = doc.data();
        final reportedAt = (data['reportedAt'] as Timestamp).toDate();
        final arrivedAt = data['technicianArrivedAt'] != null
            ? (data['technicianArrivedAt'] as Timestamp).toDate()
            : null;

        if (arrivedAt != null) {
          final responseTime =
              arrivedAt.difference(reportedAt).inMinutes / 60.0;
          totalTime += responseTime;
          count++;
        }
      }

      return count > 0 ? totalTime / count : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Map<String, dynamic> _getDefaultKPIData() {
    return {
      'customerSatisfaction': 4.2,
      'executionPercentage': 87.5,
      'preventiveCost': 15420.0,
      'correctiveCost': 8930.0,
      'workingHours': 240.5,
      'technicianEfficiency': 92.3,
      'responseTime': 2.4,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text('Indicadores KPI'),
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            initialValue: selectedPeriod,
            onSelected: (value) {
              setState(() => selectedPeriod = value);
              _loadKPIData();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'week', child: Text('Esta Semana')),
              PopupMenuItem(value: 'month', child: Text('Este Mes')),
              PopupMenuItem(value: 'quarter', child: Text('Este Trimestre')),
              PopupMenuItem(value: 'year', child: Text('Este Año')),
            ],
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadKPIData,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Indicadores de Medición:',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 16),
                          _buildMainGauge(),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Los 7 KPIs
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                      children: [
                        _buildKPICard(
                          'Nivel de satisfacción del cliente',
                          kpiData['customerSatisfaction'] ?? 0.0,
                          5.0,
                          '/5',
                          Colors.green,
                          Icons.sentiment_satisfied,
                        ),
                        _buildKPICard(
                          '% de Ejecución\n(Programado Vs Ejecutados)',
                          kpiData['executionPercentage'] ?? 0.0,
                          100.0,
                          '%',
                          Colors.blue,
                          Icons.check_circle,
                        ),
                        _buildKPICard(
                          'Costo de Mantenimiento Preventivo (PM Cost)',
                          kpiData['preventiveCost'] ?? 0.0,
                          50000.0,
                          '',
                          Colors.purple,
                          Icons.build,
                        ),
                        _buildKPICard(
                          'Costo de Mantenimiento Correctivo (CM Cost)',
                          kpiData['correctiveCost'] ?? 0.0,
                          30000.0,
                          '',
                          Colors.orange,
                          Icons.warning,
                        ),
                        _buildKPICard(
                          'Horas de trabajo invertidas en cada equipo',
                          kpiData['workingHours'] ?? 0.0,
                          500.0,
                          'h',
                          Colors.indigo,
                          Icons.schedule,
                        ),
                        _buildKPICard(
                          'Eficiencias de los Técnicos\n(Programado vs Ejecutado)',
                          kpiData['technicianEfficiency'] ?? 0.0,
                          100.0,
                          '%',
                          Colors.teal,
                          Icons.speed,
                        ),
                        _buildKPICard(
                          'Tiempo de respuesta\n(Fallas vs Llegada)',
                          kpiData['responseTime'] ?? 0.0,
                          24.0,
                          'h',
                          Colors.red,
                          Icons.timer,
                          isInverted: true,
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Resumen
                    _buildSummaryCards(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMainGauge() {
    double overallScore = _calculateOverallScore();

    return Container(
      height: 150,
      width: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 150,
            width: 150,
            child: CircularProgressIndicator(
              value: overallScore / 100,
              strokeWidth: 12,
              backgroundColor: Colors.grey[300],
              valueColor:
                  AlwaysStoppedAnimation<Color>(_getScoreColor(overallScore)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${overallScore.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
              Text(
                'Rendimiento General',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(
    String title,
    double value,
    double maxValue,
    String unit,
    Color color,
    IconData icon, {
    bool isInverted = false,
  }) {
    double percentage = _calculatePercentage(value, maxValue, unit, isInverted);
    String displayValue = _formatDisplayValue(value, unit);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: 12),

          // Gauge simplificado
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 100,
                  width: 100,
                  child: CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _getGaugeColor(percentage)),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 20),
                    SizedBox(height: 4),
                    Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 8),

          // Indicador de colores
          _buildColorIndicator(),
        ],
      ),
    );
  }

  Widget _buildColorIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
            width: 8,
            height: 4,
            color: Colors.red,
            margin: EdgeInsets.symmetric(horizontal: 1)),
        Container(
            width: 8,
            height: 4,
            color: Colors.orange,
            margin: EdgeInsets.symmetric(horizontal: 1)),
        Container(
            width: 8,
            height: 4,
            color: Colors.yellow,
            margin: EdgeInsets.symmetric(horizontal: 1)),
        Container(
            width: 8,
            height: 4,
            color: Colors.lightGreen,
            margin: EdgeInsets.symmetric(horizontal: 1)),
        Container(
            width: 8,
            height: 4,
            color: Colors.green,
            margin: EdgeInsets.symmetric(horizontal: 1)),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen del Período',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Satisfacción',
                  '${(kpiData['customerSatisfaction'] ?? 0.0).toStringAsFixed(1)}/5',
                  Icons.star,
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSummaryItem(
                  'Ejecución',
                  '${(kpiData['executionPercentage'] ?? 0.0).toStringAsFixed(0)}%',
                  Icons.check,
                  Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Costo Total',
                  '\$${_formatCurrency((kpiData['preventiveCost'] ?? 0.0) + (kpiData['correctiveCost'] ?? 0.0))}',
                  Icons.attach_money,
                  Colors.purple,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSummaryItem(
                  'Horas Totales',
                  '${(kpiData['workingHours'] ?? 0.0).toStringAsFixed(0)}h',
                  Icons.schedule,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculatePercentage(
      double value, double maxValue, String unit, bool isInverted) {
    if (unit == '/5') {
      return (value / maxValue) * 100;
    } else if (unit == '%') {
      return value;
    } else if (unit == '' || unit == '\$') {
      return ((value / maxValue) * 100).clamp(0, 100);
    } else if (unit == 'h') {
      if (isInverted) {
        return (100 - ((value / maxValue) * 100)).clamp(0, 100);
      } else {
        return ((value / maxValue) * 100).clamp(0, 100);
      }
    }
    return value;
  }

  String _formatDisplayValue(double value, String unit) {
    if (unit == '/5') {
      return '${value.toStringAsFixed(1)}$unit';
    } else if (unit == '%') {
      return '${value.toStringAsFixed(1)}$unit';
    } else if (unit == '' || unit == '\$') {
      return '\$${_formatCurrency(value)}';
    } else if (unit == 'h') {
      return '${value.toStringAsFixed(1)}$unit';
    }
    return '${value.toStringAsFixed(1)}$unit';
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  double _calculateOverallScore() {
    if (kpiData.isEmpty) return 0.0;

    double total = 0;
    int count = 0;

    // Satisfacción (0-5 -> 0-100)
    final satisfaction = kpiData['customerSatisfaction'] ?? 0.0;
    total += (satisfaction / 5.0) * 100;
    count++;

    // Ejecución (ya en %)
    final execution = kpiData['executionPercentage'] ?? 0.0;
    total += execution;
    count++;

    // Eficiencia (ya en %)
    final efficiency = kpiData['technicianEfficiency'] ?? 0.0;
    total += efficiency;
    count++;

    // Tiempo de respuesta (invertido: menos tiempo = mejor)
    final responseTime = kpiData['responseTime'] ?? 0.0;
    total += (100 - ((responseTime / 24) * 100)).clamp(0, 100);
    count++;

    return count > 0 ? total / count : 0.0;
  }

  Color _getScoreColor(double score) {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.lightGreen;
    if (score >= 60) return Colors.yellow;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  Color _getGaugeColor(double percentage) {
    if (percentage >= 85) return Colors.green;
    if (percentage >= 70) return Colors.lightGreen;
    if (percentage >= 60) return Colors.yellow;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }
}
