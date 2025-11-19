import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_model.dart';


class MaintenanceNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final MaintenanceNotificationService _instance =
      MaintenanceNotificationService._internal();
  factory MaintenanceNotificationService() => _instance;
  MaintenanceNotificationService._internal();

  /// Programar notificaciones para un mantenimiento
  Future<void> scheduleMaintenanceNotifications(
      MaintenanceSchedule maintenance) async {
    try {
      // Notificación 24 horas antes
      await _scheduleNotification(
        maintenance,
        maintenance.scheduledDate.subtract(const Duration(hours: 24)),
        'Recordatorio de Mantenimiento',
        'Mañana tienes programado el mantenimiento de ${maintenance.equipmentName}',
        NotificationType.reminder24h,
      );

      // Notificación 2 horas antes
      await _scheduleNotification(
        maintenance,
        maintenance.scheduledDate.subtract(const Duration(hours: 2)),
        'Mantenimiento Próximo',
        'En 2 horas: Mantenimiento de ${maintenance.equipmentName} en ${maintenance.clientName}',
        NotificationType.reminder2h,
      );

      // Notificación al momento programado
      await _scheduleNotification(
        maintenance,
        maintenance.scheduledDate,
        'Hora del Mantenimiento',
        'Es hora de realizar el mantenimiento de ${maintenance.equipmentName}',
        NotificationType.scheduled,
      );
    } catch (e) {
      debugPrint('Error programando notificaciones: $e');
      rethrow;
    }
  }

  /// Programar una notificación específica
  Future<void> _scheduleNotification(
    MaintenanceSchedule maintenance,
    DateTime scheduledTime,
    String title,
    String body,
    NotificationType type,
  ) async {
    // Solo programar si la fecha es futura
    if (scheduledTime.isBefore(DateTime.now())) {
      return;
    }

    final notificationData = {
      'maintenanceId': maintenance.id,
      'equipmentId': maintenance.equipmentId,
      'equipmentName': maintenance.equipmentName,
      'clientId': maintenance.clientId,
      'clientName': maintenance.clientName,
      'technicianId': maintenance.technicianId,
      'technicianName': maintenance.technicianName,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'maintenanceDate': Timestamp.fromDate(maintenance.scheduledDate),
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'status': 'pending',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };

    await _firestore.collection('notifications').add(notificationData);

    // En una implementación real, aquí programarías la notificación local
    // usando paquetes como flutter_local_notifications
    if (kDebugMode) {
      print('Notificación programada: $title para ${scheduledTime.toString()}');
    }
  }

  /// Enviar notificaciones pendientes
  Future<void> sendPendingNotifications() async {
    try {
      final now = DateTime.now();
      final notifications = await _firestore
          .collection('notifications')
          .where('status', isEqualTo: 'pending')
          .where('scheduledTime', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      for (final doc in notifications.docs) {
        final data = doc.data();

        // Enviar la notificación
        await _sendNotification(data);

        // Marcar como enviada
        await doc.reference.update({
          'status': 'sent',
          'sentAt': Timestamp.fromDate(now),
        });
      }
    } catch (e) {
      debugPrint('Error enviando notificaciones: $e');
    }
  }

  /// Enviar una notificación específica
  Future<void> _sendNotification(Map<String, dynamic> notificationData) async {
    final title = notificationData['title'] as String;
    final body = notificationData['body'] as String;
    final technicianId = notificationData['technicianId'] as String?;

    // 1. Notificación push (si está implementada)
    if (technicianId != null) {
      await _sendPushNotification(technicianId, title, body);
    }

    // 2. Notificación por email
    await _sendEmailNotification(notificationData);

    // 3. Notificación por SMS (si está configurado)
    await _sendSMSNotification(notificationData);

    // 4. Notificación por WhatsApp (si está configurado)
    await _sendWhatsAppNotification(notificationData);

    if (kDebugMode) {
      print('Notificación enviada: $title');
    }
  }

  /// Enviar notificación push
  Future<void> _sendPushNotification(
      String userId, String title, String body) async {
    // Implementar con Firebase Cloud Messaging
    // Aquí iría la lógica para enviar notificación push
    if (kDebugMode) {
      print('Push notification enviada a $userId: $title');
    }
  }

  /// Enviar notificación por email
  Future<void> _sendEmailNotification(Map<String, dynamic> data) async {
    try {
      // En producción, usar un servicio como SendGrid, AWS SES, etc.
      final emailData = {
        'to': await _getTechnicianEmail(data['technicianId']),
        'subject': data['title'],
        'body': _buildEmailBody(data),
        'type': 'maintenance_reminder',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'status': 'pending',
      };

      await _firestore.collection('emailQueue').add(emailData);

      if (kDebugMode) {
        print('Email programado para ${emailData['to']}');
      }
    } catch (e) {
      debugPrint('Error programando email: $e');
    }
  }

  /// Enviar notificación por SMS
  Future<void> _sendSMSNotification(Map<String, dynamic> data) async {
    try {
      final phoneNumber = await _getTechnicianPhone(data['technicianId']);
      if (phoneNumber == null) return;

      final smsData = {
        'to': phoneNumber,
        'message': _buildSMSMessage(data),
        'type': 'maintenance_reminder',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'status': 'pending',
      };

      await _firestore.collection('smsQueue').add(smsData);

      if (kDebugMode) {
        print('SMS programado para $phoneNumber');
      }
    } catch (e) {
      debugPrint('Error programando SMS: $e');
    }
  }

  /// Enviar notificación por WhatsApp
  Future<void> _sendWhatsAppNotification(Map<String, dynamic> data) async {
    try {
      final phoneNumber = await _getTechnicianPhone(data['technicianId']);
      if (phoneNumber == null) return;

      final whatsappData = {
        'to': phoneNumber,
        'message': _buildWhatsAppMessage(data),
        'type': 'maintenance_reminder',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'status': 'pending',
      };

      await _firestore.collection('whatsappQueue').add(whatsappData);

      if (kDebugMode) {
        print('WhatsApp programado para $phoneNumber');
      }
    } catch (e) {
      debugPrint('Error programando WhatsApp: $e');
    }
  }

  /// Notificar falla de equipo
  Future<void> sendEquipmentFailureAlert(
    String equipmentId,
    String equipmentName,
    String clientName,
    String description,
  ) async {
    try {
      // Obtener técnicos asignados al equipo
      final technicians = await _getAssignedTechnicians(equipmentId);

      // Enviar alertas a todos los técnicos asignados
      for (final technician in technicians) {
        final alertData = {
          'equipmentId': equipmentId,
          'equipmentName': equipmentName,
          'clientName': clientName,
          'description': description,
          'technicianId': technician['id'],
          'technicianName': technician['name'],
          'type': 'equipment_failure',
          'priority': 'high',
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'status': 'pending',
        };

        // Enviar inmediatamente
        await _sendNotification({
          'title': 'Falla de Equipo Reportada',
          'body': 'Falla en $equipmentName de $clientName: $description',
          'technicianId': technician['id'],
          ...alertData,
        });

        // Guardar en historial de alertas
        await _firestore.collection('equipmentAlerts').add(alertData);
      }

      // También notificar a supervisores
      await _notifySupervisors(
          equipmentId, equipmentName, clientName, description);
    } catch (e) {
      debugPrint('Error enviando alerta de falla: $e');
      rethrow;
    }
  }

  /// Notificar mantenimiento vencido
  Future<void> checkAndNotifyOverdueMaintenances() async {
    try {
      final now = DateTime.now();
      final overdueMaintenances = await _firestore
          .collection('maintenanceSchedules')
          .where('status', isEqualTo: 'scheduled')
          .where('scheduledDate', isLessThan: Timestamp.fromDate(now))
          .get();

      for (final doc in overdueMaintenances.docs) {
        final maintenance = MaintenanceSchedule.fromFirestore(doc);

        // Actualizar estado a vencido
        await doc.reference.update({
          'status': 'overdue',
          'updatedAt': Timestamp.fromDate(now),
        });

        // Enviar alerta de mantenimiento vencido
        await _sendOverdueAlert(maintenance);
      }
    } catch (e) {
      debugPrint('Error verificando mantenimientos vencidos: $e');
    }
  }

  /// Enviar alerta de mantenimiento vencido
  Future<void> _sendOverdueAlert(MaintenanceSchedule maintenance) async {
    final alertData = {
      'title': 'Mantenimiento Vencido',
      'body':
          'El mantenimiento de ${maintenance.equipmentName} está vencido desde ${_formatDate(maintenance.scheduledDate)}',
      'technicianId': maintenance.technicianId,
      'maintenanceId': maintenance.id,
      'equipmentId': maintenance.equipmentId,
      'priority': 'high',
    };

    await _sendNotification(alertData);
  }

  /// Cancelar notificaciones de un mantenimiento
  Future<void> cancelMaintenanceNotifications(String maintenanceId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('maintenanceId', isEqualTo: maintenanceId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in notifications.docs) {
        await doc.reference.update({
          'status': 'cancelled',
          'cancelledAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      debugPrint('Error cancelando notificaciones: $e');
    }
  }

  // Métodos auxiliares
  Future<String?> _getTechnicianEmail(String? technicianId) async {
    if (technicianId == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(technicianId).get();
      return doc.data()?['email'];
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getTechnicianPhone(String? technicianId) async {
    if (technicianId == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(technicianId).get();
      return doc.data()?['phone'];
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, String>>> _getAssignedTechnicians(
      String equipmentId) async {
    try {
      final equipment =
          await _firestore.collection('equipments').doc(equipmentId).get();
      final assignedTechnicianIds =
          List<String>.from(equipment.data()?['assignedTechnicians'] ?? []);

      List<Map<String, String>> technicians = [];
      for (final techId in assignedTechnicianIds) {
        final techDoc = await _firestore.collection('users').doc(techId).get();
        if (techDoc.exists) {
          technicians.add({
            'id': techId,
            'name': techDoc.data()?['name'] ?? '',
            'email': techDoc.data()?['email'] ?? '',
            'phone': techDoc.data()?['phone'] ?? '',
          });
        }
      }

      return technicians;
    } catch (e) {
      debugPrint('Error obteniendo técnicos asignados: $e');
      return [];
    }
  }

  Future<void> _notifySupervisors(String equipmentId, String equipmentName,
      String clientName, String description) async {
    try {
      // Obtener supervisores del cliente
      final supervisors = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'supervisor')
          .get();

      for (final supervisor in supervisors.docs) {
        await _sendNotification({
          'title': 'Falla de Equipo - Reporte de Supervisor',
          'body': 'Falla reportada en $equipmentName de $clientName',
          'technicianId': supervisor.id,
          'priority': 'high',
        });
      }
    } catch (e) {
      debugPrint('Error notificando supervisores: $e');
    }
  }

  String _buildEmailBody(Map<String, dynamic> data) {
    return '''
    Estimado ${data['technicianName'] ?? 'Técnico'},
    
    Este es un recordatorio de mantenimiento programado:
    
    Equipo: ${data['equipmentName']}
    Cliente: ${data['clientName']}
    Fecha: ${_formatDate((data['maintenanceDate'] as Timestamp).toDate())}
    
    Por favor, asegúrate de realizar el mantenimiento según lo programado.
    
    Saludos,
    Sistema PM Monitor
    ''';
  }

  String _buildSMSMessage(Map<String, dynamic> data) {
    return 'PM Monitor: Recordatorio mantenimiento ${data['equipmentName']} - ${data['clientName']} el ${_formatDate((data['maintenanceDate'] as Timestamp).toDate())}';
  }

  String _buildWhatsAppMessage(Map<String, dynamic> data) {
    return '''
🔧 *PM Monitor - Recordatorio*

📅 Mantenimiento programado:
🏢 Cliente: ${data['clientName']}
⚙️ Equipo: ${data['equipmentName']}
🗓️ Fecha: ${_formatDate((data['maintenanceDate'] as Timestamp).toDate())}

¡No olvides realizar el mantenimiento!
    ''';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

enum NotificationType {
  reminder24h,
  reminder2h,
  scheduled,
  overdue,
  equipmentFailure,
  maintenanceComplete,
}
