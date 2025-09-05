import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/equipment_model.dart';

class QRGeneratorService {
  // Generar datos JSON para el QR
  static Map<String, dynamic> generateEquipmentData(Equipment equipment) {
    return {
      'id': equipment.id,
      'equipmentNumber': equipment.equipmentNumber,
      'rfidTag': equipment.rfidTag,
      'name': equipment.name,
      'brand': equipment.brand,
      'model': equipment.model,
      'capacity': equipment.capacity,
      'capacityUnit': equipment.capacityUnit,
      'serialNumber': equipment.serialNumber,
      'category': equipment.category,
      'location': equipment.location,
      'branch': equipment.branch,
      'status': equipment.status,
      'condition': equipment.condition,
      'lifeScale': equipment.lifeScale,
      'clientId': equipment.clientId,
      'costs': {
        'equipment': equipment.equipmentCost,
        'totalPM': equipment.totalPmCost,
        'totalCM': equipment.totalCmCost,
        'total': equipment.totalCost,
      },
      'maintenance': {
        'frequency': equipment.maintenanceFrequency,
        'lastDate': equipment.lastMaintenanceDate?.toIso8601String(),
        'nextDate': equipment.nextMaintenanceDate?.toIso8601String(),
        'estimatedHours': equipment.estimatedMaintenanceHours,
      },
      'timestamps': {
        'created': equipment.createdAt.toIso8601String(),
        'updated': equipment.updatedAt.toIso8601String(),
      },
      'type': 'pm_monitor_equipment',
      'version': '1.0',
    };
  }

  // Crear widget QR customizado
  static Widget buildQRWidget(Equipment equipment, {double size = 200}) {
    final qrData = generateEquipmentData(equipment);
    final jsonString = jsonEncode(qrData);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Text(
            'PM MONITOR',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 8),

          // Equipment info
          Text(
            equipment.equipmentNumber,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${equipment.brand} ${equipment.model}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),

          // QR Code
          QrImageView(
            data: jsonString,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),

          const SizedBox(height: 12),

          // Footer info
          Text(
            equipment.name,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'RFID: ${equipment.rfidTag}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // Generar y guardar imagen del QR
  static Future<File?> generateQRImage(Equipment equipment,
      {double size = 300}) async {
    try {
      final qrData = generateEquipmentData(equipment);
      final jsonString = jsonEncode(qrData);

      // Crear el painter del QR
      final qrPainter = QrPainter(
        data: jsonString,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      // Crear imagen del QR
      final picData = await qrPainter.toImageData(size);
      if (picData == null) return null;

      // Convertir a bytes
      final pngBytes = picData.buffer.asUint8List();

      // Guardar archivo
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'QR_${equipment.equipmentNumber}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      print('Error generando imagen QR: $e');
      return null;
    }
  }

  // Generar QR con diseño completo
  static Future<File?> generateCustomQRImage(Equipment equipment) async {
    try {
      final GlobalKey repaintBoundaryKey = GlobalKey();

      // Crear widget para capturar
      final qrWidget = RepaintBoundary(
        key: repaintBoundaryKey,
        child: Container(
          width: 400,
          height: 500,
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: buildQRWidget(equipment, size: 250),
        ),
      );

      // Necesitarías renderizar este widget y convertirlo a imagen
      // Esto requiere un contexto de Flutter más complejo

      return null; // Implementar según necesidades
    } catch (e) {
      print('Error generando QR customizado: $e');
      return null;
    }
  }

  // Compartir QR
  static Future<void> shareQR(Equipment equipment) async {
    try {
      final file = await generateQRImage(equipment);
      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Código QR - ${equipment.equipmentNumber}\n${equipment.name}',
          subject: 'Equipo ${equipment.equipmentNumber}',
        );
      }
    } catch (e) {
      print('Error compartiendo QR: $e');
    }
  }
}
