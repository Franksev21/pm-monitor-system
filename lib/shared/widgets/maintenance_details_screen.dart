import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pm_monitor/core/services/maintenance_schedule_service.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_model.dart';
import 'package:pm_monitor/features/maintenance/screens/add_maintenance_screen.dart';

class MaintenanceDetailScreen extends StatefulWidget {
  final String maintenanceId;

  const MaintenanceDetailScreen({
    super.key,
    required this.maintenanceId,
  });

  @override
  State<MaintenanceDetailScreen> createState() =>
      _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<MaintenanceDetailScreen> {
  final MaintenanceScheduleService _service = MaintenanceScheduleService();
  MaintenanceSchedule? _maintenance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaintenance();
  }

  Future<void> _loadMaintenance() async {
    setState(() => _isLoading = true);

    final maintenance = await _service.getMaintenanceById(widget.maintenanceId);

    setState(() {
      _maintenance = maintenance;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del Mantenimiento'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_maintenance == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del Mantenimiento'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Mantenimiento no encontrado'),
        ),
      );
    }

    final m = _maintenance!;
    final statusColor = MaintenanceSchedule.getStatusColor(m.status);
    final statusIcon = MaintenanceSchedule.getStatusIcon(m.status);
    final statusName = MaintenanceSchedule.getStatusDisplayName(m.status);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Detalle del Mantenimiento'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Botón editar
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddMaintenanceScreen(),
                ),
              );

              // Si editó, recargar
              if (result == true) {
                _loadMaintenance();
              }
            },
          ),

          // Botón eliminar
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con estado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(color: statusColor.withOpacity(0.3)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          m.equipmentName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Información General
            _buildSection(
              title: 'Información General',
              children: [
                _buildInfoRow(
                  icon: Icons.business,
                  label: 'Cliente',
                  value: m.clientName,
                ),
                _buildInfoRow(
                  icon: Icons.location_on,
                  label: 'Sucursal',
                  value: m.branchName!,
                ),
                _buildInfoRow(
                  icon: Icons.build,
                  label: 'Equipo',
                  value: m.equipmentName,
                ),
                _buildInfoRow(
                  icon: Icons.category,
                  label: 'Tipo',
                  value: MaintenanceSchedule.getTypeDisplayName(m.type),
                ),
              ],
            ),

            // Programación
            _buildSection(
              title: 'Programación',
              children: [
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  label: 'Fecha programada',
                  value: DateFormat('dd/MM/yyyy HH:mm').format(m.scheduledDate),
                ),
                _buildInfoRow(
                  icon: Icons.schedule,
                  label: 'Duración estimada',
                  value: m.estimatedHours != null
                      ? "${m.estimatedHours} hrs"
                      : "${m.estimatedHours!.toDouble().toInt()} min",
                ),
                _buildInfoRow(
                  icon: Icons.repeat,
                  label: 'Frecuencia',
                  value: m.frequency != null
                      ? _getFrequencyName(m.frequency!.toString())
                      : 'No recurrente',
                ),
              ],
            ),

            // Técnico Asignado
            if (m.technicianName != null)
              _buildSection(
                title: 'Técnico Asignado',
                children: [
                  _buildInfoRow(
                    icon: Icons.person,
                    label: 'Nombre',
                    value: m.technicianName!,
                  ),
                ],
              ),

            // Tareas Programadas
            if (m.tasks.isNotEmpty)
              _buildSection(
                title: 'Tareas a Realizar',
                children: m.tasks.toList()
                    .map((task) => _buildTaskItem(task))
                    .toList(),
              ),

            // Ejecución (si está ejecutado)
            if (m.status == MaintenanceStatus.executed) ...[
              _buildSection(
                title: 'Información de Ejecución',
                children: [
                  if (m.completedBy != null)
                    _buildInfoRow(
                      icon: Icons.person_outline,
                      label: 'Completado por',
                      value: m.completedBy!,
                    ),
                  if (m.completedDate != null)
                    _buildInfoRow(
                      icon: Icons.check_circle_outline,
                      label: 'Fecha de completado',
                      value: DateFormat('dd/MM/yyyy HH:mm')
                          .format(m.completedDate!),
                    ),
                  _buildInfoRow(
                    icon: Icons.percent,
                    label: 'Porcentaje completado',
                    value: '${m.completionPercentage}%',
                  ),
                  if (m.notes != null && m.notes!.isNotEmpty)
                    _buildInfoRow(
                      icon: Icons.note,
                      label: 'Notas',
                      value: m.notes!,
                    ),
                ],
              ),

              // Fotos
              if (m.photoUrls != null && m.photoUrls!.isNotEmpty)
                _buildSection(
                  title: 'Evidencias Fotográficas',
                  children: [
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: m.photoUrls!.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                m.photoUrls![index],
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _getFrequencyName(String frequency) {
    switch (frequency) {
      case 'weekly':
        return 'Semanal';
      case 'biweekly':
        return 'Bi-semanal';
      case 'monthly':
        return 'Mensual';
      case 'bimonthly':
        return 'Cada 2 meses';
      case 'quarterly':
        return 'Trimestral';
      case 'fourmonthly':
        return 'Cuatrimestral';
      case 'semiannual':
        return 'Semestral';
      case 'annual':
        return 'Anual';
      default:
        return frequency;
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Mantenimiento'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este mantenimiento?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Cerrar diálogo

              // Mostrar loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                await _service.deleteMaintenance(widget.maintenanceId);

                Navigator.pop(context); // Cerrar loading
                Navigator.pop(context, true); // Volver con resultado

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mantenimiento eliminado'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context); // Cerrar loading

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
