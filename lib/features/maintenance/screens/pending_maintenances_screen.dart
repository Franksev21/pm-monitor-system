import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/features/maintenance/screens/maintenance_execution_screen.dart';

class PendingMaintenancesScreen extends StatefulWidget {
  const PendingMaintenancesScreen({super.key});

  @override
  State<PendingMaintenancesScreen> createState() =>
      _PendingMaintenancesScreenState();
}

class _PendingMaintenancesScreenState extends State<PendingMaintenancesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mantenimientos Pendientes'),
          backgroundColor: const Color(0xFF4285F4),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No hay usuario autenticado'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenimientos Pendientes'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('maintenanceSchedules')
            .where('technicianId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'assigned') // ✅ SOLO ASIGNADOS
            .orderBy('scheduledDate')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('❌ Error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[300],
                    ),
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
                  Text('Cargando mantenimientos pendientes...'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¡Excelente!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No tienes mantenimientos asignados',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver al Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final maintenances = snapshot.data!.docs;
          debugPrint('✅ ${maintenances.length} mantenimientos asignados');

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
    final type = data['type'] ?? 'preventive';

    // Colores según tipo
    Color statusColor = Colors.blue;
    String statusText = 'Preventivo';

    if (type == 'emergency') {
      statusColor = Colors.red;
      statusText = 'Urgente';
    } else if (type == 'corrective') {
      statusColor = Colors.orange;
      statusText = 'Correctivo';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMaintenanceDetails(id, data),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // IZQUIERDA: Nombre equipo + cliente
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipmentName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.business, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            clientName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // DERECHA: Tipo + Botones
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón Detalles
                      SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () => _showMaintenanceDetails(id, data),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: statusColor,
                            side: BorderSide(color: statusColor, width: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Detalles',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Botón Iniciar
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () => _startMaintenance(id, data),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: statusColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Iniciar',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMaintenanceDetails(String id, Map<String, dynamic> data) {
    final equipmentName = data['equipmentName'] ?? 'Equipo sin nombre';
    final clientName = data['clientName'] ?? 'Cliente no especificado';
    final location = data['location'] ?? data['branchName'] ?? 'Sin ubicación';
    final type = data['type'] ?? 'preventive';
    final estimatedHours = data['estimatedHours'] ?? 2;
    final description = data['description'] ?? '';
    final tasks = data['tasks'] as List<dynamic>?;

    String typeText = 'Preventivo';
    if (type == 'corrective') {
      typeText = 'Correctivo';
    } else if (type == 'emergency') {
      typeText = 'Emergencia';
    } else if (type == 'inspection') {
      typeText = 'Inspección';
    } else if (type == 'technicalAssistance') {
      typeText = 'Asistencia Técnica';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          equipmentName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.business, 'Cliente', clientName),
              _buildDetailRow(Icons.location_on, 'Ubicación', location),
              _buildDetailRow(Icons.category, 'Tipo', typeText),
              _buildDetailRow(
                  Icons.schedule, 'Duración estimada', '${estimatedHours}h'),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Descripción:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(description),
              ],
              if (tasks != null && tasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Tareas a realizar:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...tasks.map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(task.toString())),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _startMaintenance(id, data);
            },
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Iniciar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startMaintenance(String id, Map<String, dynamic> data) async {
    try {
      // Actualizar estado a 'inProgress' antes de navegar
      await _firestore.collection('maintenanceSchedules').doc(id).update({
        'status': 'inProgress',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Preparar datos completos del mantenimiento
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
        'photoUrls': data['photoUrls'] ?? [],
        'description': data['description'] ?? '',
        'notes': data['notes'] ?? '',
        'equipmentNumber': data['equipmentNumber'] ?? '',
        'equipmentCategory': data['equipmentCategory'] ?? '',
      };

      debugPrint('✅ Iniciando mantenimiento con datos: $maintenanceData');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Iniciando: ${data['equipmentName']}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        // Navegar a la pantalla de ejecución
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaintenanceExecutionScreen(
              maintenance: maintenanceData,
            ),
          ),
        );

        // Si el mantenimiento fue completado
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
      debugPrint('❌ Error al iniciar mantenimiento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar mantenimiento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
