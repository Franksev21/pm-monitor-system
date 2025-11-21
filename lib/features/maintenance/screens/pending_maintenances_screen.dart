import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
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
        // ✅ CAMBIO: Buscar por 'generated' y 'assigned' en lugar de 'scheduled' y 'pending'
        stream: _firestore
            .collection('maintenanceSchedules')
            .where('technicianId', isEqualTo: currentUserId)
            .where('status', whereIn: ['generated', 'assigned']) // ✅ CORREGIDO
            .orderBy('scheduledDate')
            .snapshots(),
        builder: (context, snapshot) {
          // Error
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

          // Cargando
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

          // Sin datos
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
                    'No tienes mantenimientos pendientes',
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

          // Datos disponibles
          final maintenances = snapshot.data!.docs;

          debugPrint('✅ ${maintenances.length} mantenimientos pendientes');

          return RefreshIndicator(
            onRefresh: () async {
              // El StreamBuilder se actualiza automáticamente
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
    // Extraer datos con valores por defecto
    final equipmentName = data['equipmentName'] ?? 'Equipo sin nombre';
    final clientName = data['clientName'] ?? 'Cliente no especificado';
    final location = data['location'] ?? data['branchName'] ?? 'Sin ubicación';
    final scheduledDate = data['scheduledDate'] as Timestamp?;
    final estimatedHours = data['estimatedHours'] ?? 2;
    final status = data['status'] ?? 'generated';
    final type = data['type'] ?? 'preventive';

    // Formatear fecha
    String dateStr = 'Sin fecha';
    String timeStr = '';
    if (scheduledDate != null) {
      final date = scheduledDate.toDate();
      dateStr = DateFormat('dd/MM/yyyy').format(date);
      timeStr = DateFormat('HH:mm').format(date);
    }

    // Determinar color según estado y tipo
    Color statusColor = Colors.blue;
    IconData statusIcon = Icons.schedule;
    String statusText = 'Asignado';

    if (status == 'generated') {
      statusColor = Colors.orange;
      statusIcon = Icons.new_releases;
      statusText = 'Generado';
    } else if (type == 'emergency') {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = 'Urgente';
    } else if (type == 'corrective') {
      statusColor = Colors.orange;
      statusIcon = Icons.build;
      statusText = 'Correctivo';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMaintenanceDetails(id, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
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
                ],
              ),

              const SizedBox(height: 12),

              // Cliente
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

              // Ubicación
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

              // Fecha y Duración
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(width: 16),
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${estimatedHours}h',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _startMaintenance(id, data),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Iniciar'),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showMaintenanceDetails(id, data),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Detalles'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: statusColor,
                        side: BorderSide(color: statusColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
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

    // Traducir tipo
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

  void _startMaintenance(String id, Map<String, dynamic> data) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Iniciando mantenimiento: ${data['equipmentName']}'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MaintenanceExecutionScreen( maintenance: {},
        ),
      ),
    );
  }
}
