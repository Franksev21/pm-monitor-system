// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
// import 'package:pm_monitor/core/models/kpi_model.dart';
// import 'package:pm_monitor/core/models/maintenance_calendar_model.dart';


// class KPIService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
//   // Singleton pattern
//   static final KPIService _instance = KPIService._internal();
//   factory KPIService() => _instance;
//   KPIService._internal();

//   /// Calcular todos los KPIs principales
//   Future<List<KPIData>> calculateAllKPIs({
//     String? clientId,
//     String? technicianId,
//     DateTime? startDate,
//     DateTime? endDate,
//   }) async {
//     final period = _getDefaultPeriod(startDate, endDate);
    
//     try {
//       final kpis = await Future.wait([
//         _calculateCustomerSatisfaction(clientId, period['start'], period['end']),
//         _calculateExecutionPercentage(clientId, technicianId, period['start'], period['end']),
//         _calculatePreventiveCost(clientId, period['start'], period['end']),
//         _calculateCorrectiveCost(clientId, period['start'], period['end']),
//         _calculateWorkingHours(technicianId, period['start'], period['end']),
//         _calculateTechnicianEfficiency(technicianId, period['start'], period['end']),
//         _calculateResponseTime(clientId, period['start'], period['end']),
//       ]);

//       return kpis;
//     } catch (e) {
//       debugPrint('Error calculando KPIs: $e');
//       return _getEmptyKPIs();
//     }
//   }

//   /// 1. Nivel de satisfacción del cliente
//   Future<KPIData> _calculateCustomerSatisfaction(
//     String? clientId, 
//     DateTime startDate, 
//     DateTime endDate
//   ) async {
//     try {
//       Query query = _firestore.collection('customerSurveys')
//           .where('createdAt', isGreaterThanOrEqualTo: startDate)
//           .where('createdAt', isLessThanOrEqualTo: endDate);

//       if (clientId != null) {
//         query = query.where('clientId', isEqualTo: clientId);
//       }

//       final surveys = await query.get();
      
//       if (surveys.docs.isEmpty) {
//         return KPIData(
//           id: 'customer_satisfaction',
//           type: KPIType.customerSatisfaction,
//           title: 'Satisfacción del Cliente',
//           subtitle: 'Promedio de encuestas',
//           value: 0.0,
//           unit: '/5',
//           displayValue: '0.0',
//           trend: KPITrend.stable,
//           color: Colors.orange,
//           icon: Icons.sentiment_satisfied,
//           calculatedAt: DateTime.now(),
//         );
//       }

//       double totalScore = 0;
//       int count = 0;

//       for (var doc in surveys.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final responses = data['responses'] as Map<String, dynamic>?;
        
//         if (responses != null) {
//           double surveyAverage = 0;
//           int questionCount = 0;
          
//           responses.forEach((question, score) {
//             if (score is num) {
//               surveyAverage += score.toDouble();
//               questionCount++;
//             }
//           });
          
//           if (questionCount > 0) {
//             totalScore += surveyAverage / questionCount;
//             count++;
//           }
//         }
//       }

//       final currentScore = count > 0 ? totalScore / count : 0.0;
//       final previousScore = await _getPreviousPeriodSatisfaction(clientId, startDate);
//       final trend = _calculateTrend(currentScore, previousScore);

//       return KPIData(
//         id: 'customer_satisfaction',
//         type: KPIType.customerSatisfaction,
//         title: 'Satisfacción del Cliente',
//         subtitle: 'Promedio de $count encuestas',
//         value: currentScore,
//         unit: '/5',
//         displayValue: currentScore.toStringAsFixed(1),
//         trend: trend['trend'],
//         trendPercentage: trend['percentage'],
//         color: _getSatisfactionColor(currentScore),
//         icon: Icons.sentiment_satisfied,
//         calculatedAt: DateTime.now(),
//         metadata: {
//           'totalSurveys': count,
//           'totalResponses': surveys.docs.length,
//         },
//       );
//     } catch (e) {
//       debugPrint('Error calculando satisfacción del cliente: $e');
//       return _getErrorKPI(KPIType.customerSatisfaction);
//     }
//   }

