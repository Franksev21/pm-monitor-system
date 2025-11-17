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
  static Future<Uint8List> generateMaintenancePDF(
      Map<String, dynamic> maintenance) async {
    final pdf = pw.Document();

    print('🔄 Iniciando descarga de fotos para PDF...');
    print('📸 URLs disponibles: ${maintenance['photoUrls']}');

    // Descargar fotos para incluir en el PDF
    final photoImages =
        await _downloadPhotos(maintenance['photoUrls'] as List? ?? []);

    print('✅ Fotos descargadas para PDF: ${photoImages.length}');

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

            // Evidencias fotográficas - CORREGIDA
            if (photoImages.isNotEmpty) ...[
              _buildPhotosSection(photoImages),
              pw.SizedBox(height: 20),
            ] else ...[
              // Mostrar mensaje si no hay fotos
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  border: pw.Border.all(color: PdfColors.orange200),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'No se encontraron evidencias fotográficas para este mantenimiento',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.orange700,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Notas y observaciones
            if (maintenance['notes'] != null &&
                maintenance['notes'].toString().isNotEmpty)
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
            _buildDailyReportHeader(date, maintenances.length),
            pw.SizedBox(height: 20),

            // Resumen estadístico
            _buildDailyStatsSection(stats),
            pw.SizedBox(height: 20),

            // Lista de mantenimientos
            _buildDailyMaintenancesList(maintenances),
            pw.SizedBox(height: 20),

            // Métricas por técnico
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

  /// Descargar fotos de URLs para incluir en PDF - MEJORADA
  static Future<List<Uint8List>> _downloadPhotos(
      List<dynamic> photoUrls) async {
    List<Uint8List> images = [];

    print('🔄 Descargando ${photoUrls.length} fotos...');

    for (int i = 0; i < photoUrls.length; i++) {
      String url = photoUrls[i].toString();
      try {
        print('📥 Descargando foto ${i + 1}: $url');

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'PM-Monitor-PDF-Generator/1.0',
          },
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Timeout al descargar foto');
          },
        );

        if (response.statusCode == 200) {
          print(
              '✅ Foto ${i + 1} descargada: ${response.bodyBytes.length} bytes');
          images.add(response.bodyBytes);
        } else {
          print('❌ Error HTTP ${response.statusCode} en foto ${i + 1}');
        }
      } catch (e) {
        print('❌ Error descargando foto ${i + 1}: $e');
        // Continuar con las demás fotos
      }
    }

    print('✅ Total fotos descargadas: ${images.length}/${photoUrls.length}');
    return images;
  }

  /// Header del PDF de mantenimiento individual
  static pw.Widget _buildMaintenanceHeader(Map<String, dynamic> maintenance) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
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
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Técnico: ${maintenance['technicianName'] ?? 'No asignado'}',
                  style: const pw.TextStyle(
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
      [
        'Duración Estimada',
        '${maintenance['estimatedDurationMinutes'] ?? 0} minutos'
      ],
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
                        color:
                            isCompleted ? PdfColors.green : PdfColors.grey300,
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
                          color:
                              isCompleted ? PdfColors.grey600 : PdfColors.black,
                          decoration: isCompleted
                              ? pw.TextDecoration.lineThrough
                              : null,
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
      cost != null ? '\${cost.toStringAsFixed(2)}' : 'No especificado'
    ];
  }

  /// Sección de evidencias fotográficas - CORREGIDA PARA EVITAR ERROR DE GRIDVIEW
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

        // ARREGLADO: Usar Container con altura fija en lugar de GridView infinito
        pw.Container(
          height: 200, // Altura fija para evitar constraints infinitos
          width: double.infinity,
          child: pw.GridView(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0, // Aspecto cuadrado definido
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
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Mostrar más fotos en filas adicionales si hay más de 4
        if (photoImages.length > 4) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            height: 200,
            width: double.infinity,
            child: pw.GridView(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
              children: photoImages.skip(4).take(4).map((imageData) {
                return pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.ClipRRect(
                    child: pw.Image(
                      pw.MemoryImage(imageData),
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // Contador de fotos
        if (photoImages.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${photoImages.length} foto${photoImages.length != 1 ? 's' : ''} de evidencia',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (photoImages.length > 8)
                  pw.Text(
                    'Se muestran las primeras 8 fotos',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
              ],
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
  static pw.Widget _buildDailyReportHeader(DateTime date, int count) {
    final dayString = DateFormat('EEEE', 'es').format(date);
    final dateString = DateFormat('dd/MM/yyyy', 'es').format(date);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColors.blue700, PdfColors.blue500],
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
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
            'Reporte de Mantenimientos Completados',
            style: const pw.TextStyle(
              fontSize: 16,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '$dayString, $dateString',
            style: const pw.TextStyle(
              fontSize: 14,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            '$count mantenimiento${count != 1 ? 's' : ''} completado${count != 1 ? 's' : ''}',
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
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
                      style: const pw.TextStyle(fontSize: 11),
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
      decoration: const pw.BoxDecoration(
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
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Este documento certifica la ejecución y completación del mantenimiento según los estándares establecidos.',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // IMPLEMENTACIÓN DE REPORTES DIARIOS Y DE PERÍODO

  static pw.Widget _buildDailyStatsSection(Map<String, dynamic> stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Resumen Ejecutivo',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryCard('Completados',
                  stats['totalCompleted'].toString(), PdfColors.green),
              _buildSummaryCard('Técnicos',
                  stats['techniciansInvolved'].toString(), PdfColors.blue),
              _buildSummaryCard(
                  'Tiempo Total',
                  '${stats['totalHours'].toStringAsFixed(1)}h',
                  PdfColors.orange),
              _buildSummaryCard(
                  'Promedio',
                  '${stats['avgCompletion'].toStringAsFixed(1)}%',
                  PdfColors.purple),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryCard(
      String title, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Text(
            title,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDailyMaintenancesList(
      List<Map<String, dynamic>> maintenances) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detalle de Mantenimientos Completados',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green700,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1),
            5: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green100),
              children: [
                _buildTableHeader('Equipo'),
                _buildTableHeader('Cliente'),
                _buildTableHeader('Hora'),
                _buildTableHeader('Técnico'),
                _buildTableHeader('Duración'),
                _buildTableHeader('Progreso'),
              ],
            ),
            // Filas de datos
            ...maintenances.map((maintenance) => pw.TableRow(
                  children: [
                    _buildTableCell(maintenance['equipmentName'] ?? 'N/A'),
                    _buildTableCell(maintenance['clientName'] ?? 'N/A'),
                    _buildTableCell(
                        _formatDateTime(maintenance['scheduledDate'])
                            .split(' ')[1]),
                    _buildTableCell(
                        maintenance['technicianName'] ?? 'No asignado'),
                    _buildTableCell(
                        '${maintenance['estimatedDurationMinutes'] ?? 0} min'),
                    _buildTableCell(
                        '${maintenance['completionPercentage'] ?? 100}%'),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTechniciansSection(
      List<Map<String, dynamic>> maintenances) {
    final technicianPerformance = <String, Map<String, dynamic>>{};

    for (final maintenance in maintenances) {
      final techName = maintenance['technicianName'] ?? 'Sin asignar';
      if (!technicianPerformance.containsKey(techName)) {
        technicianPerformance[techName] = {
          'count': 0,
          'totalTime': 0,
          'avgCompletion': 0.0,
        };
      }

      technicianPerformance[techName]!['count'] += 1;
      technicianPerformance[techName]!['totalTime'] +=
          maintenance['estimatedDurationMinutes'] ?? 0;
      final currentAvg =
          technicianPerformance[techName]!['avgCompletion'] as double;
      final newCompletion = maintenance['completionPercentage'] ?? 100;
      technicianPerformance[techName]!['avgCompletion'] =
          (currentAvg * (technicianPerformance[techName]!['count'] - 1) +
                  newCompletion) /
              technicianPerformance[techName]!['count'];
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Métricas de Eficiencia por Técnico',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue700,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue100),
              children: [
                _buildTableHeader('Técnico'),
                _buildTableHeader('Completados'),
                _buildTableHeader('Tiempo Total'),
                _buildTableHeader('Eficiencia Prom.'),
              ],
            ),
            // Filas de datos
            ...technicianPerformance.entries.map((entry) => pw.TableRow(
                  children: [
                    _buildTableCell(entry.key),
                    _buildTableCell(entry.value['count'].toString()),
                    _buildTableCell(
                        '${(entry.value['totalTime'] / 60).toStringAsFixed(1)}h'),
                    _buildTableCell(
                        '${(entry.value['avgCompletion'] as double).toStringAsFixed(1)}%'),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  // IMPLEMENTACIONES BÁSICAS PARA REPORTES DE PERÍODO

  static pw.Widget _buildPeriodReportHeader(
      DateTime start, DateTime end, String type) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.purple100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$_appName - Reporte $type',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple700,
            ),
          ),
          pw.Text(
            'Período: ${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}',
            style: const pw.TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildExecutiveSummary(Map<String, dynamic> stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      child: pw.Text(
        'Resumen Ejecutivo del Período',
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildMetricsSection(Map<String, dynamic> stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      child: pw.Text(
        'Métricas y Indicadores',
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildDailyBreakdown(Map<String, dynamic> grouped) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      child: pw.Text(
        'Desglose Diario',
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildReportFooter() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
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
            'Reporte generado automáticamente el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  // MÉTODOS AUXILIARES DE CÁLCULO

  static Map<String, dynamic> _calculateDailyStats(
      List<Map<String, dynamic>> maintenances) {
    final totalCompleted = maintenances.length;
    final techniciansInvolved = maintenances
        .map((m) => m['technicianId'])
        .where((id) => id != null)
        .toSet()
        .length;
    final totalMinutes = maintenances.fold<int>(
        0, (sum, m) => sum + (m['estimatedDurationMinutes'] as int? ?? 0));
    final totalHours = totalMinutes / 60.0;
    final avgCompletion = maintenances.isNotEmpty
        ? maintenances.fold<int>(0,
                (sum, m) => sum + (m['completionPercentage'] as int? ?? 100)) /
            maintenances.length
        : 0.0;

    return {
      'totalCompleted': totalCompleted,
      'techniciansInvolved': techniciansInvolved,
      'totalHours': totalHours,
      'avgCompletion': avgCompletion,
    };
  }

  static Map<String, dynamic> _calculatePeriodStats(
      List<Map<String, dynamic>> maintenances) {
    return _calculateDailyStats(maintenances); // Usar la misma lógica por ahora
  }

  static Map<String, dynamic> _groupMaintenancesByDate(
      List<Map<String, dynamic>> maintenances) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final maintenance in maintenances) {
      final date = maintenance['scheduledDate'];
      if (date != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format((date as dynamic).toDate
            ? (date as dynamic).toDate()
            : DateTime.parse(date.toString()));
        if (grouped[dateKey] == null) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(maintenance);
      }
    }

    return grouped;
  }

  static String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'No disponible';
    try {
      DateTime dateTime;
      if (timestamp.toString().contains('Timestamp')) {
        // Es un Timestamp de Firestore
        dateTime = (timestamp as dynamic).toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
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
      final completedDate = maintenance['completedDate'];

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

  /// MÉTODOS PÚBLICOS PARA USO EN LA APLICACIÓN

  /// Guardar PDF de mantenimiento en el dispositivo
  static Future<File?> saveMaintenancePDF(
      Map<String, dynamic> maintenance) async {
    try {
      final pdfData = await generateMaintenancePDF(maintenance);
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'Mantenimiento_${maintenance['equipmentName']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pdfData);
      return file;
    } catch (e) {
      print('Error guardando PDF de mantenimiento: $e');
      return null;
    }
  }

  /// Compartir PDF de mantenimiento
  static Future<void> shareMaintenancePDF(
      Map<String, dynamic> maintenance) async {
    try {
      final file = await saveMaintenancePDF(maintenance);
      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              'Reporte de mantenimiento completado\nEquipo: ${maintenance['equipmentName']}\nCliente: ${maintenance['clientName']}',
          subject:
              'Mantenimiento ${maintenance['equipmentName']} - ${_formatDateTime(maintenance['completedAt'])}',
        );
      }
    } catch (e) {
      print('Error compartiendo PDF de mantenimiento: $e');
    }
  }

  /// Vista previa para imprimir mantenimiento
  static Future<void> printMaintenancePDF(
      Map<String, dynamic> maintenance) async {
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
