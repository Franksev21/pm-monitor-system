// lib/core/services/alert_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlertService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Envía una alerta a un técnico específico
  static Future<bool> sendAlertToTechnician({
    required String technicianId,
    required String technicianName,
    required String message,
    String priority = 'high', // 'normal' | 'high' | 'critical'
  }) async {
    try {
      final sender = _auth.currentUser;
      await _firestore.collection('alerts').add({
        'technicianId': technicianId,
        'technicianName': technicianName,
        'message': message,
        'priority': priority,
        'sentBy': sender?.displayName ?? sender?.email ?? 'Admin',
        'sentById': sender?.uid,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Marca la alerta como leída
  static Future<void> markAsRead(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream de alertas no leídas para un técnico
  static Stream<QuerySnapshot> unreadAlertsStream(String technicianId) {
    return _firestore
        .collection('alerts')
        .where('technicianId', isEqualTo: technicianId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
