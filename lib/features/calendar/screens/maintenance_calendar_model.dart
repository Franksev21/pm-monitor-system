import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum MaintenanceStatus {
  scheduled, // Programado
  inProgress, // En progreso
  completed, // Completado
  overdue, // Vencido
  cancelled // Cancelado
}

enum MaintenanceType {
  preventive, // Preventivo
  corrective, // Correctivo
  emergency, // Emergencia
  inspection // Inspección
}

enum FrequencyType {
  weekly, // Semanal
  biweekly, // Bi-semanal
  monthly, // Mensual
  quarterly, // Trimestral
  biannual, // Semestral
  annual, // Anual
  custom // Personalizado
}

class MaintenanceSchedule {
  final String id;
  final String equipmentId;
  final String equipmentName;
  final String clientId;
  final String clientName;
  final String? technicianId;
  final String? technicianName;
  final String? supervisorId;
  final String? supervisorName;
  final DateTime scheduledDate;
  final DateTime? completedDate;
  final MaintenanceStatus status;
  final MaintenanceType type;
  final FrequencyType frequency;
  final String? notes;
  final List<String> tasks;
  final int estimatedDurationMinutes;
  final double? estimatedCost;
  final double? actualCost;
  final String? location;
  final List<String> photoUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? completedBy;
  final int? completionPercentage;
  final Map<String, bool>? taskCompletion;

  MaintenanceSchedule({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.clientId,
    required this.clientName,
    this.technicianId,
    this.technicianName,
    this.supervisorId,
    this.supervisorName,
    required this.scheduledDate,
    this.completedDate,
    required this.status,
    required this.type,
    required this.frequency,
    this.notes,
    required this.tasks,
    required this.estimatedDurationMinutes,
    this.estimatedCost,
    this.actualCost,
    this.location,
    required this.photoUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.completedBy,
    this.completionPercentage = 0,
    this.taskCompletion,
  });

  factory MaintenanceSchedule.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return MaintenanceSchedule(
      id: doc.id,
      equipmentId: data['equipmentId'] ?? '',
      equipmentName: data['equipmentName'] ?? '',
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      technicianId: data['technicianId'],
      technicianName: data['technicianName'],
      supervisorId: data['supervisorId'],
      supervisorName: data['supervisorName'],
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      completedDate: data['completedDate'] != null
          ? (data['completedDate'] as Timestamp).toDate()
          : null,
      status: MaintenanceStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => MaintenanceStatus.scheduled,
      ),
      type: MaintenanceType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => MaintenanceType.preventive,
      ),
      frequency: FrequencyType.values.firstWhere(
        (e) => e.toString().split('.').last == data['frequency'],
        orElse: () => FrequencyType.monthly,
      ),
      notes: data['notes'],
      tasks: List<String>.from(data['tasks'] ?? []),
      // CORREGIDO: Manejo seguro de conversión de tipos numéricos
      estimatedDurationMinutes:
          _safeIntFromDynamic(data['estimatedDurationMinutes']) ?? 60,
      estimatedCost: _safeDoubleFromDynamic(data['estimatedCost']),
      actualCost: _safeDoubleFromDynamic(data['actualCost']),
      location: data['location'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      completedBy: data['completedBy'],
      // CORREGIDO: Manejo seguro de porcentaje de completación
      completionPercentage:
          _safeIntFromDynamic(data['completionPercentage']) ?? 0,
      taskCompletion: data['taskCompletion'] != null
          ? Map<String, bool>.from(data['taskCompletion'])
          : null,
    );
  }

  // MÉTODOS AUXILIARES PARA CONVERSIÓN SEGURA DE TIPOS
  static int? _safeIntFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _safeDoubleFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'clientId': clientId,
      'clientName': clientName,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'completedDate':
          completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'frequency': frequency.toString().split('.').last,
      'notes': notes,
      'tasks': tasks,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'estimatedCost': estimatedCost,
      'actualCost': actualCost,
      'location': location,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'completedBy': completedBy,
      'completionPercentage': completionPercentage,
      'taskCompletion': taskCompletion,
    };
  }

  MaintenanceSchedule copyWith({
    String? id,
    String? equipmentId,
    String? equipmentName,
    String? clientId,
    String? clientName,
    String? technicianId,
    String? technicianName,
    String? supervisorId,
    String? supervisorName,
    DateTime? scheduledDate,
    DateTime? completedDate,
    MaintenanceStatus? status,
    MaintenanceType? type,
    FrequencyType? frequency,
    String? notes,
    List<String>? tasks,
    int? estimatedDurationMinutes,
    double? estimatedCost,
    double? actualCost,
    String? location,
    List<String>? photoUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? completedBy,
    int? completionPercentage,
    Map<String, bool>? taskCompletion,
  }) {
    return MaintenanceSchedule(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentName: equipmentName ?? this.equipmentName,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      status: status ?? this.status,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      notes: notes ?? this.notes,
      tasks: tasks ?? this.tasks,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
      location: location ?? this.location,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      completedBy: completedBy ?? this.completedBy,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      taskCompletion: taskCompletion ?? this.taskCompletion,
    );
  }

  bool get isOverdue {
    if (status == MaintenanceStatus.completed ||
        status == MaintenanceStatus.cancelled) {
      return false;
    }
    return DateTime.now().isAfter(scheduledDate);
  }

  Color get statusColor {
    switch (status) {
      case MaintenanceStatus.scheduled:
        return isOverdue ? Colors.red : Colors.blue;
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

  String get statusDisplayName {
    switch (status) {
      case MaintenanceStatus.scheduled:
        return 'Programado';
      case MaintenanceStatus.inProgress:
        return 'En Progreso';
      case MaintenanceStatus.completed:
        return 'Completado';
      case MaintenanceStatus.overdue:
        return 'Vencido';
      case MaintenanceStatus.cancelled:
        return 'Cancelado';
    }
  }

  String get frequencyDisplayName {
    switch (frequency) {
      case FrequencyType.weekly:
        return 'Semanal';
      case FrequencyType.biweekly:
        return 'Bi-semanal';
      case FrequencyType.monthly:
        return 'Mensual';
      case FrequencyType.quarterly:
        return 'Trimestral';
      case FrequencyType.biannual:
        return 'Semestral';
      case FrequencyType.annual:
        return 'Anual';
      case FrequencyType.custom:
        return 'Personalizado';
    }
  }
}
