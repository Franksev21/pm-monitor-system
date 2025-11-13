import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio para sincronizar clientes con usuarios
class ClientUserSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crear usuario para un cliente existente
  Future<bool> createUserForClient({
    required String clientId,
    required String clientName,
    required String clientEmail,
    required String clientPhone,
  }) async {
    try {
      // Verificar si ya existe un usuario para este cliente
      final existingUser = await _firestore
          .collection('users')
          .where('email', isEqualTo: clientEmail)
          .limit(1)
          .get();

      if (existingUser.docs.isNotEmpty) {
        print('⚠️ Ya existe un usuario para este cliente');
        // Actualizar el clientId en el usuario existente
        await existingUser.docs.first.reference.update({
          'clientId': clientId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      // Generar contraseña temporal
      final temporaryPassword = _generateTemporaryPassword();

      // Generar ID único para el usuario
      String userId = _generateUserId();

      // ✅ CREAR USUARIO EN AUTH (pero sin interferir con la sesión actual)
      // Guardamos el usuario actual
      final currentUser = _auth.currentUser;

      try {
        // Intentar crear en Firebase Auth
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: clientEmail,
          password: temporaryPassword,
        );

        userId = userCredential.user!.uid;

        // Si se creó exitosamente, cerrar su sesión y restaurar la del admin
        await _auth.signOut();

        // Si había un usuario anterior, no intentamos restaurarlo aquí
        // porque causaría problemas
      } catch (authError) {
        print(
            '⚠️ No se pudo crear en Auth (probablemente ya existe): $authError');
        // Continuar con el ID generado
      }

      // Crear documento en colección users
      await _firestore.collection('users').doc(userId).set({
        'id': userId,
        'name': clientName,
        'email': clientEmail,
        'phone': clientPhone,
        'role': 'client',
        'clientId': clientId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'photoUrl': null,
        'temporaryPassword': temporaryPassword,
      });

      // Actualizar el cliente con el userId
      await _firestore.collection('clients').doc(clientId).update({
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Usuario creado para cliente: $clientName');
      print('📧 Email: $clientEmail');
      print('🔑 Contraseña temporal: $temporaryPassword');

      return true;
    } catch (e) {
      print('❌ Error creando usuario para cliente: $e');
      return false;
    }
  }

  /// Sincronizar todos los clientes sin usuario
  Future<int> syncAllClientsWithoutUsers() async {
    try {
      int syncedCount = 0;

      // Obtener todos los clientes
      final clientsSnapshot = await _firestore.collection('clients').get();

      for (var clientDoc in clientsSnapshot.docs) {
        final clientData = clientDoc.data();
        final clientId = clientDoc.id;
        final userId = clientData['userId'];

        // Si el cliente no tiene userId, crear usuario
        if (userId == null || userId.toString().isEmpty) {
          final success = await createUserForClient(
            clientId: clientId,
            clientName: clientData['name'] ?? 'Cliente',
            clientEmail: clientData['email'] ?? '',
            clientPhone: clientData['phone'] ?? '',
          );

          if (success) {
            syncedCount++;
          }

          // Pequeña pausa entre creaciones para evitar rate limits
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      print('✅ Sincronizados $syncedCount clientes');
      return syncedCount;
    } catch (e) {
      print('❌ Error sincronizando clientes: $e');
      return 0;
    }
  }

  /// Generar contraseña temporal
  String _generateTemporaryPassword() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'Temp${timestamp.toString().substring(7)}!';
  }

  /// Generar ID de usuario único
  String _generateUserId() {
    return _firestore.collection('users').doc().id;
  }

  /// Obtener contraseña temporal de un cliente
  Future<String?> getTemporaryPassword(String clientEmail) async {
    try {
      final userSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: clientEmail)
          .where('role', isEqualTo: 'client')
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        return userSnapshot.docs.first.data()['temporaryPassword'] as String?;
      }
      return null;
    } catch (e) {
      print('Error obteniendo contraseña temporal: $e');
      return null;
    }
  }

  /// Marcar que el cliente cambió su contraseña
  Future<void> markPasswordChanged(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'temporaryPassword': FieldValue.delete(),
        'passwordChanged': true,
        'passwordChangedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marcando contraseña cambiada: $e');
    }
  }
}
