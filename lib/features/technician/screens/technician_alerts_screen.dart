import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pm_monitor/core/services/alert_service.dart';

class TechnicianAlertsScreen extends StatelessWidget {
  const TechnicianAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis Alertas')),
        body: const Center(child: Text('No se pudo obtener el usuario')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mis Alertas',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Marcar todas como leídas
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            tooltip: 'Marcar todas como leídas',
            onPressed: () => _markAllAsRead(context, currentUserId),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .where('technicianId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF2196F3))));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Error al cargar alertas',
                      style: TextStyle(fontSize: 16, color: Colors.red[600])),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Ordenar en memoria
          docs.sort((a, b) {
            final aTime =
                (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTime =
                (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No tienes alertas',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(
                      'Cuando el administrador te envíe una alerta aparecerá aquí',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          // Separar no leídas y leídas
          final unread = docs
              .where(
                  (d) => (d.data() as Map<String, dynamic>)['isRead'] != true)
              .toList();
          final read = docs
              .where(
                  (d) => (d.data() as Map<String, dynamic>)['isRead'] == true)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Resumen
              _buildSummaryBar(unread.length, read.length),
              const SizedBox(height: 16),

              // No leídas
              if (unread.isNotEmpty) ...[
                _buildSectionHeader('No leídas', unread.length, Colors.red),
                const SizedBox(height: 8),
                ...unread
                    .map((doc) => _buildAlertCard(context, doc, isNew: true)),
                const SizedBox(height: 20),
              ],

              // Leídas
              if (read.isNotEmpty) ...[
                _buildSectionHeader('Leídas', read.length, Colors.grey),
                const SizedBox(height: 8),
                ...read
                    .map((doc) => _buildAlertCard(context, doc, isNew: false)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryBar(int unreadCount, int readCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: unreadCount > 0
              ? [Colors.red[400]!, Colors.red[600]!]
              : [Colors.green[400]!, Colors.green[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            unreadCount > 0 ? Icons.notification_important : Icons.check_circle,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unreadCount > 0
                      ? 'Tienes $unreadCount alerta${unreadCount > 1 ? 's' : ''} sin leer'
                      : 'Todas las alertas leídas',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '${unreadCount + readCount} alertas en total',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
  }

  Widget _buildAlertCard(BuildContext context, QueryDocumentSnapshot doc,
      {required bool isNew}) {
    final data = doc.data() as Map<String, dynamic>;
    final message = data['message'] ?? '';
    final priority = data['priority'] ?? 'normal';
    final sentBy = data['sentBy'] ?? 'Admin';
    final createdAt = data['createdAt'] as Timestamp?;
    final date = createdAt?.toDate();

    final priorityConfig = _getPriorityConfig(priority);

    return GestureDetector(
      onTap: () {
        if (isNew) {
          AlertService.markAsRead(doc.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alerta marcada como leída'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isNew ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isNew ? (priorityConfig['color'] as Color) : Colors.grey[300]!,
            width: isNew ? 1.5 : 0.5,
          ),
          boxShadow: isNew
              ? [
                  BoxShadow(
                    color: (priorityConfig['color'] as Color).withOpacity(0.15),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Indicador de no leída
                  if (isNew)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: priorityConfig['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          (priorityConfig['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            (priorityConfig['color'] as Color).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(priorityConfig['icon'] as IconData,
                            size: 14, color: priorityConfig['color'] as Color),
                        const SizedBox(width: 4),
                        Text(
                          priorityConfig['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: priorityConfig['color'] as Color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (date != null)
                    Text(
                      _formatRelativeTime(date),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Mensaje
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: isNew ? Colors.grey[800] : Colors.grey[600],
                  fontWeight: isNew ? FontWeight.w500 : FontWeight.normal,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              // Footer
              Row(
                children: [
                  Icon(Icons.person, size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(sentBy,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const Spacer(),
                  if (date != null) ...[
                    Icon(Icons.calendar_today,
                        size: 11, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM/yyyy hh:mm a').format(date),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                  if (isNew) ...[
                    const SizedBox(width: 8),
                    Text('Toca para marcar leída',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[400],
                            fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Map<String, dynamic> _getPriorityConfig(String priority) {
    switch (priority) {
      case 'critical':
        return {'color': Colors.red, 'icon': Icons.error, 'label': 'CRÍTICA'};
      case 'high':
        return {'color': Colors.orange, 'icon': Icons.warning, 'label': 'ALTA'};
      default:
        return {'color': Colors.blue, 'icon': Icons.info, 'label': 'NORMAL'};
    }
  }

  Future<void> _markAllAsRead(BuildContext context, String userId) async {
    try {
      final unreadDocs = await FirebaseFirestore.instance
          .collection('alerts')
          .where('technicianId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadDocs.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No hay alertas pendientes'),
                backgroundColor: Colors.blue),
          );
        }
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${unreadDocs.docs.length} alertas marcadas como leídas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al marcar alertas'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}
