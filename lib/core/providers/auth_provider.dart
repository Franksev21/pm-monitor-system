import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  // Constructor - Escuchar cambios de autenticación
  AuthProvider() {
    _initializeAuth();
  }

  // Inicializar autenticación
  void _initializeAuth() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        // Usuario logueado - obtener datos completos
        _currentUser = await _authService.getUserData(user.uid);
      } else {
        // Usuario no logueado
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  // Verificar sesión inicial
  Future<void> initializeAuth() async {
    _setLoading(true);
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        _currentUser = await _authService.getUserData(currentUser.uid);
      }
    } catch (e) {
      _setError('Error al inicializar sesión: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final user =
          await _authService.signInWithEmailAndPassword(email, password);
      if (user != null) {
        _currentUser = user;
        _setLoading(false);
        return true;
      } else {
        _setError('Error al iniciar sesión');
        return false;
      }
    } catch (e) {
      _setError(e.toString());
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
      final user = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
      );

      if (user != null) {
        _currentUser = user;
        _setLoading(false);
        return true;
      } else {
        _setError('Error al crear cuenta');
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _currentUser = null;
    } catch (e) {
      _setError('Error al cerrar sesión: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Crear usuarios iniciales (solo para desarrollo)
  Future<void> createInitialUsers() async {
    _setLoading(true);
    try {
      await _authService.createInitialUsers();
    } catch (e) {
      _setError('Error creando usuarios iniciales: $e');
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
