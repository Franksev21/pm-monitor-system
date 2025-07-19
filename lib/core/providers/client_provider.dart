import 'package:flutter/material.dart';
import '../models/client_model.dart';
import '../services/client_service.dart';

class ClientProvider extends ChangeNotifier {
  final ClientService _clientService = ClientService();

  List<ClientModel> _clients = [];
  ClientModel? _selectedClient;
  bool _isLoading = false;
  String? _errorMessage;

  // Filtros
  String _searchQuery = '';
  ClientStatus? _statusFilter;
  ClientType? _typeFilter;

  // Getters
  List<ClientModel> get clients => _filteredClients;
  ClientModel? get selectedClient => _selectedClient;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  ClientStatus? get statusFilter => _statusFilter;
  ClientType? get typeFilter => _typeFilter;

  // Lista filtrada
  List<ClientModel> get _filteredClients {
    var filtered = List<ClientModel>.from(_clients);

    // Filtro por búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((client) {
        return client.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            client.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            client.phone.contains(_searchQuery);
      }).toList();
    }

    // Filtro por estado
    if (_statusFilter != null) {
      filtered =
          filtered.where((client) => client.status == _statusFilter).toList();
    }

    // Filtro por tipo
    if (_typeFilter != null) {
      filtered =
          filtered.where((client) => client.type == _typeFilter).toList();
    }

    return filtered;
  }

  // Estadísticas
  int get totalClients => _clients.length;
  int get activeClients =>
      _clients.where((c) => c.status == ClientStatus.active).length;
  int get inactiveClients =>
      _clients.where((c) => c.status == ClientStatus.inactive).length;
  int get prospectClients =>
      _clients.where((c) => c.status == ClientStatus.prospect).length;

  Map<ClientType, int> get clientsByType {
    final Map<ClientType, int> result = {};
    for (var type in ClientType.values) {
      result[type] = _clients.where((c) => c.type == type).length;
    }
    return result;
  }

  // Inicializar y cargar clientes
  void initialize() {
    loadClients();
  }

  // Cargar clientes desde Firebase
  void loadClients() {
    _setLoading(true);
    _clientService.getClients().listen(
      (clients) {
        _clients = clients;
        _setLoading(false);
        notifyListeners();
      },
      onError: (error) {
        _setError('Error al cargar clientes: $error');
      },
    );
  }

  // Crear cliente
  Future<bool> createClient(ClientModel client) async {
    _setLoading(true);
    try {
      await _clientService.createClient(client);
      _clearError();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Actualizar cliente
  Future<bool> updateClient(ClientModel client) async {
    _setLoading(true);
    try {
      await _clientService.updateClient(client);
      _clearError();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Eliminar cliente
  Future<bool> deleteClient(String clientId) async {
    _setLoading(true);
    try {
      await _clientService.deleteClient(clientId);
      _clearError();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Seleccionar cliente
  void selectClient(ClientModel client) {
    _selectedClient = client;
    notifyListeners();
  }

  // Limpiar selección
  void clearSelection() {
    _selectedClient = null;
    notifyListeners();
  }

  // Obtener cliente por ID
  Future<ClientModel?> getClientById(String id) async {
    try {
      return await _clientService.getClientById(id);
    } catch (e) {
      _setError('Error al obtener cliente: $e');
      return null;
    }
  }

  // Filtros y búsqueda
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(ClientStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setTypeFilter(ClientType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _statusFilter = null;
    _typeFilter = null;
    notifyListeners();
  }

  // Crear clientes de prueba
  Future<bool> createMockClients(String createdBy) async {
    _setLoading(true);
    try {
      await _clientService.createMockClients(createdBy);
      _clearError();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al crear clientes de prueba: $e');
      return false;
    }
  }

  // Métodos privados
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Validaciones
  String? validateClientName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'El nombre es requerido';
    }
    if (name.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    return null;
  }

  String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'El email es requerido';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Ingresa un email válido';
    }
    return null;
  }

  String? validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return 'El teléfono es requerido';
    }
    if (phone.trim().length < 10) {
      return 'Ingresa un teléfono válido';
    }
    return null;
  }

  String? validateTaxId(String? taxId) {
    if (taxId == null || taxId.trim().isEmpty) {
      return 'El RNC/Cédula es requerido';
    }
    return null;
  }
}
