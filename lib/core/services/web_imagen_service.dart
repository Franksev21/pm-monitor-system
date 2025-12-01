import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/equipment_model.dart';
import 'qr_generator_service.dart';

class WebImageService {
  static const String _storageBasePath = 'equipment_cards';

  /// Generar imagen de tarjeta del equipo para web - VERSIÓN SIMPLIFICADA
  static Future<String?> generateEquipmentWebImage(Equipment equipment) async {
    try {
      // Generar QR y subir directamente como fallback
      final qrFile =
          await QRGeneratorService.generateQRImage(equipment, size: 200);

      if (qrFile != null) {
        final qrBytes = await qrFile.readAsBytes();
        final imageUrl = await _uploadImageToStorage(equipment, qrBytes);
        return imageUrl;
      }

      return _generateFallbackURL(equipment);
    } catch (e) {
      print('Error generando imagen web: $e');
      return _generateFallbackURL(equipment);
    }
  }

  /// Método alternativo usando Canvas para crear imagen personalizada
  static Future<Uint8List?> _createEquipmentCard(Equipment equipment) async {
    try {
      // Crear una imagen programáticamente usando Canvas
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(600, 800);

      // Fondo con gradiente
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      // Área de contenido blanca
      final whitePaint = Paint()..color = Colors.white;
      final contentRect =
          Rect.fromLTWH(20, 100, size.width - 40, size.height - 140);
      canvas.drawRRect(
        RRect.fromRectAndRadius(contentRect, const Radius.circular(12)),
        whitePaint,
      );

      // Texto del header
      final headerTextPainter = TextPainter(
        text: TextSpan(
          text: 'PM MONITOR\n${equipment.name}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      headerTextPainter.layout();
      headerTextPainter.paint(canvas, const Offset(30, 30));

      // Información del equipo
      final infoText = '''
Equipo: ${equipment.equipmentNumber}
RFID: ${equipment.rfidTag}
Marca: ${equipment.brand} ${equipment.model}
Capacidad: ${equipment.capacity} ${equipment.capacityUnit}
Estado: ${equipment.status}
Ubicación: ${equipment.location}
''';

      final infoTextPainter = TextPainter(
        text: TextSpan(
          text: infoText,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      infoTextPainter.layout(maxWidth: contentRect.width - 40);
      infoTextPainter.paint(
          canvas, Offset(contentRect.left + 20, contentRect.top + 20));

      // Finalizar la imagen
      final picture = recorder.endRecording();
      final image =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error creando tarjeta personalizada: $e');
      return null;
    }
  }

  /// Subir imagen a Firebase Storage
  static Future<String?> _uploadImageToStorage(
      Equipment equipment, Uint8List imageBytes) async {
    try {
      final fileName =
          '${equipment.equipmentNumber}_${DateTime.now().millisecondsSinceEpoch}.png';
      final ref =
          FirebaseStorage.instance.ref().child('$_storageBasePath/$fileName');

      await ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/png',
          customMetadata: {
            'equipmentId': equipment.id ?? '',
            'equipmentNumber': equipment.equipmentNumber,
            'generatedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error subiendo imagen: $e');
      return null;
    }
  }

  /// Generar URL del QR que apunta a la imagen web
  static Future<String> generateQRWebImageURL(Equipment equipment) async {
    // Intentar generar la imagen personalizada primero
    final customImageBytes = await _createEquipmentCard(equipment);

    if (customImageBytes != null) {
      final imageUrl = await _uploadImageToStorage(equipment, customImageBytes);
      if (imageUrl != null) {
        return imageUrl;
      }
    }

    // Si falla, intentar con QR simple
    final imageUrl = await generateEquipmentWebImage(equipment);

    if (imageUrl != null) {
      return imageUrl;
    } else {
      // Fallback final: URL estática con parámetros
      return _generateFallbackURL(equipment);
    }
  }

  /// URL de fallback si falla la generación de imagen
  static String _generateFallbackURL(Equipment equipment) {
    const baseUrl = 'https://pmmonitor-web.vercel.app/equipment-card';
    final params = {
      'id': equipment.id ?? '',
      'number': equipment.equipmentNumber,
      'name': equipment.name,
      'brand': equipment.brand,
      'model': equipment.model,
      'capacity': '${equipment.capacity}',
      'unit': equipment.capacityUnit,
      'rfid': equipment.rfidTag,
      'status': equipment.status,
      'condition': equipment.condition,
      'location': equipment.location,
      'branch': equipment.branch,
    };

    final query = params.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$baseUrl?$query';
  }

  /// Método simplificado para crear imagen HTML estática
  static Future<String?> generateHTMLImageURL(Equipment equipment) async {
    try {
      // Crear HTML simple que se renderice como imagen
      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Equipo ${equipment.equipmentNumber}</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #1976D2, #1565C0);
            color: white;
            width: 600px;
            height: 800px;
            box-sizing: border-box;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .card {
            background: white;
            color: #333;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        .equipment-title {
            font-size: 24px;
            font-weight: bold;
            color: #1976D2;
            margin-bottom: 10px;
            text-align: center;
        }
        .info-row {
            display: flex;
            margin: 8px 0;
            border-bottom: 1px solid #eee;
            padding-bottom: 5px;
        }
        .label {
            font-weight: bold;
            width: 120px;
            color: #666;
        }
        .value {
            flex: 1;
            color: #333;
        }
        .qr-section {
            text-align: center;
            margin: 20px 0;
            padding: 20px;
            background: #f5f5f5;
            border-radius: 8px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>PM MONITOR</h1>
        <p>Sistema de Mantenimiento Preventivo</p>
    </div>
    
    <div class="card">
        <div class="equipment-title">${equipment.name}</div>
        
        <div class="info-row">
            <span class="label">Número:</span>
            <span class="value">${equipment.equipmentNumber}</span>
        </div>
        
        <div class="info-row">
            <span class="label">RFID:</span>
            <span class="value">${equipment.rfidTag}</span>
        </div>
        
        <div class="info-row">
            <span class="label">Marca/Modelo:</span>
            <span class="value">${equipment.brand} ${equipment.model}</span>
        </div>
        
        <div class="info-row">
            <span class="label">Capacidad:</span>
            <span class="value">${equipment.capacity} ${equipment.capacityUnit}</span>
        </div>
        
        <div class="info-row">
            <span class="label">Estado:</span>
            <span class="value">${equipment.status}</span>
        </div>
        
        <div class="info-row">
            <span class="label">Condición:</span>
            <span class="value">${equipment.condition}</span>
        </div>
        
        <div class="info-row">
            <span class="label">Ubicación:</span>
            <span class="value">${equipment.location}</span>
        </div>
        
        <div class="info-row">
            <span class="label">Sucursal:</span>
            <span class="value">${equipment.branch}</span>
        </div>
        
        <div class="qr-section">
            <p><strong>Código QR del Equipo</strong></p>
            <p style="font-size: 12px; color: #666;">
                Escanea para acceder a la información completa
            </p>
        </div>
        
        <div style="text-align: center; margin-top: 30px; font-size: 12px; color: #888;">
            Generado: ${DateTime.now().toString().substring(0, 19)}
        </div>
    </div>
</body>
</html>
''';

      // Por ahora, devolver la URL de fallback
      // En una implementación real, subirías este HTML a un servicio web
      return _generateFallbackURL(equipment);
    } catch (e) {
      print('Error generando HTML: $e');
      return _generateFallbackURL(equipment);
    }
  }

  /// Limpiar imágenes antiguas (opcional)
  static Future<void> cleanOldImages() async {
    try {
      final ref = FirebaseStorage.instance.ref().child(_storageBasePath);
      final result = await ref.listAll();

      final now = DateTime.now();

      for (final item in result.items) {
        try {
          final metadata = await item.getMetadata();
          final createdTime = metadata.timeCreated;

          if (createdTime != null) {
            final daysDiff = now.difference(createdTime).inDays;

            // Eliminar imágenes más antiguas de 30 días
            if (daysDiff > 30) {
              await item.delete();
            }
          }
        } catch (e) {
          print('Error procesando item ${item.fullPath}: $e');
        }
      }
    } catch (e) {
      print('Error limpiando imágenes antiguas: $e');
    }
  }
}
