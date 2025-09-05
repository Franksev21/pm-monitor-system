import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/core/services/qr_generator_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MiniQRWidget extends StatelessWidget {
  final Equipment equipment;
  final double size;

  const MiniQRWidget({
    Key? key,
    required this.equipment,
    this.size = 60,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final qrData = QRGeneratorService.generateEquipmentData(equipment);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: QrImageView(
        data: jsonEncode(qrData),
        version: QrVersions.auto,
        size: size - 8,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      ),
    );
  }
}