//   /// 2. Porcentaje de ejecución (Programado vs Ejecutado)
//   Future<KPIData> _calculateExecutionPercentage(
//     String? clientId,
//     String? technicianId,
//     DateTime startDate,
//     DateTime endDate,
//   ) async {
//     try {
//       Query query = _firestore.collection('maintenanceSchedules')
//           .where('scheduledDate', isGreaterThanOrEqualTo: startDate)
//           .where('scheduledDate', isLessThanOrEqualTo: endDate);

//       if (clientId != null) {
//         query = query.where('clientId', isEqualTo: clientId);
//       }
//       if (technicianId != null) {
//         query = query.where('technicianId', isEqualTo: technicianId);
//       }

//       final maintenances = await query.get();
      
//       int scheduled = 0;
//       int completed = 0;
//       int total = maintenances.docs.length;

//       for (var doc in maintenances.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final status = data['status'] as String;
        
//         if (status == 'scheduled' || status == 'inProgress' || status == 'overdue') {
//           scheduled++;
//         } else if (status == 'completed') {
//           completed++;
//         }
//       }

//       final executionPercentage = total > 0 ? (completed / total) * 100 : 0.0;
//       final previousPercentage = await _getPreviousPeriodExecution(clientId, technicianId, startDate);
//       final trend = _calculateTrend(executionPercentage, previousPercentage);

//       return KPIData(
//         id: 'execution_percentage',
//         type: KPIType.executionPercentage,
//         title: '% de Ejecución',
//         subtitle: '$completed de $total completados',
//         value: executionPercentage,
//         unit: '%',
//         displayValue: '${executionPercentage.toStringAsFixed(1)}%',
//         trend: trend['trend'],
//         trendPercentage: trend['percentage'],
//         color: _getPercentageColor(executionPercentage),
//         icon: Icons.check_circle_outline,
//         calculatedAt: DateTime.now(),
//         metadata: {
//           'scheduled': scheduled,
//           'completed': completed,
//           'total': total,
//         },
//       );
//     } catch (e) {
//       debugPrint('Error calculando porcentaje de ejecución: $e');
//       return _getErrorKPI(KPIType.executionPercentage);
//     }
//   }

//   /// 3. Costo de Mantenimiento Preventivo
//   Future<KPIData> _calculatePreventiveCost(
//     String? clientId,
//     DateTime startDate,
//     DateTime endDate,
//   ) async {
//     try {
//       Query query = _firestore.collection('maintenanceSchedules')
//           .where('type', isEqualTo: 'preventive')
//           .where('scheduledDate', isGreaterThanOrEqualTo: startDate)
//           .where('scheduledDate', isLessThanOrEqualTo: endDate);

//       if (clientId != null) {
//         query = query.where('clientId', isEqualTo: clientId);
//       }

//       final maintenances = await query.get();
      
//       double totalCost = 0;
//       int count = 0;

//       for (var doc in maintenances.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final actualCost = data['actualCost'] as double?;
//         final estimatedCost = data['estimatedCost'] as double?;
        
//         final cost = actualCost ?? estimatedCost ?? 0;
//         totalCost += cost;
//         if (cost > 0) count++;
//       }

//       final previousCost = await _getPreviousPeriodPreventiveCost(clientId, startDate);
//       final trend = _calculateTrend(totalCost, previousCost);

//       return KPIData(
//         id: 'preventive_cost',
//         type: KPIType.preventiveCost,
//         title: 'Costo PM',
//         subtitle: 'Mantenimiento Preventivo',
//         value: totalCost,
//         unit: '\$',
//         displayValue: '\$${totalCost.toStringAsFixed(2)}',
//         trend: trend['trend'],
//         trendPercentage: trend['percentage'],
//         color: Colors.blue,
//         icon: Icons.build_circle,
//         calculatedAt: DateTime.now(),
//         metadata: {
//           'totalMaintenances': maintenances.docs.length,
//           'averageCost': count > 0 ? totalCost / count : 0,
//         },
//       );
//     } catch (e) {
//       debugPrint('Error calculando costo preventivo: $e');
//       return _getErrorKPI(KPIType.preventiveCost);
//     }
//   }

