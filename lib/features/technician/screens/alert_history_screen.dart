// lib/features/technician/screens/alert_history_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AlertHistoryScreen extends StatelessWidget {
  final String technicianId;
  final String technicianName;

  const AlertHistoryScreen({
    super.key,
    required this.technicianId,
    required this.technicianName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historial de Alertas',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            Text(technicianName,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .where('technicianId', isEqualTo: technicianId)
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
                  const SizedBox(height: 8),
                  Text('${snapshot.error}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No hay alertas enviadas',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('Las alertas enviadas a $technicianName aparecerán aquí',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          // Agrupar por fecha
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = data['createdAt'] as Timestamp?;
            final date = createdAt?.toDate() ?? DateTime.now();
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            grouped.putIfAbsent(dateKey, () => []).add(doc);
          }

          final sortedKeys = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final dateKey = sortedKeys[index];
              final alerts = grouped[dateKey]!;
              final date = DateTime.parse(dateKey);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado de fecha
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: 8, top: index > 0 ? 16 : 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDateHeader(date),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                            '${alerts.length} alerta${alerts.length > 1 ? 's' : ''}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  // Alertas del día
                  ...alerts.map((doc) => _buildAlertCard(doc)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Hoy';
    if (dateOnly == yesterday) return 'Ayer';
    return DateFormat('dd MMM yyyy', 'es').format(date);
  }

  Widget _buildAlertCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final message = data['message'] ?? '';
    final priority = data['priority'] ?? 'normal';
    final sentBy = data['sentBy'] ?? 'Admin';
    final isRead = data['isRead'] ?? false;
    final createdAt = data['createdAt'] as Timestamp?;
    final readAt = data['readAt'] as Timestamp?;
    final date = createdAt?.toDate();

    final priorityConfig = _getPriorityConfig(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? Colors.grey[300]! : priorityConfig['color'] as Color,
          width: isRead ? 0.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: prioridad + hora
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (priorityConfig['color'] as Color).withOpacity(0.1),
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
                // Estado leído/no leído
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRead ? Icons.done_all : Icons.schedule,
                        size: 12,
                        color: isRead ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isRead ? 'Leída' : 'No leída',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color:
                              isRead ? Colors.green[700] : Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Mensaje
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            // Footer: enviado por + fecha/hora
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.send, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text('Enviada por: ',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500])),
                      Text(sentBy,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (date != null) ...[
                        Icon(Icons.access_time,
                            size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('hh:mm a').format(date),
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                  if (isRead && readAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.done_all,
                            size: 13, color: Colors.green[400]),
                        const SizedBox(width: 6),
                        Text('Leída: ',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                        Text(
                          DateFormat('dd/MM/yyyy hh:mm a')
                              .format(readAt.toDate()),
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[600],
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getPriorityConfig(String priority) {
    switch (priority) {
      case 'critical':
        return {
          'color': Colors.red,
          'icon': Icons.error,
          'label': 'CRÍTICA',
        };
      case 'high':
        return {
          'color': Colors.orange,
          'icon': Icons.warning,
          'label': 'ALTA',
        };
      default:
        return {
          'color': Colors.blue,
          'icon': Icons.info,
          'label': 'NORMAL',
        };
    }
  }
}
