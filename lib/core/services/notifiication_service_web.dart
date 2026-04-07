// Stub para web — las notificaciones no están disponibles en web
class NotificationService {
  void setupMessageListeners() {
    // No-op en web
  }

  Future<void> sendFaultNotifications({
    required String equipmentName,
    required String equipmentId,
    required String severity,
    required String description,
    required String reportId,
  }) async {
    // No-op en web
  }
}
