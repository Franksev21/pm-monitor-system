/// Nombres de colecciones de Firestore.
///
/// Usar SIEMPRE estas constantes en lugar de strings literales para evitar
/// errores silenciosos por typos (p. ej. `maintenance_schedules` vs
/// `maintenanceSchedules`).
abstract final class FirestoreCollections {
  static const String users = 'users';
  static const String clients = 'clients';
  static const String equipments = 'equipments';
  static const String maintenanceSchedules = 'maintenanceSchedules';
  static const String faultReports = 'faultReports';
  static const String alerts = 'alerts';
  static const String notifications = 'notifications';
  static const String pendingNotifications = 'pendingNotifications';
  static const String sentNotifications = 'sentNotifications';
  static const String customerSurveys = 'customerSurveys';
  static const String equipmentFailures = 'equipmentFailures';
  static const String maintenanceIssues = 'maintenanceIssues';
  static const String whatsappQueue = 'whatsappQueue';
  static const String smsQueue = 'smsQueue';
}
