import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/core/models/fault_report_model.dart';
import 'package:pm_monitor/core/services/notification_service.dart';

class ClientFaultReportScreen extends StatefulWidget {
  final String? equipmentId;
  final String? equipmentNumber;
  final String? equipmentName;

  const ClientFaultReportScreen({
    super.key,
    this.equipmentId,
    this.equipmentNumber,
    this.equipmentName,
  });

  @override
  State<ClientFaultReportScreen> createState() =>
      _ClientFaultReportScreenState();
}

class _ClientFaultReportScreenState extends State<ClientFaultReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _selectedEquipmentId;
  String? _selectedEquipmentNumber;
  String? _selectedEquipmentName;
  String _severity = 'MEDIA';
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _clientEquipments = [];
  bool _isLoadingEquipments = true;

  @override
  void initState() {
    super.initState();
    if (widget.equipmentId != null) {
      _selectedEquipmentId = widget.equipmentId;
      _selectedEquipmentNumber = widget.equipmentNumber;
      _selectedEquipmentName = widget.equipmentName;
    }
    _loadClientEquipments();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadClientEquipments() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Obtener nombre del cliente
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final userData = userDoc.data();
      final clientName = userData?['name'] ?? '';

      if (clientName.isEmpty) return;

      // Obtener equipos del cliente
      final equipmentsSnapshot =
          await _firestore.collection('equipments').get();

      final equipments = equipmentsSnapshot.docs.where((doc) {
        final data = doc.data();
        final branch = (data['branch'] ?? '').toString().toLowerCase();
        return branch == clientName.toLowerCase();
      }).map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'equipmentNumber': data['equipmentNumber'] ?? '',
          'name': data['name'] ?? '',
          'status': data['status'] ?? '',
        };
      }).toList();

      setState(() {
        _clientEquipments = equipments;
        _isLoadingEquipments = false;
      });
    } catch (e) {
      print('Error cargando equipos: $e');
      setState(() {
        _isLoadingEquipments = false;
      });
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedEquipmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un equipo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener datos del cliente
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data();
      final clientName = userData?['name'] ?? '';

      // Crear reporte
      final report = FaultReport(
        equipmentId: _selectedEquipmentId!,
        equipmentNumber: _selectedEquipmentNumber!,
        equipmentName: _selectedEquipmentName!,
        clientId: currentUser.uid,
        clientName: clientName,
        severity: _severity,
        description: _descriptionController.text.trim(),
        status: 'pending',
        reportedAt: DateTime.now(),
      );

      // Guardar en Firestore
      final docRef =
          await _firestore.collection('faultReports').add(report.toFirestore());

      print('✅ Reporte creado: ${docRef.id}');

      // Enviar notificaciones usando el servicio
      try {
        final notificationService = NotificationService();
        await notificationService.sendFaultNotifications(
          equipmentName: _selectedEquipmentName!,
          equipmentId: _selectedEquipmentId!,
          severity: _severity,
          description: _descriptionController.text.trim(),
          reportId: docRef.id,
        );
        print('✅ Notificaciones push enviadas');
      } catch (notificationError) {
        print('⚠️ Error enviando notificaciones push: $notificationError');
        // No detener el proceso si fallan las notificaciones push
      }

      // Crear notificación pendiente para administradores (backup)
      try {
        await _firestore.collection('pendingNotifications').add({
          'type': 'fault_report',
          'severity': _severity,
          'message':
              '🚨 FALLA REPORTADA\nEquipo: $_selectedEquipmentNumber\nSeveridad: $_severity\nCliente: $clientName\nDescripción: ${_descriptionController.text.trim()}\nID: ${docRef.id}',
          'equipmentId': _selectedEquipmentId,
          'reportId': docRef.id,
          'clientId': currentUser.uid,
          'clientName': clientName,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ Notificación pendiente creada');
      } catch (notificationError) {
        print('⚠️ Error creando notificación pendiente: $notificationError');
        // No detener el proceso si falla
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '¡Falla reportada exitosamente!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Los técnicos han sido notificados',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Error reportando falla: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Error al reportar: ${e.toString().split(']').last}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Reportar Falla'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingEquipments
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado de alerta
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.orange],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reportar Falla',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Describe el problema y te ayudaremos',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Seleccionar equipo
                    if (widget.equipmentId == null) ...[
                      const Text(
                        'Seleccionar Equipo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedEquipmentId,
                          decoration: InputDecoration(
                            hintText: 'Selecciona el equipo con falla',
                            prefixIcon: const Icon(Icons.build_circle),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _clientEquipments.map((equipment) {
                            return DropdownMenuItem<String>(
                              value: equipment['id'],
                              child: Text(
                                '${equipment['equipmentNumber']} - ${equipment['name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            final selected = _clientEquipments.firstWhere(
                              (e) => e['id'] == value,
                            );
                            setState(() {
                              _selectedEquipmentId = value;
                              _selectedEquipmentNumber =
                                  selected['equipmentNumber'];
                              _selectedEquipmentName = selected['name'];
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor selecciona un equipo';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.build_circle,
                                color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedEquipmentNumber ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  Text(
                                    _selectedEquipmentName ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Nivel de severidad
                    const Text(
                      'Nivel de Severidad',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSeverityOption('BAJA', Colors.green),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSeverityOption('MEDIA', Colors.orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child:
                              _buildSeverityOption('ALTA', Colors.deepOrange),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSeverityOption('CRITICA', Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Descripción
                    const Text(
                      'Descripción del Problema',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText:
                              'Describe el problema con el mayor detalle posible...\n\n'
                              '• ¿Qué está fallando?\n'
                              '• ¿Cuándo comenzó el problema?\n'
                              '• ¿Hay algún ruido o señal extraña?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor describe el problema';
                          }
                          if (value.trim().length < 10) {
                            return 'Por favor proporciona más detalles (mínimo 10 caracteres)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botón enviar
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send),
                                  SizedBox(width: 8),
                                  Text(
                                    'Enviar Reporte',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSeverityOption(String severity, Color color) {
    final isSelected = _severity == severity;

    return InkWell(
      onTap: () {
        setState(() {
          _severity = severity;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.white : color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              severity,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
