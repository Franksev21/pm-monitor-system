import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';

class EquipmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'equipments';

  // Funciones helper para conversión segura (movidas aquí para evitar errores de static)
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  // Obtener todos los equipos
  Stream<List<Equipment>> getAllEquipments() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .toList();
      } catch (e) {
        print('Error parsing equipments: $e');
        return <Equipment>[];
      }
    });
  }

  // Obtener equipos por cliente - SIN ÍNDICE COMPUESTO
  Stream<List<Equipment>> getEquipmentsByClient(String clientId) {
    return _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .toList();
      } catch (e) {
        print('Error parsing client equipments: $e');
        return <Equipment>[];
      }
    });
  }

  // Obtener equipos activos por cliente - CORREGIDO
  Stream<List<Equipment>> getActiveEquipmentsByClient(String clientId) {
    return _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .where((equipment) => equipment.isActive)
            .toList();
      } catch (e) {
        print('Error parsing active equipments: $e');
        return <Equipment>[];
      }
    });
  }

  // Obtener equipos por técnico asignado - CORREGIDO
  Stream<List<Equipment>> getEquipmentsByTechnician(String technicianId) {
    return _firestore
        .collection(_collection)
        .where('assignedTechnicianId', isEqualTo: technicianId)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .where((equipment) => equipment.isActive)
            .toList()
          ..sort((a, b) {
            if (a.nextMaintenanceDate == null && b.nextMaintenanceDate == null)
              return 0;
            if (a.nextMaintenanceDate == null) return 1;
            if (b.nextMaintenanceDate == null) return -1;
            return a.nextMaintenanceDate!.compareTo(b.nextMaintenanceDate!);
          });
      } catch (e) {
        print('Error parsing technician equipments: $e');
        return <Equipment>[];
      }
    });
  }

  // Obtener equipos que necesitan mantenimiento - CORREGIDO
  Stream<List<Equipment>> getEquipmentsNeedingMaintenance() {
    DateTime today = DateTime.now();
    DateTime weekFromNow = today.add(Duration(days: 7));

    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .where((equipment) =>
                equipment.nextMaintenanceDate != null &&
                equipment.nextMaintenanceDate!.isBefore(weekFromNow))
            .toList()
          ..sort((a, b) =>
              a.nextMaintenanceDate!.compareTo(b.nextMaintenanceDate!));
      } catch (e) {
        print('Error parsing equipments needing maintenance: $e');
        return <Equipment>[];
      }
    });
  }

  // Obtener equipos vencidos - CORREGIDO
  Stream<List<Equipment>> getOverdueEquipments() {
    DateTime today = DateTime.now();

    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .where((equipment) =>
                equipment.nextMaintenanceDate != null &&
                equipment.nextMaintenanceDate!.isBefore(today))
            .toList()
          ..sort((a, b) =>
              a.nextMaintenanceDate!.compareTo(b.nextMaintenanceDate!));
      } catch (e) {
        print('Error parsing overdue equipments: $e');
        return <Equipment>[];
      }
    });
  }

  // Obtener equipo por ID - Con manejo de errores mejorado
  Future<Equipment?> getEquipmentById(String equipmentId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection(_collection).doc(equipmentId).get();

      if (doc.exists) {
        return Equipment.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting equipment: $e');
      return null;
    }
  }

  // Obtener equipo por RFID
  Future<Equipment?> getEquipmentByRFID(String rfidTag) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('rfidTag', isEqualTo: rfidTag)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Equipment.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting equipment by RFID: $e');
      return null;
    }
  }

  // Obtener equipo por QR Code
  Future<Equipment?> getEquipmentByQRCode(String qrCode) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Equipment.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting equipment by QR Code: $e');
      return null;
    }
  }

  // Obtener equipo por número de equipo
  Future<Equipment?> getEquipmentByNumber(String equipmentNumber) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('equipmentNumber', isEqualTo: equipmentNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Equipment.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting equipment by number: $e');
      return null;
    }
  }

  // Crear equipo - Con validación mejorada
  Future<String?> createEquipment(Equipment equipment) async {
    try {
      // Verificar que el número de equipo no exista
      Equipment? existing =
          await getEquipmentByNumber(equipment.equipmentNumber);
      if (existing != null) {
        throw Exception('Equipment number already exists');
      }

      // Verificar que el RFID no exista si se proporciona
      if (equipment.rfidTag.isNotEmpty) {
        Equipment? existingRFID = await getEquipmentByRFID(equipment.rfidTag);
        if (existingRFID != null) {
          throw Exception('RFID tag already exists');
        }
      }

      DocumentReference docRef =
          await _firestore.collection(_collection).add(equipment.toFirestore());

      return docRef.id;
    } catch (e) {
      print('Error creating equipment: $e');
      return null;
    }
  }

  // Actualizar equipo
  Future<bool> updateEquipment(Equipment equipment) async {
    try {
      if (equipment.id == null) return false;

      await _firestore
          .collection(_collection)
          .doc(equipment.id)
          .update(equipment.toFirestore());

      return true;
    } catch (e) {
      print('Error updating equipment: $e');
      return false;
    }
  }

  // Eliminar equipo (soft delete)
  Future<bool> deleteEquipment(String equipmentId, String deletedBy) async {
    try {
      await _firestore.collection(_collection).doc(equipmentId).update({
        'isActive': false,
        'status': 'Eliminado',
        'updatedAt': DateTime.now(),
        'updatedBy': deletedBy,
      });

      return true;
    } catch (e) {
      print('Error deleting equipment: $e');
      return false;
    }
  }

  // Asignar técnico a equipo
  Future<bool> assignTechnician(
    String equipmentId,
    String technicianId,
    String technicianName,
    String assignedBy,
  ) async {
    try {
      await _firestore.collection(_collection).doc(equipmentId).update({
        'assignedTechnicianId': technicianId,
        'assignedTechnicianName': technicianName,
        'updatedAt': DateTime.now(),
        'updatedBy': assignedBy,
      });

      return true;
    } catch (e) {
      print('Error assigning technician: $e');
      return false;
    }
  }

  // Actualizar próxima fecha de mantenimiento
  Future<bool> updateNextMaintenanceDate(
    String equipmentId,
    DateTime nextDate,
    String updatedBy,
  ) async {
    try {
      await _firestore.collection(_collection).doc(equipmentId).update({
        'nextMaintenanceDate': nextDate,
        'updatedAt': DateTime.now(),
        'updatedBy': updatedBy,
      });

      return true;
    } catch (e) {
      print('Error updating next maintenance date: $e');
      return false;
    }
  }

  // Actualizar estado del equipo
  Future<bool> updateEquipmentStatus(
    String equipmentId,
    String status,
    String updatedBy,
  ) async {
    try {
      await _firestore.collection(_collection).doc(equipmentId).update({
        'status': status,
        'updatedAt': DateTime.now(),
        'updatedBy': updatedBy,
      });

      return true;
    } catch (e) {
      print('Error updating equipment status: $e');
      return false;
    }
  }

  // Agregar foto al equipo
  Future<bool> addPhotoToEquipment(
    String equipmentId,
    String photoUrl,
    String updatedBy,
  ) async {
    try {
      await _firestore.collection(_collection).doc(equipmentId).update({
        'photoUrls': FieldValue.arrayUnion([photoUrl]),
        'updatedAt': DateTime.now(),
        'updatedBy': updatedBy,
      });

      return true;
    } catch (e) {
      print('Error adding photo: $e');
      return false;
    }
  }

  // Eliminar foto del equipo
  Future<bool> removePhotoFromEquipment(
    String equipmentId,
    String photoUrl,
    String updatedBy,
  ) async {
    try {
      await _firestore.collection(_collection).doc(equipmentId).update({
        'photoUrls': FieldValue.arrayRemove([photoUrl]),
        'updatedAt': DateTime.now(),
        'updatedBy': updatedBy,
      });

      return true;
    } catch (e) {
      print('Error removing photo: $e');
      return false;
    }
  }

  // Actualizar costos de mantenimiento
  Future<bool> updateMaintenanceCosts(
    String equipmentId,
    double pmCost,
    double cmCost,
    String updatedBy,
  ) async {
    try {
      await _firestore.collection(_collection).doc(equipmentId).update({
        'totalPmCost': pmCost,
        'totalCmCost': cmCost,
        'updatedAt': DateTime.now(),
        'updatedBy': updatedBy,
      });

      return true;
    } catch (e) {
      print('Error updating maintenance costs: $e');
      return false;
    }
  }

  // Incrementar contador de mantenimientos
  Future<bool> incrementMaintenanceCount(
    String equipmentId,
    String updatedBy,
  ) async {
    try {
      await _firestore.collection(_collection).doc(equipmentId).update({
        'totalMaintenances': FieldValue.increment(1),
        'lastMaintenanceDate': DateTime.now(),
        'updatedAt': DateTime.now(),
        'updatedBy': updatedBy,
      });

      return true;
    } catch (e) {
      print('Error incrementing maintenance count: $e');
      return false;
    }
  }

  // Incrementar contador de fallas
  Future<bool> incrementFailureCount(
    String equipmentId,
    String updatedBy,
  ) async {
    try {
      await _firestore.collection(_collection).doc(equipmentId).update({
        'totalFailures': FieldValue.increment(1),
        'updatedAt': DateTime.now(),
        'updatedBy': updatedBy,
      });

      return true;
    } catch (e) {
      print('Error incrementing failure count: $e');
      return false;
    }
  }

  // Actualizar temperatura actual
  Future<bool> updateCurrentTemperature(
    String equipmentId,
    double temperature,
  ) async {
    try {
      await _firestore.collection(_collection).doc(equipmentId).update({
        'currentTemperature': temperature,
        'updatedAt': DateTime.now(),
      });

      return true;
    } catch (e) {
      print('Error updating temperature: $e');
      return false;
    }
  }

  // Búsqueda de equipos por texto - SIMPLIFICADA CON MANEJO DE ERRORES
  Future<List<Equipment>> searchEquipments(String searchTerm) async {
    try {
      // Obtener todos los equipos y filtrar en memoria para evitar múltiples consultas complejas
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      String searchLower = searchTerm.toLowerCase();

      List<Equipment> equipments = [];

      for (DocumentSnapshot doc in snapshot.docs) {
        try {
          Equipment equipment = Equipment.fromFirestore(doc);

          if (equipment.name.toLowerCase().contains(searchLower) ||
              equipment.brand.toLowerCase().contains(searchLower) ||
              equipment.model.toLowerCase().contains(searchLower) ||
              equipment.equipmentNumber.toLowerCase().contains(searchLower) ||
              equipment.location.toLowerCase().contains(searchLower) ||
              equipment.branch.toLowerCase().contains(searchLower)) {
            equipments.add(equipment);
          }
        } catch (e) {
          print('Error parsing equipment in search: ${doc.id} - $e');
          continue;
        }
      }

      return equipments;
    } catch (e) {
      print('Error searching equipments: $e');
      return [];
    }
  }

  // Obtener estadísticas de equipos por cliente - CON MANEJO DE ERRORES
  Future<Map<String, dynamic>> getEquipmentStatsByClient(
      String clientId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('clientId', isEqualTo: clientId)
          .get();

      List<Equipment> equipments = [];

      for (DocumentSnapshot doc in snapshot.docs) {
        try {
          equipments.add(Equipment.fromFirestore(doc));
        } catch (e) {
          print('Error parsing equipment in stats: ${doc.id} - $e');
          continue;
        }
      }

      int total = equipments.length;
      int active = equipments.where((e) => e.isActive).length;
      int needingMaintenance =
          equipments.where((e) => e.needsMaintenance).length;
      int overdue = equipments.where((e) => e.isOverdue).length;

      double totalCost = equipments.fold(0, (sum, e) => sum + e.totalCost);
      double totalPmCost = equipments.fold(0, (sum, e) => sum + e.totalPmCost);
      double totalCmCost = equipments.fold(0, (sum, e) => sum + e.totalCmCost);

      double averageEfficiency = equipments.isEmpty
          ? 0.0
          : equipments.fold(0.0, (sum, e) => sum + e.maintenanceEfficiency) /
              equipments.length;

      return {
        'total': total,
        'active': active,
        'needingMaintenance': needingMaintenance,
        'overdue': overdue,
        'totalCost': totalCost,
        'totalPmCost': totalPmCost,
        'totalCmCost': totalCmCost,
        'averageEfficiency': averageEfficiency,
      };
    } catch (e) {
      print('Error getting equipment stats: $e');
      return {
        'total': 0,
        'active': 0,
        'needingMaintenance': 0,
        'overdue': 0,
        'totalCost': 0.0,
        'totalPmCost': 0.0,
        'totalCmCost': 0.0,
        'averageEfficiency': 0.0,
      };
    }
  }

  // Generar próximo número de equipo automáticamente - CORREGIDO
  Future<String> generateEquipmentNumber(String clientId) async {
    try {
      // Validar que el clientId tenga al menos 3 caracteres
      if (clientId.length < 3) {
        String prefix = clientId.toUpperCase().padRight(3, 'X');
        return '$prefix-001';
      }

      // Obtener todos los equipos del cliente
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('clientId', isEqualTo: clientId)
          .get();

      if (snapshot.docs.isEmpty) {
        // Primer equipo del cliente
        return '${clientId.substring(0, 3).toUpperCase()}-001';
      }

      // Encontrar el número más alto
      int maxNumber = 0;
      String prefix = '${clientId.substring(0, 3).toUpperCase()}-';

      for (DocumentSnapshot doc in snapshot.docs) {
        try {
          Equipment equipment = Equipment.fromFirestore(doc);
          String equipmentNumber = equipment.equipmentNumber;

          if (equipmentNumber.startsWith(prefix)) {
            // Extraer el número del final - CORREGIDO
            RegExp regex = RegExp(r'-(\d+)$');
            RegExpMatch? match = regex.firstMatch(equipmentNumber);

            if (match != null) {
              int number = int.parse(match.group(1)!);
              if (number > maxNumber) {
                maxNumber = number;
              }
            }
          }
        } catch (e) {
          print('Error parsing equipment number: ${doc.id} - $e');
          continue;
        }
      }

      // Generar el siguiente número
      int nextNumber = maxNumber + 1;
      return '$prefix${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error generating equipment number: $e');
      // Fallback con timestamp para evitar duplicados
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String shortTimestamp = timestamp.substring(timestamp.length - 6);
      String prefix =
          clientId.length >= 3 ? clientId.substring(0, 3).toUpperCase() : 'EQP';
      return '$prefix-$shortTimestamp';
    }
  }

  // Método para limpiar y migrar datos corruptos - CORREGIDO
  Future<void> cleanupCorruptedEquipments() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_collection).get();

      int cleaned = 0;
      int failed = 0;

      for (DocumentSnapshot doc in snapshot.docs) {
        try {
          // Intentar parsear el equipo
          Equipment.fromFirestore(doc);
        } catch (e) {
          try {
            // Si falla, intentar limpiar los datos
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            // Limpiar campos problemáticos usando las funciones helper locales
            data['capacity'] = _safeToDouble(data['capacity']);
            data['equipmentCost'] = _safeToDouble(data['equipmentCost']);
            data['totalPmCost'] = _safeToDouble(data['totalPmCost']);
            data['totalCmCost'] = _safeToDouble(data['totalCmCost']);
            data['latitude'] = _safeToDouble(data['latitude']);
            data['longitude'] = _safeToDouble(data['longitude']);
            data['lifeScale'] = _safeToInt(data['lifeScale']);
            data['frequencyDays'] = _safeToInt(data['frequencyDays']);
            data['estimatedMaintenanceHours'] =
                _safeToInt(data['estimatedMaintenanceHours']);
            data['totalMaintenances'] = _safeToInt(data['totalMaintenances']);
            data['totalFailures'] = _safeToInt(data['totalFailures']);
            data['averageResponseTime'] =
                _safeToDouble(data['averageResponseTime']);
            data['maintenanceEfficiency'] =
                _safeToDouble(data['maintenanceEfficiency']);
            data['minTemperature'] = _safeToDouble(data['minTemperature']);
            data['maxTemperature'] = _safeToDouble(data['maxTemperature']);
            data['currentTemperature'] =
                _safeToDouble(data['currentTemperature']);

            // Actualizar el documento
            await doc.reference.update(data);
            cleaned++;
            print('Cleaned equipment: ${doc.id}');
          } catch (cleanError) {
            failed++;
            print('Failed to clean equipment: ${doc.id} - $cleanError');
          }
        }
      }

      print('Cleanup completed: $cleaned cleaned, $failed failed');
    } catch (e) {
      print('Error in cleanup process: $e');
    }
  }
}
