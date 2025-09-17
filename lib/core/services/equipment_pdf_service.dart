import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../models/equipment_model.dart';
import 'qr_generator_service.dart';

class EquipmentPDFService {
  static const String _appName = 'PM MONITOR';

  /// Generar PDF completo del equipo
  static Future<Uint8List> generateEquipmentPDF(Equipment equipment) async {
    final pdf = pw.Document();

    // Generar QR como imagen para incluir en PDF
    final qrImageData = await _generateQRImageData(equipment);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(equipment),
            pw.SizedBox(height: 20),

            // QR Section
            _buildQRSection(equipment, qrImageData),
            pw.SizedBox(height: 20),

            // Información General
            _buildInfoSection('INFORMACIÓN GENERAL', [
              ['Número de Equipo', equipment.equipmentNumber],
              ['RFID Tag', equipment.rfidTag],
              ['Nombre', equipment.name],
              [
                'Descripción',
                equipment.description.isNotEmpty ? equipment.description : 'N/A'
              ],
              ['Categoría', equipment.category],
              [
                'Número de Serie',
                equipment.serialNumber.isNotEmpty
                    ? equipment.serialNumber
                    : 'N/A'
              ],
            ]),
            pw.SizedBox(height: 15),

            // Especificaciones Técnicas
            _buildInfoSection('ESPECIFICACIONES TÉCNICAS', [
              ['Marca', equipment.brand],
              ['Modelo', equipment.model],
              ['Capacidad', '${equipment.capacity} ${equipment.capacityUnit}'],
              ['Estado', equipment.status],
              ['Condición', equipment.condition],
              ['Vida Útil (1-10)', '${equipment.lifeScale}'],
            ]),
            pw.SizedBox(height: 15),

            // Ubicación
            _buildInfoSection('UBICACIÓN E INSTALACIÓN', [
              ['Ubicación', equipment.location],
              ['Sucursal', equipment.branch],
              ['País', equipment.country],
              ['Región', equipment.region],
              ['Dirección', equipment.address],
            ]),
            pw.SizedBox(height: 15),

            // Costos
            _buildCostSection(equipment),
            pw.SizedBox(height: 15),

            // Mantenimiento
            _buildMaintenanceSection(equipment),
            pw.SizedBox(height: 30),

            // Footer
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generar imagen QR para incluir en PDF
  static Future<Uint8List?> _generateQRImageData(Equipment equipment) async {
    try {
      // Usar el servicio existente para generar el archivo QR
      final qrFile =
          await QRGeneratorService.generateQRImage(equipment, size: 200);
      if (qrFile != null) {
        return await qrFile.readAsBytes();
      }
      return null;
    } catch (e) {
      print('Error generando QR para PDF: $e');
      return null;
    }
  }

  /// Header del PDF
  static pw.Widget _buildHeader(Equipment equipment) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.blue700, PdfColors.blue500],
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _appName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Sistema de Mantenimiento Preventivo',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'FICHA TÉCNICA',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Generado: ${_formatDateTime(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  equipment.name,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.Text(
                  '${equipment.brand} ${equipment.model}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Equipo: ${equipment.equipmentNumber}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sección del QR Code
  static pw.Widget _buildQRSection(
      Equipment equipment, Uint8List? qrImageData) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // QR Code
          pw.Container(
            width: 120,
            height: 120,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: qrImageData != null
                ? pw.Image(
                    pw.MemoryImage(qrImageData),
                    fit: pw.BoxFit.contain,
                  )
                : pw.Center(
                    child: pw.Text(
                      'QR Code\nNo disponible',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
          ),

          pw.SizedBox(width: 20),

          // Información del QR
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Código QR del Equipo',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Este código QR contiene toda la información técnica del equipo en formato JSON estructurado para acceso rápido desde dispositivos móviles.',
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Información incluida en el QR:',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                ...const [
                  '• Especificaciones técnicas completas',
                  '• Códigos de identificación (RFID, Serie)',
                  '• Estado actual y condición del equipo',
                  '• Información de ubicación e instalación',
                  '• Historial de costos y mantenimiento',
                  '• Metadatos de creación y actualización',
                ].map((item) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(
                        item,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construir sección de información
  static pw.Widget _buildInfoSection(String title, List<List<String>> data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
            },
            children: data.map((row) {
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      row[0],
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      row[1],
                      style: pw.TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Sección de costos
  static pw.Widget _buildCostSection(Equipment equipment) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(
            color: PdfColors.green100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'INFORMACIÓN DE COSTOS',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green700,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Concepto',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Moneda',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Monto',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              // Datos
              ...[
                [
                  'Costo del Equipo',
                  equipment.currency,
                  _formatCurrency(equipment.equipmentCost)
                ],
                [
                  'Mantenimientos Preventivos',
                  equipment.currency,
                  _formatCurrency(equipment.totalPmCost)
                ],
                [
                  'Mantenimientos Correctivos',
                  equipment.currency,
                  _formatCurrency(equipment.totalCmCost)
                ],
                [
                  'TOTAL INVERTIDO',
                  equipment.currency,
                  _formatCurrency(equipment.totalCost)
                ],
              ].map((row) {
                final isTotal = row[0].contains('TOTAL');
                return pw.TableRow(
                  decoration: isTotal
                      ? pw.BoxDecoration(color: PdfColors.green50)
                      : null,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        row[0],
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: isTotal
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        row[1],
                        style: pw.TextStyle(fontSize: 11),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        row[2],
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: isTotal
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  /// Sección de mantenimiento
  static pw.Widget _buildMaintenanceSection(Equipment equipment) {
    return _buildInfoSection('PROGRAMACIÓN DE MANTENIMIENTO', [
      ['Frecuencia', equipment.maintenanceFrequency],
      ['Frecuencia (días)', '${equipment.frequencyDays} días'],
      [
        'Horas Estimadas',
        '${equipment.estimatedMaintenanceHours}h por mantenimiento'
      ],
      [
        'Último Mantenimiento',
        equipment.lastMaintenanceDate != null
            ? _formatDateTime(equipment.lastMaintenanceDate!)
            : 'Nunca'
      ],
      [
        'Próximo Mantenimiento',
        equipment.nextMaintenanceDate != null
            ? _formatDateTime(equipment.nextMaintenanceDate!)
            : 'No programado'
      ],
      [
        'Alertas de Mantenimiento',
        equipment.enableMaintenanceAlerts ? 'Habilitadas' : 'Deshabilitadas'
      ],
      [
        'Alertas de Fallas',
        equipment.enableFailureAlerts ? 'Habilitadas' : 'Deshabilitadas'
      ],
      [
        'Monitoreo de Temperatura',
        equipment.hasTemperatureMonitoring ? 'Habilitado' : 'Deshabilitado'
      ],
    ]);
  }

  /// Footer del PDF
  static pw.Widget _buildFooter() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            '$_appName - Sistema de Mantenimiento Preventivo',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Documento generado automáticamente el ${_formatDateTime(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Este documento contiene información confidencial del equipo y debe ser manejado de acuerdo a las políticas de la empresa.',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Formatear fecha y hora
  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Formatear moneda
  static String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }

  /// Guardar PDF en el dispositivo
  static Future<File?> savePDFToDevice(Equipment equipment) async {
    try {
      final pdfData = await generateEquipmentPDF(equipment);
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'Equipo_${equipment.equipmentNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pdfData);
      return file;
    } catch (e) {
      print('Error guardando PDF: $e');
      return null;
    }
  }

  /// Compartir PDF
  static Future<void> sharePDF(Equipment equipment) async {
    try {
      final file = await savePDFToDevice(equipment);
      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              'Ficha técnica del equipo ${equipment.equipmentNumber}\n${equipment.name}',
          subject:
              'Equipo ${equipment.equipmentNumber} - ${equipment.brand} ${equipment.model}',
        );
      }
    } catch (e) {
      print('Error compartiendo PDF: $e');
    }
  }

  /// Vista previa para imprimir
  static Future<void> printPDF(Equipment equipment) async {
    try {
      final pdfData = await generateEquipmentPDF(equipment);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name: 'Equipo_${equipment.equipmentNumber}',
      );
    } catch (e) {
      print('Error imprimiendo PDF: $e');
    }
  }
}
