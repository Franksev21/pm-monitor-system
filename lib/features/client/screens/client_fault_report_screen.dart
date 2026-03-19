import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/core/models/fault_report_model.dart';
import 'package:pm_monitor/core/services/notification_service.dart';
import 'package:pm_monitor/features/others/screens/qr_scanner_screen.dart';

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

  List<Map<String, dynamic>> _allEquipments = [];
  List<Map<String, dynamic>> _filteredEquipments = [];

  // Filtros — orden: Sucursal → Departamento → Tipo
  String _selectedBranch = 'Todas';
  String _selectedDepartment = 'Todos';
  String _selectedTipo = 'Todos';
  List<String> _availableBranches = ['Todas'];
  List<String> _availableDepartments = ['Todos'];
  List<String> _availableTipos = ['Todos'];

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

  Future<void> _scanQRToSelectEquipment() async {
    // Navegar al scanner y esperar resultado
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    // El QRScannerScreen navega a EquipmentDetailScreen directamente.
    // Si quisiéramos pre-seleccionar el equipo aquí, usaríamos un callback.
    // Por ahora el flujo es: escanear → ver detalle del equipo → reportar falla desde ahí.
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

      final snapshot = await _firestore.collection('equipments').get();

      final equipments = snapshot.docs.where((doc) {
        final branch = (doc.data()['branch'] ?? '').toString().toLowerCase();
        return branch == clientName.toLowerCase();
      }).map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'equipmentNumber': d['equipmentNumber'] ?? '',
          'name': d['name'] ?? '',
          'status': d['status'] ?? '',
          'branch': d['branch'] ?? '',
          'tipo': d['tipo'] ?? '',
          'location': d['location'] ?? '',
          'category': d['category'] ?? '',
          'brand': d['brand'] ?? '',
          'model': d['model'] ?? '',
        };
      }).toList();

      final branches = <String>{'Todas'};
      final departments = <String>{'Todos'};
      final tipos = <String>{'Todos'};

      for (final eq in equipments) {
        if ((eq['branch'] as String).isNotEmpty) branches.add(eq['branch']);
        if ((eq['location'] as String).isNotEmpty)
          departments.add(eq['location']);
        if ((eq['tipo'] as String).isNotEmpty) tipos.add(eq['tipo']);
      }

      setState(() {
        _allEquipments = equipments;
        _filteredEquipments = equipments;
        _availableBranches = [
          'Todas',
          ...branches.toList().where((b) => b != 'Todas').toList()..sort()
        ];
        _availableDepartments = [
          'Todos',
          ...departments.toList().where((d) => d != 'Todos').toList()..sort()
        ];
        _availableTipos = [
          'Todos',
          ...tipos.toList().where((t) => t != 'Todos').toList()..sort()
        ];
        _isLoadingEquipments = false;

        if (_selectedEquipmentId != null) {
          try {
            _selectedEquipmentData = _allEquipments
                .firstWhere((e) => e['id'] == _selectedEquipmentId);
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
        final matchDept = _selectedDepartment == 'Todos' ||
            eq['location'] == _selectedDepartment;
        final matchTipo =
            _selectedTipo == 'Todos' || eq['tipo'] == _selectedTipo;
        return matchBranch && matchDept && matchTipo;
      }).toList();

      if (_selectedEquipmentId != null) {
        final stillExists =
            _filteredEquipments.any((e) => e['id'] == _selectedEquipmentId);
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

    setState(() => _isSubmitting = true);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Usuario no autenticado');

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final clientName = userDoc.data()?['name'] ?? '';

      final equipLocation = _selectedEquipmentData?['location'] ?? '';
      final equipBranch = _selectedEquipmentData?['branch'] ?? '';

      final report = FaultReport(
        equipmentId: _selectedEquipmentId!,
        equipmentNumber: _selectedEquipmentNumber!,
        equipmentName: _selectedEquipmentName!,
        clientId: currentUser.uid,
        clientName: clientName,
        severity: 'MEDIA',
        description: _descriptionController.text.trim(),
        status: 'pending',
        reportedAt: DateTime.now(),
        location: equipLocation.isNotEmpty
            ? '$equipLocation, $equipBranch'
            : equipBranch,
      );

      final docRef =
          await _firestore.collection('faultReports').add(report.toFirestore());

      try {
        await NotificationService().sendFaultNotifications(
          equipmentName: _selectedEquipmentName!,
          equipmentId: _selectedEquipmentId!,
          severity: 'MEDIA',
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : 'Falla reportada sin descripción adicional',
          reportId: docRef.id,
        );
      } catch (e) {
        debugPrint('Error notificaciones: $e');
      }

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
        debugPrint('Error pendingNotifications: $e');
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reportar: ${e.toString().split(']').last}'),
            backgroundColor: Colors.red,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear QR del equipo',
            onPressed: _scanQRToSelectEquipment,
          ),
        ],
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
                    // ── Encabezado ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Colors.red, Colors.orange]),
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

                    if (widget.equipmentId == null) ...[
                      // ── 1. SUCURSAL ──
                      _buildFilterLabel('Sucursal'),
                      const SizedBox(height: 8),
                      _buildFilterDropdown(
                        value: _selectedBranch,
                        items: _availableBranches,
                        icon: Icons.store_outlined,
                        onChanged: (v) {
                          _selectedBranch = v ?? 'Todas';
                          _applyFilters();
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── 2. DEPARTAMENTO ──
                      _buildFilterLabel('Departamento'),
                      const SizedBox(height: 8),
                      _buildFilterDropdown(
                        value: _selectedDepartment,
                        items: _availableDepartments,
                        icon: Icons.meeting_room_outlined,
                        onChanged: (v) {
                          _selectedDepartment = v ?? 'Todos';
                          _applyFilters();
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── 3. TIPO DE EQUIPO ──
                      _buildFilterLabel('Tipo de Equipo'),
                      const SizedBox(height: 8),
                      _buildFilterDropdown(
                        value: _selectedTipo,
                        items: _availableTipos,
                        icon: Icons.category_outlined,
                        onChanged: (v) {
                          _selectedTipo = v ?? 'Todos';
                          _applyFilters();
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── 4. SELECCIONAR EQUIPO ──
                      _buildFilterLabel('Seleccionar Equipo'),
                      const SizedBox(height: 8),
                      _buildFilterDropdown(
                        value: _selectedEquipmentId,
                        items: const [],
                        icon: Icons.build_circle_outlined,
                        hintText: _filteredEquipments.isEmpty
                            ? 'No hay equipos con estos filtros'
                            : 'Selecciona el equipo con falla',
                        customItems: _filteredEquipments.map((eq) {
                          return DropdownMenuItem<String>(
                            value: eq['id'] as String,
                            child: Text(
                              '${eq['equipmentNumber']} - ${eq['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          final selected = _filteredEquipments
                              .firstWhere((e) => e['id'] == value);
                          setState(() {
                            _selectedEquipmentId = value;
                            _selectedEquipmentNumber =
                                selected['equipmentNumber'] as String;
                            _selectedEquipmentName = selected['name'] as String;
                            _selectedEquipmentData = selected;
                          });
                        },
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

                    // ── Info reducida del equipo: Descripción, Marca, Departamento ──
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
                            // Solo 3 campos
                            _buildInfoRow(
                              Icons.devices,
                              'Descripción',
                              _selectedEquipmentData!['category'] as String,
                            ),
                            _buildInfoRow(
                              Icons.business,
                              'Marca',
                              '${_selectedEquipmentData!['brand'] as String}'
                            ),
                            _buildInfoRow(
                              Icons.meeting_room_outlined,
                              'Departamento',
                              _selectedEquipmentData!['location'] as String,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Nota (opcional) ──
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
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Botón enviar ──
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildFilterLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
    );
  }

  Widget _buildFilterDropdown({
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String? hintText,
    List<DropdownMenuItem<String>>? customItems,
  }) {
    return Container(
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
        value: value,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey),
          hintText: hintText,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
        isExpanded: true,
        items: customItems ??
            items.map((item) {
              return DropdownMenuItem(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis));
            }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