//   /// 4. Costo de Mantenimiento Correctivo
//   Future<KPIData> _calculateCorrectiveCost(
//     String? clientId,
//     DateTime startDate,
//     DateTime endDate,
//   ) async {
//     try {
//       Query query = _firestore.collection('maintenanceSchedules')
//           .where('type', isEqualTo: 'corrective')
//           .where('scheduledDate', isGreaterThanOrEqualTo: startDate)
//           .where('scheduledDate', isLessThanOrEqualTo: endDate);

//       if (clientId != null) {
//         query = query.where('clientId', isEqualTo: clientId);
//       }

//       final maintenances = await query.get();
      
//       double totalCost = 0;
//       int count = 0;

//       for (var doc in maintenances.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final actualCost = data['actualCost'] as double?;
//         final estimatedCost = data['estimatedCost'] as double?;
        
//         final cost = actualCost ?? estimatedCost ?? 0;
//         totalCost += cost;
//         if (cost > 0) count++;
//       }

//       final previousCost = await _getPreviousPeriodCorrectiveCost(clientId, startDate);
//       final trend = _calculateTrend(totalCost, previousCost);

//       return KPIData(
//         id: 'corrective_cost',
//         type: KPIType.correctiveCost,
//         title: 'Costo CM',
//         subtitle: 'Mantenimiento Correctivo',
//         value: totalCost,
//         unit: '\$',
//         displayValue: '\$${totalCost.toStringAsFixed(2)}',
//         trend: trend['trend'],
//         trendPercentage: trend['percentage'],
//         color: Colors.red,
//         icon: Icons.warning_amber,
//         calculatedAt: DateTime.now(),
//         metadata: {
//           'totalMaintenances': maintenances.docs.length,
//           'averageCost': count > 0 ? totalCost / count : 0,
//         },
//       );
//     } catch (e) {
//       debugPrint('Error calculando costo correctivo: $e');
//       return _getErrorKPI(KPIType.correctiveCost);
//     }
//   }

//   /// 5. Horas de trabajo invertidas
//   Future<KPIData> _calculateWorkingHours(
//     String? technicianId,
//     DateTime startDate,
//     DateTime endDate,
//   ) async {
//     try {
//       Query query = _firestore.collection('maintenanceSchedules')
//           .where('status', isEqualTo: 'completed')
//           .where('completedDate', isGreaterThanOrEqualTo: startDate)
//           .where('completedDate', isLessThanOrEqualTo: endDate);

//       if (technicianId != null) {
//         query = query.where('technicianId', isEqualTo: technicianId);
//       }

//       final maintenances = await query.get();
      
//       double totalHours = 0;
//       int count = maintenances.docs.length;

//       for (var doc in maintenances.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final duration = data['estimatedDurationMinutes'] as int? ?? 0;
//         totalHours += duration / 60.0;
//       }

//       final previousHours = await _getPreviousPeriodWorkingHours(technicianId, startDate);
//       final trend = _calculateTrend(totalHours, previousHours);

//       return KPIData(
//         id: 'working_hours',
//         type: KPIType.workingHours,
//         title: 'Horas Trabajadas',
//         subtitle: '$count mantenimientos',
//         value: totalHours,
//         unit: 'hrs',
//         displayValue: '${totalHours.toStringAsFixed(1)}h',
//         trend: trend['trend'],
//         trendPercentage: trend['percentage'],
//         color: Colors.purple,
//         icon: Icons.schedule,
//         calculatedAt: DateTime.now(),
//         metadata: {
//           'totalMaintenances': count,
//           'averageHoursPerMaintenance': count > 0 ? totalHours / count : 0,
//         },
//       );
//     } catch (e) {
//       debugPrint('Error calculando horas de trabajo: $e');
//       return _getErrorKPI(KPIType.workingHours);
//     }
//   }

//   /// 6. Eficiencia de técnicos
//   Future<KPIData> _calculateTechnicianEfficiency(
//     String? technicianId,
//     DateTime startDate,
//     DateTime endDate,
//   ) async {
//     try {
//       Query query = _firestore.collection('maintenanceSchedules')
//           .where('scheduledDate', isGreaterThanOrEqualTo: startDate)
//           .where('scheduledDate', isLessThanOrEqualTo: endDate);

//       if (technicianId != null) {
//         query = query.where('technicianId', isEqualTo: technicianId);
//       }

//       final maintenances = await query.get();
      
