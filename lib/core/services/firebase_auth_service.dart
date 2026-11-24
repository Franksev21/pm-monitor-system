import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../exceptions/auth_exception.dart'; // Asegúrate de importar AuthException

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Usuario actual
  User? get currentUser => _auth.currentUser;

  // Stream de cambios de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Login con manejo mejorado de errores
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // Validación previa
      if (email.isEmpty || password.isEmpty) {
        throw AuthException(
          code: 'empty-fields',
          message: 'Por favor completa todos los campos',
        );
      }

      // Intentar login
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        // Obtener datos del usuario desde Firestore
        final userData = await getUserData(credential.user!.uid);

        if (userData == null) {
          throw AuthException(
            code: 'user-not-found-in-database',
            message: 'Usuario no encontrado en la base de datos',
          );
        }

        // Bloquear cuentas desactivadas (soft delete)
        if (!userData.isActive) {
          await _auth.signOut();
          throw AuthException(
            code: 'user-disabled',
            message: _getSpanishErrorMessage('user-disabled'),
          );
        }

        // Actualizar último login
        await _updateLastLogin(credential.user!.uid);

        return userData;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: _getSpanishErrorMessage(e.code),
      );
    } on AuthException {
      rethrow; // Re-lanzar AuthException personalizadas
    } catch (e) {
      throw AuthException(
        code: 'unknown',
        message: 'Error desconocido: ${e.toString()}',
      );
    }
  }

  // Registro con validaciones mejoradas
  Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    try {
      // Validaciones
      _validateRegistrationData(email, password, name, phone);

      // Crear cuenta en Firebase Auth
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        // Enviar email de verificación (opcional)
        try {
          await credential.user!.sendEmailVerification();
        } catch (e) {
          print('Error sending verification email: $e');
        }

        // Crear documento en Firestore
        final user = UserModel(
          id: credential.user!.uid,
          email: email.trim(),
          name: name.trim(),
          phone: phone.trim(),
          // El auto-registro nunca otorga privilegios: los roles de personal
          // se asignan desde AdminAddUserScreen (y lo exige firestore.rules).
          role: UserRole.client,
          createdAt: DateTime.now(),
          isActive: true,
          emailVerified: false,
          profileImageUrl: null,
          lastLogin: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(user.toJson());

        return user;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: _getSpanishErrorMessage(e.code),
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        code: 'unknown',
        message: 'Error al crear cuenta: ${e.toString()}',
      );
    }
  }

  // Obtener datos del usuario desde Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      if (data == null) {
        return null;
      }

      return UserModel.fromJson(data);
    } catch (e) {
      print('Error getting user data: $e');
      throw AuthException(
        code: 'database-error',
        message: 'Error al obtener datos del usuario',
      );
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException(
        code: 'signout-error',
        message: 'Error al cerrar sesión',
      );
    }
  }

  // Restablecer contraseña
  Future<void> resetPassword(String email) async {
    try {
      if (email.isEmpty) {
        throw AuthException(
          code: 'empty-email',
          message: 'Por favor ingresa tu correo electrónico',
        );
      }

      // Validar formato de email
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw AuthException(
          code: 'invalid-email-format',
          message: 'El formato del correo electrónico no es válido',
        );
      }

      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: _getSpanishErrorMessage(e.code),
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        code: 'unknown',
        message: 'Error al enviar correo de recuperación',
      );
    }
  }

  // Actualizar último login
  Future<void> _updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLogin': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // No lanzar error, solo registrar
      print('Error updating last login: $e');
    }
  }

  // Validaciones de registro
  void _validateRegistrationData(
    String email,
    String password,
    String name,
    String phone,
  ) {
    // Validar campos vacíos
    if (email.isEmpty || password.isEmpty || name.isEmpty || phone.isEmpty) {
      throw AuthException(
        code: 'empty-fields',
        message: 'Todos los campos son requeridos',
      );
    }

    // Validar email
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      throw AuthException(
        code: 'invalid-email-format',
        message: 'El formato del correo electrónico no es válido',
      );
    }

    // Validar contraseña - mínimo 6 caracteres para compatibilidad con tu código actual
    if (password.length < 6) {
      throw AuthException(
        code: 'weak-password',
        message: 'La contraseña debe tener al menos 6 caracteres',
      );
    }

    // Opcional: Validar contraseña fuerte (puedes comentar esto si prefieres contraseñas simples para desarrollo)
    // if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
    //   throw AuthException(
    //     code: 'weak-password-pattern',
    //     message: 'La contraseña debe contener mayúsculas, minúsculas y números',
    //   );
    // }

    // Validar nombre
    if (name.trim().length < 2) {
      throw AuthException(
        code: 'invalid-name',
        message: 'El nombre debe tener al menos 2 caracteres',
      );
    }

    // Validar teléfono (formato flexible)
    if (phone.replaceAll(RegExp(r'[^\d]'), '').length < 7) {
      throw AuthException(
        code: 'invalid-phone',
        message: 'El número de teléfono debe tener al menos 7 dígitos',
      );
    }
  }

  // Mensajes de error en español
  String _getSpanishErrorMessage(String code) {
    switch (code) {
      // Errores de login
      case 'user-not-found':
        return '❌ No existe una cuenta con este correo electrónico';
      case 'wrong-password':
        return '🔒 La contraseña es incorrecta';
      case 'invalid-email':
        return '📧 El correo electrónico no es válido';
      case 'user-disabled':
        return '🚫 Esta cuenta ha sido deshabilitada';
      case 'too-many-requests':
        return '⏳ Demasiados intentos fallidos. Intenta más tarde';

      // Errores de registro
      case 'email-already-in-use':
        return '📧 Este correo ya está registrado';
      case 'weak-password':
        return '🔒 La contraseña es muy débil (mínimo 6 caracteres)';
      case 'operation-not-allowed':
        return '🚫 Operación no permitida';

      // Errores de red
      case 'network-request-failed':
        return '🌐 Error de conexión. Verifica tu internet';

      // Errores generales de credenciales
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return '❌ Correo o contraseña incorrectos';

      // Error por defecto
      default:
        return '❓ Error de autenticación. Por favor, intenta de nuevo.';
    }
  }

  // Verificar si es el primer uso (no hay usuarios admin)
  Future<bool> isFirstTimeSetup() async {
    try {
      final adminUsers = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      return adminUsers.docs.isEmpty;
    } catch (e) {
      print('Error checking first time setup: $e');
      return false;
    }
  }

  // Obtener todos los usuarios (solo para admin)
  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw AuthException(
        code: 'fetch-users-error',
        message: 'Error al obtener usuarios',
      );
    }
  }

  // Actualizar información del usuario
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      throw AuthException(
        code: 'update-user-error',
        message: 'Error al actualizar usuario',
      );
    }
  }

  // Eliminar usuario (soft delete)
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': false,
        'deletedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw AuthException(
        code: 'delete-user-error',
        message: 'Error al eliminar usuario',
      );
    }
  }
}
