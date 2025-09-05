import 'package:flutter/material.dart';
import '../../../core/models/equipment_model.dart';
import '../../../core/services/qr_generator_service.dart';

class QRDisplayScreen extends StatelessWidget {
  final Equipment equipment;

  const QRDisplayScreen({Key? key, required this.equipment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Código QR - ${equipment.equipmentNumber}'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareQR(context),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadQR(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // QR Code principal
            Center(
              child: QRGeneratorService.buildQRWidget(equipment, size: 250),
            ),

            const SizedBox(height: 24),

            // Información del equipo
            _buildEquipmentInfo(),

            const SizedBox(height: 24),

            // Botones de acción
            _buildActionButtons(context),

            const SizedBox(height: 24),

            // Información técnica
            _buildTechnicalInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información del Equipo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Número', equipment.equipmentNumber),
            _buildInfoRow('RFID', equipment.rfidTag),
            _buildInfoRow('Nombre', equipment.name),
            _buildInfoRow(
                'Marca/Modelo', '${equipment.brand} ${equipment.model}'),
            _buildInfoRow(
                'Capacidad', '${equipment.capacity} ${equipment.capacityUnit}'),
            _buildInfoRow(
                'Ubicación', '${equipment.location}, ${equipment.branch}'),
            _buildInfoRow('Estado', equipment.status),
            _buildInfoRow('Condición',
                '${equipment.conditionIcon} ${equipment.condition}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _shareQR(context),
            icon: const Icon(Icons.share),
            label: const Text('Compartir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _downloadQR(context),
            icon: const Icon(Icons.download),
            label: const Text('Descargar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicalInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información Técnica del QR',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Este código QR contiene toda la información técnica del equipo en formato JSON. '
              'Puede ser escaneado por cualquier aplicación de lectura QR para obtener:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ...const [
              '• Especificaciones técnicas completas',
              '• Historial de costos',
              '• Información de mantenimiento',
              '• Datos de ubicación y estado',
              '• Códigos de identificación (RFID, Serie)',
            ].map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(item, style: TextStyle(color: Colors.grey[600])),
                )),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Formato: JSON estructurado',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[700],
                    ),
                  ),
                  Text(
                    'Versión: 1.0',
                    style: TextStyle(color: Colors.blue[600]),
                  ),
                  Text(
                    'Tipo: pm_monitor_equipment',
                    style: TextStyle(color: Colors.blue[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareQR(BuildContext context) async {
    try {
      await QRGeneratorService.shareQR(equipment);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error compartiendo QR: $e')),
      );
    }
  }

  Future<void> _downloadQR(BuildContext context) async {
    try {
      final file = await QRGeneratorService.generateQRImage(equipment);
      if (file != null) {
        // Copiar a galería o descargas
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR guardado en: ${file.path}'),
            action: SnackBarAction(
              label: 'Ver',
              onPressed: () {
                // Abrir archivo o galería
              },
            ),
          ),
        );
      } else {
        throw Exception('No se pudo generar la imagen');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error descargando QR: $e')),
      );
    }
  }
}