//       int totalAssigned = 0;
//       int completedOnTime = 0;
//       int totalCompleted = 0;

//       for (var doc in maintenances.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final status = data['status'] as String;
//         final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();
//         final completedDate = data['completedDate'] != null 
//             ? (data['completedDate'] as Timestamp).toDate() 
//             : null;

//         totalAssigned++;

//         if (status == 'completed') {
//           totalCompleted++;
          
//           // Verificar si se completó a tiempo (dentro del día programado)
//           if (completedDate != null) {
//             final daysDifference = completedDate.difference(scheduledDate).inDays;
//             if (daysDifference <= 1) { // Completado el mismo día o máximo 1 día después
//               completedOnTime++;
//             }
//           }
//         }
//       }

//       final efficiency = totalAssigned > 0 ? (completedOnTime / totalAssigned) * 100 : 0.0;
//       final previousEfficiency = await _getPreviousPeriodEfficiency(technicianId, startDate);
//       final trend = _calculateTrend(efficiency, previousEfficiency);

//       return KPIData(
//         id: 'technician_efficiency',
//         type: KPIType.technicianEfficiency,
//         title: 'Eficiencia',
//         subtitle: '$completedOnTime de $totalAssigned a tiempo',
//         value: efficiency,
//         unit: '%',
//         displayValue: '${efficiency.toStringAsFixed(1)}%',
//         trend: trend['trend'],
//         trendPercentage: trend['percentage'],
//         color: _getPercentageColor(efficiency),
//         icon: Icons.speed,
//         calculatedAt: DateTime.now(),
//         metadata: {
//           'totalAssigned': totalAssigned,
//           'totalCompleted': totalCompleted,
//           'completedOnTime': completedOnTime,
//         },
//       );
//     } catch (e) {
//       debugPrint('Error calculando eficiencia de técnicos: $e');
//       return _getErrorKPI(KPIType.technicianEfficiency);
//     }
//   }

//   /// 7. Tiempo de respuesta a fallas
//   Future<KPIData> _calculateResponseTime(
//     String? clientId,
//     DateTime startDate,
//     DateTime endDate,
//   ) async {
//     try {
//       Query query = _firestore.collection('equipmentFailures')
//           .where('reportedAt', isGreaterThanOrEqualTo: startDate)
//           .where('reportedAt', isLessThanOrEqualTo: endDate);

//       if (clientId != null) {
//         query = query.where('clientId', isEqualTo: clientId);
//       }

//       final failures = await query.get();
      
//       if (failures.docs.isEmpty) {
//         return KPIData(
//           id: 'response_time',
//           type: KPIType.responseTime,
//           title: 'Tiempo de Respuesta',
//           subtitle: 'Sin fallas reportadas',
//           value: 0.0,
//           unit: 'hrs',
//           displayValue: '0h',
//           trend: KPITrend.stable,
//           color: Colors.green,
//           icon: Icons.timer,
//           calculatedAt: DateTime.now(),
//         );
//       }

//       double totalResponseTime = 0;
//       int count = 0;

//       for (var doc in failures.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final reportedAt = (data['reportedAt'] as Timestamp).toDate();
//         final respondedAt = data['respondedAt'] != null 
//             ? (data['respondedAt'] as Timestamp).toDate() 
//             : null;

//         if (respondedAt != null) {
//           final responseTime = respondedAt.difference(reportedAt).inMinutes / 60.0;
//           totalResponseTime += responseTime;
//           count++;
//         }
//       }

//       final averageResponseTime = count > 0 ? totalResponseTime / count : 0.0;
//       final previousResponseTime = await _getPreviousPeriodResponseTime(clientId, startDate);
//       final trend = _calculateTrend(averageResponseTime, previousResponseTime);

//       return KPIData(
//         id: 'response_time',
//         type: KPIType.responseTime,
//         title: 'Tiempo de Respuesta',
//         subtitle: 'Promedio de $count fallas',
//         value: averageResponseTime,
//         unit: 'hrs',
//         displayValue: '${averageResponseTime.toStringAsFixed(1)}h',
//         trend: trend['trend'],
//         trendPercentage: trend['percentage'],
//         color: _getResponseTimeColor(averageResponseTime),
//         icon: Icons.timer,
//         calculatedAt: DateTime.now(),
//         metadata: {
//           'totalFailures': failures.docs.length,
//           'respondedFailures': count,
//         },
//       );
//     } catch (e) {
//       debugPrint('Error calculando tiempo de respuesta: $e');
//       return _getErrorKPI(KPIType.responseTime);
//     }
//   }

