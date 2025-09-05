import 'package:cloud_firestore/cloud_firestore.dart';

class FaultReport {
  final String? id;
  final String equipmentId;
  final String equipmentName;
  final String clientId;
  final String description;
  final String severity;
  final String status;
  final DateTime reportedAt;
  final String location;

  FaultReport({
    this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.clientId,
    required this.description,
    required this.severity,
    this.status = 'reportada',
    required this.reportedAt,
    required this.location,
  });

  factory FaultReport.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return FaultReport(
      id: doc.id,
      equipmentId: data['equipmentId'] ?? '',
      equipmentName: data['equipmentName'] ?? '',
      clientId: data['clientId'] ?? '',
      description: data['description'] ?? '',
      severity: data['severity'] ?? 'media',
      status: data['status'] ?? 'reportada',
      reportedAt: (data['reportedAt'] as Timestamp).toDate(),
      location: data['location'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'clientId': clientId,
      'description': description,
      'severity': severity,
      'status': status,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'location': location,
    };
  }
}
