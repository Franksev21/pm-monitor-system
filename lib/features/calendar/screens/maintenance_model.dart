import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// NUEVOS ESTADOS ⭐
enum MaintenanceStatus {
  generated, // ⚪ Generado - Creado, sin técnico asignado
  assigned, // 🟡 Asignado - Tiene técnico, pendiente de ejecución
  executed // 🟢 Ejecutado - Completado
}

enum MaintenanceType {
  preventive,
  corrective,
  emergency,
  inspection,
  technicalAssistance
}

enum FrequencyType {
  weekly,
  biweekly,
  monthly,
  bimonthly,
  quarterly,
  quadrimestral,
  biannual,
  annual
}

class MaintenanceSchedule {
  final String id;
  final String equipmentId;
  final String equipmentName;
  final String clientId;
  final String clientName;
  final String? branchId;
  final String branchName;
  final String? technicianId;
  final String? technicianName;
  final String? supervisorId;
  final String? supervisorName;
  final DateTime scheduledDate;
  final MaintenanceStatus status;
  final MaintenanceType type;
  final FrequencyType? frequency;
  final String? notes;
  final List<String> tasks;
  final String location;
  final List<String>? photoUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? completedBy;
  final DateTime? completedDate;
  final int completionPercentage;
  final Map<String, bool>? taskCompletion;
  final Map<String, String>? taskFrequencies;
  final double? estimatedHours;

  // Notas y aprobación
  final String? technicianNotes;
  final String? adminNotes;
  final String? adminApprovalNotes;
  final bool? isApprovedByAdmin;
  final String? approvedBy;
  final DateTime? approvedDate;
  final DateTime? startedAt;

  // ✅ NUEVO: Razones de tareas no completadas (guardadas por el técnico)
  final Map<String, String>? skipReasons;

  MaintenanceSchedule({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.clientId,
    required this.clientName,
    this.branchId,
    required this.branchName,
    this.technicianId,
    this.technicianName,
    this.supervisorId,
    this.supervisorName,
    required this.scheduledDate,
    required this.status,
    required this.type,
    this.frequency,
    this.notes,
    required this.tasks,
    required this.location,
    this.photoUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.completedBy,
    this.completedDate,
    this.completionPercentage = 0,
    this.taskCompletion,
    this.taskFrequencies,
    this.estimatedHours,
    this.technicianNotes,
    this.adminNotes,
    this.adminApprovalNotes,
    this.isApprovedByAdmin,
    this.approvedBy,
    this.approvedDate,
    this.startedAt,
    this.skipReasons, // ✅ NUEVO
  });

  factory MaintenanceSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    double? estimatedHours;
    if (data['estimatedHours'] != null) {
      estimatedHours = (data['estimatedHours'] as num).toDouble();
    } else if (data['estimatedDurationMinutes'] != null) {
      final minutes = (data['estimatedDurationMinutes'] as num).toDouble();
      estimatedHours = minutes / 60.0;
    }

