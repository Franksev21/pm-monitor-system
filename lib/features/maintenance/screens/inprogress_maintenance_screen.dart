import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/features/maintenance/screens/maintenance_execution_screen.dart';

class InProgressMaintenancesScreen extends StatefulWidget {
  const InProgressMaintenancesScreen({super.key});

  @override
  State<InProgressMaintenancesScreen> createState() =>
      _InProgressMaintenancesScreenState();
}

class _InProgressMaintenancesScreenState
    extends State<InProgressMaintenancesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mantenimientos En Proceso'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No hay usuario autenticado'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenimientos En Proceso'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('maintenanceSchedules')
            .where('technicianId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'inProgress')
            .orderBy('startedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar datos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando mantenimientos en proceso...'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_outline, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay mantenimientos en proceso',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Inicia un mantenimiento para verlo aquí',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver al Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final maintenances = snapshot.data!.docs;
          debugPrint('✅ ${maintenances.length} mantenimientos en proceso');

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: maintenances.length,
              itemBuilder: (context, index) {
                final doc = maintenances[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildMaintenanceCard(doc.id, data);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMaintenanceCard(String id, Map<String, dynamic> data) {
    final equipmentName = data['equipmentName'] ?? 'Equipo sin nombre';
    final clientName = data['clientName'] ?? 'Cliente no especificado';
    final location = data['location'] ?? data['branchName'] ?? 'Sin ubicación';
    final startedAt = data['startedAt'] as Timestamp?;
    final type = data['type'] ?? 'preventive';
    final completionPercentage = data['completionPercentage'] ?? 0;

    String timeElapsed = 'Hace un momento';
    if (startedAt != null) {
      final started = startedAt.toDate();
      final now = DateTime.now();
      final difference = now.difference(started);

      if (difference.inHours > 0) {
        timeElapsed = 'Hace ${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        timeElapsed = 'Hace ${difference.inMinutes}min';
      }
    }

    Color statusColor = Colors.blue;
    IconData statusIcon = Icons.build_circle;

    if (type == 'emergency') {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
    } else if (type == 'corrective') {
      statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _continueMaintenance(id, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      equipmentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'EN PROCESO',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      clientName,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    timeElapsed,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Barra de progreso
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progreso',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$completionPercentage%',
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: completionPercentage / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _continueMaintenance(id, data),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Continuar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continueMaintenance(
      String id, Map<String, dynamic> data) async {
    try {
      final maintenanceData = {
        'id': id,
        'equipmentName': data['equipmentName'] ?? 'Equipo sin nombre',
        'clientName': data['clientName'] ?? 'Cliente no especificado',
        'location': data['location'] ?? data['branchName'] ?? 'Sin ubicación',
        'equipmentId': data['equipmentId'],
        'clientId': data['clientId'],
        'branchId': data['branchId'],
        'scheduledDate': data['scheduledDate'],
        'estimatedHours': data['estimatedHours'] ?? 2,
        'type': data['type'] ?? 'preventive',
        'frequency': data['frequency'] ?? 'monthly',
        'tasks': data['tasks'] ?? [],
        'description': data['description'] ?? '',
        'notes': data['notes'] ?? '',
        'equipmentNumber': data['equipmentNumber'] ?? '',
        'equipmentCategory': data['equipmentCategory'] ?? '',
        'photoUrls': data['photoUrls'] ?? [],
      };

      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaintenanceExecutionScreen(
              maintenance: maintenanceData,
            ),
          ),
        );

        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mantenimiento completado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error al continuar mantenimiento: $e');
      if (mounted) {
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
