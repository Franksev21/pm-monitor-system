import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pm_monitor/core/models/fault_report_model.dart';
import '../services/notification_service.dart';

class FaultReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  Future<String> createFaultReport(FaultReport faultReport) async {
    DocumentReference docRef = await _firestore
        .collection('faultReports')
        .add(faultReport.toFirestore());

    await _sendNotifications(faultReport, docRef.id);

    await _notificationService.sendFaultNotifications(
      equipmentName: faultReport.equipmentName,
      equipmentId: faultReport.equipmentId,
      severity: faultReport.severity,
      description: faultReport.description,
      reportId: docRef.id,
    );

    return docRef.id;
  }

  Future<void> _sendNotifications(
      FaultReport faultReport, String reportId) async {
    String message = '''
🚨 FALLA REPORTADA
Equipo: ${faultReport.equipmentName}
Severidad: ${faultReport.severity.toUpperCase()}
Descripción: ${faultReport.description}
ID: $reportId
''';

    await _firestore.collection('pendingNotifications').add({
      'type': 'fault_report',
      'message': message,
      'equipmentId': faultReport.equipmentId,
      'severity': faultReport.severity,
      'createdAt': Timestamp.now(),
      'status': 'pending',
    });
  }
}