//   // Métodos auxiliares para calcular tendencias del período anterior
//   Future<double> _getPreviousPeriodSatisfaction(String? clientId, DateTime currentStart) async {
//     final days = DateTime.now().difference(currentStart).inDays;
//     final previousStart = currentStart.subtract(Duration(days: days));
//     final previousEnd = currentStart.subtract(const Duration(days: 1));
    
//     try {
//       Query query = _firestore.collection('customerSurveys')
//           .where('createdAt', isGreaterThanOrEqualTo: previousStart)
//           .where('createdAt', isLessThanOrEqualTo: previousEnd);

//       if (clientId != null) {
//         query = query.where('clientId', isEqualTo: clientId);
//       }

//       final surveys = await query.get();
      
//       if (surveys.docs.isEmpty) return 0.0;

//       double totalScore = 0;
//       int count = 0;

//       for (var doc in surveys.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final responses = data['responses'] as Map<String, dynamic>?;
        
//         if (responses != null) {
//           double surveyAverage = 0;
//           int questionCount = 0;
          
//           responses.forEach((question, score) {
//             if (score is num) {
//               surveyAverage += score.toDouble();
//               questionCount++;
//             }
//           });
          
//           if (questionCount > 0) {
//             totalScore += surveyAverage / questionCount;
//             count++;
//           }
//         }
//       }

//       return count > 0 ? totalScore / count : 0.0;
//     } catch (e) {
//       return 0.0;
//     }
//   }

//   // Métodos auxiliares para otros períodos anteriores (implementación similar)
//   Future<double> _getPreviousPeriodExecution(String? clientId, String? technicianId, DateTime currentStart) async {
//     try {
//       final days = DateTime.now().difference(currentStart).inDays;
//       final previousStart = currentStart.subtract(Duration(days: days));
//       final previousEnd = currentStart.subtract(const Duration(days: 1));
      
//       Query query = _firestore.collection('maintenanceSchedules')
//           .where('scheduledDate', isGreaterThanOrEqualTo: previousStart)
//           .where('scheduledDate', isLessThanOrEqualTo: previousEnd);

//       if (clientId != null) query = query.where('clientId', isEqualTo: clientId);
//       if (technicianId != null) query = query.where('technicianId', isEqualTo: technicianId);

//       final maintenances = await query.get();
      
//       int completed = 0;
//       int total = maintenances.docs.length;

//       for (var doc in maintenances.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         if (data['status'] == 'completed') completed++;
//       }

//       return total > 0 ? (completed / total) * 100 : 0.0;
//     } catch (e) {
//       return 0.0;
//     }
//   }

//   Future<double> _getPreviousPeriodPreventiveCost(String? clientId, DateTime currentStart) async {
//     try {
//       final days = DateTime.now().difference(currentStart).inDays;
//       final previousStart = currentStart.subtract(Duration(days: days));
//       final previousEnd = currentStart.subtract(const Duration(days: 1));
      
//       Query query = _firestore.collection('maintenanceSchedules')
//           .where('type', isEqualTo: 'preventive')
//           .where('scheduledDate', isGreaterThanOrEqualTo: previousStart)
//           .where('scheduledDate', isLessThanOrEqualTo: previousEnd);

//       if (clientId != null) query = query.where('clientId', isEqualTo: clientId);

//       final maintenances = await query.get();
//       double totalCost = 0;

//       for (var doc in maintenances.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final cost = (data['actualCost'] ?? data['estimatedCost'] ?? 0) as double;
//         totalCost += cost;
//       }

//       return totalCost;
//     } catch (e) {
//       return 0.0;
//     }
//   }

//   Future<double> _getPreviousPeriodCorrectiveCost(String? clientId, DateTime currentStart) async {
//     try {
//       final days = DateTime.now().difference(currentStart).inDays;
//       final previousStart = currentStart.subtract(Duration(days: days));
//       final previousEnd = currentStart.subtract(const Duration(days: 1));
      
