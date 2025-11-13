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
  preventive, // Preventivo - CON frecuencia
  corrective, // Correctivo - CON frecuencia
  emergency, // Emergencia - SIN frecuencia
  inspection, // Inspección - SIN frecuencia
  technicalAssistance // Asistencia Técnica - SIN frecuencia
}

enum FrequencyType {
  weekly, // Semanal
  biweekly, // Bi-semanal
  monthly, // Mensual
  bimonthly, // C/2 Meses
  quarterly, // Trimestral
  quadrimestral, // Cuatrimestral
  biannual, // Semestral
  annual, // Anual
}

class MaintenanceSchedule {
  final String id;
  final String equipmentId;
  final String equipmentName;
  final String clientId;
  final String clientName;
  final String? branchId; // NUEVO
  final String? branchName; // NUEVO
  final String? technicianId;
  final String? technicianName;
  final String? supervisorId;
  final String? supervisorName;
  final DateTime scheduledDate;
  final DateTime? completedDate;
  final MaintenanceStatus status;
  final MaintenanceType type;
  final FrequencyType? frequency; // AHORA OPCIONAL
  final String? notes;
  final List<String> tasks;
  final String? location;
  final List<String> photoUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? completedBy;
  final int? completionPercentage;
  final Map<String, bool>? taskCompletion;
  final Map<String, String>?
      taskFrequencies; // NUEVO: Frecuencias individuales por tarea

  MaintenanceSchedule({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.clientId,
    required this.clientName,
    this.branchId, // NUEVO
    this.branchName, // NUEVO
    this.technicianId,
    this.technicianName,
    this.supervisorId,
    this.supervisorName,
    required this.scheduledDate,
    this.completedDate,
    required this.status,
    required this.type,
    this.frequency, // AHORA OPCIONAL
    this.notes,
    required this.tasks,
    this.location,
    required this.photoUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.completedBy,
    this.completionPercentage = 0,
    this.taskCompletion,
    this.taskFrequencies, // NUEVO
  });

  // NUEVO: Verificar si el tipo requiere frecuencia
  static bool requiresFrequency(MaintenanceType type) {
    return type == MaintenanceType.preventive ||
        type == MaintenanceType.corrective;
  }

  factory MaintenanceSchedule.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return MaintenanceSchedule(
      id: doc.id,
      equipmentId: data['equipmentId'] ?? '',
      equipmentName: data['equipmentName'] ?? '',
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      branchId: data['branchId'], // NUEVO
      branchName: data['branchName'], // NUEVO
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
      frequency: data['frequency'] != null // ACTUALIZADO
          ? FrequencyType.values.firstWhere(
              (e) => e.toString().split('.').last == data['frequency'],
              orElse: () => FrequencyType.monthly,
            )
          : null,
      notes: data['notes'],
      tasks: List<String>.from(data['tasks'] ?? []),
      location: data['location'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      completedBy: data['completedBy'],
      completionPercentage:
          _safeIntFromDynamic(data['completionPercentage']) ?? 0,
      taskCompletion: data['taskCompletion'] != null
          ? Map<String, bool>.from(data['taskCompletion'])
          : null,
      taskFrequencies: data['taskFrequencies'] != null
          ? Map<String, String>.from(data['taskFrequencies'])
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
      'branchId': branchId, // NUEVO
      'branchName': branchName, // NUEVO
      'technicianId': technicianId,
      'technicianName': technicianName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'completedDate':
          completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'frequency': frequency?.toString().split('.').last, // ACTUALIZADO
      'notes': notes,
      'tasks': tasks,
      'location': location,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'completedBy': completedBy,
      'completionPercentage': completionPercentage,
      'taskCompletion': taskCompletion,
      'taskFrequencies': taskFrequencies,
    };
  }

  MaintenanceSchedule copyWith({
    String? id,
    String? equipmentId,
    String? equipmentName,
    String? clientId,
    String? clientName,
    String? branchId, // NUEVO
    String? branchName, // NUEVO
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
    String? location,
    List<String>? photoUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? completedBy,
    int? completionPercentage,
    Map<String, bool>? taskCompletion,
    Map<String, String>? taskFrequencies,
  }) {
    return MaintenanceSchedule(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentName: equipmentName ?? this.equipmentName,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      branchId: branchId ?? this.branchId, // NUEVO
      branchName: branchName ?? this.branchName, // NUEVO
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
      location: location ?? this.location,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      completedBy: completedBy ?? this.completedBy,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      taskCompletion: taskCompletion ?? this.taskCompletion,
      taskFrequencies: taskFrequencies ?? this.taskFrequencies,
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

  String get typeDisplayName {
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

  String get frequencyDisplayName {
    if (frequency == null) return 'N/A'; // NUEVO

    switch (frequency!) {
      case FrequencyType.weekly:
        return 'Semanal';
      case FrequencyType.biweekly:
        return 'C/2 Semanas';
      case FrequencyType.monthly:
        return 'Mensual';
      case FrequencyType.bimonthly:
        return 'C/2 Meses';
      case FrequencyType.quarterly:
        return 'C/3 Meses';
      case FrequencyType.quadrimestral:
        return 'C/4 Meses';
      case FrequencyType.biannual:
        return 'C/6 Meses';
      case FrequencyType.annual:
        return 'Anual';
    }
  }

  // NUEVO: Obtener tareas por tipo de mantenimiento
  static List<String> getTasksForType(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.preventive:
        return [
          'Limpieza de filtros',
          'Revisión de gas refrigerante',
          'Inspección de componentes eléctricos',
          'Lubricación de partes móviles',
          'Verificación de temperaturas',
          'Limpieza de serpentines',
          'Revisión de drenajes',
          'Inspección de aislamiento',
          'Prueba de funcionamiento',
          'Verificación de controles',
        ];

      case MaintenanceType.corrective:
        return [
          'Reparación de fuga de refrigerante',
          'Reemplazo de compresor',
          'Reparación de motor de ventilador',
          'Reemplazo de capacitor',
          'Reparación de tarjeta electrónica',
          'Reemplazo de válvula de expansión',
          'Reparación de drenaje obstruido',
          'Reemplazo de termostato',
          'Reparación de cableado',
          'Soldadura de tubería',
        ];

      case MaintenanceType.emergency:
        return [
          'Detención de emergencia del equipo',
          'Reparación urgente de fuga',
          'Restauración de energía',
          'Reparación de corto circuito',
          'Control de temperatura crítica',
          'Diagnóstico rápido',
          'Aislamiento de componente dañado',
        ];

      case MaintenanceType.inspection:
        return [
          'Levantamiento fotográfico del equipo',
          'Registro de datos de placa',
          'Medición de temperaturas',
          'Medición de presiones',
          'Medición de voltajes',
          'Registro de modelo y marca',
          'Evaluación de condición general',
          'Registro de ubicación',
          'Fotografía de instalación',
          'Registro de observaciones',
        ];

      case MaintenanceType.technicalAssistance:
        return [
          'Asesoramiento técnico',
          'Configuración de controles',
          'Capacitación de usuario',
          'Ajuste de parámetros',
          'Verificación de funcionamiento',
          'Resolución de consultas',
          'Entrega de documentación',
        ];
    }
  }
}
