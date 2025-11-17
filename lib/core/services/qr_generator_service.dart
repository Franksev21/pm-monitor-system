import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/equipment_model.dart';


enum QRType {
  whatsappInfo, // Mensaje de WhatsApp con información
  webUrl, // URL para navegador web con parámetros
  appDeepLink, // Link directo a la app
  jsonData, // JSON completo (para apps especializadas)
}

class QRGeneratorService {
  static const String _webBaseUrl = 'https://pmmonitor.app/equipment/';
  static const String _appScheme = 'pmmonitor://equipment/';

  // Generar contenido del QR según el tipo
  static Future<String> generateQRContent(
      Equipment equipment, QRType type) async {
    switch (type) {
      case QRType.whatsappInfo:
        return _generateWhatsAppMessage(equipment);
      case QRType.webUrl:
        return _generateWebURL(equipment);
      case QRType.appDeepLink:
        return _generateAppDeepLink(equipment);
      case QRType.jsonData:
        return _generateJSONData(equipment);
    }
  }

  // WhatsApp con información del equipo
  static String _generateWhatsAppMessage(Equipment equipment) {
    final message = '''🔧 *INFORMACIÓN DEL EQUIPO*

📋 *Datos Generales:*
• Número: ${equipment.equipmentNumber}
• RFID: ${equipment.rfidTag}
• Nombre: ${equipment.name}

⚙️ *Especificaciones:*
• Marca: ${equipment.brand}
• Modelo: ${equipment.model}
• Capacidad: ${equipment.capacity} ${equipment.capacityUnit}
• Categoría: ${equipment.category}

📍 *Ubicación:*
• Lugar: ${equipment.location}
• Sucursal: ${equipment.branch}
• Dirección: ${equipment.address}

📊 *Estado Actual:*
• Estado: ${equipment.status}
• Condición: ${equipment.condition}
• Vida Útil: ${equipment.lifeScale}/10

🔧 *Mantenimiento:*
• Frecuencia: ${equipment.maintenanceFrequency}
• Próximo: ${equipment.nextMaintenanceDate != null ? equipment.nextMaintenanceDate.toString().substring(0, 10) : 'No programado'}
• Horas estimadas: ${equipment.estimatedMaintenanceHours}h

💰 *Costos:*
• Equipo: ${equipment.currency} ${equipment.equipmentCost.toStringAsFixed(2)}
• Total PM: ${equipment.currency} ${equipment.totalPmCost.toStringAsFixed(2)}
• Total CM: ${equipment.currency} ${equipment.totalCmCost.toStringAsFixed(2)}

---
📱 *PM Monitor - Sistema de Mantenimiento*
Generado: ${DateTime.now().toString().substring(0, 19)}''';

    // Codificar para WhatsApp URL
    final encodedMessage = Uri.encodeComponent(message);
    return 'https://wa.me/?text=$encodedMessage';
  }

  // URL para navegador web con parámetros
  static String _generateWebURL(Equipment equipment) {
    final params = {
      'id': equipment.id ?? '',
      'number': equipment.equipmentNumber,
      'rfid': equipment.rfidTag,
      'name': equipment.name,
      'brand': equipment.brand,
      'model': equipment.model,
      'client': equipment.clientId,
    };

    final query = params.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_webBaseUrl${equipment.equipmentNumber}?$query';
  }

  // Deep link para abrir en la app
  static String _generateAppDeepLink(Equipment equipment) {
    return '$_appScheme${equipment.equipmentNumber}';
  }

  // JSON completo (método original)
  static String _generateJSONData(Equipment equipment) {
    final qrData = generateEquipmentData(equipment);
    return jsonEncode(qrData);
  }

  // Datos JSON completos (método original mantenido para compatibilidad)
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

  // Widget QR simplificado
  static Widget buildQRWidget(
    Equipment equipment, {
    double size = 200,
    QRType type = QRType.whatsappInfo, // Cambiar default a WhatsApp
  }) {
    // Para WhatsApp y otros tipos sincrónicos
    String qrContent;
    switch (type) {
      case QRType.whatsappInfo:
        qrContent = _generateWhatsAppMessage(equipment);
        break;
      case QRType.webUrl:
        qrContent = _generateWebURL(equipment);
        break;
      case QRType.appDeepLink:
        qrContent = _generateAppDeepLink(equipment);
        break;
      case QRType.jsonData:
        qrContent = _generateJSONData(equipment);
        break;
    }

    return _buildQRContainer(equipment, qrContent, size, type);
  }