//       Query query = _firestore.collection('maintenanceSchedules')
//           .where('type', isEqualTo: 'corrective')
//           .where('scheduledDate', isGreaterThanOrEqualTo: previousStart)
//           .where('scheduledDate', isLessThanOrEqualTo: previousEnd);

//       if (clientId != null) query = query.where('clientId', isEqualTo: clientId);

//       final maintenances = await query.get();
//       double totalCost = 0;

//       for (var doc in maintenances.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final cost = (data['actualCost'] ?? data['estimatedCost'] ?? 0) as double;
//         totalCost += cost;
//       }

//       return totalCost;
//     } catch (e) {
//       return 0.0;
//     }
//   }

//   Future<double> _getPreviousPeriodWorkingHours(String? technicianId, DateTime currentStart) async {
//     try {
//       final days = DateTime.now().difference(currentStart).inDays;
//       final previousStart = currentStart.subtract(Duration(days: days));
//       final previousEnd = currentStart.subtract(const Duration(days: 1));
      
//       Query query = _firestore.collection('maintenanceSchedules')
//           .where('status', isEqualTo: 'completed')
//           .where('completedDate', isGreaterThanOrEqualTo: previousStart)
//           .where('completedDate', isLessThanOrEqualTo: previousEnd);

//       if (technicianId != null) query = query.where('technicianId', isEqualTo: technicianId);

//       final maintenances = await query.get();
//       double totalHours = 0;

//       for (var doc in maintenances.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final duration = data['estimatedDurationMinutes'] as int? ?? 0;
//         totalHours += duration / 60.0;
//       }

//       return totalHours;
//     } catch (e) {
//       return 0.0;
//     }
//   }

//   Future<double> _getPreviousPeriodEfficiency(String? technicianId, DateTime currentStart) async {
//     try {
//       final days = DateTime.now().difference(currentStart).inDays;
//       final previousStart = currentStart.subtract(Duration(days: days));
//       final previousEnd = currentStart.subtract(const Duration(days: 1));
      
//       Query query = _firestore.collection('maintenanceSchedules')
//           .where('scheduledDate', isGreaterThanOrEqualTo: previousStart)
//           .where('scheduledDate', isLessThanOrEqualTo: previousEnd);

//       if (technicianId != null) query = query.where('technicianId', isEqualTo: technicianId);

//       final maintenances = await query.get();
      
//       int totalAssigned = 0;
//       int completedOnTime = 0;

//       for (var doc in maintenances.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final status = data['status'] as String;
//         final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();
//         final completedDate = data['completedDate'] != null 
//             ? (data['completedDate'] as Timestamp).toDate() 
//             : null;

//         totalAssigned++;

//         if (status == 'completed' && completedDate != null) {
//           final daysDifference = completedDate.difference(scheduledDate).inDays;
//           if (daysDifference <= 1) {
//             completedOnTime++;
//           }
//         }
//       }

//       return totalAssigned > 0 ? (completedOnTime / totalAssigned) * 100 : 0.0;
//     } catch (e) {
//       return 0.0;
//     }
//   }

//   Future<double> _getPreviousPeriodResponseTime(String? clientId, DateTime currentStart) async {
//     try {
//       final days = DateTime.now().difference(currentStart).inDays;
//       final previousStart = currentStart.subtract(Duration(days: days));
//       final previousEnd = currentStart.subtract(const Duration(days: 1));
      
//       Query query = _firestore.collection('equipmentFailures')
//           .where('reportedAt', isGreaterThanOrEqualTo: previousStart)
//           .where('reportedAt', isLessThanOrEqualTo: previousEnd);

//       if (clientId != null) query = query.where('clientId', isEqualTo: clientId);

//       final failures = await query.get();
      
//       double totalResponseTime = 0;
//       int count = 0;

//       for (var doc in failures.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final reportedAt = (data['reportedAt'] as Timestamp).toDate();
//         final respondedAt = data['respondedAt'] != null 
//             ? (data['respondedAt'] as Timestamp).toDate() 
//             : null;

//         if (respondedAt != null) {
//           final responseTime = respondedAt.difference(reportedAt).inMinutes / 60.0;
//           totalResponseTime += responseTime;
//           count++;
//         }
//       }

