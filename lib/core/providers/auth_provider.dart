import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  // Usuarios mock para pruebas (luego reemplazaremos con Firebase)
  final List<Map<String, dynamic>> _mockUsers = [
    {
      'email': 'admin@pmmonitor.com',
      'password': '123456',
      'user': UserModel(
        id: '1',
        email: 'admin@pmmonitor.com',
        name: 'Administrador Principal',
        phone: '+1-809-555-0001',
        role: UserRole.admin,
      ),
    },
    {
      'email': 'supervisor@pmmonitor.com',
      'password': '123456',
      'user': UserModel(
        id: '2',
        email: 'supervisor@pmmonitor.com',
        name: 'Carlos Supervisor',
        phone: '+1-809-555-0002',
        role: UserRole.supervisor,
      ),
    },
    {
      'email': 'tecnico@pmmonitor.com',
      'password': '123456',
      'user': UserModel(
        id: '3',
        email: 'tecnico@pmmonitor.com',
        name: 'Juan Técnico',
        phone: '+1-809-555-0003',
        role: UserRole.technician,
      ),
    },
    {
      'email': 'cliente@pmmonitor.com',
      'password': '123456',
      'user': UserModel(
        id: '4',
        email: 'cliente@pmmonitor.com',
        name: 'Empresa Cliente',
        phone: '+1-809-555-0004',
        role: UserRole.client,
      ),
    },
  ];

  // Inicializar - verificar si hay sesión guardada
  Future<void> initializeAuth() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      if (userJson != null) {
        // Simular delay de red
        await Future.delayed(const Duration(seconds: 1));

        // Aquí normalmente verificaríamos el token con el servidor
        final userData = _mockUsers.firstWhere(
          (u) => u['user'].email == userJson,
          orElse: () => {},
        );

        if (userData.isNotEmpty) {
          _currentUser = userData['user'] as UserModel;
        }
      }
    } catch (e) {
      _setError('Error al inicializar sesión');
    } finally {
      _setLoading(false);
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Simular delay de red
      await Future.delayed(const Duration(seconds: 2));

      // Buscar usuario en datos mock
      final userData = _mockUsers.firstWhere(
        (user) => user['email'] == email && user['password'] == password,
        orElse: () => {},
      );

      if (userData.isEmpty) {
        _setError('Credenciales incorrectas');
        return false;
      }

      _currentUser = userData['user'] as UserModel;

      // Guardar sesión
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', email);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al iniciar sesión: $e');
      return false;
    }
  }

  // Register
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Simular delay de red
      await Future.delayed(const Duration(seconds: 2));

      // Verificar si el email ya existe
      final existingUser = _mockUsers.any((user) => user['email'] == email);
      if (existingUser) {
        _setError('El email ya está registrado');
        return false;
      }

      // Crear nuevo usuario
      final newUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        email: email,
        name: name,
        phone: phone,
        role: role,
      );

      // Agregar a la lista mock (en producción sería guardado en Firebase)
      _mockUsers.add({
        'email': email,
        'password': password,
        'user': newUser,
      });

      _currentUser = newUser;

      // Guardar sesión
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', email);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al registrar usuario: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
      _currentUser = null;
    } catch (e) {
      _setError('Error al cerrar sesión');
    } finally {
      _setLoading(false);
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
}
