import 'package:cloud_firestore/cloud_firestore.dart';

class FaultReport {
  final String? id;
  final String equipmentId;
  final String equipmentNumber;
  final String equipmentName;
  final String clientId;
  final String clientName;
  final String severity; // BAJA, MEDIA, ALTA, CRITICA
  final String description;
  final String status; // pending, in_progress, resolved
  final DateTime reportedAt;
  final DateTime? respondedAt; // Cuando el técnico responde
  final DateTime? resolvedAt; // Cuando se resuelve
  final String? assignedTechnicianId;
  final String? assignedTechnicianName;
  final String? responseNotes;
  final List<String> photoUrls;
  final String location;

  // Métrica de tiempo de respuesta en minutos
  int? get responseTimeMinutes {
    if (respondedAt != null) {
      return respondedAt!.difference(reportedAt).inMinutes;
    }
    return null;
  }

  // Tiempo de respuesta en formato legible
  String get responseTimeFormatted {
    if (responseTimeMinutes == null) return 'Pendiente';
    if (responseTimeMinutes! < 60) {
      return '$responseTimeMinutes minutos';
    } else if (responseTimeMinutes! < 1440) {
      return '${(responseTimeMinutes! / 60).toStringAsFixed(1)} horas';
    } else {
      return '${(responseTimeMinutes! / 1440).toStringAsFixed(1)} días';
    }
  }

  // Tiempo transcurrido desde el reporte
  String get timeElapsed {
    final now = DateTime.now();
    final difference = now.difference(reportedAt);

    if (difference.inMinutes < 60) {
      return 'hace ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'hace ${difference.inHours} horas';
    } else {
      return 'hace ${difference.inDays} días';
    }
  }

  // Color según severidad
  String get severityColor {
    switch (severity.toUpperCase()) {
      case 'CRITICA':
        return '#D32F2F'; // Rojo oscuro
      case 'ALTA':
        return '#F57C00'; // Naranja oscuro
      case 'MEDIA':
        return '#FFA726'; // Naranja
      case 'BAJA':
        return '#66BB6A'; // Verde
      default:
        return '#9E9E9E'; // Gris
    }
  }

  FaultReport({
    this.id,
    required this.equipmentId,
    required this.equipmentNumber,
    required this.equipmentName,
    required this.clientId,
    required this.clientName,
    required this.severity,
    required this.description,
    this.status = 'pending',
    required this.reportedAt,
    this.respondedAt,
    this.resolvedAt,
    this.assignedTechnicianId,
    this.assignedTechnicianName,
    this.responseNotes,
    this.photoUrls = const [],
    this.location = '',
  });

  factory FaultReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FaultReport(
      id: doc.id,
      equipmentId: data['equipmentId'] ?? '',
      equipmentNumber: data['equipmentNumber'] ?? '',
      equipmentName: data['equipmentName'] ?? '',
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      severity: data['severity'] ?? 'MEDIA',
      description: data['description'] ?? '',
      status: data['status'] ?? 'pending',
      reportedAt: data['reportedAt'] != null
          ? (data['reportedAt'] as Timestamp).toDate()
          : DateTime.now(),
      respondedAt: data['respondedAt'] != null
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
      assignedTechnicianId: data['assignedTechnicianId'],
      assignedTechnicianName: data['assignedTechnicianName'],
      responseNotes: data['responseNotes'],
      photoUrls:
          data['photoUrls'] != null ? List<String>.from(data['photoUrls']) : [],
      location: data['location'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'equipmentId': equipmentId,
      'equipmentNumber': equipmentNumber,
      'equipmentName': equipmentName,
      'clientId': clientId,
      'clientName': clientName,
      'severity': severity,
      'description': description,
      'status': status,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'assignedTechnicianId': assignedTechnicianId,
      'assignedTechnicianName': assignedTechnicianName,
      'responseNotes': responseNotes,
      'photoUrls': photoUrls,
      'location': location,
    };
  }

  // Método copyWith para actualizaciones
  FaultReport copyWith({
    String? id,
    String? equipmentId,
    String? equipmentNumber,
    String? equipmentName,
    String? clientId,
    String? clientName,
    String? severity,
    String? description,
    String? status,
    DateTime? reportedAt,
    DateTime? respondedAt,
    DateTime? resolvedAt,
    String? assignedTechnicianId,
    String? assignedTechnicianName,
    String? responseNotes,
    List<String>? photoUrls,
    String? location,
  }) {
    return FaultReport(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentNumber: equipmentNumber ?? this.equipmentNumber,
      equipmentName: equipmentName ?? this.equipmentName,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      status: status ?? this.status,
      reportedAt: reportedAt ?? this.reportedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      assignedTechnicianId: assignedTechnicianId ?? this.assignedTechnicianId,
      assignedTechnicianName:
          assignedTechnicianName ?? this.assignedTechnicianName,
      responseNotes: responseNotes ?? this.responseNotes,
      photoUrls: photoUrls ?? this.photoUrls,
      location: location ?? this.location,
    );
  }
}
