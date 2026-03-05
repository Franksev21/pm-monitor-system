import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pm_monitor/core/services/maintenance_schedule_service.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminMaintenanceReviewScreen extends StatefulWidget {
  final MaintenanceSchedule maintenance;

  const AdminMaintenanceReviewScreen({
    super.key,
    required this.maintenance,
  });

  @override
  State<AdminMaintenanceReviewScreen> createState() =>
      _AdminMaintenanceReviewScreenState();
}

class _AdminMaintenanceReviewScreenState
    extends State<AdminMaintenanceReviewScreen> {
  final _adminNotesController = TextEditingController();
  final _adminApprovalNotesController = TextEditingController();
  final _maintenanceService = MaintenanceScheduleService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _adminNotesController.text = widget.maintenance.adminNotes ?? '';
    _adminApprovalNotesController.text =
        widget.maintenance.adminApprovalNotes ?? '';
  }

  @override
  void dispose() {
    _adminNotesController.dispose();
    _adminApprovalNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completionColor = widget.maintenance.getCompletionColor();
    final completionPercentage = widget.maintenance.completionPercentage;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Revisión de Mantenimiento'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!widget.maintenance.isApproved)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveAdminNotes,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(completionColor, completionPercentage),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInformacionGeneral(),
                  const SizedBox(height: 16),
                  _buildFechas(),
                  const SizedBox(height: 16),
                  _buildTareasRealizadas(),
                  const SizedBox(height: 16),
                  _buildEvidenciasFotograficas(),
                  const SizedBox(height: 16),
                  _buildNotasTecnico(),
                  const SizedBox(height: 16),
                  _buildNotasAdministrador(),
                  const SizedBox(height: 16),
                  _buildNotasAprobacion(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.maintenance.isApproved
          ? null
          : FloatingActionButton.extended(
              onPressed: _isSaving ? null : _showApprovalDialog,
              backgroundColor: Colors.green,
              icon: const Icon(Icons.check_circle),
              label: const Text('Aprobar Mantenimiento'),
            ),
    );
  }

  Widget _buildHeader(Color completionColor, int completionPercentage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.build, color: Colors.blue[700]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.maintenance.equipmentName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.maintenance.clientName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: completionPercentage / 100,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          AlwaysStoppedAnimation<Color>(completionColor),
                    ),
                  ),
                  Text(
                    '$completionPercentage%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: completionColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Completitud del Mantenimiento',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: completionPercentage / 100,
                        minHeight: 12,
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(completionColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (widget.maintenance.isApproved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 16, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Aprobado',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Pendiente',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInformacionGeneral() {
    return _buildSection(
      title: 'Información General',
      icon: Icons.info_outline,
      color: Colors.blue,
      child: Column(
        children: [
          _buildInfoRow('Cliente:', widget.maintenance.clientName),
          _buildInfoRow('Ubicación:', widget.maintenance.location),
          _buildInfoRow('Equipo:', widget.maintenance.equipmentName),
          _buildInfoRow(
            'Categoría:',
            MaintenanceSchedule.getTypeDisplayName(widget.maintenance.type),
          ),
          _buildInfoRow(
            'Técnico:',
            widget.maintenance.technicianName ?? 'Sin asignar',
          ),
          _buildInfoRow(
            'T. Estimado:',
            widget.maintenance.estimatedHours != null &&
                    widget.maintenance.estimatedHours! > 0
                ? '${widget.maintenance.estimatedHours!.toStringAsFixed(1)} hrs'
                : 'No especificado',
          ),
        ],
      ),
    );
  }

  Widget _buildFechas() {
    final startedAt = widget.maintenance.startedAt;
    final completedDate = widget.maintenance.completedDate;
    final scheduledDate = widget.maintenance.scheduledDate;
    final estimatedHours = widget.maintenance.estimatedHours ?? 0;

    // Calcular duración real
    Duration? realDuration;
    String realDurationText = 'N/A';

    if (startedAt != null && completedDate != null) {
      realDuration = completedDate.difference(startedAt);
      final hours = realDuration.inHours;
      final minutes = realDuration.inMinutes.remainder(60);
      realDurationText =
          hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';
    }

    // Tiempo estimado display
    final estimatedDurationText = estimatedHours > 0
        ? '${estimatedHours.toStringAsFixed(1)} hrs'
        : 'No especificado';

    // ✅ NUEVA LÓGICA DE EFICIENCIA
    // efficiency = (realHours / estimatedHours) * 100
    // 100% = exactamente en tiempo
    // < 100% = más rápido que lo estimado
    // > 100% = más lento que lo estimado
    double? efficiency;
    String efficiencyText = 'N/A';
    Color efficiencyColor = Colors.grey;
    IconData efficiencyIcon = Icons.help_outline;

    if (realDuration != null && estimatedHours > 0) {
      final realHours = realDuration.inMinutes / 60;
      efficiency = (realHours / estimatedHours) * 100;
      efficiencyText = '${efficiency.toStringAsFixed(0)}%';

      if (efficiency >= 85 && efficiency <= 115) {
        // ✅ En tiempo (85–115%)
        efficiencyColor = Colors.green;
        efficiencyIcon = Icons.check_circle;
      } else if (efficiency >= 50 && efficiency < 85) {
        // ⚡ Más rápido de lo esperado (50–84%)
        efficiencyColor = Colors.blue;
        efficiencyIcon = Icons.bolt;
      } else if (efficiency < 50) {
        // ⚠️ Muy rápido — revisar calidad (< 50%)
        efficiencyColor = Colors.orange;
        efficiencyIcon = Icons.warning_amber;
      } else if (efficiency > 115 && efficiency <= 150) {
        // 🕐 Tomó más tiempo (116–150%)
        efficiencyColor = Colors.amber[700]!;
        efficiencyIcon = Icons.schedule;
      } else {
        // 🔴 Excedió significativamente (> 150%)
        efficiencyColor = Colors.red;
        efficiencyIcon = Icons.error;
      }
    }

    return _buildSection(
      title: 'Fechas',
      icon: Icons.calendar_today,
      color: Colors.green,
      child: Column(
        children: [
          // Programado con tiempo estimado
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  'Programado:',
                  DateFormat('dd/MM/yyyy HH:mm').format(scheduledDate),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      estimatedDurationText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Iniciado
          if (startedAt != null) ...[
            _buildInfoRow(
              'Iniciado:',
              DateFormat('dd/MM/yyyy HH:mm').format(startedAt),
            ),
            const SizedBox(height: 12),
          ],

          // Completado con duración real
          if (completedDate != null) ...[
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    'Completado:',
                    DateFormat('dd/MM/yyyy HH:mm').format(completedDate),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        realDurationText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: Colors.orange[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aún no se ha registrado la fecha de completado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ✅ Indicador de eficiencia con nueva lógica
          if (efficiency != null && estimatedHours > 0) ...[
            const SizedBox(height: 16),

            // Leyenda de referencia
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildEfficiencyLegend('< 50%', '⚠️ Revisar', Colors.orange),
                  _buildEfficiencyLegend('50–84%', '⚡ Rápido', Colors.blue),
                  _buildEfficiencyLegend('85–115%', '✅ Ok', Colors.green),
                  _buildEfficiencyLegend('> 115%', '🕐 Lento', Colors.red),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Badge principal de eficiencia
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: efficiencyColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: efficiencyColor.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(efficiencyIcon, color: efficiencyColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eficiencia del Técnico',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _getEfficiencyMessage(efficiency),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 70,
                    child: Text(
                      efficiencyText,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: efficiencyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEfficiencyLegend(String range, String label, Color color) {
    return Column(
      children: [
        Text(
          range,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  /// ✅ NUEVA lógica: efficiency = (realHours / estimatedHours) * 100
  /// 100% = exactamente en tiempo
  /// < 100% = más rápido | > 100% = más lento
  String _getEfficiencyMessage(double efficiency) {
    if (efficiency >= 85 && efficiency <= 115) {
      return 'Completado dentro del tiempo estimado ✓';
    } else if (efficiency >= 50 && efficiency < 85) {
      return 'Completado más rápido de lo esperado';
    } else if (efficiency < 50) {
      return 'Muy rápido — se recomienda revisar calidad';
    } else if (efficiency > 115 && efficiency <= 150) {
      return 'Tomó más tiempo que lo estimado';
    } else {
      return 'Excedió significativamente el tiempo estimado';
    }
  }

  Widget _buildTareasRealizadas() {
    final taskCompletion = widget.maintenance.taskCompletion ?? {};
    final completedTasks =
        taskCompletion.values.where((completed) => completed).length;
    final totalTasks = widget.maintenance.tasks.length;

    return _buildSection(
      title: 'Tareas Realizadas',
      icon: Icons.checklist,
      color: Colors.purple,
      trailing: Text(
        '$completedTasks / $totalTasks',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.purple[700],
        ),
      ),
      child: Column(
        children: widget.maintenance.tasks.map((task) {
          final isCompleted = taskCompletion[task] ?? false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.cancel,
                  color: isCompleted ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task,
                    style: TextStyle(
                      color: isCompleted ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEvidenciasFotograficas() {
    final photoUrls = widget.maintenance.photoUrls ?? [];

    return _buildSection(
      title: 'Evidencias Fotográficas',
      icon: Icons.photo_library,
      color: Colors.orange,
      trailing: Text(
        '${photoUrls.length} foto${photoUrls.length != 1 ? 's' : ''}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.orange[700],
        ),
      ),
      child: photoUrls.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No hay evidencias fotográficas',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: photoUrls.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photoUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNotasTecnico() {
    return _buildSection(
      title: '📝 Notas del Técnico',
      icon: Icons.engineering,
      color: Colors.indigo,
      child: widget.maintenance.hasTechnicianNotes
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo[200]!),
              ),
              child: Text(
                widget.maintenance.technicianNotes!,
                style: const TextStyle(fontSize: 14),
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'El técnico no dejó notas',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
    );
  }

  Widget _buildNotasAdministrador() {
    final isApproved = widget.maintenance.isApproved;

    return _buildSection(
      title: '📋 Notas del Administrador (Internas)',
      icon: Icons.admin_panel_settings,
      color: Colors.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estas notas son solo para uso interno y no serán visibles para el cliente.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adminNotesController,
            enabled: !isApproved,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Agregar notas internas sobre este mantenimiento...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: isApproved ? Colors.grey[100] : Colors.white,
            ),
          ),
          if (isApproved)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '⚠️ Mantenimiento aprobado. No se pueden editar las notas.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotasAprobacion() {
    final isApproved = widget.maintenance.isApproved;

    return _buildSection(
      title: '✉️ Mensaje para el Cliente',
      icon: Icons.send,
      color: Colors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observaciones: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adminApprovalNotesController,
            enabled: !isApproved,
            maxLines: 5,
            decoration: InputDecoration(
              hintText:
                  'Escribir mensaje profesional para el cliente sobre el trabajo realizado...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: isApproved ? Colors.grey[100] : Colors.white,
            ),
          ),
          if (isApproved) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '✅ Aprobado el ${DateFormat('dd/MM/yyyy HH:mm').format(widget.maintenance.approvedDate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAdminNotes() async {
    setState(() => _isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Usuario no autenticado');

      await _maintenanceService.updateAdminNotes(
        maintenanceId: widget.maintenance.id,
        adminNotes: _adminNotesController.text.trim(),
        adminApprovalNotes: _adminApprovalNotesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notas guardadas exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _approveMaintenance() async {
    setState(() => _isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Usuario no autenticado');

      await _maintenanceService.updateAdminNotes(
        maintenanceId: widget.maintenance.id,
        adminNotes: _adminNotesController.text.trim(),
        adminApprovalNotes: _adminApprovalNotesController.text.trim(),
        isApprovedByAdmin: true,
        approvedBy: currentUser.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Mantenimiento aprobado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showApprovalDialog() async {
    if (_adminApprovalNotesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '⚠️ Debes escribir un mensaje para el cliente antes de aprobar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar Mantenimiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Estás seguro de aprobar este mantenimiento?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Una vez aprobado, no podrás editar las notas.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _approveMaintenance();
    }
  }
}
