import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Servicio para sincronizar clientes con usuarios
class ClientUserSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
        final existing = existingUser.docs.first;
        if (existing.data()['role'] != 'client') return false;
        await existing.reference.update({
          'clientId': clientId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('clients').doc(clientId).update({
          'userId': existing.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      // Generar contraseña temporal
      final temporaryPassword = _generateTemporaryPassword();

      // Generar ID único para el usuario
      late String userId;

      // A secondary Firebase app keeps customer account creation isolated from
      // the administrator's active Firebase Auth session.
      FirebaseApp? secondaryApp;
      try {
        secondaryApp = await Firebase.initializeApp(
          name: 'client_signup_${DateTime.now().millisecondsSinceEpoch}',
          options: Firebase.app().options,
        );
        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        final userCredential =
            await secondaryAuth.createUserWithEmailAndPassword(
          email: clientEmail,
          password: temporaryPassword,
        );
        userId = userCredential.user!.uid;
      } catch (authError) {
        debugPrint('No se pudo crear el acceso Auth del cliente: $authError');
        return false;
      } finally {
        if (secondaryApp != null) {
          try {
            await FirebaseAuth.instanceFor(app: secondaryApp).signOut();
            await secondaryApp.delete();
          } catch (cleanupError) {
            debugPrint('No se pudo cerrar la sesión secundaria: $cleanupError');
          }
        }
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

      debugPrint('Usuario creado para cliente: $clientName');

      return true;
    } catch (e) {
      debugPrint('Error creando usuario para cliente: $e');
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