    return MaintenanceSchedule(
      id: doc.id,
      equipmentId: data['equipmentId'] ?? '',
      equipmentName: data['equipmentName'] ?? '',
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      branchId: data['branchId'],
      branchName: data['branchName'] ?? '',
      technicianId: data['technicianId'],
      technicianName: data['technicianName'],
      supervisorId: data['supervisorId'],
      supervisorName: data['supervisorName'],
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      status: _parseStatus(data['status']),
      type: _parseType(data['type']),
      frequency:
          data['frequency'] != null ? _parseFrequency(data['frequency']) : null,
      notes: data['notes'],
      tasks: List<String>.from(data['tasks'] ?? []),
      location: data['location'] ?? '',
      photoUrls: data['photoUrls'] != null
          ? List<String>.from(data['photoUrls'])
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      completedBy: data['completedBy'],
      completedDate: data['completedDate'] != null
          ? (data['completedDate'] as Timestamp).toDate()
          : null,
      completionPercentage:
          (data['completionPercentage'] as num?)?.toInt() ?? 0,
      taskCompletion: data['taskCompletion'] != null
          ? Map<String, bool>.from(data['taskCompletion'])
          : null,
      taskFrequencies: data['taskFrequencies'] != null
          ? Map<String, String>.from(data['taskFrequencies'])
          : null,
      estimatedHours: estimatedHours,
      technicianNotes: data['technicianNotes'],
      adminNotes: data['adminNotes'],
      adminApprovalNotes: data['adminApprovalNotes'],
      isApprovedByAdmin: data['isApprovedByAdmin'],
      approvedBy: data['approvedBy'],
      approvedDate: data['approvedDate'] != null
          ? (data['approvedDate'] as Timestamp).toDate()
          : null,
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      // ✅ NUEVO: Leer skipReasons de Firestore
      skipReasons: data['skipReasons'] != null
          ? Map<String, String>.from(data['skipReasons'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'clientId': clientId,
      'clientName': clientName,
      'branchId': branchId,
      'branchName': branchName,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'frequency': frequency?.toString().split('.').last,
      'notes': notes,
      'tasks': tasks,
      'location': location,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'completedBy': completedBy,
      'completedDate':
          completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'completionPercentage': completionPercentage,
      'taskCompletion': taskCompletion,
      'taskFrequencies': taskFrequencies,
      'estimatedHours': estimatedHours,
      'technicianNotes': technicianNotes,
      'adminNotes': adminNotes,
      'adminApprovalNotes': adminApprovalNotes,
      'isApprovedByAdmin': isApprovedByAdmin,
      'approvedBy': approvedBy,
      'approvedDate':
          approvedDate != null ? Timestamp.fromDate(approvedDate!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'skipReasons': skipReasons, // ✅ NUEVO
    };
  }

  static MaintenanceStatus _parseStatus(String? statusString) {
    if (statusString == null) return MaintenanceStatus.generated;
    switch (statusString) {
      case 'scheduled':
        return MaintenanceStatus.generated;
      case 'inProgress':
        return MaintenanceStatus.assigned;
      case 'completed':
        return MaintenanceStatus.executed;
      case 'overdue':
        return MaintenanceStatus.assigned;
      case 'cancelled':
        return MaintenanceStatus.generated;
      case 'generated':
        return MaintenanceStatus.generated;
      case 'assigned':
        return MaintenanceStatus.assigned;
      case 'executed':
        return MaintenanceStatus.executed;
      default:
        return MaintenanceStatus.generated;
    }
  }

  static MaintenanceType _parseType(String? typeString) {
    if (typeString == null) return MaintenanceType.preventive;
    switch (typeString) {
      case 'preventive':
        return MaintenanceType.preventive;
      case 'corrective':
        return MaintenanceType.corrective;
      case 'emergency':
        return MaintenanceType.emergency;
      case 'inspection':
        return MaintenanceType.inspection;
      case 'technicalAssistance':
        return MaintenanceType.technicalAssistance;
      default:
        return MaintenanceType.preventive;
    }
  }

  static FrequencyType _parseFrequency(String frequencyString) {
    switch (frequencyString) {
      case 'weekly':
        return FrequencyType.weekly;
      case 'biweekly':
        return FrequencyType.biweekly;
      case 'monthly':
        return FrequencyType.monthly;
      case 'bimonthly':
        return FrequencyType.bimonthly;
      case 'quarterly':
        return FrequencyType.quarterly;
      case 'quadrimestral':
        return FrequencyType.quadrimestral;
      case 'biannual':
        return FrequencyType.biannual;
      case 'annual':
        return FrequencyType.annual;
      default:
        return FrequencyType.monthly;
    }
  }

  MaintenanceSchedule copyWith({
    String? id,
    String? equipmentId,
    String? equipmentName,
    String? clientId,
    String? clientName,
    String? branchId,
    String? branchName,
    String? technicianId,
    String? technicianName,
    String? supervisorId,
    String? supervisorName,
    DateTime? scheduledDate,
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
    DateTime? completedDate,
    int? completionPercentage,
    Map<String, bool>? taskCompletion,
    Map<String, String>? taskFrequencies,
    double? estimatedHours,
    String? technicianNotes,
    String? adminNotes,
    String? adminApprovalNotes,
    bool? isApprovedByAdmin,
    String? approvedBy,
    DateTime? approvedDate,
    DateTime? startedAt,
    Map<String, String>? skipReasons, // ✅ NUEVO
  }) {
    return MaintenanceSchedule(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentName: equipmentName ?? this.equipmentName,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      scheduledDate: scheduledDate ?? this.scheduledDate,
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
      completedDate: completedDate ?? this.completedDate,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      taskCompletion: taskCompletion ?? this.taskCompletion,
      taskFrequencies: taskFrequencies ?? this.taskFrequencies,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      technicianNotes: technicianNotes ?? this.technicianNotes,
      adminNotes: adminNotes ?? this.adminNotes,
      adminApprovalNotes: adminApprovalNotes ?? this.adminApprovalNotes,
      isApprovedByAdmin: isApprovedByAdmin ?? this.isApprovedByAdmin,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedDate: approvedDate ?? this.approvedDate,
      startedAt: startedAt ?? this.startedAt,
      skipReasons: skipReasons ?? this.skipReasons, // ✅ NUEVO
    );
  }

  static bool requiresFrequency(MaintenanceType type) =>
      type == MaintenanceType.preventive;

  static Color getStatusColor(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.generated:
        return Colors.grey.shade400;
      case MaintenanceStatus.assigned:
        return Colors.orange.shade600;
      case MaintenanceStatus.executed:
        return Colors.green.shade600;
    }
  }

  static String getStatusDisplayName(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.generated:
        return 'Generado';
      case MaintenanceStatus.assigned:
        return 'Asignado';
      case MaintenanceStatus.executed:
        return 'Ejecutado';
    }
  }

