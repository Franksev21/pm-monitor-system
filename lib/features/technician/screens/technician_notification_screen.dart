import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../maintenance/screens/pending_maintenances_screen.dart';

class TechnicianNotificationsScreen extends StatefulWidget {
  const TechnicianNotificationsScreen({super.key});

  @override
  State<TechnicianNotificationsScreen> createState() =>
      _TechnicianNotificationsScreenState();
}

class _TechnicianNotificationsScreenState
    extends State<TechnicianNotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Configurar timeago en español
    timeago.setLocaleMessages('es', timeago.EsMessages());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Marcar todas como leídas',
            onPressed: () => _markAllAsRead(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('pendingNotifications')
            .where('status', isEqualTo: 'pending')
            .snapshots(), // Quitamos temporalmente el orderBy
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Reintentar
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          var notifications = snapshot.data?.docs ?? [];

          // Ordenar manualmente por fecha mientras se crea el índice
          notifications.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime =
                (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bTime =
                (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bTime.compareTo(aTime); // Más reciente primero
          });

          // Limitar a 50
          if (notifications.length > 50) {
            notifications = notifications.sublist(0, 50);
          }

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay notificaciones',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aquí aparecerán tus alertas y avisos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notificationDoc = notifications[index];
                final data = notificationDoc.data() as Map<String, dynamic>;

                return _buildNotificationCard(
                  notificationId: notificationDoc.id,
                  type: data['type'] ?? 'info',
                  message: data['message'] ?? 'Sin mensaje',
                  createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  severity: data['severity'],
                  equipmentId: data['equipmentId'],
                  reportId: data['reportId'],
                  maintenanceId: data['maintenanceId'],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard({
    required String notificationId,
    required String type,
    required String message,
    required DateTime createdAt,
    String? severity,
    String? equipmentId,
    String? reportId,
    String? maintenanceId,
  }) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    switch (type) {
      case 'fault_report':
        icon = Icons.warning;
        iconColor = _getSeverityColor(severity);
        bgColor = _getSeverityColor(severity).withOpacity(0.1);
        break;
      case 'maintenance_assigned':
        icon = Icons.assignment;
        iconColor = const Color(0xFF4285F4);
        bgColor = const Color(0xFF4285F4).withOpacity(0.1);
        break;
      case 'maintenance_reminder':
        icon = Icons.alarm;
        iconColor = Colors.orange;
        bgColor = Colors.orange.withOpacity(0.1);
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.grey;
        bgColor = Colors.grey.withOpacity(0.1);
    }

    return Dismissible(
      key: Key(notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) {
        _dismissNotification(notificationId);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleNotificationTap(
            type: type,
            equipmentId: equipmentId,
            reportId: reportId,
            maintenanceId: maintenanceId,
            notificationId: notificationId,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getNotificationTitle(type),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeago.format(createdAt, locale: 'es'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getNotificationTitle(String type) {
    switch (type) {
      case 'fault_report':
        return 'Falla Reportada';
      case 'maintenance_assigned':
        return 'Nuevo Mantenimiento';
      case 'maintenance_reminder':
        return 'Recordatorio';
      default:
        return 'Notificación';
    }
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'alta':
      case 'high':
        return Colors.red;
      case 'media':
      case 'medium':
        return Colors.orange;
      case 'baja':
      case 'low':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleNotificationTap({
    required String type,
    String? equipmentId,
    String? reportId,
    String? maintenanceId,
    required String notificationId,
  }) async {
    // Marcar como leída
    await _dismissNotification(notificationId);

    if (!mounted) return;

    // Navegar según el tipo
    switch (type) {
      case 'fault_report':
        if (reportId != null) {
          // Navegar a la pantalla de mantenimientos pendientes donde aparecen las fallas
          print('proximamente');
        }
        break;
      case 'maintenance_assigned':
      case 'maintenance_reminder':
        if (maintenanceId != null) {
          // Navegar a la pantalla de mantenimientos pendientes
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const PendingMaintenancesScreen()),
          );
        }
        break;
      default:
        break;
    }
  }

  Future<void> _dismissNotification(String notificationId) async {
    try {
      await _firestore
          .collection('pendingNotifications')
          .doc(notificationId)
          .update({
        'status': 'read',
        'readAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error al marcar notificación como leída: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('pendingNotifications')
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {
          'status': 'read',
          'readAt': Timestamp.now(),
        });
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todas las notificaciones marcadas como leídas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
