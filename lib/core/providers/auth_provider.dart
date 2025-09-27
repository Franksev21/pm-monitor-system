import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';
import '../exceptions/auth_exception.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = {};

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, String> get fieldErrors => _fieldErrors;
  bool get isAuthenticated => _currentUser != null;

  // Constructor
  AuthProvider() {
    _initializeAuth();
  }

  // Inicializar autenticación
  void _initializeAuth() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        try {
          _currentUser = await _authService.getUserData(user.uid);
        } catch (e) {
          print('Error getting user data: $e');
          _currentUser = null;
        }
      } else {
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

  // Login mejorado con manejo de errores específicos
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearErrors();

    try {
      // Validaciones básicas
      if (email.isEmpty) {
        _setFieldError('email', 'El correo es requerido');
        _setLoading(false);
        return false;
      }

      if (password.isEmpty) {
        _setFieldError('password', 'La contraseña es requerida');
        _setLoading(false);
        return false;
      }

      final user = await _authService.signInWithEmailAndPassword(
        email.trim(),
        password,
      );

      if (user != null) {
        _currentUser = user;
        _setLoading(false);
        return true;
      } else {
        _setError('Error al iniciar sesión');
        return false;
      }
    } on AuthException catch (e) {
      // Manejar errores específicos de autenticación
      print('AuthException: ${e.code} - ${e.message}');

      // Determinar qué campo tiene el error
      if (e.code == 'user-not-found') {
        _setFieldError('email', e.message);
      } else if (e.code == 'invalid-email') {
        _setFieldError('email', e.message);
      } else if (e.code == 'wrong-password') {
        _setFieldError('password', e.message);
      } else if (e.code == 'INVALID_LOGIN_CREDENTIALS' ||
          e.code == 'invalid-credential') {
        // Cuando las credenciales son inválidas (error genérico)
        // Mostrar como error general en lugar de específico de campo
        _setError(
            '❌ Correo o contraseña incorrectos. Por favor verifica tus credenciales.');
      } else if (e.code == 'too-many-requests') {
        _setError(e.message);
      } else if (e.code == 'user-disabled') {
        _setError(e.message);
      } else {
        // Error general
        _setError(e.message);
      }
      return false;
    } on FirebaseAuthException catch (e) {
      // Manejar errores de Firebase directamente
      print('FirebaseAuthException: ${e.code} - ${e.message}');

      String errorMessage = _getSpanishErrorMessage(e.code);

      // Para Firebase, manejar los códigos de error específicos
      switch (e.code) {
        case 'user-not-found':
          _setFieldError('email', errorMessage);
          break;
        case 'invalid-email':
          _setFieldError('email', errorMessage);
          break;
        case 'wrong-password':
          _setFieldError('password', errorMessage);
          break;
        case 'INVALID_LOGIN_CREDENTIALS':
        case 'invalid-credential':
          // Error genérico de credenciales inválidas
          // No especifica si es email o contraseña
          _setError(errorMessage);
          break;
        case 'too-many-requests':
        case 'user-disabled':
        case 'network-request-failed':
          _setError(errorMessage);
          break;
        default:
          _setError(errorMessage);
      }
      return false;
    } catch (e) {
      print('General error: $e');
      _setError('Error inesperado: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Register mejorado
  Future<bool> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    _setLoading(true);
    _clearErrors();

    try {
      // Validar que las contraseñas coincidan
      if (password != confirmPassword) {
        _setFieldError('confirmPassword', 'Las contraseñas no coinciden');
        _setLoading(false);
        return false;
      }

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
        _setError('Error al crear la cuenta');
        return false;
      }
    } on AuthException catch (e) {
      // Mapear errores a campos específicos
      if (e.code.contains('email')) {
        _setFieldError('email', e.message);
      } else if (e.code.contains('password')) {
        _setFieldError('password', e.message);
      } else if (e.code.contains('name')) {
        _setFieldError('name', e.message);
      } else if (e.code.contains('phone')) {
        _setFieldError('phone', e.message);
      } else {
        _setError(e.message);
      }
      return false;
    } catch (e) {
      _setError('Error inesperado: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Restablecer contraseña
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearErrors();

    try {
      await _authService.resetPassword(email);
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      if (e.code.contains('email') || e.code == 'user-not-found') {
        _setFieldError('email', e.message);
      } else {
        _setError(e.message);
      }
      return false;
    } catch (e) {
      _setError('Error al enviar correo de recuperación');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Logout
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _currentUser = null;
      _clearErrors();
    } catch (e) {
      _setError('Error al cerrar sesión');
    } finally {
      _setLoading(false);
    }
  }

  // Mensajes de error en español mejorados
  String _getSpanishErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return '❌ No existe una cuenta con este correo electrónico';
      case 'wrong-password':
        return '🔒 La contraseña es incorrecta';
      case 'invalid-email':
        return '📧 El formato del correo electrónico no es válido';
      case 'user-disabled':
        return '🚫 Esta cuenta ha sido deshabilitada. Contacta al administrador.';
      case 'too-many-requests':
        return '⏳ Demasiados intentos fallidos. Por favor, intenta más tarde.';
      case 'email-already-in-use':
        return '📧 Este correo electrónico ya está registrado';
      case 'weak-password':
        return '🔒 La contraseña debe tener al menos 6 caracteres';
      case 'network-request-failed':
        return '🌐 Error de conexión. Por favor, verifica tu internet';
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        // Este es el error genérico cuando las credenciales son incorrectas
        return '❌ Las credenciales ingresadas son incorrectas. Verifica tu correo y contraseña.';
      case 'operation-not-allowed':
        return '🚫 Esta operación no está permitida';
      case 'invalid-verification-code':
        return '❌ El código de verificación es inválido';
      case 'invalid-verification-id':
        return '❌ El ID de verificación es inválido';
      default:
        // Error genérico con más detalle
        return '❓ Error de autenticación: $code. Por favor, intenta nuevamente.';
    }
  }

  // Métodos privados
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _setFieldError(String field, String error) {
    _fieldErrors[field] = error;
    notifyListeners();
  }

  void _clearErrors() {
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();
  }

  // Obtener error para un campo específico
  String? getFieldError(String field) {
    return _fieldErrors[field];
  }

  // Limpiar error de un campo específico
  void clearFieldError(String field) {
    _fieldErrors.remove(field);
    notifyListeners();
  }

  // Limpiar error general
  void clearGeneralError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Verificar si hay algún error
  bool get hasErrors => _errorMessage != null || _fieldErrors.isNotEmpty;

  // Obtener todos los errores como string
  String getAllErrorsAsString() {
    final List<String> errors = [];

    if (_errorMessage != null && _errorMessage!.isNotEmpty) {
      errors.add(_errorMessage!);
    }

    _fieldErrors.forEach((field, error) {
      errors.add(error);
    });

    return errors.join('\n');
  }
}
