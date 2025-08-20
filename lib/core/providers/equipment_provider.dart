import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/core/services/equipment_service.dart';

class EquipmentProvider with ChangeNotifier {
  final EquipmentService _equipmentService = EquipmentService();

  // Estados de carga
  bool _isLoading = false;
  bool _isCreating = false;
  bool _isUpdating = false;
  bool _isDeleting = false;

  // Listas de equipos
  List<Equipment> _allEquipments = [];
  List<Equipment> _clientEquipments = [];
  List<Equipment> _technicianEquipments = [];
  List<Equipment> _needingMaintenance = [];
  List<Equipment> _overdueEquipments = [];
  List<Equipment> _searchResults = [];

  // Equipo seleccionado
  Equipment? _selectedEquipment;

  // Estadísticas
  Map<String, dynamic> _equipmentStats = {};

  // Error handling
  String? _errorMessage;

  // Filtros y búsqueda
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  String _selectedStatus = 'Todos';
  String _selectedCondition = 'Todos';

  // Getters para estados de carga
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  bool get isUpdating => _isUpdating;
  bool get isDeleting => _isDeleting;

  // Getters para las listas
  List<Equipment> get allEquipments => _allEquipments;
  List<Equipment> get clientEquipments => _clientEquipments;
  List<Equipment> get technicianEquipments => _technicianEquipments;
  List<Equipment> get needingMaintenance => _needingMaintenance;
  List<Equipment> get overdueEquipments => _overdueEquipments;
  List<Equipment> get searchResults => _searchResults;

  // Getter para equipo seleccionado
  Equipment? get selectedEquipment => _selectedEquipment;

  // Getter para estadísticas
  Map<String, dynamic> get equipmentStats => _equipmentStats;

  // Getter para error
  String? get errorMessage => _errorMessage;

  // Getters para filtros
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get selectedStatus => _selectedStatus;
  String get selectedCondition => _selectedCondition;

