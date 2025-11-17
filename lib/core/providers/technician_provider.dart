import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/technician_model.dart';
import 'package:pm_monitor/core/services/tecnician_service.dart';
import 'package:pm_monitor/core/services/user_management_service.dart';

class TechnicianProvider with ChangeNotifier {
  final TechnicianService _technicianService = TechnicianService();
  final UserManagementService _userManagementService = UserManagementService();

  // Estado local
  List<TechnicianModel> _technicians = [];
  List<TechnicianModel> _filteredTechnicians = [];
  TechnicianModel? _selectedTechnician;
  bool _isLoading = false;
  String _searchQuery = '';
  String _errorMessage = '';
  Map<String, int> _stats = {};

  // Getters
  List<TechnicianModel> get technicians => _technicians;
  List<TechnicianModel> get filteredTechnicians => _filteredTechnicians;
  TechnicianModel? get selectedTechnician => _selectedTechnician;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get errorMessage => _errorMessage;
  Map<String, int> get stats => _stats;

  // Getter para técnicos activos
  List<TechnicianModel> get activeTechnicians =>
      _technicians.where((tech) => tech.isActive).toList();

  // Getter para técnicos inactivos
  List<TechnicianModel> get inactiveTechnicians =>
      _technicians.where((tech) => !tech.isActive).toList();

  // Stream de técnicos
  Stream<List<TechnicianModel>> get techniciansStream =>
      _technicianService.getTechniciansStream();

  // Inicializar listener del stream
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

  // Buscar técnicos
  void searchTechnicians(String query) {
    _searchQuery = query;
    _applySearchFilter();
    notifyListeners();
  }

  // Aplicar filtro de búsqueda
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

  // Limpiar búsqueda
  void clearSearch() {
    _searchQuery = '';
    _filteredTechnicians = List.from(_technicians);
    notifyListeners();
  }

  // Seleccionar técnico
  void selectTechnician(TechnicianModel? technician) {
    _selectedTechnician = technician;
    notifyListeners();
  }

  // Obtener técnico por ID
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

  // Crear técnico
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

  // Actualizar técnico
  Future<bool> updateTechnician(
      String technicianId, Map<String, dynamic> updates) async {
    try {
      _setLoading(true);
      await _technicianService.updateTechnician(technicianId, updates);

      // Actualizar en la lista local
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

  // Cambiar estado del técnico
  Future<bool> toggleTechnicianStatus(
      String technicianId, bool isActive) async {
    try {
      _setLoading(true);
      await _technicianService.toggleTechnicianStatus(technicianId, isActive);

      // Actualizar en la lista local
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

  // Asignar equipos a técnico
  Future<bool> assignEquipmentsToTechnician(
      String technicianId, List<String> equipmentIds) async {
    try {
      _setLoading(true);
      await _technicianService.assignEquipmentsToTechnician(
          technicianId, equipmentIds);

      // Actualizar en la lista local
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

  // Agregar equipo a técnico
  Future<bool> addEquipmentToTechnician(
      String technicianId, String equipmentId, String technicianName) async {
    try {
      _setLoading(true);

      // Usar el nuevo método sincronizado
      await _technicianService.assignEquipmentToTechnicianSync(
          technicianId, equipmentId, technicianName);

      // Actualizar en la lista local
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

  // Remover equipo de técnico
  Future<bool> removeEquipmentFromTechnician(
      String technicianId, String equipmentId) async {
    try {
      _setLoading(true);

      // Usar el nuevo método sincronizado
      await _technicianService.unassignEquipmentFromTechnicianSync(
          technicianId, equipmentId);

      // Actualizar en la lista local
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

  // Actualizar tarifa horaria
  Future<bool> updateTechnicianRate(
      String technicianId, double hourlyRate) async {
    try {
      await _technicianService.updateTechnicianRate(technicianId, hourlyRate);

      // Actualizar en la lista local
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

  // Cargar estadísticas
  Future<void> loadStats() async {
    try {
      _stats = await _technicianService.getTechnicianStats();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Métodos de utilidad privados
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

  // Limpiar provider
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

  // Refrescar datos
  Future<void> refresh() async {
    await loadStats();
    // El stream se actualiza automáticamente
  }

  Future<int> getAssignedEquipmentsCount(String technicianId) async {
    try {
      return await _technicianService.getAssignedEquipmentsCount(technicianId);
    } catch (e) {
      print('Error al obtener conteo de equipos: $e');
      return 0;
    }
  }

  // Cargar conteos de equipos para todos los técnicos
  Future<void> loadEquipmentCounts() async {
    try {
      for (int i = 0; i < _technicians.length; i++) {
        notifyListeners();
      }
    } catch (e) {
      print('Error al cargar conteos de equipos: $e');
    }
  }

  Future<void> syncEquipmentData() async {
    try {
      _setLoading(true);
      await _technicianService.syncTechnicianEquipmentData();
      _clearError();

      // Recargar datos después de la sincronización
      await refresh();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
// También agregar estos métodos helper si no los tienes:
  void setLoading(bool loading) {
    // Actualizar tu estado de loading
    notifyListeners();
  }

  void setError(String error) {
    // Manejar tu estado de error
    notifyListeners();
  }
}
