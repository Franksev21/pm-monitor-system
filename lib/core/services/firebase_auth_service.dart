
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Usuario actual
  User? get currentUser => _auth.currentUser;

  // Stream de cambios de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Login
  Future<UserModel?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        return await getUserData(credential.user!.uid);
      }
    } catch (e) {
      throw _handleAuthException(e);
    }
    return null;
  }

  // Registro
  Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Crear documento de usuario en Firestore
        final userData = UserModel(
          id: credential.user!.uid,
          email: email,
          name: name,
          phone: phone,
          role: role,
        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(userData.toJson());

        return userData;
      }
    } catch (e) {
      throw _handleAuthException(e);
    }
    return null;
  }

  // Obtener datos del usuario desde Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
  }

  // Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Manejo de errores
  String _handleAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No se encontró ningún usuario con este correo.';
        case 'wrong-password':
          return 'Contraseña incorrecta.';
        case 'email-already-in-use':
          return 'Este correo ya está registrado.';
        case 'weak-password':
          return 'La contraseña es muy débil.';
        case 'invalid-email':
          return 'El correo electrónico no es válido.';
        default:
          return e.message ?? 'Error de autenticación.';
      }
    }
    return 'Error desconocido: $e';
  }

  // Crear usuarios iniciales para pruebas
  Future<void> createInitialUsers() async {
    final users = [
      {
        'email': 'admin@pmmonitor.com',
        'password': '123456',
        'name': 'Administrador Principal',
        'phone': '+1-809-555-0001',
        'role': UserRole.admin,
      },
      {
        'email': 'tecnico@pmmonitor.com',
        'password': '123456',
        'name': 'Juan Técnico',
        'phone': '+1-809-555-0003',
        'role': UserRole.technician,
      },
      {
        'email': 'cliente@pmmonitor.com',
        'password': '123456',
        'name': 'Empresa Cliente',
        'phone': '+1-809-555-0004',
        'role': UserRole.client,
      },
    ];

    for (var userData in users) {
      try {
        await registerWithEmailAndPassword(
          email: userData['email'] as String,
          password: userData['password'] as String,
          name: userData['name'] as String,
          phone: userData['phone'] as String,
          role: userData['role'] as UserRole,
        );
        print('Usuario creado: ${userData['email']}');
      } catch (e) {
        print('Error creando usuario ${userData['email']}: $e');
      }
    }
  }
}