//       return count > 0 ? totalResponseTime / count : 0.0;
//     } catch (e) {
//       return 0.0;
//     }
//   }

//   // Métodos auxiliares para cálculos
//   Map<String, dynamic> _calculateTrend(double current, double previous) {
//     if (previous == 0) {
//       return {'trend': KPITrend.stable, 'percentage': null};
//     }

//     final difference = current - previous;
//     final percentage = (difference / previous) * 100;

//     KPITrend trend;
//     if (percentage.abs() < 1) {
//       trend = KPITrend.stable;
//     } else if (difference > 0) {
//       trend = KPITrend.increasing;
//     } else {
//       trend = KPITrend.decreasing;
//     }

//     return {
//       'trend': trend,
//       'percentage': percentage.abs(),
//     };
//   }

//   Color _getSatisfactionColor(double score) {
//     if (score >= 4.0) return Colors.green;
//     if (score >= 3.0) return Colors.orange;
//     return Colors.red;
//   }

//   Color _getPercentageColor(double percentage) {
//     if (percentage >= 80) return Colors.green;
//     if (percentage >= 60) return Colors.orange;
//     return Colors.red;
//   }

//   Color _getResponseTimeColor(double hours) {
//     if (hours <= 2) return Colors.green;
//     if (hours <= 8) return Colors.orange;
//     return Colors.red;
//   }

//   Map<String, DateTime> _getDefaultPeriod(DateTime? startDate, DateTime? endDate) {
//     final now = DateTime.now();
//     return {
//       'start': startDate ?? DateTime(now.year, now.month, 1),
//       'end': endDate ?? now,
//     };
//   }

//   List<KPIData> _getEmptyKPIs() {
//     return [
//       _getErrorKPI(KPIType.customerSatisfaction),
//       _getErrorKPI(KPIType.executionPercentage),
//       _getErrorKPI(KPIType.preventiveCost),
//       _getErrorKPI(KPIType.correctiveCost),
//       _getErrorKPI(KPIType.workingHours),
//       _getErrorKPI(KPIType.technicianEfficiency),
//       _getErrorKPI(KPIType.responseTime),
//     ];
//   }

//   KPIData _getErrorKPI(KPIType type) {
//     final config = _getKPIConfig(type);
//     return KPIData(
//       id: config['id'],
//       type: type,
//       title: config['title'],
//       subtitle: 'Error al calcular',
//       value: 0,
//       unit: config['unit'],
//       displayValue: '0${config['unit']}',
//       trend: KPITrend.stable,
//       color: Colors.grey,
//       icon: config['icon'],
//       calculatedAt: DateTime.now(),
//     );
//   }

//   Map<String, dynamic> _getKPIConfig(KPIType type) {
//     switch (type) {
//       case KPIType.customerSatisfaction:
//         return {
//           'id': 'customer_satisfaction',
//           'title': 'Satisfacción del Cliente',
//           'unit': '/5',
//           'icon': Icons.sentiment_satisfied,
//         };
//       case KPIType.executionPercentage:
//         return {
//           'id': 'execution_percentage',
//           'title': '% de Ejecución',
//           'unit': '%',
//           'icon': Icons.check_circle_outline,
//         };
//       case KPIType.preventiveCost:
//         return {
//           'id': 'preventive_cost',
//           'title': 'Costo PM',
//           'unit': '\,
//           'icon': Icons.build_circle,
//         };
//       case KPIType.correctiveCost:
//         return {
//           'id': 'corrective_cost',
//           'title': 'Costo CM',
//           'unit': '\,
//           'icon': Icons.warning_amber,
//         };
//       case KPIType.workingHours:
//         return {
//           'id': 'working_hours',
//           'title': 'Horas Trabajadas',
//           'unit': 'h',
//           'icon': Icons.schedule,
//         };
//       case KPIType.technicianEfficiency:
//         return {
//           'id': 'technician_efficiency',
//           'title': 'Eficiencia',
//           'unit': '%',
//           'icon': Icons.speed,
//         };
//       case KPIType.responseTime:
//         return {
//           'id': 'response_time',
//           'title': 'Tiempo de Respuesta',
//           'unit': 'h',
//           'icon': Icons.timer,
//         };
//     }
//   }
// }