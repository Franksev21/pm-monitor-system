import 'package:flutter/material.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_calendar_model.dart';

class MaintenanceStatsWidget extends StatelessWidget {
  final List<MaintenanceSchedule> maintenances;
  final VoidCallback? onTap;

  const MaintenanceStatsWidget({
    super.key,
    required this.maintenances,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return Card(
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estadísticas del Mes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Total',
                      stats['total'].toString(),
                      Icons.calendar_today,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Programados',
                      stats['scheduled'].toString(),
                      Icons.schedule,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Completados',
                      stats['completed'].toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Vencidos',
                      stats['overdue'].toString(),
                      Icons.warning,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              if (stats['efficiency'] != null) ...[
                const SizedBox(height: 16),
                _buildEfficiencyIndicator(stats['efficiency'] as double),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyIndicator(double efficiency) {
    Color efficiencyColor;
    String efficiencyText;

    if (efficiency >= 0.9) {
      efficiencyColor = Colors.green;
      efficiencyText = 'Excelente';
    } else if (efficiency >= 0.7) {
      efficiencyColor = Colors.orange;
      efficiencyText = 'Buena';
    } else {
      efficiencyColor = Colors.red;
      efficiencyText = 'Necesita mejora';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Eficiencia',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              efficiencyText,
              style: TextStyle(
                color: efficiencyColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: efficiency,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(efficiencyColor),
        ),
        const SizedBox(height: 4),
        Text(
          '${(efficiency * 100).toInt()}% de mantenimientos completados a tiempo',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateStats() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    // Filtrar mantenimientos del mes actual
    final monthlyMaintenances = maintenances.where((maintenance) {
      return maintenance.scheduledDate
              .isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
          maintenance.scheduledDate
              .isBefore(endOfMonth.add(const Duration(days: 1)));
    }).toList();

    int total = monthlyMaintenances.length;
    int scheduled = 0;
    int inProgress = 0;
    int completed = 0;
    int overdue = 0;
    int cancelled = 0;

    int completedOnTime = 0; // Para calcular eficiencia

    for (final maintenance in monthlyMaintenances) {
      switch (maintenance.status) {
        case MaintenanceStatus.scheduled:
          if (maintenance.isOverdue) {
            overdue++;
          } else {
            scheduled++;
          }
          break;
        case MaintenanceStatus.inProgress:
          inProgress++;
          break;
        case MaintenanceStatus.completed:
          completed++;
          // Verificar si se completó a tiempo para calcular eficiencia
          if (maintenance.completedDate != null &&
              maintenance.completedDate!.isBefore(
                  maintenance.scheduledDate.add(const Duration(hours: 24)))) {
            completedOnTime++;
          }
          break;
        case MaintenanceStatus.overdue:
          overdue++;
          break;
        case MaintenanceStatus.cancelled:
          cancelled++;
          break;
      }
    }

    // Calcular eficiencia (mantenimientos completados a tiempo vs total completados)
    double? efficiency;
    if (completed > 0) {
      efficiency = completedOnTime / completed;
    }

    return {
      'total': total,
      'scheduled': scheduled,
      'inProgress': inProgress,
      'completed': completed,
      'overdue': overdue,
      'cancelled': cancelled,
      'efficiency': efficiency,
      'completedOnTime': completedOnTime,
    };
  }
}
