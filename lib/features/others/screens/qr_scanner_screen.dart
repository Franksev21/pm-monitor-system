import 'package:flutter/material.dart';
import 'package:pm_monitor/features/equipment/equipment_detail_screen.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isProcessing = false;
  bool _flashOn = false;

  @override
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      controller!.pauseCamera();
      controller!.resumeCamera();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing &&
          scanData.code != null &&
          scanData.code!.isNotEmpty) {
        _searchEquipment(scanData.code!);
      }
    });
  }

  Future<void> _searchEquipment(String equipmentNumber) async {
    setState(() {
      _isProcessing = true;
    });

    // Pausar la cámara mientras procesamos
    await controller?.pauseCamera();

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
        Navigator.pop(context); // Cerrar escáner
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
        setState(() {
          _isProcessing = false;
        });
        // Reanudar cámara si seguimos en la pantalla
        await controller?.resumeCamera();
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

    setState(() {
      _isProcessing = false;
    });
  }

  void _toggleFlash() async {
    await controller?.toggleFlash();
    final flashStatus = await controller?.getFlashStatus();
    setState(() {
      _flashOn = flashStatus ?? false;
    });
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
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: const Color(0xFF4285F4),
              borderRadius: 20,
              borderLength: 40,
              borderWidth: 8,
              cutOutSize: MediaQuery.of(context).size.width * 0.7,
            ),
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
