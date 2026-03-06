import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pm_monitor/core/models/technician_model.dart';
import 'package:pm_monitor/core/services/tecnician_service.dart';

class TechnicianProvider with ChangeNotifier {
  final TechnicianService _technicianService = TechnicianService();
  final ImagePicker _imagePicker = ImagePicker();

  List<TechnicianModel> _technicians = [];
  List<TechnicianModel> _filteredTechnicians = [];
  TechnicianModel? _selectedTechnician;
  bool _isLoading = false;
  String _searchQuery = '';
  String _errorMessage = '';
  Map<String, int> _stats = {};
  String? _uploadingPhotoForId; // ← NUEVO: tracking qué técnico está subiendo

  List<TechnicianModel> get technicians => _technicians;
  List<TechnicianModel> get filteredTechnicians => _filteredTechnicians;
  TechnicianModel? get selectedTechnician => _selectedTechnician;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get errorMessage => _errorMessage;
  Map<String, int> get stats => _stats;
  String? get uploadingPhotoForId => _uploadingPhotoForId;

  List<TechnicianModel> get activeTechnicians =>
      _technicians.where((tech) => tech.isActive).toList();

  List<TechnicianModel> get inactiveTechnicians =>
      _technicians.where((tech) => !tech.isActive).toList();

  Stream<List<TechnicianModel>> get techniciansStream =>
      _technicianService.getTechniciansStream();