  static String getTypeDisplayName(MaintenanceType type) {
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

  static String getFrequencyDisplayName(FrequencyType frequency) {
    switch (frequency) {
      case FrequencyType.weekly:
        return 'Semanal';
      case FrequencyType.biweekly:
        return 'Bi-semanal';
      case FrequencyType.monthly:
        return 'Mensual';
      case FrequencyType.bimonthly:
        return 'Cada 2 meses';
      case FrequencyType.quarterly:
        return 'Trimestral';
      case FrequencyType.quadrimestral:
        return 'Cuatrimestral';
      case FrequencyType.biannual:
        return 'Semestral';
      case FrequencyType.annual:
        return 'Anual';
    }
  }

  static IconData getStatusIcon(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.generated:
        return Icons.assignment_outlined;
      case MaintenanceStatus.assigned:
        return Icons.person_outline;
      case MaintenanceStatus.executed:
        return Icons.check_circle_outline;
    }
  }

  Color getCompletionColor() {
    if (completionPercentage == 100) return Colors.green;
    if (completionPercentage >= 61) return Colors.orange;
    return Colors.red;
  }

  bool get isPendingApproval =>
      status == MaintenanceStatus.executed &&
      (isApprovedByAdmin == null || !isApprovedByAdmin!);

  bool get isApproved =>
      status == MaintenanceStatus.executed && isApprovedByAdmin == true;

  bool get hasTechnicianNotes =>
      technicianNotes != null && technicianNotes!.isNotEmpty;

  bool get hasAdminNotes => adminNotes != null && adminNotes!.isNotEmpty;

  bool get hasAdminApprovalNotes =>
      adminApprovalNotes != null && adminApprovalNotes!.isNotEmpty;

  // ✅ NUEVO helper
  bool get hasSkipReasons => skipReasons != null && skipReasons!.isNotEmpty;
}
