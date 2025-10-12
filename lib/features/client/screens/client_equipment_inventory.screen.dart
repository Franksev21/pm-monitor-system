import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/features/equipment/equipment_detail_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ClientEquipmentInventoryScreen extends StatefulWidget {
  const ClientEquipmentInventoryScreen({super.key});

  @override
  State<ClientEquipmentInventoryScreen> createState() =>
      _ClientEquipmentInventoryScreenState();
}

class _ClientEquipmentInventoryScreenState
    extends State<ClientEquipmentInventoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedLocation = 'Todos';
  String _selectedStatus = 'Todos';
  List<String> _locations = ['Todos'];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Obtener nombre del cliente
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final userData = userDoc.data();
      final clientName = userData?['name'] ?? '';

      if (clientName.isEmpty) return;

      // Obtener equipos por branch
      final equipments = await _firestore
          .collection('equipments')
          .where('branch', isEqualTo: clientName)
          .get();

      final locationSet = <String>{'Todos'};
      for (var doc in equipments.docs) {
        final location = doc.data()['location'] as String?;
        if (location != null && location.isNotEmpty) {
          locationSet.add(location);
        }
      }

      if (mounted) {
        setState(() {
          _locations = locationSet.toList()..sort();
        });
      }
    } catch (e) {
      print('Error cargando ubicaciones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Mis Equipos'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear QR',
            onPressed: () => _scanQRCode(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: _buildEquipmentList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Barra de búsqueda
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o número...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          // Filtros
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Ubicación',
                  value: _selectedLocation,
                  items: _locations,
                  onChanged: (value) {
                    setState(() {
                      _selectedLocation = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Estado',
                  value: _selectedStatus,
                  items: const [
                    'Todos',
                    'Operativo',
                    'Mantenimiento',
                    'Inactivo'
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEquipmentList() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Center(child: Text('Usuario no autenticado'));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(currentUserId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (userSnapshot.hasError) {
          print('❌ Error obteniendo usuario: ${userSnapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Error cargando datos del cliente'),
              ],
            ),
          );
        }

        if (!userSnapshot.hasData || userSnapshot.data?.data() == null) {
          return const Center(
            child: Text('No se encontró información del usuario'),
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final clientName = userData['name'] ?? '';

        if (clientName.isEmpty) {
          return const Center(
            child: Text('Tu perfil no tiene un nombre asignado'),
          );
        }

        print('✅ Buscando equipos para: "$clientName"');

        // CAMBIO: Obtener TODOS los equipos y filtrar en el cliente
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('equipments').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print('❌ Error: ${snapshot.error}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Error de permisos'),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        '${snapshot.error}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Filtrar equipos que pertenecen al cliente (case-insensitive)
            var equipments = snapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final equipmentBranch = (data['branch'] ?? '').toString();

                  // Comparación sin distinguir mayúsculas/minúsculas
                  return equipmentBranch.toLowerCase() ==
                      clientName.toLowerCase();
                }).toList() ??
                [];

            print('✅ Equipos encontrados: ${equipments.length}');

            // Aplicar filtros adicionales de búsqueda, ubicación y estado
            equipments = equipments.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final equipmentNumber =
                  (data['equipmentNumber'] ?? '').toString().toLowerCase();
              final location = data['location'] ?? '';
              final status = data['status'] ?? '';

              // Filtro de búsqueda
              if (_searchQuery.isNotEmpty) {
                if (!name.contains(_searchQuery) &&
                    !equipmentNumber.contains(_searchQuery)) {
                  return false;
                }
              }

              // Filtro de ubicación
              if (_selectedLocation != 'Todos' &&
                  location != _selectedLocation) {
                return false;
              }

              // Filtro de estado
              if (_selectedStatus != 'Todos' && status != _selectedStatus) {
                return false;
              }

              return true;
            }).toList();

            if (equipments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.devices_other,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty ||
                              _selectedLocation != 'Todos' ||
                              _selectedStatus != 'Todos'
                          ? 'No se encontraron equipos con estos filtros'
                          : 'No tienes equipos registrados',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_searchQuery.isNotEmpty ||
                        _selectedLocation != 'Todos' ||
                        _selectedStatus != 'Todos')
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                              _selectedLocation = 'Todos';
                              _selectedStatus = 'Todos';
                            });
                          },
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Limpiar filtros'),
                        ),
                      ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: equipments.length,
                itemBuilder: (context, index) {
                  final equipmentDoc = equipments[index];
                  final data = equipmentDoc.data() as Map<String, dynamic>;

                  return _buildEquipmentCard(
                    equipmentId: equipmentDoc.id,
                    equipmentNumber: data['equipmentNumber'] ?? 'N/A',
                    name: data['name'] ?? 'Sin nombre',
                    brand: data['brand'] ?? '',
                    model: data['model'] ?? '',
                    location: data['location'] ?? 'Sin ubicación',
                    status: data['status'] ?? 'Desconocido',
                    condition: data['condition'] ?? 'N/A',
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEquipmentCard({
    required String equipmentId,
    required String equipmentNumber,
    required String name,
    required String brand,
    required String model,
    required String location,
    required String status,
    required String condition,
  }) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'Operativo':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Mantenimiento':
        statusColor = Colors.orange;
        statusIcon = Icons.build_circle;
        break;
      case 'Inactivo':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    Color conditionColor;
    switch (condition.toLowerCase()) {
      case 'excelente':
        conditionColor = Colors.green;
        break;
      case 'bueno':
        conditionColor = Colors.blue;
        break;
      case 'regular':
        conditionColor = Colors.orange;
        break;
      case 'malo':
        conditionColor = Colors.red;
        break;
      default:
        conditionColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToEquipmentDetail(equipmentId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.ac_unit,
                      color: Color(0xFF4285F4),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equipmentNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (brand.isNotEmpty || model.isNotEmpty)
                          Text(
                            '$brand ${model}'.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code),
                    onPressed: () => _showQRCode(equipmentNumber, name),
                    tooltip: 'Ver código QR',
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.location_on,
                      label: location,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      icon: statusIcon,
                      label: status,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Condición: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: conditionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: conditionColor),
                    ),
                    child: Text(
                      condition,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: conditionColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showQRCode(String equipmentNumber, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 400,
            maxHeight: 600,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Título con botón cerrar
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/csc-logo.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Código QR del Equipo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 24,
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // QR Code con logo CSC embebido
                  Container(
                    width: 240,
                    height: 240,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4285F4).withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: equipmentNumber,
                      version: QrVersions.auto,
                      size: 208,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      embeddedImage:
                          const AssetImage('assets/images/csc-logo.png'),
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size(40, 40),
                      ),
                      padding: const EdgeInsets.all(4),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nombre del equipo
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Número del equipo
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF4285F4).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code,
                          size: 16,
                          color: Color(0xFF4285F4),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          equipmentNumber,
                          style: const TextStyle(
                            color: Color(0xFF4285F4),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Información
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Escanea este código para acceder al equipo rápidamente',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Función de compartir próximamente'),
                                backgroundColor: Color(0xFF4285F4),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Compartir'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4285F4),
                            side: const BorderSide(
                              color: Color(0xFF4285F4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4285F4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Cerrar',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
void _navigateToEquipmentDetail(String equipmentId) async {
    try {
      // Obtener el equipo completo desde Firestore
      final equipmentDoc =
          await _firestore.collection('equipments').doc(equipmentId).get();

      if (!equipmentDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Equipo no encontrado'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Crear objeto Equipment
      final equipment = Equipment.fromFirestore(equipmentDoc);

      // Navegar al detalle
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EquipmentDetailScreen(equipment: equipment),
          ),
        );
      }
    } catch (e) {
      print('Error navegando al detalle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar el equipo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scanQRCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Abriendo escáner QR...'),
        backgroundColor: Color(0xFF4285F4),
      ),
    );
    // TODO: Implementar escáner QR
    // Navigator.push(context, MaterialPageRoute(builder: (context) => QRScannerScreen()));
  }
}