  // Construir container del QR
  static Widget _buildQRContainer(
      Equipment equipment, String qrContent, double size, QRType type) {
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
          const Text(
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
            data: qrContent,
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
          const SizedBox(height: 4),
          // Indicador del tipo de QR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: getQRTypeColor(type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              getQRTypeLabel(type),
              style: TextStyle(
                fontSize: 8,
                color: getQRTypeColor(type),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Colores para tipos de QR
  static Color getQRTypeColor(QRType type) {
    switch (type) {
      case QRType.whatsappInfo:
        return Colors.green;
      case QRType.webUrl:
        return Colors.blue;
      case QRType.appDeepLink:
        return Colors.purple;
      case QRType.jsonData:
        return Colors.orange;
    }
  }

  // Etiquetas para tipos de QR
  static String getQRTypeLabel(QRType type) {
    switch (type) {
      case QRType.whatsappInfo:
        return 'WHATSAPP';
      case QRType.webUrl:
        return 'WEB URL';
      case QRType.appDeepLink:
        return 'APP LINK';
      case QRType.jsonData:
        return 'JSON DATA';
    }
  }

  // Títulos descriptivos
  static String getQRTypeTitle(QRType type) {
    switch (type) {
      case QRType.whatsappInfo:
        return 'Mensaje de WhatsApp';
      case QRType.webUrl:
        return 'Página Web';
      case QRType.appDeepLink:
        return 'Abrir en la App';
      case QRType.jsonData:
        return 'Datos JSON Completos';
    }
  }

  // Descripciones detalladas
  static String getQRTypeDescription(QRType type) {
    switch (type) {
      case QRType.whatsappInfo:
        return 'El QR abre WhatsApp con un mensaje preformateado que contiene toda la información del equipo de forma organizada y fácil de compartir.';
      case QRType.webUrl:
        return 'El QR lleva a una página web con la información del equipo organizada en formato web responsive.';
      case QRType.appDeepLink:
        return 'El QR abre directamente este equipo en la aplicación PM Monitor (si está instalada).';
      case QRType.jsonData:
        return 'El QR contiene todos los datos técnicos en formato JSON para aplicaciones especializadas.';
    }
  }

  // Generar imagen QR con tipo específico
  static Future<File?> generateQRImage(
    Equipment equipment, {
    double size = 300,
    QRType type = QRType.webUrl,
  }) async {
    try {
      final qrContent = await generateQRContent(equipment, type);

      final qrPainter = QrPainter(
        data: qrContent,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final picData = await qrPainter.toImageData(size);
      if (picData == null) return null;

      final pngBytes = picData.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final typeLabel = getQRTypeLabel(type).replaceAll(' ', '_');
      final fileName =
          'QR_${equipment.equipmentNumber}_${typeLabel}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      print('Error generando imagen QR: $e');
      return null;
    }
  }

  // Compartir QR con opción de tipo
  static Future<void> shareQR(Equipment equipment,
      {QRType type = QRType.webUrl}) async {
    try {
      final file = await generateQRImage(equipment, type: type);
      if (file != null) {
        final typeLabel = getQRTypeLabel(type);
        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              'Código QR ($typeLabel) - ${equipment.equipmentNumber}\n${equipment.name}',
          subject: 'Equipo ${equipment.equipmentNumber}',
        );
      }
    } catch (e) {
      print('Error compartiendo QR: $e');
    }
  }

  // Método para generar QR múltiple (todos los tipos)
  static Future<List<File>> generateAllQRTypes(Equipment equipment) async {
    final files = <File>[];

    for (final type in QRType.values) {
      final file = await generateQRImage(equipment, type: type);
      if (file != null) {
        files.add(file);
      }
    }

    return files;
  }

  // Validar URL generada
  static bool isValidURL(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' ||
              uri.scheme == 'https' ||
              uri.scheme == 'pmmonitor');
    } catch (e) {
      return false;
    }
  }
}
