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
  bool _isSubmitting = false;
  bool _isLoadingEquipments = true;

  // Todos los equipos del cliente
  List<Map<String, dynamic>> _allEquipments = [];
  // Equipos filtrados para mostrar en el dropdown
  List<Map<String, dynamic>> _filteredEquipments = [];

  // Filtros
  String _selectedBranch = 'Todas';
  String _selectedTipo = 'Todos';
  List<String> _availableBranches = ['Todas'];
  List<String> _availableTipos = ['Todos'];

  // Info del equipo seleccionado
  Map<String, dynamic>? _selectedEquipmentData;

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

      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final userData = userDoc.data();
      final clientName = userData?['name'] ?? '';

      if (clientName.isEmpty) return;

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
          'branch': data['branch'] ?? '',
          'tipo': data['tipo'] ?? '',
          'location': data['location'] ?? '',
          'category': data['category'] ?? '',
          'brand': data['brand'] ?? '',
          'model': data['model'] ?? '',
        };
      }).toList();

      // Extraer sucursales y tipos únicos
      final branches = <String>{'Todas'};
      final tipos = <String>{'Todos'};
      for (var eq in equipments) {
        if ((eq['branch'] as String).isNotEmpty) {
          branches.add(eq['branch'] as String);
        }
        if ((eq['tipo'] as String).isNotEmpty) {
          tipos.add(eq['tipo'] as String);
        }
      }

      setState(() {
        _allEquipments = equipments;
        _filteredEquipments = equipments;
        _availableBranches = branches.toList();
        _availableTipos = tipos.toList();
        _isLoadingEquipments = false;

        // Si viene con equipo preseleccionado, cargar sus datos
        if (_selectedEquipmentId != null) {
          try {
            _selectedEquipmentData = _allEquipments.firstWhere(
              (e) => e['id'] == _selectedEquipmentId,
            );
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('Error cargando equipos: $e');
      setState(() => _isLoadingEquipments = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredEquipments = _allEquipments.where((eq) {
        final matchBranch =
            _selectedBranch == 'Todas' || eq['branch'] == _selectedBranch;
        final matchTipo =
            _selectedTipo == 'Todos' || eq['tipo'] == _selectedTipo;
        return matchBranch && matchTipo;
      }).toList();

      // Si el equipo seleccionado ya no está en los filtrados, limpiar
      if (_selectedEquipmentId != null) {
        final stillExists = _filteredEquipments.any(
          (e) => e['id'] == _selectedEquipmentId,
        );
        if (!stillExists) {
          _selectedEquipmentId = null;
          _selectedEquipmentNumber = null;
          _selectedEquipmentName = null;
          _selectedEquipmentData = null;
        }
      }
    });
  }

  Future<void> _submitReport() async {
    if (_selectedEquipmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un equipo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Nota es opcional, no validamos el form
    setState(() => _isSubmitting = true);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Usuario no autenticado');

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data();
      final clientName = userData?['name'] ?? '';

      final equipLocation = _selectedEquipmentData?['location'] ?? '';
      final equipBranch = _selectedEquipmentData?['branch'] ?? '';

      final report = FaultReport(
        equipmentId: _selectedEquipmentId!,
        equipmentNumber: _selectedEquipmentNumber!,
        equipmentName: _selectedEquipmentName!,
        clientId: currentUser.uid,
        clientName: clientName,
        severity: 'MEDIA', // Severidad fija ya que se removió el selector
        description: _descriptionController.text.trim(),
        status: 'pending',
        reportedAt: DateTime.now(),
        location: equipLocation.isNotEmpty
            ? '$equipLocation, $equipBranch'
            : equipBranch,
      );

      final docRef =
          await _firestore.collection('faultReports').add(report.toFirestore());

      // Enviar notificaciones
      try {
        final notificationService = NotificationService();
        await notificationService.sendFaultNotifications(
          equipmentName: _selectedEquipmentName!,
          equipmentId: _selectedEquipmentId!,
          severity: 'MEDIA',
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : 'Falla reportada sin descripción adicional',
          reportId: docRef.id,
        );
      } catch (e) {
        debugPrint('Error enviando notificaciones: $e');
      }

      // Notificación pendiente
      try {
        await _firestore.collection('pendingNotifications').add({
          'type': 'fault_report',
          'severity': 'MEDIA',
          'message':
              'FALLA REPORTADA\nEquipo: $_selectedEquipmentNumber - $_selectedEquipmentName\nUbicación: ${equipLocation.isNotEmpty ? "$equipLocation, $equipBranch" : equipBranch}\nCliente: $clientName\n${_descriptionController.text.trim().isNotEmpty ? "Nota: ${_descriptionController.text.trim()}" : ""}\nID: ${docRef.id}',
          'equipmentId': _selectedEquipmentId,
          'reportId': docRef.id,
          'clientId': currentUser.uid,
          'clientName': clientName,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error creando notificación pendiente: $e');
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
                      Text('¡Falla reportada exitosamente!',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Los técnicos han sido notificados',
                          style: TextStyle(fontSize: 12)),
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
      debugPrint('Error reportando falla: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reportar: ${e.toString().split(']').last}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                    // Encabezado
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
                          const Icon(Icons.warning_amber_rounded,
                              size: 48, color: Colors.white),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Reportar Falla',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                const SizedBox(height: 4),
                                Text('Selecciona el equipo con la falla',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.9))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Filtros si no viene equipo preseleccionado
                    if (widget.equipmentId == null) ...[
                      // Filtro Sucursal
                      const Text('Sucursal',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedBranch,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.business_center,
                                color: Colors.grey),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          isExpanded: true,
                          items: _availableBranches.map((branch) {
                            return DropdownMenuItem(
                                value: branch,
                                child: Text(branch,
                                    overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (value) {
                            _selectedBranch = value ?? 'Todas';
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Filtro Tipo
                      const Text('Tipo de Equipo',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedTipo,
                          decoration: InputDecoration(
                            prefixIcon:
                                const Icon(Icons.category, color: Colors.grey),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          isExpanded: true,
                          items: _availableTipos.map((tipo) {
                            return DropdownMenuItem(
                                value: tipo,
                                child: Text(tipo,
                                    overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (value) {
                            _selectedTipo = value ?? 'Todos';
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selector de equipo
                      const Text('Seleccionar Equipo',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedEquipmentId,
                          decoration: InputDecoration(
                            hintText: _filteredEquipments.isEmpty
                                ? 'No hay equipos con estos filtros'
                                : 'Selecciona el equipo con falla',
                            prefixIcon: const Icon(Icons.build_circle,
                                color: Colors.grey),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          isExpanded: true,
                          items: _filteredEquipments.map((equipment) {
                            return DropdownMenuItem<String>(
                              value: equipment['id'] as String,
                              child: Text(
                                '${equipment['equipmentNumber']} - ${equipment['name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            final selected = _filteredEquipments.firstWhere(
                              (e) => e['id'] == value,
                            );
                            setState(() {
                              _selectedEquipmentId = value;
                              _selectedEquipmentNumber =
                                  selected['equipmentNumber'] as String;
                              _selectedEquipmentName =
                                  selected['name'] as String;
                              _selectedEquipmentData = selected;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Equipo preseleccionado
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
                                  Text(_selectedEquipmentNumber ?? '',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700)),
                                  Text(_selectedEquipmentName ?? '',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Info del equipo seleccionado (ubicación)
                    if (_selectedEquipmentData != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 6),
                                Text('Información del Equipo',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[700])),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildEquipmentInfoRow(
                                Icons.precision_manufacturing,
                                'Tipo',
                                _selectedEquipmentData!['tipo'] as String),
                            _buildEquipmentInfoRow(Icons.devices, 'Categoría',
                                _selectedEquipmentData!['category'] as String),
                            _buildEquipmentInfoRow(
                                Icons.business,
                                'Marca / Modelo',
                                '${_selectedEquipmentData!['brand']} ${_selectedEquipmentData!['model']}'),
                            _buildEquipmentInfoRow(
                                Icons.business_center,
                                'Sucursal',
                                _selectedEquipmentData!['branch'] as String),
                            if ((_selectedEquipmentData!['location'] as String)
                                .isNotEmpty)
                              _buildEquipmentInfoRow(
                                  Icons.place,
                                  'Departamento',
                                  _selectedEquipmentData!['location']
                                      as String),
                            _buildEquipmentInfoRow(Icons.settings, 'Estado',
                                _selectedEquipmentData!['status'] as String),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Nota (opcional)
                    Row(
                      children: [
                        const Text('Nota',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Opcional',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600])),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              'Agrega una nota adicional sobre la falla...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        // Sin validator — es opcional
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
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send),
                                  SizedBox(width: 8),
                                  Text('Enviar Reporte',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEquipmentInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
