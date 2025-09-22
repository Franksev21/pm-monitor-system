import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/equipment_model.dart';
import '../../../core/services/qr_generator_service.dart';
import '../../../core/services/equipment_pdf_service.dart';

class QRDisplayScreen extends StatefulWidget {
  final Equipment equipment;

  const QRDisplayScreen({Key? key, required this.equipment}) : super(key: key);

  @override
  State<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends State<QRDisplayScreen> {
  QRType _selectedQRType = QRType.whatsappInfo;
  bool _isGeneratingPDF = false;
  bool _isSharingQR = false;
  bool _isSharingPDF = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Código QR - ${widget.equipment.equipmentNumber}'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share_qr',
                child: ListTile(
                  leading: Icon(Icons.qr_code),
                  title: Text('Compartir QR'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'share_all_qr',
                child: ListTile(
                  leading: Icon(Icons.qr_code_2),
                  title: Text('Compartir Todos los QR'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'share_pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf),
                  title: Text('Compartir PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'print_pdf',
                child: ListTile(
                  leading: Icon(Icons.print),
                  title: Text('Imprimir PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Selector de tipo de QR
            _buildQRTypeSelector(),

            const SizedBox(height: 16),

            // QR Code principal
            Center(
              child: QRGeneratorService.buildQRWidget(
                widget.equipment,
                size: 250,
                type: _selectedQRType,
              ),
            ),

            const SizedBox(height: 24),

            // Información sobre el tipo de QR seleccionado
            _buildQRTypeInfo(),

            const SizedBox(height: 24),

            // Información del equipo
            _buildEquipmentInfo(),

            const SizedBox(height: 24),

            // Botones de acción principales
            _buildMainActionButtons(),

            const SizedBox(height: 16),

            // Botones secundarios
            _buildSecondaryActionButtons(),

            const SizedBox(height: 24),

            // Información técnica
            _buildTechnicalInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildQRTypeSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipo de Código QR',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...QRType.values.map((type) => RadioListTile<QRType>(
                  title: Text(QRGeneratorService.getQRTypeTitle(type)),
                  subtitle: Text(
                    QRGeneratorService.getQRTypeDescription(type),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: type,
                  groupValue: _selectedQRType,
                  onChanged: (QRType? value) {
                    if (value != null) {
                      setState(() {
                        _selectedQRType = value;
                      });
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildQRTypeInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            QRGeneratorService.getQRTypeColor(_selectedQRType).withOpacity(0.1),
        border: Border.all(
            color: QRGeneratorService.getQRTypeColor(_selectedQRType)
                .withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getQRTypeIcon(_selectedQRType),
                color: Colors.blueGrey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                QRGeneratorService.getQRTypeTitle(_selectedQRType),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: QRGeneratorService.getQRTypeColor(_selectedQRType),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            QRGeneratorService.getQRTypeDescription(_selectedQRType),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getQRTypeIcon(QRType type) {
    switch (type) {
      case QRType.whatsappInfo:
        return Icons.message;
      case QRType.webUrl:
        return Icons.web;
      case QRType.appDeepLink:
        return Icons.phone_android;
      case QRType.jsonData:
        return Icons.code;
    }
  }

  Widget _buildEquipmentInfo() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFF1976D2),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Información del Equipo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Número', widget.equipment.equipmentNumber),
            _buildInfoRow('RFID', widget.equipment.rfidTag),
            _buildInfoRow('Nombre', widget.equipment.name),
            _buildInfoRow('Marca/Modelo',
                '${widget.equipment.brand} ${widget.equipment.model}'),
            _buildInfoRow('Capacidad',
                '${widget.equipment.capacity} ${widget.equipment.capacityUnit}'),
            _buildInfoRow('Ubicación',
                '${widget.equipment.location}, ${widget.equipment.branch}'),
            _buildInfoRow('Estado', widget.equipment.status),
            _buildInfoRow('Condición', widget.equipment.condition),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButtons() {
    return Column(
      children: [
        // Compartir QR del tipo seleccionado
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isSharingQR ? null : () => _shareQR(),
            icon: _isSharingQR
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Icon(Icons.qr_code),
            label:
                Text(_isSharingQR ? 'Compartiendo...' : 'Compartir Código QR'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  QRGeneratorService.getQRTypeColor(_selectedQRType),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Generar y Compartir PDF
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isSharingPDF ? null : () => _sharePDF(),
            icon: _isSharingPDF
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Text(
                _isSharingPDF ? 'Generando PDF...' : 'Generar y Compartir PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isGeneratingPDF ? null : () => _savePDF(),
            icon: _isGeneratingPDF
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_isGeneratingPDF ? 'Guardando...' : 'Descargar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1976D2),
              side: const BorderSide(color: Color(0xFF1976D2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _printPDF(),
            icon: const Icon(Icons.print),
            label: const Text('Imprimir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicalInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: const Color(0xFF1976D2),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Información Técnica',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Diferentes tipos de códigos QR para distintos usos:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            _buildFeatureSection(
              'Imagen Web',
              Icons.image,
              Colors.purple,
              [
                'Abre directamente una imagen visual',
                'Información completa en formato gráfico',
                'Compatible con cualquier lector QR',
                'No requiere app especial',
              ],
            ),
            const SizedBox(height: 12),
            _buildFeatureSection(
              'Página Web',
              Icons.web,
              Colors.green,
              [
                'Información organizada en formato web',
                'Responsive para móviles',
                'Fácil de compartir URL',
              ],
            ),
            const SizedBox(height: 12),
            _buildFeatureSection(
              'App Directa',
              Icons.phone_android,
              Colors.blue,
              [
                'Abre directamente en PM Monitor',
                'Acceso completo a funciones',
                'Requiere app instalada',
              ],
            ),
            const SizedBox(height: 12),
            _buildFeatureSection(
              'Datos JSON',
              Icons.code,
              Colors.orange,
              [
                'Información técnica completa',
                'Para desarrolladores',
                'Integración con otros sistemas',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureSection(
      String title, IconData icon, Color color, List<String> features) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // Métodos de acción
  void _handleMenuSelection(String value) {
    switch (value) {
      case 'share_qr':
        _shareQR();
        break;
      case 'share_all_qr':
        _shareAllQRTypes();
        break;
      case 'share_pdf':
        _sharePDF();
        break;
      case 'print_pdf':
        _printPDF();
        break;
    }
  }

  Future<void> _shareQR() async {
    setState(() {
      _isSharingQR = true;
    });

    try {
      await QRGeneratorService.shareQR(widget.equipment, type: _selectedQRType);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código QR compartido exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error compartiendo QR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharingQR = false;
        });
      }
    }
  }

  Future<void> _shareAllQRTypes() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generando todos los tipos de QR...'),
            ],
          ),
        ),
      );

      final files =
          await QRGeneratorService.generateAllQRTypes(widget.equipment);

      if (mounted) {
        Navigator.of(context).pop();

        if (files.isNotEmpty) {
          // Compartir todos los archivos
          await Share.shareXFiles(
            files.map((f) => XFile(f.path)).toList(),
            text: 'Códigos QR del equipo ${widget.equipment.equipmentNumber}',
            subject:
                'Equipo ${widget.equipment.equipmentNumber} - Todos los QR',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('${files.length} códigos QR compartidos exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generando QRs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sharePDF() async {
    setState(() {
      _isSharingPDF = true;
    });

    try {
      await EquipmentPDFService.sharePDF(widget.equipment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generado y compartido exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generando PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharingPDF = false;
        });
      }
    }
  }

  Future<void> _savePDF() async {
    setState(() {
      _isGeneratingPDF = true;
    });

    try {
      final file = await EquipmentPDFService.savePDFToDevice(widget.equipment);

      if (file != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF guardado exitosamente'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Ver ubicación',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Archivo guardado en: ${file.path}'),
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPDF = false;
        });
      }
    }
  }

  Future<void> _printPDF() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparando documento para imprimir...'),
            ],
          ),
        ),
      );

      await EquipmentPDFService.printPDF(widget.equipment);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparando impresión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
