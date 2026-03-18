import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pm_monitor/features/calendar/screens/maintenance_management_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/client_provider.dart';
import '../../../core/providers/equipment_provider.dart';
import '../../../core/models/client_model.dart';
import '../../../config/theme/app_theme.dart';
import 'add_client_screen.dart';
import '../../equipment/add_equipment_screen.dart';
import '../../equipment/client_equipment_list_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final ClientModel client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  // ── Fotos generales ──
  List<String> _photoUrls = [];
  bool _loadingPhotos = false;
  bool _uploadingPhoto = false;

  // ── Logo y foto representante ──
  String? _logoUrl;
  String? _repPhotoUrl;
  bool _uploadingLogo = false;
  bool _uploadingRepPhoto = false;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final equipmentProvider =
          Provider.of<EquipmentProvider>(context, listen: false);
      equipmentProvider.loadEquipmentsByClient(widget.client.id);
    });
    _loadPhotos();
  }

  // ─────────────────────────────────────────────────────
  //  FOTOS — carga, upload, eliminación
  // ─────────────────────────────────────────────────────
  Future<void> _loadPhotos() async {
    setState(() => _loadingPhotos = true);
    try {
      final doc =
          await _firestore.collection('clients').doc(widget.client.id).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _photoUrls = List<String>.from(data?['photoUrls'] ?? []);
          _logoUrl = data?['logoUrl'] as String?;
          _repPhotoUrl = data?['repPhotoUrl'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error cargando fotos: $e');
    }
    setState(() => _loadingPhotos = false);
  }

  Future<void> _uploadLogo() async {
    final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 600);
    if (picked == null) return;
    setState(() => _uploadingLogo = true);
    try {
      final file = File(picked.path);
      final ref = _storage.ref().child('clients/${widget.client.id}/logo.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _firestore
          .collection('clients')
          .doc(widget.client.id)
          .update({'logoUrl': url});
      setState(() => _logoUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Logo actualizado'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    setState(() => _uploadingLogo = false);
  }

  Future<void> _uploadRepPhoto() async {
    final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 600);
    if (picked == null) return;
    setState(() => _uploadingRepPhoto = true);
    try {
      final file = File(picked.path);
      final ref = _storage
          .ref()
          .child('clients/${widget.client.id}/representative.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _firestore
          .collection('clients')
          .doc(widget.client.id)
          .update({'repPhotoUrl': url});
      setState(() => _repPhotoUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Foto del representante actualizada'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    setState(() => _uploadingRepPhoto = false);
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked == null) return;

      setState(() => _uploadingPhoto = true);

      final file = File(picked.path);
      final fileName =
          'clients/${widget.client.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = _storage.ref().child(fileName);
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // Guardar URL en Firestore
      await _firestore.collection('clients').doc(widget.client.id).update({
        'photoUrls': FieldValue.arrayUnion([url]),
      });

      setState(() {
        _photoUrls.add(url);
        _uploadingPhoto = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto agregada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _uploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePhoto(String url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Eliminar foto'),
        content: const Text('¿Estás seguro de que quieres eliminar esta foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Eliminar de Storage
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Si falla Storage seguimos igual (puede que ya no exista)
    }

    // Eliminar URL de Firestore
    await _firestore.collection('clients').doc(widget.client.id).update({
      'photoUrls': FieldValue.arrayRemove([url]),
    });

    setState(() => _photoUrls.remove(url));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Foto eliminada'), backgroundColor: Colors.orange),
      );
    }
  }

  void _showPhotoSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Agregar foto',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF1976D2)),
                ),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('Elegir de galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openPhotoViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewerScreen(
          urls: _photoUrls,
          initialIndex: initialIndex,
          clientName: widget.client.name,
          onDelete: _deletePhoto,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddClientScreen(client: widget.client),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Editar'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildBasicInfo(),
            _buildAddressInfo(),
            _buildPhotosSection(), // ← FOTOS
            if (widget.client.branches.isNotEmpty) _buildBranchesInfo(),
            if (widget.client.contacts.isNotEmpty) _buildContactsInfo(),
            if (widget.client.notes.isNotEmpty) _buildNotesInfo(),
            _buildActions(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEquipmentScreen(client: widget.client),
            ),
          );
          if (result == true && mounted) {
            final equipmentProvider =
                Provider.of<EquipmentProvider>(context, listen: false);
            equipmentProvider.loadEquipmentsByClient(widget.client.id);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Agregar Equipo'),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  SECCIÓN DE FOTOS
  // ─────────────────────────────────────────────────────
  Widget _buildPhotosSection() {
    return _buildSection(
      title: 'Fotos del Cliente',
      icon: Icons.photo_library_outlined,
      trailing: _uploadingPhoto
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF1976D2)),
            )
          : IconButton(
              icon: const Icon(Icons.add_a_photo, color: Color(0xFF1976D2)),
              tooltip: 'Agregar foto',
              onPressed: _showPhotoSourceDialog,
            ),
      child: _loadingPhotos
          ? const Center(
              child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ))
          : _photoUrls.isEmpty
              ? _buildEmptyPhotos()
              : _buildPhotoGrid(),
    );
  }

  Widget _buildEmptyPhotos() {
    return GestureDetector(
      onTap: _showPhotoSourceDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text(
              'Toca para agregar fotos',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Instalaciones, oficinas, equipos...',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: _photoUrls.length + 1, // +1 para el botón "Agregar"
          itemBuilder: (context, index) {
            // Última celda = botón agregar
            if (index == _photoUrls.length) {
              return GestureDetector(
                onTap: _uploadingPhoto ? null : _showPhotoSourceDialog,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF1976D2).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: _uploadingPhoto
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1976D2),
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                color: Color(0xFF1976D2), size: 26),
                            SizedBox(height: 4),
                            Text(
                              'Agregar',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                ),
              );
            }

            // Celda de foto
            return GestureDetector(
              onTap: () => _openPhotoViewer(index),
              onLongPress: () => _deletePhoto(_photoUrls[index]),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _photoUrls[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child:
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                  // Ícono de eliminar en la esquina
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _deletePhoto(_photoUrls[index]),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          '${_photoUrls.length} foto${_photoUrls.length != 1 ? 's' : ''} · Mantén presionado para eliminar',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  //  RESTO DE LA PANTALLA (sin cambios)
  // ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    // Obtener contacto principal
    final primaryContact = widget.client.contacts.isNotEmpty
        ? widget.client.contacts.firstWhere(
            (c) => c.isPrimary,
            orElse: () => widget.client.contacts.first,
          )
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          children: [
            // ── Logo + Representante ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LOGO
                _buildLogoWidget(),
                const SizedBox(width: 32),
                // REPRESENTANTE
                _buildRepPhotoWidget(primaryContact),
              ],
            ),
            const SizedBox(height: 20),

            // Nombre empresa
            Text(
              widget.client.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Tipo + Estado
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getTypeIcon(widget.client.type),
                          size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(widget.client.type.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.client.statusColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(widget.client.status.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                    'Sucursales', widget.client.totalBranches.toString()),
                _buildStatItem(
                    'Contactos', widget.client.totalContacts.toString()),
                Consumer<EquipmentProvider>(
                  builder: (context, equipmentProvider, child) {
                    final count = equipmentProvider.clientEquipments.length;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => count > 0
                              ? ClientEquipmentListScreen(client: widget.client)
                              : AddEquipmentScreen(client: widget.client),
                        ),
                      ).then((result) {
                        if (result == true) {
                          equipmentProvider
                              .loadEquipmentsByClient(widget.client.id);
                        }
                      }),
                      child: Column(
                        children: [
                          Text('$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const Text('Equipos',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Logo de la empresa ──
  Widget _buildLogoWidget() {
    return Column(
      children: [
        // Label superior
        const Text(
          'Logo',
          style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            GestureDetector(
              onTap: _uploadLogo,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.8), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: _uploadingLogo
                    ? const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF1976D2)))
                    : _logoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _logoUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.business,
                                  color: Color(0xFF1976D2),
                                  size: 36),
                            ),
                          )
                        : const Icon(Icons.business,
                            color: Color(0xFF1976D2), size: 36),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _uploadLogo,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF1976D2), width: 1.5),
                  ),
                  child: const Icon(Icons.edit,
                      size: 12, color: Color(0xFF1976D2)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Toca para editar',
          style: TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  // ── Foto del representante con nombre y cargo ──
  Widget _buildRepPhotoWidget(dynamic primaryContact) {
    final repName = primaryContact?.name as String? ?? '';
    final repPosition = primaryContact?.position as String? ?? '';

    return Column(
      children: [
        // Label superior
        const Text(
          'Representante',
          style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            GestureDetector(
              onTap: _uploadRepPhoto,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.8), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: _uploadingRepPhoto
                    ? const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF1976D2)))
                    : _repPhotoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              _repPhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _defaultRepAvatar(repName),
                            ),
                          )
                        : _defaultRepAvatar(repName),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _uploadRepPhoto,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF1976D2), width: 1.5),
                  ),
                  child: const Icon(Icons.edit,
                      size: 12, color: Color(0xFF1976D2)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Nombre del representante
        if (repName.isNotEmpty)
          Text(
            repName,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        // Cargo
        if (repPosition.isNotEmpty)
          Text(
            repPosition,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (repName.isEmpty)
          const Text(
            'Toca para editar',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
      ],
    );
  }

  Widget _defaultRepAvatar(String name) {
    final initial = name.isNotEmpty
        ? name[0].toUpperCase()
        : widget.client.name[0].toUpperCase();
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
            color: Color(0xFF1976D2),
            fontSize: 28,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style:
                TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
      ],
    );
  }

  Widget _buildBasicInfo() {
    return _buildSection(
      title: 'Información General',
      icon: Icons.business,
      child: Column(
        children: [
          _buildInfoRow(Icons.email, 'Email', widget.client.email),
          _buildInfoRow(Icons.phone, 'Teléfono', widget.client.phone),
          if (widget.client.website != null)
            _buildInfoRow(Icons.language, 'Sitio Web', widget.client.website!),
          _buildInfoRow(Icons.badge, 'RNC/Cédula', widget.client.taxId),
          _buildInfoRow(Icons.calendar_today, 'Cliente desde',
              _formatDate(widget.client.createdAt)),
        ],
      ),
    );
  }

  Widget _buildAddressInfo() {
    return _buildSection(
      title: 'Dirección Principal',
      icon: Icons.location_on,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.client.mainAddress.fullAddress,
                style: AppTheme.bodyLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Próximamente: Abrir en mapas'))),
                    icon: const Icon(Icons.map),
                    label: const Text('Ver en Mapa'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Próximamente: Cómo llegar'))),
                    icon: const Icon(Icons.directions),
                    label: const Text('Cómo llegar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchesInfo() {
    return _buildSection(
      title: 'Sucursales (${widget.client.branches.length})',
      icon: Icons.apartment,
      child: Column(
        children: widget.client.branches
            .map((branch) => _buildBranchCard(branch))
            .toList(),
      ),
    );
  }

  Widget _buildBranchCard(BranchModel branch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store,
                    color:
                        branch.isActive ? AppTheme.primaryColor : Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(branch.name,
                      style: AppTheme.headingSmall.copyWith(
                          color: branch.isActive ? null : Colors.grey)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: branch.isActive
                        ? AppTheme.successColor.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    branch.isActive ? 'Activa' : 'Inactiva',
                    style: AppTheme.bodySmall.copyWith(
                        color: branch.isActive
                            ? AppTheme.successColor
                            : Colors.grey,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(branch.address.fullAddress,
                        style: AppTheme.bodyMedium)),
              ],
            ),
            if (branch.managerName != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text('Gerente: ${branch.managerName}',
                    style: AppTheme.bodyMedium),
              ]),
            ],
            if (branch.managerPhone != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(branch.managerPhone!, style: AppTheme.bodyMedium),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactsInfo() {
    return _buildSection(
      title: 'Contactos (${widget.client.contacts.length})',
      icon: Icons.contacts,
      child: Column(
        children: widget.client.contacts
            .map((contact) => _buildContactCard(contact))
            .toList(),
      ),
    );
  }

  Widget _buildContactCard(ContactModel contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  contact.isPrimary ? AppTheme.primaryColor : Colors.grey[400],
              child: Text(contact.name[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(contact.name,
                            style: AppTheme.bodyLarge
                                .copyWith(fontWeight: FontWeight.w600)),
                      ),
                      if (contact.isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Principal',
                              style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  Text(contact.position,
                      style: AppTheme.bodyMedium
                          .copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.email, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(contact.email, style: AppTheme.bodySmall)),
                  ]),
                  Row(children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(contact.phone, style: AppTheme.bodySmall),
                  ]),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                    icon: const Icon(Icons.call),
                    onPressed: () {},
                    color: AppTheme.primaryColor),
                IconButton(
                    icon: const Icon(Icons.email),
                    onPressed: () {},
                    color: AppTheme.primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesInfo() {
    return _buildSection(
      title: 'Notas',
      icon: Icons.note,
      child: Text(widget.client.notes, style: AppTheme.bodyLarge),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MaintenanceManagementScreen()),
              ),
              icon: const Icon(Icons.build),
              label: const Text('Mantenimiento'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente: Ver reportes'))),
              icon: const Icon(Icons.analytics),
              label: const Text('Reportes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: AppTheme.headingSmall
                          .copyWith(color: AppTheme.primaryColor)),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        AppTheme.bodySmall.copyWith(color: Colors.grey[600])),
                Text(value,
                    style: AppTheme.bodyMedium
                        .copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(ClientType type) {
    switch (type) {
      case ClientType.small:
        return Icons.store;
      case ClientType.medium:
        return Icons.business;
      case ClientType.large:
        return Icons.apartment;
      case ClientType.enterprise:
        return Icons.domain;
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => AddClientScreen(client: widget.client)));
        break;
      case 'delete':
        _showDeleteDialog(context);
        break;
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text(
            '¿Estás seguro de que quieres eliminar a ${widget.client.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await context
                  .read<ClientProvider>()
                  .deleteClient(widget.client.id);
              if (success && context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Cliente eliminado exitosamente'),
                      backgroundColor: AppTheme.successColor),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  VISOR DE FOTOS A PANTALLA COMPLETA
// ─────────────────────────────────────────────────────
class _PhotoViewerScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final String clientName;
  final Future<void> Function(String url) onDelete;

  const _PhotoViewerScreen({
    required this.urls,
    required this.initialIndex,
    required this.clientName,
    required this.onDelete,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<String> _urls;

  @override
  void initState() {
    super.initState();
    _urls = List.from(widget.urls);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${widget.clientName} · ${_currentIndex + 1}/${_urls.length}',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Eliminar foto',
            onPressed: () async {
              final url = _urls[_currentIndex];
              Navigator.pop(context);
              await widget.onDelete(url);
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _urls.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.network(
              _urls[i],
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              },
              errorBuilder: (_, __, ___) => const Center(
                  child:
                      Icon(Icons.broken_image, color: Colors.grey, size: 64)),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _urls.length > 1
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _urls.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentIndex ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          i == _currentIndex ? Colors.white : Colors.grey[600],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
