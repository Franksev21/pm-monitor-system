import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerSurvey {
  final String? id;
  final String clientId;
  final String clientName;
  final String maintenanceId;
  final String equipmentId;
  final String equipmentNumber;
  final String technicianId;
  final String technicianName;

  // Las 5 preguntas (calificación de 1-5)
  final int serviceQuality; // Calidad del servicio
  final int responseTime; // Tiempo de respuesta
  final int technicianProfessionalism; // Profesionalismo del técnico
  final int problemResolution; // Resolución del problema
  final int overallSatisfaction; // Satisfacción general

  final String? comments; // Comentarios adicionales
  final double averageRating; // Promedio automático
  final DateTime createdAt;
  final bool isCompleted;

  CustomerSurvey({
    this.id,
    required this.clientId,
    required this.clientName,
    required this.maintenanceId,
    required this.equipmentId,
    required this.equipmentNumber,
    required this.technicianId,
    required this.technicianName,
    required this.serviceQuality,
    required this.responseTime,
    required this.technicianProfessionalism,
    required this.problemResolution,
    required this.overallSatisfaction,
    this.comments,
    required this.averageRating,
    required this.createdAt,
    this.isCompleted = false,
  });

  // Calcular promedio automáticamente
  static double calculateAverage(int q1, int q2, int q3, int q4, int q5) {
    return (q1 + q2 + q3 + q4 + q5) / 5.0;
  }

  factory CustomerSurvey.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CustomerSurvey(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      maintenanceId: data['maintenanceId'] ?? '',
      equipmentId: data['equipmentId'] ?? '',
      equipmentNumber: data['equipmentNumber'] ?? '',
      technicianId: data['technicianId'] ?? '',
      technicianName: data['technicianName'] ?? '',
      serviceQuality: data['serviceQuality'] ?? 0,
      responseTime: data['responseTime'] ?? 0,
      technicianProfessionalism: data['technicianProfessionalism'] ?? 0,
      problemResolution: data['problemResolution'] ?? 0,
      overallSatisfaction: data['overallSatisfaction'] ?? 0,
      comments: data['comments'],
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isCompleted: data['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'maintenanceId': maintenanceId,
      'equipmentId': equipmentId,
      'equipmentNumber': equipmentNumber,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'serviceQuality': serviceQuality,
      'responseTime': responseTime,
      'technicianProfessionalism': technicianProfessionalism,
      'problemResolution': problemResolution,
      'overallSatisfaction': overallSatisfaction,
      'comments': comments,
      'averageRating': averageRating,
      'createdAt': Timestamp.fromDate(createdAt),
      'isCompleted': isCompleted,
    };
  }

  CustomerSurvey copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? maintenanceId,
    String? equipmentId,
    String? equipmentNumber,
    String? technicianId,
    String? technicianName,
    int? serviceQuality,
    int? responseTime,
    int? technicianProfessionalism,
    int? problemResolution,
    int? overallSatisfaction,
    String? comments,
    double? averageRating,
    DateTime? createdAt,
    bool? isCompleted,
  }) {
    return CustomerSurvey(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      maintenanceId: maintenanceId ?? this.maintenanceId,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentNumber: equipmentNumber ?? this.equipmentNumber,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      serviceQuality: serviceQuality ?? this.serviceQuality,
      responseTime: responseTime ?? this.responseTime,
      technicianProfessionalism:
          technicianProfessionalism ?? this.technicianProfessionalism,
      problemResolution: problemResolution ?? this.problemResolution,
      overallSatisfaction: overallSatisfaction ?? this.overallSatisfaction,
      comments: comments ?? this.comments,
      averageRating: averageRating ?? this.averageRating,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
