import 'package:flutter/material.dart';

enum KPIType {
  customerSatisfaction,
  executionPercentage,
  preventiveCost,
  correctiveCost,
  workingHours,
  technicianEfficiency,
  responseTime,
}

enum KPITrend {
  increasing,
  decreasing,
  stable,
}

class KPIData {
  final String id;
  final KPIType type;
  final String title;
  final String subtitle;
  final dynamic value; // Puede ser double, int, String
  final String unit; // %, $, horas, etc.
  final String displayValue; // Valor formateado para mostrar
  final KPITrend trend;
  final double? trendPercentage;
  final Color color;
  final IconData icon;
  final DateTime calculatedAt;
  final Map<String, dynamic>? metadata; // Datos adicionales para cálculo

  KPIData({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.displayValue,
    required this.trend,
    this.trendPercentage,
    required this.color,
    required this.icon,
    required this.calculatedAt,
    this.metadata,
  });

  String get trendText {
    if (trendPercentage == null) return '';

    final sign = trend == KPITrend.increasing
        ? '+'
        : trend == KPITrend.decreasing
            ? '-'
            : '';
    return '$sign${trendPercentage!.abs().toStringAsFixed(1)}%';
  }

  Color get trendColor {
    // Para algunos KPIs, el aumento es bueno, para otros es malo
    bool isIncreaseGood = _isIncreasePositive(type);

    switch (trend) {
      case KPITrend.increasing:
        return isIncreaseGood ? Colors.green : Colors.red;
      case KPITrend.decreasing:
        return isIncreaseGood ? Colors.red : Colors.green;
      case KPITrend.stable:
        return Colors.grey;
    }
  }

  bool _isIncreasePositive(KPIType type) {
    switch (type) {
      case KPIType.customerSatisfaction:
      case KPIType.executionPercentage:
      case KPIType.technicianEfficiency:
        return true; // Aumento es bueno
      case KPIType.preventiveCost:
      case KPIType.correctiveCost:
      case KPIType.responseTime:
        return false; // Aumento es malo
      case KPIType.workingHours:
        return true; // Depende del contexto, por defecto bueno
    }
  }
}

class ClientSatisfactionData {
  final String clientId;
  final String clientName;
  final double satisfactionScore; // 1-5
  final int totalSurveys;
  final DateTime lastSurveyDate;
  final Map<String, int> responses; // pregunta -> puntuación

  ClientSatisfactionData({
    required this.clientId,
    required this.clientName,
    required this.satisfactionScore,
    required this.totalSurveys,
    required this.lastSurveyDate,
    required this.responses,
  });
}

class MaintenanceExecutionData {
  final int scheduled;
  final int completed;
  final int inProgress;
  final int overdue;
  final int cancelled;
  final double executionPercentage;
  final DateTime periodStart;
  final DateTime periodEnd;

  MaintenanceExecutionData({
    required this.scheduled,
    required this.completed,
    required this.inProgress,
    required this.overdue,
    required this.cancelled,
    required this.executionPercentage,
    required this.periodStart,
    required this.periodEnd,
  });

  int get total => scheduled + completed + inProgress + overdue + cancelled;
}

class CostAnalysisData {
  final double totalPreventiveCost;
  final double totalCorrectiveCost;
  final double totalCost;
  final int preventiveMaintenances;
  final int correctiveMaintenances;
  final double averagePreventiveCost;
  final double averageCorrectiveCost;
  final DateTime periodStart;
  final DateTime periodEnd;

  CostAnalysisData({
    required this.totalPreventiveCost,
    required this.totalCorrectiveCost,
    required this.preventiveMaintenances,
    required this.correctiveMaintenances,
    required this.periodStart,
    required this.periodEnd,
  })  : totalCost = totalPreventiveCost + totalCorrectiveCost,
        averagePreventiveCost = preventiveMaintenances > 0
            ? totalPreventiveCost / preventiveMaintenances
            : 0,
        averageCorrectiveCost = correctiveMaintenances > 0
            ? totalCorrectiveCost / correctiveMaintenances
            : 0;

  double get costEfficiencyRatio {
    return totalCorrectiveCost > 0
        ? totalPreventiveCost / totalCorrectiveCost
        : 0;
  }
}

class TechnicianEfficiencyData {
  final String technicianId;
  final String technicianName;
  final double plannedHours;
  final double actualHours;
  final int completedMaintenances;
  final int assignedMaintenances;
  final double efficiencyPercentage;
  final double qualityScore; // Basado en feedback del cliente
  final DateTime periodStart;
  final DateTime periodEnd;

  TechnicianEfficiencyData({
    required this.technicianId,
    required this.technicianName,
    required this.plannedHours,
    required this.actualHours,
    required this.completedMaintenances,
    required this.assignedMaintenances,
    required this.qualityScore,
    required this.periodStart,
    required this.periodEnd,
  }) : efficiencyPercentage = assignedMaintenances > 0
            ? (completedMaintenances / assignedMaintenances) * 100
            : 0;

  double get timeEfficiency {
    return plannedHours > 0 ? (plannedHours / actualHours) * 100 : 0;
  }
}

class ResponseTimeData {
  final String equipmentId;
  final String equipmentName;
  final DateTime failureReportedAt;
  final DateTime? technicianArrivedAt;
  final DateTime? maintenanceStartedAt;
  final DateTime? maintenanceCompletedAt;
  final double responseTimeHours;
  final double resolutionTimeHours;
  final String priority; // high, medium, low

  ResponseTimeData({
    required this.equipmentId,
    required this.equipmentName,
    required this.failureReportedAt,
    this.technicianArrivedAt,
    this.maintenanceStartedAt,
    this.maintenanceCompletedAt,
    required this.priority,
  })  : responseTimeHours = technicianArrivedAt != null
            ? technicianArrivedAt.difference(failureReportedAt).inMinutes / 60.0
            : 0,
        resolutionTimeHours = maintenanceCompletedAt != null
            ? maintenanceCompletedAt.difference(failureReportedAt).inMinutes /
                60.0
            : 0;

  bool get isWithinSLA {
    // SLA basado en prioridad
    switch (priority) {
      case 'high':
        return responseTimeHours <= 2; // 2 horas máximo
      case 'medium':
        return responseTimeHours <= 8; // 8 horas máximo
      case 'low':
        return responseTimeHours <= 24; // 24 horas máximo
      default:
        return responseTimeHours <= 8;
    }
  }
}