  // Lista filtrada de equipos del cliente
  List<Equipment> get filteredClientEquipments {
    List<Equipment> filtered = List.from(_clientEquipments);

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((equipment) =>
              equipment.name
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              equipment.brand
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              equipment.model
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              equipment.equipmentNumber
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              equipment.location
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Filtrar por categoría
    if (_selectedCategory != 'Todos') {
      filtered = filtered
          .where((equipment) => equipment.category == _selectedCategory)
          .toList();
    }

    // Filtrar por estado
    if (_selectedStatus != 'Todos') {
      filtered = filtered
          .where((equipment) => equipment.status == _selectedStatus)
          .toList();
    }

    // Filtrar por condición
    if (_selectedCondition != 'Todos') {
      filtered = filtered
          .where((equipment) => equipment.condition == _selectedCondition)
          .toList();
    }

    return filtered;
  }

  // Obtener categorías únicas
  List<String> get availableCategories {
    Set<String> categories = {'Todos'};
    categories.addAll(_clientEquipments.map((e) => e.category));
    return categories.toList();
  }

  // Obtener estados únicos
  List<String> get availableStatuses {
    Set<String> statuses = {'Todos'};
    statuses.addAll(_clientEquipments.map((e) => e.status));
    return statuses.toList();
  }

  // Obtener condiciones únicas
  List<String> get availableConditions {
    Set<String> conditions = {'Todos'};
    conditions.addAll(_clientEquipments.map((e) => e.condition));
    return conditions.toList();
  }

  // Limpiar error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Establecer error
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Cargar todos los equipos
  void loadAllEquipments() {
    _equipmentService.getAllEquipments().listen(
      (equipments) {
        _allEquipments = equipments;
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading equipments: $error');
      },
    );
  }

  // Cargar equipos por cliente
  void loadEquipmentsByClient(String clientId) {
    _isLoading = true;
    notifyListeners();

    _equipmentService.getEquipmentsByClient(clientId).listen(
      (equipments) {
        _clientEquipments = equipments;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading client equipments: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Cargar equipos activos por cliente
  void loadActiveEquipmentsByClient(String clientId) {
    _isLoading = true;
    notifyListeners();

    _equipmentService.getActiveEquipmentsByClient(clientId).listen(
      (equipments) {
        _clientEquipments = equipments;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading active equipments: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Cargar equipos por técnico
  void loadEquipmentsByTechnician(String technicianId) {
    _isLoading = true;
    notifyListeners();

    _equipmentService.getEquipmentsByTechnician(technicianId).listen(
      (equipments) {
        _technicianEquipments = equipments;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading technician equipments: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Cargar equipos que necesitan mantenimiento
  void loadEquipmentsNeedingMaintenance() {
    _equipmentService.getEquipmentsNeedingMaintenance().listen(
      (equipments) {
        _needingMaintenance = equipments;
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading equipments needing maintenance: $error');
      },
    );
  }

  // Cargar equipos vencidos
  void loadOverdueEquipments() {
    _equipmentService.getOverdueEquipments().listen(
      (equipments) {
        _overdueEquipments = equipments;
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading overdue equipments: $error');
      },
    );
  }

  // Obtener equipo por ID
  Future<void> loadEquipmentById(String equipmentId) async {
    try {
      _isLoading = true;
      Equipment? equipment =
          await _equipmentService.getEquipmentById(equipmentId);
      _selectedEquipment = equipment;
    } catch (error) {
      _setError('Error loading equipment: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Buscar equipo por RFID
  Future<Equipment?> getEquipmentByRFID(String rfidTag) async {
    try {
      return await _equipmentService.getEquipmentByRFID(rfidTag);
    } catch (error) {
      _setError('Error finding equipment by RFID: $error');
      return null;
    }
  }

  // Buscar equipo por QR Code
  Future<Equipment?> getEquipmentByQRCode(String qrCode) async {
    try {
      return await _equipmentService.getEquipmentByQRCode(qrCode);
    } catch (error) {
      _setError('Error finding equipment by QR Code: $error');
      return null;
    }
  }

  // Crear equipo
  Future<bool> createEquipment(Equipment equipment) async {
    _isCreating = true;
    notifyListeners();

    try {
      String? equipmentId = await _equipmentService.createEquipment(equipment);
      _isCreating = false;
      notifyListeners();

      if (equipmentId != null) {
        // Recargar la lista del cliente
        loadEquipmentsByClient(equipment.clientId);
        return true;
      }
      return false;
    } catch (error) {
      _setError('Error creating equipment: $error');
      _isCreating = false;
      notifyListeners();
      return false;
    }
  }

  // Actualizar equipo
  Future<bool> updateEquipment(Equipment equipment) async {
    _isUpdating = true;
    notifyListeners();

    try {
      bool success = await _equipmentService.updateEquipment(equipment);
      _isUpdating = false;
      notifyListeners();

      if (success) {
        // Actualizar el equipo seleccionado si es el mismo
        if (_selectedEquipment?.id == equipment.id) {
          _selectedEquipment = equipment;
        }

        // Recargar la lista del cliente
        loadEquipmentsByClient(equipment.clientId);
        return true;
      }
      return false;
    } catch (error) {
      _setError('Error updating equipment: $error');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  // Eliminar equipo
  Future<bool> deleteEquipment(
      String equipmentId, String deletedBy, String clientId) async {
    _isDeleting = true;
    notifyListeners();

    try {
      bool success =
          await _equipmentService.deleteEquipment(equipmentId, deletedBy);
      _isDeleting = false;
      notifyListeners();

      if (success) {
        // Recargar la lista del cliente
        loadEquipmentsByClient(clientId);
        return true;
      }
      return false;
    } catch (error) {
      _setError('Error deleting equipment: $error');
      _isDeleting = false;
      notifyListeners();
      return false;
    }
  }

  // Asignar técnico
  Future<bool> assignTechnician(
    String equipmentId,
    String technicianId,
    String technicianName,
    String assignedBy,
    String clientId,
  ) async {
    try {
      bool success = await _equipmentService.assignTechnician(
        equipmentId,
        technicianId,
        technicianName,
        assignedBy,
      );

      if (success) {
        loadEquipmentsByClient(clientId);
        return true;
      }
      return false;
    } catch (error) {
      _setError('Error assigning technician: $error');
      return false;
    }
  }

  // Actualizar estado del equipo
  Future<bool> updateEquipmentStatus(
    String equipmentId,
    String status,
    String updatedBy,
    String clientId,
  ) async {
    try {
      bool success = await _equipmentService.updateEquipmentStatus(
        equipmentId,
        status,
        updatedBy,
      );

      if (success) {
        loadEquipmentsByClient(clientId);
        return true;
      }
      return false;
    } catch (error) {
      _setError('Error updating equipment status: $error');
      return false;
    }
  }

  // Buscar equipos
  Future<void> searchEquipments(String searchTerm) async {
    if (searchTerm.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    try {
      List<Equipment> results =
          await _equipmentService.searchEquipments(searchTerm);
      _searchResults = results;
      notifyListeners();
    } catch (error) {
      _setError('Error searching equipments: $error');
    }
  }

  // Cargar estadísticas por cliente
  Future<void> loadEquipmentStatsByClient(String clientId) async {
    try {
      Map<String, dynamic> stats =
          await _equipmentService.getEquipmentStatsByClient(clientId);
      _equipmentStats = stats;
      notifyListeners();
    } catch (error) {
      _setError('Error loading equipment stats: $error');
    }
  }

  // Generar número de equipo usando tu método corregido
  Future<String> generateEquipmentNumber(String clientId) async {
    try {
      return await _equipmentService.generateEquipmentNumber(clientId);
    } catch (error) {
      _setError('Error generating equipment number: $error');
      return '${clientId.substring(0, 3).toUpperCase()}-001';
    }
  }

  // Establecer filtros de búsqueda
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSelectedStatus(String status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void setSelectedCondition(String condition) {
    _selectedCondition = condition;
    notifyListeners();
  }

  // Limpiar filtros
  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'Todos';
    _selectedStatus = 'Todos';
    _selectedCondition = 'Todos';
    notifyListeners();
  }

  // Establecer equipo seleccionado
  void setSelectedEquipment(Equipment? equipment) {
    _selectedEquipment = equipment;
    notifyListeners();
  }

  // Limpiar equipo seleccionado
  void clearSelectedEquipment() {
    _selectedEquipment = null;
    notifyListeners();
  }

  // Limpiar todas las listas
  void clearAllData() {
    _allEquipments = [];
    _clientEquipments = [];
    _technicianEquipments = [];
    _needingMaintenance = [];
    _overdueEquipments = [];
    _searchResults = [];
    _selectedEquipment = null;
    _equipmentStats = {};
    _errorMessage = null;
    clearFilters();
    notifyListeners();
  }

  // Verificar si un equipo necesita mantenimiento pronto
  bool equipmentNeedsMaintenanceSoon(Equipment equipment) {
    if (equipment.nextMaintenanceDate == null) return false;

    DateTime now = DateTime.now();
    DateTime warningDate =
        equipment.nextMaintenanceDate!.subtract(Duration(days: 3));

    return now.isAfter(warningDate) &&
        now.isBefore(equipment.nextMaintenanceDate!);
  }

  // Obtener equipos del cliente que necesitan mantenimiento pronto
  List<Equipment> get clientEquipmentsNeedingMaintenanceSoon {
    return _clientEquipments
        .where((equipment) =>
            equipment.isActive && equipmentNeedsMaintenanceSoon(equipment))
        .toList();
  }

  // Obtener equipos del cliente vencidos
  List<Equipment> get clientOverdueEquipments {
    return _clientEquipments
        .where((equipment) => equipment.isActive && equipment.isOverdue)
        .toList();
  }

  // Obtener conteo por estado para el cliente
  Map<String, int> get clientEquipmentStatusCount {
    Map<String, int> statusCount = {};

    for (Equipment equipment in _clientEquipments) {
      if (equipment.isActive) {
        statusCount[equipment.status] =
            (statusCount[equipment.status] ?? 0) + 1;
      }
    }

    return statusCount;
  }

  // Obtener conteo por condición para el cliente
  Map<String, int> get clientEquipmentConditionCount {
    Map<String, int> conditionCount = {};

    for (Equipment equipment in _clientEquipments) {
      if (equipment.isActive) {
        conditionCount[equipment.condition] =
            (conditionCount[equipment.condition] ?? 0) + 1;
      }
    }

    return conditionCount;
  }

  // Calcular eficiencia promedio del cliente
  double get clientAverageEfficiency {
    if (_clientEquipments.isEmpty) return 0.0;

    List<Equipment> activeEquipments =
        _clientEquipments.where((e) => e.isActive).toList();
    if (activeEquipments.isEmpty) return 0.0;

    double totalEfficiency =
        activeEquipments.fold(0.0, (sum, e) => sum + e.maintenanceEfficiency);
    return totalEfficiency / activeEquipments.length;
  }

  // Calcular costo total del cliente
  double get clientTotalCost {
    return _clientEquipments.fold(0.0, (sum, e) => sum + e.totalCost);
  }

  // Calcular costo total de mantenimientos preventivos del cliente
  double get clientTotalPmCost {
    return _clientEquipments.fold(0.0, (sum, e) => sum + e.totalPmCost);
  }

  // Calcular costo total de mantenimientos correctivos del cliente
  double get clientTotalCmCost {
    return _clientEquipments.fold(0.0, (sum, e) => sum + e.totalCmCost);
  }

  // Obtener próximos mantenimientos (próximos 30 días)
  List<Equipment> get upcomingMaintenances {
    DateTime now = DateTime.now();
    DateTime monthFromNow = now.add(Duration(days: 30));

    return _clientEquipments
        .where((equipment) =>
            equipment.isActive &&
            equipment.nextMaintenanceDate != null &&
            equipment.nextMaintenanceDate!.isAfter(now) &&
            equipment.nextMaintenanceDate!.isBefore(monthFromNow))
        .toList()
      ..sort(
          (a, b) => a.nextMaintenanceDate!.compareTo(b.nextMaintenanceDate!));
  }

  @override
  void dispose() {
    super.dispose();
  }

  void initialize() {
    loadAllEquipments();
    loadEquipmentsNeedingMaintenance();
    loadOverdueEquipments();
  }
}
