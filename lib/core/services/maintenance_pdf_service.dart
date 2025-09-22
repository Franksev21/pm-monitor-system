import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class MaintenancePDFService {
  static const String _appName = 'PM MONITOR';

  /// Generar PDF de un mantenimiento completado individual
  static Future<Uint8List> generateMaintenancePDF(Map<String, dynamic> maintenance) async {
    final pdf = pw.Document();

    // Descargar fotos para incluir en el PDF
    final photoImages = await _downloadPhotos(maintenance['photoUrls'] as List? ?? []);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            _buildMaintenanceHeader(maintenance),
            pw.SizedBox(height: 20),

            // Información del mantenimiento
            _buildMaintenanceInfo(maintenance),
            pw.SizedBox(height: 20),

            // Tareas realizadas
            _buildTasksSection(maintenance),
            pw.SizedBox(height: 20),

            // Fechas y duración
            _buildDatesSection(maintenance),
            pw.SizedBox(height: 20),

            // Evidencias fotográficas
            if (photoImages.isNotEmpty) ...[
              _buildPhotosSection(photoImages),
              pw.SizedBox(height: 20),
            ],

            // Notas y observaciones
            if (maintenance['notes'] != null && maintenance['notes'].toString().isNotEmpty)
              _buildNotesSection(maintenance['notes'].toString()),

            pw.SizedBox(height: 30),

            // Footer
            _buildMaintenanceFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generar PDF de reporte diario de mantenimientos
  static Future<Uint8List> generateDailyReportPDF(
    List<Map<String, dynamic>> maintenances,
    DateTime date,
  ) async {
    final pdf = pw.Document();

    // Calcular estadísticas
    final stats = _calculateDailyStats(maintenances);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header del reporte diario
            _buildDailyReportHeader(date),
            pw.SizedBox(height: 20),

            // Resumen estadístico
            _buildDailyStatsSection(stats),
            pw.SizedBox(height: 20),

            // Lista de mantenimientos
            _buildDailyMaintenancesList(maintenances),
            pw.SizedBox(height: 30),

            // Footer
            _buildReportFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generar PDF de reporte de período (semanal, mensual, etc.)
  static Future<Uint8List> generatePeriodReportPDF(
    List<Map<String, dynamic>> maintenances,
    DateTime startDate,
    DateTime endDate,
    String periodType,
  ) async {
    final pdf = pw.Document();

    // Calcular estadísticas del período
    final stats = _calculatePeriodStats(maintenances);
    final groupedByDate = _groupMaintenancesByDate(maintenances);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header del reporte
            _buildPeriodReportHeader(startDate, endDate, periodType),
            pw.SizedBox(height: 20),

            // Resumen ejecutivo
            _buildExecutiveSummary(stats),
            pw.SizedBox(height: 20),

            // Gráficos y métricas
            _buildMetricsSection(stats),
            pw.SizedBox(height: 20),

            // Detalle por días
            _buildDailyBreakdown(groupedByDate),
            pw.SizedBox(height: 20),

            // Técnicos más activos
            _buildTechniciansSection(maintenances),
            pw.SizedBox(height: 30),

            // Footer
            _buildReportFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Descargar fotos de URLs para incluir en PDF
  static Future<List<Uint8List>> _downloadPhotos(List<dynamic> photoUrls) async {
    List<Uint8List> images = [];
    
    for (String url in photoUrls) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          images.add(response.bodyBytes);
        }
      } catch (e) {
        print('Error downloading photo: $e');
        // Continuar con las demás fotos
      }
    }
    
    return images;
  }

  /// Header del PDF de mantenimiento individual
  static pw.Widget _buildMaintenanceHeader(Map<String, dynamic> maintenance) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.green700, PdfColors.green500],
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
                    'Reporte de Mantenimiento Completado',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(16),
                ),
                child: pw.Text(
                  'COMPLETADO',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
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
                  maintenance['equipmentName'] ?? 'Equipo',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
                pw.Text(
                  'Cliente: ${maintenance['clientName'] ?? 'No especificado'}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Técnico: ${maintenance['technicianName'] ?? 'No asignado'}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Información básica del mantenimiento
  static pw.Widget _buildMaintenanceInfo(Map<String, dynamic> maintenance) {
    return _buildInfoSection('INFORMACIÓN DEL MANTENIMIENTO', [
      ['Tipo de Mantenimiento', maintenance['type'] ?? 'Preventivo'],
      ['Frecuencia', maintenance['frequency'] ?? 'No especificada'],
      ['Ubicación', maintenance['location'] ?? 'No especificada'],
      ['Duración Estimada', '${maintenance['estimatedDurationMinutes'] ?? 0} minutos'],
      ['Progreso Completado', '${maintenance['completionPercentage'] ?? 100}%'],
    ]);
  }

  /// Sección de tareas realizadas
  static pw.Widget _buildTasksSection(Map<String, dynamic> maintenance) {
    final tasks = maintenance['tasks'] as List? ?? [];
    final taskCompletion = maintenance['taskCompletion'] as Map? ?? {};

    if (tasks.isEmpty) {
      return pw.Container();
    }

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
            'TAREAS REALIZADAS',
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
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: tasks.map((task) {
              final isCompleted = taskCompletion[task.toString()] == true;
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 12,
                      height: 12,
                      decoration: pw.BoxDecoration(
                        color: isCompleted ? PdfColors.green : PdfColors.grey300,
                        shape: pw.BoxShape.circle,
                      ),
                      child: isCompleted
                          ? pw.Center(
                              child: pw.Text(
                                '✓',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        task.toString(),
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: isCompleted ? PdfColors.grey600 : PdfColors.black,
                          decoration: isCompleted ? pw.TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

static pw.Widget _buildDatesSection(Map<String, dynamic> maintenance) {
    return _buildInfoSection('FECHAS Y DURACIÓN', [
      _buildDateRow('Fecha Programada', maintenance['scheduledDate']),
      _buildDateRow('Fecha de Finalización', maintenance['completedAt']),
      _buildDurationRow(
          'Duración Estimada', maintenance['estimatedDurationMinutes']),
      _buildCostRow('Costo Estimado', maintenance['estimatedCost']),
      _buildCostRow('Costo Real', maintenance['actualCost']),
    ]);
  }

  static List<String> _buildDateRow(String label, dynamic date) {
    return [label, _formatDateTime(date)];
  }

  static List<String> _buildDurationRow(String label, int? minutes) {
    final duration = minutes ?? 0;
    final hours = duration ~/ 60;
    final mins = duration % 60;
    final formatted = hours > 0 ? '$hours h $mins min' : '$mins minutos';
    return [label, formatted];
  }

  static List<String> _buildCostRow(String label, double? cost) {
    return [
      label,
      cost != null ? '\$${cost.toStringAsFixed(2)}' : 'No especificado'
    ];
  }


  /// Sección de evidencias fotográficas
  static pw.Widget _buildPhotosSection(List<Uint8List> photoImages) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(
            color: PdfColors.orange100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'EVIDENCIAS FOTOGRÁFICAS',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange700,
            ),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.GridView(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: photoImages.take(4).map((imageData) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.ClipRRect(
                child: pw.Image(
                  pw.MemoryImage(imageData),
                  fit: pw.BoxFit.cover,
                  // borderRadius: pw.BorderRadius.circular(6),
                ),
              ),
            );
          }).toList(),
        ),
        if (photoImages.length > 4)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Se muestran 4 de ${photoImages.length} fotos disponibles',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  /// Sección de notas
  static pw.Widget _buildNotesSection(String notes) {
    return _buildInfoSection('NOTAS Y OBSERVACIONES', [
      ['Observaciones del Técnico', notes],
    ]);
  }

  /// Header para reporte diario
  static pw.Widget _buildDailyReportHeader(DateTime date) {
    final dayString = DateFormat('EEEE', 'es').format(date);
    final dateString = DateFormat('dd/MM/yyyy', 'es').format(date);

    return pw.Row(
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
                color: PdfColors.blue700,
              ),
            ),
            pw.Text(
              'Reporte Diario de Mantenimientos',
              style: pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '$dayString, $dateString',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Generado el:',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Text(
              DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
              style: pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  /// Construir sección de información genérica
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

  /// Footer del PDF de mantenimiento
  static pw.Widget _buildMaintenanceFooter() {
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
              color: PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Reporte generado automáticamente el ${_formatDateTime(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Este documento certifica la ejecución y completación del mantenimiento según los estándares establecidos.',
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

  // Métodos auxiliares para reportes de período (implementación básica)
  
  static pw.Widget _buildPeriodReportHeader(DateTime start, DateTime end, String type) {
    return pw.Container(); // Implementar según necesidad
  }

  static pw.Widget _buildDailyStatsSection(Map<String, dynamic> stats) {
    return pw.Container(); // Implementar según necesidad
  }

  static pw.Widget _buildDailyMaintenancesList(List<Map<String, dynamic>> maintenances) {
    return pw.Container(); // Implementar según necesidad
  }

  static pw.Widget _buildExecutiveSummary(Map<String, dynamic> stats) {
    return pw.Container(); // Implementar según necesidad
  }

  static pw.Widget _buildMetricsSection(Map<String, dynamic> stats) {
    return pw.Container(); // Implementar según necesidad
  }

  static pw.Widget _buildDailyBreakdown(Map<String, dynamic> grouped) {
    return pw.Container(); // Implementar según necesidad
  }

  static pw.Widget _buildTechniciansSection(List<Map<String, dynamic>> maintenances) {
    return pw.Container(); // Implementar según necesidad
  }

  static pw.Widget _buildReportFooter() {
    return pw.Container(); // Implementar según necesidad
  }

  // Métodos auxiliares

  static Map<String, dynamic> _calculateDailyStats(List<Map<String, dynamic>> maintenances) {
    return {}; // Implementar cálculos
  }

  static Map<String, dynamic> _calculatePeriodStats(List<Map<String, dynamic>> maintenances) {
    return {}; // Implementar cálculos
  }

  static Map<String, dynamic> _groupMaintenancesByDate(List<Map<String, dynamic>> maintenances) {
    return {}; // Implementar agrupación
  }

  static String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'No disponible';
    try {
      DateTime dateTime;
      if (timestamp.toString().contains('Timestamp')) {
        // Es un Timestamp de Firestore
        dateTime = (timestamp as dynamic).toDate();
      } else {
        dateTime = DateTime.parse(timestamp.toString());
      }
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  // ignore: unused_element
  static String _calculateDuration(Map<String, dynamic> maintenance) {
    try {
      final scheduledDate = maintenance['scheduledDate'];
      final completedDate = maintenance['completedDate']; // Cambiado de completedAt
      
      if (scheduledDate != null && completedDate != null) {
        final scheduled = (scheduledDate as dynamic).toDate();
        final completed = (completedDate as dynamic).toDate();
        final duration = completed.difference(scheduled);
        
        if (duration.inHours > 0) {
          return '${duration.inHours}h ${duration.inMinutes % 60}min';
        } else {
          return '${duration.inMinutes}min';
        }
      }
      
      return '${maintenance['estimatedDurationMinutes'] ?? 0} min (estimado)';
    } catch (e) {
      return 'No disponible';
    }
  }

  /// Métodos públicos para usar en la aplicación

  /// Guardar PDF de mantenimiento en el dispositivo
  static Future<File?> saveMaintenancePDF(Map<String, dynamic> maintenance) async {
    try {
      final pdfData = await generateMaintenancePDF(maintenance);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Mantenimiento_${maintenance['equipmentName']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pdfData);
      return file;
    } catch (e) {
      print('Error guardando PDF de mantenimiento: $e');
      return null;
    }
  }

  /// Compartir PDF de mantenimiento
  static Future<void> shareMaintenancePDF(Map<String, dynamic> maintenance) async {
    try {
      final file = await saveMaintenancePDF(maintenance);
      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Reporte de mantenimiento completado\nEquipo: ${maintenance['equipmentName']}\nCliente: ${maintenance['clientName']}',
          subject: 'Mantenimiento ${maintenance['equipmentName']} - ${_formatDateTime(maintenance['completedAt'])}',
        );
      }
    } catch (e) {
      print('Error compartiendo PDF de mantenimiento: $e');
    }
  }

  /// Vista previa para imprimir mantenimiento
  static Future<void> printMaintenancePDF(Map<String, dynamic> maintenance) async {
    try {
      final pdfData = await generateMaintenancePDF(maintenance);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name: 'Mantenimiento_${maintenance['equipmentName']}',
      );
    } catch (e) {
      print('Error imprimiendo PDF de mantenimiento: $e');
    }
  }
}