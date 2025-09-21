import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  // Cargar todos los equipos - MEJORADO
  void loadAllEquipments() {
    _equipmentService.getAllEquipments().listen(
      (equipments) {
        _allEquipments = equipments;
        clearError(); // Limpiar error si fue exitoso
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading equipments: $error');
        _allEquipments = []; // Limpiar lista en caso de error
        notifyListeners();
      },
    );
  }

  // Cargar equipos por cliente - MEJORADO
  void loadEquipmentsByClient(String clientId) {
    if (clientId.isEmpty) {
      _setError('Client ID cannot be empty');
      return;
    }

    _isLoading = true;
    clearError();
    notifyListeners();

    _equipmentService.getEquipmentsByClient(clientId).listen(
      (equipments) {
        _clientEquipments = equipments;
        _isLoading = false;
        clearError();
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading client equipments: $error');
        _clientEquipments = [];
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Cargar equipos activos por cliente - MEJORADO
  void loadActiveEquipmentsByClient(String clientId) {
    if (clientId.isEmpty) {
      _setError('Client ID cannot be empty');
      return;
    }

    _isLoading = true;
    clearError();
    notifyListeners();

    _equipmentService.getActiveEquipmentsByClient(clientId).listen(
      (equipments) {
        _clientEquipments = equipments;
        _isLoading = false;
        clearError();
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading active equipments: $error');
        _clientEquipments = [];
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Cargar equipos por técnico - MEJORADO
  void loadEquipmentsByTechnician(String technicianId) {
    if (technicianId.isEmpty) {
      _setError('Technician ID cannot be empty');
      return;
    }

    _isLoading = true;
    clearError();
    notifyListeners();

    _equipmentService.getEquipmentsByTechnician(technicianId).listen(
      (equipments) {
        _technicianEquipments = equipments;
        _isLoading = false;
        clearError();
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading technician equipments: $error');
        _technicianEquipments = [];
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Cargar equipos que necesitan mantenimiento - MEJORADO
  void loadEquipmentsNeedingMaintenance() {
    _equipmentService.getEquipmentsNeedingMaintenance().listen(
      (equipments) {
        _needingMaintenance = equipments;
        clearError();
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading equipments needing maintenance: $error');
        _needingMaintenance = [];
        notifyListeners();
      },
    );
  }

  // Cargar equipos vencidos - MEJORADO
  void loadOverdueEquipments() {
    _equipmentService.getOverdueEquipments().listen(
      (equipments) {
        _overdueEquipments = equipments;
        clearError();
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading overdue equipments: $error');
        _overdueEquipments = [];
        notifyListeners();
      },
    );
  }

  // Obtener equipo por ID - MEJORADO
  Future<void> loadEquipmentById(String equipmentId) async {
    if (equipmentId.isEmpty) {
      // Usar Future.microtask para evitar setState durante build
      Future.microtask(() => _setError('Equipment ID cannot be empty'));
      return;
    }

    try {
      _isLoading = true;
      // Solo notificar si no estamos en build phase
      Future.microtask(() => notifyListeners());

      Equipment? equipment =
          await _equipmentService.getEquipmentById(equipmentId);

      _selectedEquipment = equipment;

      if (equipment == null) {
        Future.microtask(() => _setError('Equipment not found'));
      } else {
        Future.microtask(() => clearError());
      }
    } catch (error) {
      Future.microtask(() => _setError('Error loading equipment: $error'));
      _selectedEquipment = null;
    } finally {
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

// Y también actualiza estos métodos para usar Future.microtask:

// Limpiar error - CORREGIDO
  void clearError() {
    _errorMessage = null;
    // Verificar si podemos notificar inmediatamente
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      notifyListeners();
    } else {
      Future.microtask(() => notifyListeners());
    }
  }

// Establecer error - CORREGIDO
  void _setError(String error) {
    _errorMessage = error;
    print('EquipmentProvider Error: $error'); // Para debugging

    // Verificar si podemos notificar inmediatamente
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      notifyListeners();
    } else {
      Future.microtask(() => notifyListeners());
    }
  }

  // Buscar equipo por RFID - MEJORADO
  Future<Equipment?> getEquipmentByRFID(String rfidTag) async {
    if (rfidTag.isEmpty) {
      _setError('RFID tag cannot be empty');
      return null;
    }

    try {
      clearError();
      Equipment? equipment =
          await _equipmentService.getEquipmentByRFID(rfidTag);

      if (equipment == null) {
        _setError('Equipment with RFID "$rfidTag" not found');
      }

      return equipment;
    } catch (error) {
      _setError('Error finding equipment by RFID: $error');
      return null;
    }
  }

  // Buscar equipo por QR Code - MEJORADO
  Future<Equipment?> getEquipmentByQRCode(String qrCode) async {
    if (qrCode.isEmpty) {
      _setError('QR code cannot be empty');
      return null;
    }

    try {
      clearError();
      Equipment? equipment =
          await _equipmentService.getEquipmentByQRCode(qrCode);

      if (equipment == null) {
        _setError('Equipment with QR code "$qrCode" not found');
      }

      return equipment;
    } catch (error) {
      _setError('Error finding equipment by QR Code: $error');
      return null;
    }
  }

  // Crear equipo - MEJORADO
  Future<bool> createEquipment(Equipment equipment) async {
    if (equipment.equipmentNumber.isEmpty || equipment.clientId.isEmpty) {
      _setError('Equipment number and client ID are required');
      return false;
    }

    _isCreating = true;
    clearError();
    notifyListeners();

    try {
      String? equipmentId = await _equipmentService.createEquipment(equipment);

      if (equipmentId != null) {
        // Recargar la lista del cliente
        loadEquipmentsByClient(equipment.clientId);
        clearError();
        return true;
      } else {
        _setError('Failed to create equipment');
        return false;
      }
    } catch (error) {
      _setError('Error creating equipment: $error');
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  // Actualizar equipo - MEJORADO
  Future<bool> updateEquipment(Equipment equipment) async {
    if (equipment.id == null || equipment.id!.isEmpty) {
      _setError('Equipment ID is required for update');
      return false;
    }

    _isUpdating = true;
    clearError();
    notifyListeners();

    try {
      bool success = await _equipmentService.updateEquipment(equipment);

      if (success) {
        // Actualizar el equipo seleccionado si es el mismo
        if (_selectedEquipment?.id == equipment.id) {
          _selectedEquipment = equipment;
        }

        // Recargar la lista del cliente
        loadEquipmentsByClient(equipment.clientId);
        clearError();
        return true;
      } else {
        _setError('Failed to update equipment');
        return false;
      }
    } catch (error) {
      _setError('Error updating equipment: $error');
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  // Eliminar equipo - MEJORADO
  Future<bool> deleteEquipment(
      String equipmentId, String deletedBy, String clientId) async {
    if (equipmentId.isEmpty || deletedBy.isEmpty || clientId.isEmpty) {
      _setError('Equipment ID, deleted by, and client ID are required');
      return false;
    }

    _isDeleting = true;
    clearError();
    notifyListeners();

    try {
      bool success =
          await _equipmentService.deleteEquipment(equipmentId, deletedBy);

      if (success) {
        // Recargar la lista del cliente
        loadEquipmentsByClient(clientId);
        clearError();
        return true;
      } else {
        _setError('Failed to delete equipment');
        return false;
      }
    } catch (error) {
      _setError('Error deleting equipment: $error');
      return false;
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  // Asignar técnico - MEJORADO
  Future<bool> assignTechnician(
    String equipmentId,
    String technicianId,
    String technicianName,
    String assignedBy,
    String clientId,
  ) async {
    if (equipmentId.isEmpty ||
        technicianId.isEmpty ||
        technicianName.isEmpty ||
        assignedBy.isEmpty ||
        clientId.isEmpty) {
      _setError('All parameters are required for technician assignment');
      return false;
    }

    try {
      clearError();
      bool success = await _equipmentService.assignTechnician(
        equipmentId,
        technicianId,
        technicianName,
        assignedBy,
      );

      if (success) {
        loadEquipmentsByClient(clientId);
        clearError();
        return true;
      } else {
        _setError('Failed to assign technician');
        return false;
      }
    } catch (error) {
      _setError('Error assigning technician: $error');
      return false;
    }
  }

  // Actualizar estado del equipo - MEJORADO
  Future<bool> updateEquipmentStatus(
    String equipmentId,
    String status,
    String updatedBy,
    String clientId,
  ) async {
    if (equipmentId.isEmpty ||
        status.isEmpty ||
        updatedBy.isEmpty ||
        clientId.isEmpty) {
      _setError('All parameters are required for status update');
      return false;
    }

    try {
      clearError();
      bool success = await _equipmentService.updateEquipmentStatus(
        equipmentId,
        status,
        updatedBy,
      );

      if (success) {
        loadEquipmentsByClient(clientId);
        clearError();
        return true;
      } else {
        _setError('Failed to update equipment status');
        return false;
      }
    } catch (error) {
      _setError('Error updating equipment status: $error');
      return false;
    }
  }

  // Buscar equipos - MEJORADO
  Future<void> searchEquipments(String searchTerm) async {
    if (searchTerm.isEmpty) {
      _searchResults = [];
      clearError();
      notifyListeners();
      return;
    }

    try {
      clearError();
      List<Equipment> results =
          await _equipmentService.searchEquipments(searchTerm);
      _searchResults = results;

      if (results.isEmpty) {
        _setError('No equipment found matching "$searchTerm"');
      } else {
        clearError();
      }

      notifyListeners();
    } catch (error) {
      _setError('Error searching equipments: $error');
      _searchResults = [];
      notifyListeners();
    }
  }

  // Cargar estadísticas por cliente - MEJORADO
  Future<void> loadEquipmentStatsByClient(String clientId) async {
    if (clientId.isEmpty) {
      _setError('Client ID cannot be empty');
      return;
    }

    try {
      clearError();
      Map<String, dynamic> stats =
          await _equipmentService.getEquipmentStatsByClient(clientId);
      _equipmentStats = stats;
      clearError();
      notifyListeners();
    } catch (error) {
      _setError('Error loading equipment stats: $error');
      _equipmentStats = {};
      notifyListeners();
    }
  }

  // Generar número de equipo - MEJORADO
  Future<String> generateEquipmentNumber(String clientId) async {
    if (clientId.isEmpty) {
      _setError('Client ID cannot be empty');
      return 'EQP-001';
    }

    try {
      clearError();
      String equipmentNumber =
          await _equipmentService.generateEquipmentNumber(clientId);
      clearError();
      return equipmentNumber;
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
    clearError();
    notifyListeners();
  }

  // Establecer equipo seleccionado
  void setSelectedEquipment(Equipment? equipment) {
    _selectedEquipment = equipment;
    clearError();
    notifyListeners();
  }

  // Limpiar equipo seleccionado
  void clearSelectedEquipment() {
    _selectedEquipment = null;
    clearError();
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

  // Método para limpiar datos corruptos - UTILITARIO TEMPORAL
  Future<void> cleanupCorruptedData() async {
    try {
      await _equipmentService.cleanupCorruptedEquipments();
      _setError('Data cleanup completed successfully');
    } catch (error) {
      _setError('Error during data cleanup: $error');
    }
  }

  // Método para recargar datos después de limpieza
  void reloadAllData(String? clientId) {
    clearAllData();
    loadAllEquipments();
    loadEquipmentsNeedingMaintenance();
    loadOverdueEquipments();

    if (clientId != null && clientId.isNotEmpty) {
      loadEquipmentsByClient(clientId);
      loadEquipmentStatsByClient(clientId);
    }
  }

  // Método de inicialización mejorado
  void initialize({String? clientId}) {
    clearError();
    loadAllEquipments();
    loadEquipmentsNeedingMaintenance();
    loadOverdueEquipments();

    if (clientId != null && clientId.isNotEmpty) {
      loadEquipmentsByClient(clientId);
      loadEquipmentStatsByClient(clientId);
    }
  }

  // Método para retry en caso de error
  void retryLastOperation({String? clientId}) {
    clearError();
    if (clientId != null && clientId.isNotEmpty) {
      loadEquipmentsByClient(clientId);
    } else {
      loadAllEquipments();
    }
  }

  @override
  void dispose() {
    clearAllData();
    super.dispose();
  }
}
