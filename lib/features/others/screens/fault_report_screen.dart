import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/fault_report_model.dart';
import '../../../core/models/equipment_model.dart';
import '../../../core/services/fault_report_service.dart';

class FaultReportScreen extends StatefulWidget {
  final Equipment equipment;

  const FaultReportScreen({super.key, required this.equipment});

  @override
  _FaultReportScreenState createState() => _FaultReportScreenState();
}

class _FaultReportScreenState extends State<FaultReportScreen> {
  final _descriptionController = TextEditingController();
  final FaultReportService _faultService = FaultReportService();

  String _selectedSeverity = 'media';
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar Falla'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEquipmentCard(),
          const SizedBox(height: 16),
          _buildDescriptionField(),
          const SizedBox(height: 16),
          _buildSeveritySelector(),
          const SizedBox(height: 32),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.ac_unit, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                Text(widget.equipment.equipmentNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(widget.equipment.status,
                      style: const TextStyle(color: Colors.green, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${widget.equipment.brand} ${widget.equipment.model}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(widget.equipment.name,
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${widget.equipment.location}, ${widget.equipment.branch}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Descripción de la Falla',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe el problema que presenta el equipo...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeveritySelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nivel de Severidad',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...[
              {'value': 'baja', 'title': 'Baja', 'color': Colors.green},
              {'value': 'media', 'title': 'Media', 'color': Colors.orange},
              {'value': 'alta', 'title': 'Alta', 'color': Colors.red},
              {
                'value': 'critica',
                'title': 'Crítica',
                'color': Colors.red[800]!
              },
            ]
                .map((option) => RadioListTile<String>(
                      value: option['value'] as String,
                      groupValue: _selectedSeverity,
                      onChanged: (value) =>
                          setState(() => _selectedSeverity = value!),
                      title: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: option['color'] as Color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(option['title'] as String),
                        ],
                      ),
                    ))
                ,
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitReport,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _isSubmitting
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white)),
                SizedBox(width: 12),
                Text('Enviando...'),
              ],
            )
          : const Text('Reportar Falla', style: TextStyle(fontSize: 16)),
    );
  }

  Future<void> _submitReport() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor describe la falla')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      FaultReport faultReport = FaultReport(
        equipmentId: widget.equipment.id!,
        equipmentName: widget.equipment.name,
        equipmentNumber: widget.equipment.equipmentNumber,
        clientName: widget.equipment.branch ,
        clientId: widget.equipment.clientId,
        description: _descriptionController.text.trim(),
        severity: _selectedSeverity,
        reportedAt: DateTime.now(),
        location: '${widget.equipment.location}, ${widget.equipment.branch}',
      );

      String reportId = await _faultService.createFaultReport(faultReport);

      _showSuccessDialog(reportId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(String reportId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Falla Reportada',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Se han enviado notificaciones al equipo técnico',
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('ID: $reportId',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}
