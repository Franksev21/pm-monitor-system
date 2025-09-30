import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimpleBackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crear backup manual - OPCIÓN MÁS FÁCIL
  Future<bool> createManualBackup() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ Error: Usuario no autenticado');
        return false;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final role = userDoc.data()?['role'];

      if (role != 'admin') {
        print('❌ Error: Solo administradores pueden crear backups');
        throw Exception('Permisos insuficientes');
      }

      print('🔧 Iniciando backup como admin...');

      // 1. Recopilar datos principales
      final backupData = await _collectEssentialData();

      // 2. Crear archivo JSON
      final fileName = 'backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = await _saveBackupLocally(backupData, fileName);

      // 3. Subir a Firebase Storage
      await _uploadToStorage(file, fileName);

      // 4. Guardar referencia local
      await _saveBackupReference(fileName);

      print('✅ Backup completado: $fileName');
      return true;
    } catch (e) {
      print('❌ Error en backup: $e');
      return false;
    }
  }

  /// Recopilar solo datos esenciales para reducir tamaño
  Future<Map<String, dynamic>> _collectEssentialData() async {
    final data = <String, dynamic>{};

    // Colecciones críticas
    final collections = [
      'maintenanceSchedules',
      'equipments',
      'clients',
      'users'
    ];

    for (String collection in collections) {
      print('Respaldando $collection...');
      final querySnapshot = await _firestore.collection(collection).get();

      data[collection] = querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'data': _convertFirestoreData(doc.data()),
              })
          .toList();
    }

    // Metadatos del backup
    data['metadata'] = {
      'created_at': DateTime.now().toIso8601String(),
      'version': '1.0',
      'app_version': 'PM Monitor 1.0',
      'created_by': _auth.currentUser?.email ?? 'unknown',
      'total_collections': collections.length,
      'total_documents': data.values
          .where((v) => v is List)
          .cast<List>()
          .map((list) => list.length)
          .fold(0, (a, b) => a + b),
    };

    return data;
  }

  /// Convertir datos de Firestore para que sean serializables a JSON
  Map<String, dynamic> _convertFirestoreData(Map<String, dynamic> data) {
    final converted = <String, dynamic>{};

    for (final entry in data.entries) {
      converted[entry.key] = _convertValue(entry.value);
    }

    return converted;
  }

  /// Convertir valores individuales (Timestamps, etc.)
  dynamic _convertValue(dynamic value) {
    if (value == null) {
      return null;
    } else if (value is Timestamp) {
      // Convertir Timestamp a ISO string
      return {
        '_type': 'timestamp',
        '_value': value.toDate().toIso8601String(),
      };
    } else if (value is List) {
      // Procesar listas recursivamente
      return value.map((item) => _convertValue(item)).toList();
    } else if (value is Map) {
      // Procesar mapas recursivamente
      final converted = <String, dynamic>{};
      for (final entry in value.entries) {
        converted[entry.key.toString()] = _convertValue(entry.value);
      }
      return converted;
    } else {
      // Valores primitivos (String, int, double, bool)
      return value;
    }
  }

  /// Guardar backup localmente
  Future<File> _saveBackupLocally(
      Map<String, dynamic> data, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');

    final jsonString = jsonEncode(data);
    await file.writeAsString(jsonString);

    print('📁 Archivo local guardado: ${file.path}');
    return file;
  }

  /// Subir a Firebase Storage
  Future<void> _uploadToStorage(File file, String fileName) async {
    try {
      final storageRef = _storage.ref().child('backups/$fileName');

      final metadata = SettableMetadata(
        contentType: 'application/json',
        customMetadata: {
          'createdBy': _auth.currentUser?.email ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = storageRef.putFile(file, metadata);

      // Monitorear progreso
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 Subiendo: ${progress.toStringAsFixed(1)}%');
      });

      await uploadTask.whenComplete(() {
        print('☁️ Archivo subido a Firebase Storage');
      });
    } catch (e) {
      print('❌ Error subiendo a Storage: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'No tienes permisos para subir backups. Verifica que tu usuario tenga rol de admin.');
      }
      rethrow;
    }
  }

  /// Guardar referencia del backup
  Future<void> _saveBackupReference(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final backups = prefs.getStringList('backup_files') ?? [];

    backups.add(fileName);
    // Mantener solo los últimos 5 backups
    if (backups.length > 5) {
      backups.removeAt(0);
    }

    await prefs.setStringList('backup_files', backups);
    await prefs.setString('last_backup', DateTime.now().toIso8601String());
  }