  void initializeTechniciansListener() {
    _technicianService.getTechniciansStream().listen(
      (technicians) {
        _technicians = technicians;
        _applySearchFilter();
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  // ✅ NUEVO: Subir foto de perfil del técnico desde el admin
  Future<bool> uploadTechnicianPhoto(String technicianId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return false;

      _uploadingPhotoForId = technicianId;
      notifyListeners();

      // Subir a Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('technician_photos')
          .child('${technicianId}_$timestamp.jpg');

      final file = File(image.path);
      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Actualizar en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(technicianId)
          .update({
        'photoUrl': downloadUrl,
        'updatedAt': Timestamp.now(),
      });

      // Actualizar en lista local
      final index = _technicians.indexWhere((t) => t.id == technicianId);
      if (index != -1) {
        _technicians[index] = _technicians[index].copyWith(
          profileImageUrl: downloadUrl,
          updatedAt: DateTime.now(),
        );
        _applySearchFilter();
      }

      _uploadingPhotoForId = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error subiendo foto: $e');
      _uploadingPhotoForId = null;
      notifyListeners();
      return false;
    }
  }

  void searchTechnicians(String query) {
    _searchQuery = query;
    _applySearchFilter();
    notifyListeners();
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredTechnicians = List.from(_technicians);
    } else {
      final queryLower = _searchQuery.toLowerCase();
      _filteredTechnicians = _technicians.where((technician) {
        return technician.fullName.toLowerCase().contains(queryLower) ||
            technician.email.toLowerCase().contains(queryLower) ||
            technician.phone.contains(queryLower);
      }).toList();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredTechnicians = List.from(_technicians);
    notifyListeners();
  }

  void selectTechnician(TechnicianModel? technician) {
    _selectedTechnician = technician;
    notifyListeners();
  }

  Future<TechnicianModel?> getTechnicianById(String technicianId) async {
    try {
      _setLoading(true);
      final technician =
          await _technicianService.getTechnicianById(technicianId);
      _setLoading(false);
      return technician;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  Future<bool> createTechnician(TechnicianModel technician) async {
    try {
      _setLoading(true);
      await _technicianService.createTechnician(technician);
      _setLoading(false);
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateTechnician(
      String technicianId, Map<String, dynamic> updates) async {
    try {
      _setLoading(true);
      await _technicianService.updateTechnician(technicianId, updates);

      final index = _technicians.indexWhere((tech) => tech.id == technicianId);
      if (index != -1) {
        _technicians[index] = _technicians[index].copyWith(
          fullName: updates['fullName'] ?? _technicians[index].fullName,
          email: updates['email'] ?? _technicians[index].email,
          phone: updates['phone'] ?? _technicians[index].phone,
          hourlyRate: updates['hourlyRate'] ?? _technicians[index].hourlyRate,
          specialization:
              updates['specialization'] ?? _technicians[index].specialization,
          updatedAt: DateTime.now(),
        );
      }

      _setLoading(false);
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> toggleTechnicianStatus(
      String technicianId, bool isActive) async {
    try {
      _setLoading(true);
      await _technicianService.toggleTechnicianStatus(technicianId, isActive);

      final index = _technicians.indexWhere((tech) => tech.id == technicianId);
      if (index != -1) {
        _technicians[index] = _technicians[index].copyWith(
          isActive: isActive,
          updatedAt: DateTime.now(),
        );
      }

      _setLoading(false);
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> assignEquipmentsToTechnician(
      String technicianId, List<String> equipmentIds) async {
    try {
      _setLoading(true);
      await _technicianService.assignEquipmentsToTechnician(
          technicianId, equipmentIds);

      final index = _technicians.indexWhere((tech) => tech.id == technicianId);
      if (index != -1) {
        _technicians[index] = _technicians[index].copyWith(
          assignedEquipments: equipmentIds,
          updatedAt: DateTime.now(),
        );
      }

      _setLoading(false);
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> addEquipmentToTechnician(
      String technicianId, String equipmentId, String technicianName) async {
    try {
      _setLoading(true);
      await _technicianService.assignEquipmentToTechnicianSync(
          technicianId, equipmentId, technicianName);

      final index = _technicians.indexWhere((tech) => tech.id == technicianId);
      if (index != -1) {
        final currentEquipments =
            List<String>.from(_technicians[index].assignedEquipments);
        if (!currentEquipments.contains(equipmentId)) {
          currentEquipments.add(equipmentId);
          _technicians[index] = _technicians[index].copyWith(
            assignedEquipments: currentEquipments,
            updatedAt: DateTime.now(),
          );
        }
      }

      _setLoading(false);
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> removeEquipmentFromTechnician(
      String technicianId, String equipmentId) async {
    try {
      _setLoading(true);
      await _technicianService.unassignEquipmentFromTechnicianSync(
          technicianId, equipmentId);

      final index = _technicians.indexWhere((tech) => tech.id == technicianId);
      if (index != -1) {
        final currentEquipments =
            List<String>.from(_technicians[index].assignedEquipments);
        currentEquipments.remove(equipmentId);
        _technicians[index] = _technicians[index].copyWith(
          assignedEquipments: currentEquipments,
          updatedAt: DateTime.now(),
        );
      }

      _setLoading(false);
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateTechnicianRate(
      String technicianId, double hourlyRate) async {
    try {
      await _technicianService.updateTechnicianRate(technicianId, hourlyRate);

      final index = _technicians.indexWhere((tech) => tech.id == technicianId);
      if (index != -1) {
        _technicians[index] = _technicians[index].copyWith(
          hourlyRate: hourlyRate,
          updatedAt: DateTime.now(),
        );
      }

      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<void> loadStats() async {
    try {
      _stats = await _technicianService.getTechnicianStats();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
  }

  @override
  void dispose() {
    _technicians.clear();
    _filteredTechnicians.clear();
    _selectedTechnician = null;
    _searchQuery = '';
    _errorMessage = '';
    _stats.clear();
    super.dispose();
  }

  Future<void> refresh() async {
    await loadStats();
  }

  Future<int> getAssignedEquipmentsCount(String technicianId) async {
    try {
      return await _technicianService.getAssignedEquipmentsCount(technicianId);
    } catch (e) {
      debugPrint('Error al obtener conteo de equipos: $e');
      return 0;
    }
  }

  Future<void> loadEquipmentCounts() async {
    try {
      for (int i = 0; i < _technicians.length; i++) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error al cargar conteos de equipos: $e');
    }
  }

  Future<void> syncEquipmentData() async {
    try {
      _setLoading(true);
      await _technicianService.syncTechnicianEquipmentData();
      _clearError();
      await refresh();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  void setLoading(bool loading) {
    notifyListeners();
  }

  void setError(String error) {
    notifyListeners();
  }
}
