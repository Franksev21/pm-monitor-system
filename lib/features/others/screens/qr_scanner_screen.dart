import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/features/equipment/equipment_detail_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isProcessing = false;
  bool _flashOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue;
    if (code == null || code.isEmpty) return;
    await _searchEquipment(code);
  }

  Future<void> _searchEquipment(String equipmentNumber) async {
    setState(() => _isProcessing = true);
    await _controller.stop();

    try {
      print('🔍 Buscando equipo: $equipmentNumber');

      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        _showError('Usuario no autenticado');
        return;
      }

      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final userData = userDoc.data();
      final clientName = userData?['name'] ?? '';

      if (clientName.isEmpty) {
        _showError('No se pudo obtener información del cliente');
        return;
      }

      final QuerySnapshot snapshot = await _firestore
          .collection('equipments')
          .where('equipmentNumber', isEqualTo: equipmentNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _showError('Equipo no encontrado: $equipmentNumber');
        return;
      }

      final equipmentDoc = snapshot.docs.first;
      final equipmentData = equipmentDoc.data() as Map<String, dynamic>;
      final equipmentBranch = equipmentData['branch'] ?? '';

      if (equipmentBranch.toLowerCase() != clientName.toLowerCase()) {
        _showError('Este equipo no pertenece a tu organización');
        return;
      }

      final equipment = Equipment.fromFirestore(equipmentDoc);

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EquipmentDetailScreen(equipment: equipment),
          ),
        );
      }
    } catch (e) {
      print('❌ Error: $e');
      _showError('Error al buscar el equipo');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        await _controller.start();
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
    setState(() => _isProcessing = false);
  }

  void _toggleFlash() async {
    await _controller.toggleTorch();
    setState(() => _flashOn = !_flashOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear Código QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
            tooltip: 'Flash',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay del scanner
          CustomPaint(
            painter: _ScannerOverlayPainter(),
            child: const SizedBox.expand(),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Buscando equipo...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isProcessing)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
                    SizedBox(height: 12),
                    Text(
                      'Apunta la cámara al código QR del equipo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Overlay con recuadro de escaneo
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cutOutSize = size.width * 0.7;
    final left = (size.width - cutOutSize) / 2;
    final top = (size.height - cutOutSize) / 2;
    final right = left + cutOutSize;
    final bottom = top + cutOutSize;

    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final transparentPaint = Paint()..blendMode = BlendMode.clear;
    final borderPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Fondo oscuro
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Recuadro transparente
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom),
        const Radius.circular(16),
      ),
      transparentPaint,
    );

    canvas.restore();

    // Bordes azules
    const cornerLen = 40.0;
    const r = 16.0;

    // Esquina superior izquierda
    canvas.drawPath(
        Path()
          ..moveTo(left, top + cornerLen)
          ..lineTo(left, top + r)
          ..arcToPoint(Offset(left + r, top),
              radius: Radius.circular(r), clockwise: true)
          ..lineTo(left + cornerLen, top),
        borderPaint);

    // Esquina superior derecha
    canvas.drawPath(
        Path()
          ..moveTo(right - cornerLen, top)
          ..lineTo(right - r, top)
          ..arcToPoint(Offset(right, top + r),
              radius: Radius.circular(r), clockwise: true)
          ..lineTo(right, top + cornerLen),
        borderPaint);

    // Esquina inferior derecha
    canvas.drawPath(
        Path()
          ..moveTo(right, bottom - cornerLen)
          ..lineTo(right, bottom - r)
          ..arcToPoint(Offset(right - r, bottom),
              radius: Radius.circular(r), clockwise: false)
          ..lineTo(right - cornerLen, bottom),
        borderPaint);

    // Esquina inferior izquierda
    canvas.drawPath(
        Path()
          ..moveTo(left + cornerLen, bottom)
          ..lineTo(left + r, bottom)
          ..arcToPoint(Offset(left, bottom - r),
              radius: Radius.circular(r), clockwise: false)
          ..lineTo(left, bottom - cornerLen),
        borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