Future<List<BackupInfo>> getAvailableBackups() async {
    try {
      print('📂 Listando backups disponibles...');

      final listResult = await _storage.ref('backups/').listAll();
      print('✅ Encontrados ${listResult.items.length} archivos');

      final backups = <BackupInfo>[];

      for (final item in listResult.items) {
        try {
          print('  📄 Procesando: ${item.name}');
          final metadata = await item.getMetadata();

          backups.add(BackupInfo(
            fileName: item.name,
            createdAt: metadata.timeCreated ?? DateTime.now(),
            size: metadata.size ?? 0,
          ));
        } catch (e) {
          print('  ⚠️ Error con ${item.name}: $e');
        }
      }

      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      print('✅ Total procesados: ${backups.length}');
      return backups;
    } catch (e) {
      print('❌ Error listando backups: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Descargar backup específico
  Future<File?> downloadBackup(String fileName) async {
    try {
      final ref = _storage.ref().child('backups/$fileName');
      final directory = await getApplicationDocumentsDirectory();
      final localFile = File('${directory.path}/downloaded_$fileName');

      await ref.writeToFile(localFile);
      print('✅ Backup descargado: ${localFile.path}');
      return localFile;
    } catch (e) {
      print('Error descargando backup: $e');
      return null;
    }
  }

  /// Compartir backup como archivo
  Future<void> shareBackup(String fileName) async {
    try {
      final file = await downloadBackup(fileName);
      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Backup de PM Monitor - $fileName',
          subject: 'Backup de datos PM Monitor',
        );
      }
    } catch (e) {
      print('Error compartiendo backup: $e');
    }
  }

  /// Obtener información del último backup
  Future<String> getLastBackupInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackup = prefs.getString('last_backup');

    if (lastBackup == null) {
      return 'Nunca';
    }

    final date = DateTime.parse(lastBackup);
    final daysDiff = DateTime.now().difference(date).inDays;

    if (daysDiff == 0) {
      return 'Hoy';
    } else if (daysDiff == 1) {
      return 'Ayer';
    } else {
      return 'Hace $daysDiff días';
    }
  }

  /// Calcular tamaño total de backups
  Future<String> getBackupStorageUsage() async {
    try {
      final backups = await getAvailableBackups();
      final totalBytes =
          backups.fold<int>(0, (sum, backup) => sum + backup.size);

      if (totalBytes < 1024) {
        return '$totalBytes B';
      } else if (totalBytes < 1024 * 1024) {
        return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'No disponible';
    }
  }

  /// Restaurar backup (convertir timestamps de vuelta)
  Future<Map<String, dynamic>> parseBackupData(
      Map<String, dynamic> backupData) async {
    final restored = <String, dynamic>{};

    for (final entry in backupData.entries) {
      if (entry.key == 'metadata') {
        restored[entry.key] = entry.value;
        continue;
      }

      if (entry.value is List) {
        final list = entry.value as List;
        restored[entry.key] = list.map((item) {
          if (item is Map && item['data'] != null) {
            return {
              'id': item['id'],
              'data': _restoreFirestoreData(
                  Map<String, dynamic>.from(item['data'])),
            };
          }
          return item;
        }).toList();
      } else {
        restored[entry.key] = entry.value;
      }
    }

    return restored;
  }

  /// Restaurar datos de Firestore (convertir timestamps de vuelta)
  Map<String, dynamic> _restoreFirestoreData(Map<String, dynamic> data) {
    final restored = <String, dynamic>{};

    for (final entry in data.entries) {
      restored[entry.key] = _restoreValue(entry.value);
    }

    return restored;
  }

  /// Restaurar valores individuales
  dynamic _restoreValue(dynamic value) {
    if (value == null) {
      return null;
    } else if (value is Map && value['_type'] == 'timestamp') {
      // Convertir de vuelta a Timestamp
      final dateTime = DateTime.parse(value['_value']);
      return Timestamp.fromDate(dateTime);
    } else if (value is List) {
      // Procesar listas recursivamente
      return value.map((item) => _restoreValue(item)).toList();
    } else if (value is Map) {
      // Procesar mapas recursivamente
      final restored = <String, dynamic>{};
      for (final entry in value.entries) {
        restored[entry.key.toString()] = _restoreValue(entry.value);
      }
      return restored;
    } else {
      // Valores primitivos
      return value;
    }
  }

  /// Limpiar backups antiguos (mantener solo 5)
  Future<void> cleanupOldBackups() async {
    try {
      final backups = await getAvailableBackups();

      if (backups.length > 5) {
        // Eliminar los más antiguos
        final toDelete = backups.skip(5);

        for (final backup in toDelete) {
          final ref = _storage.ref().child('backups/${backup.fileName}');
          await ref.delete();
          print('🗑️ Backup eliminado: ${backup.fileName}');
        }
      }
    } catch (e) {
      print('Error limpiando backups: $e');
    }
  }

  /// Eliminar un backup específico
  Future<bool> deleteBackup(String fileName) async {
    try {
      final ref = _storage.ref().child('backups/$fileName');
      await ref.delete();

      // Actualizar referencias locales
      final prefs = await SharedPreferences.getInstance();
      final backups = prefs.getStringList('backup_files') ?? [];
      backups.remove(fileName);
      await prefs.setStringList('backup_files', backups);

      print('🗑️ Backup eliminado: $fileName');
      return true;
    } catch (e) {
      print('Error eliminando backup: $e');
      return false;
    }
  }
}

/// Modelo para información de backup
class BackupInfo {
  final String fileName;
  final DateTime createdAt;
  final int size;

  BackupInfo({
    required this.fileName,
    required this.createdAt,
    required this.size,
  });

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
