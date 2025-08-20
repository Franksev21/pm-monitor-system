import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';

class EquipmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'equipments';

  // Obtener todos los equipos
  Stream<List<Equipment>> getAllEquipments() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .toList());
  }

  // Obtener equipos por cliente - SIN ÍNDICE COMPUESTO
  Stream<List<Equipment>> getEquipmentsByClient(String clientId) {
    return _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .toList());
  }

  // Obtener equipos activos por cliente - SIN ÍNDICE COMPUESTO
  Stream<List<Equipment>> getActiveEquipmentsByClient(String clientId) {
    return _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .toList());
  }

  // Obtener equipos por técnico asignado
  Stream<List<Equipment>> getEquipmentsByTechnician(String technicianId) {
    return _firestore
        .collection(_collection)
        .where('assignedTechnicianId', isEqualTo: technicianId)
        .where('isActive', isEqualTo: true)
        .orderBy('nextMaintenanceDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .toList());
  }

  // Obtener equipos que necesitan mantenimiento
  Stream<List<Equipment>> getEquipmentsNeedingMaintenance() {
    DateTime today = DateTime.now();
    DateTime weekFromNow = today.add(Duration(days: 7));
    
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('nextMaintenanceDate', isLessThanOrEqualTo: weekFromNow)
        .orderBy('nextMaintenanceDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .toList());
  }

  // Obtener equipos vencidos
  Stream<List<Equipment>> getOverdueEquipments() {
    DateTime today = DateTime.now();
    
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('nextMaintenanceDate', isLessThan: today)
        .orderBy('nextMaintenanceDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .toList());
  }

  // Obtener equipo por ID
  Future<Equipment?> getEquipmentById(String equipmentId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_collection)
          .doc(equipmentId)
          .get();
      
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

  // Crear equipo
  Future<String?> createEquipment(Equipment equipment) async {
    try {
      // Verificar que el número de equipo no exista
      Equipment? existing = await getEquipmentByNumber(equipment.equipmentNumber);
      if (existing != null) {
        throw Exception('Equipment number already exists');
      }

      // Verificar que el RFID no exista
      Equipment? existingRFID = await getEquipmentByRFID(equipment.rfidTag);
      if (existingRFID != null) {
        throw Exception('RFID tag already exists');
      }

      DocumentReference docRef = await _firestore
          .collection(_collection)
          .add(equipment.toFirestore());
      
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
      await _firestore
          .collection(_collection)
          .doc(equipmentId)
          .update({
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
      await _firestore
          .collection(_collection)
          .doc(equipmentId)
          .update({
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
      await _firestore
          .collection(_collection)
          .doc(equipmentId)
          .update({
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
      await _firestore
          .collection(_collection)
          .doc(equipmentId)
          .update({
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
      await _firestore
          .collection(_collection)
          .doc(equipmentId)
          .update({
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
      await _firestore
          .collection(_collection)
          .doc(equipmentId)
          .update({
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
      await _firestore
          .collection(_collection)
          .doc(equipmentId)
          .update({
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
      await _firestore
          .collection(_collection)
          .doc(equipmentId)
          .update({
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
      await _firestore
          .collection(_collection)
          .doc(equipmentId)
          .update({
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
      await _firestore
          .collection(_collection)
          .doc(equipmentId)
          .update({
        'currentTemperature': temperature,
        'updatedAt': DateTime.now(),
      });
      
      return true;
    } catch (e) {
      print('Error updating temperature: $e');
      return false;
    }
  }

  // Búsqueda de equipos por texto
  Future<List<Equipment>> searchEquipments(String searchTerm) async {
    try {
      String searchLower = searchTerm.toLowerCase();
      
      // Buscar por diferentes campos
      List<Future<QuerySnapshot>> futures = [
        _firestore
            .collection(_collection)
            .where('name', isGreaterThanOrEqualTo: searchLower)
            .where('name', isLessThan: searchLower + 'z')
            .get(),
        _firestore
            .collection(_collection)
            .where('brand', isGreaterThanOrEqualTo: searchLower)
            .where('brand', isLessThan: searchLower + 'z')
            .get(),
        _firestore
            .collection(_collection)
            .where('model', isGreaterThanOrEqualTo: searchLower)
            .where('model', isLessThan: searchLower + 'z')
            .get(),
        _firestore
            .collection(_collection)
            .where('equipmentNumber', isGreaterThanOrEqualTo: searchLower)
            .where('equipmentNumber', isLessThan: searchLower + 'z')
            .get(),
      ];

      List<QuerySnapshot> results = await Future.wait(futures);
      Set<String> equipmentIds = {};
      List<Equipment> equipments = [];

      for (QuerySnapshot snapshot in results) {
        for (DocumentSnapshot doc in snapshot.docs) {
          if (!equipmentIds.contains(doc.id)) {
            equipmentIds.add(doc.id);
            equipments.add(Equipment.fromFirestore(doc));
          }
        }
      }

      return equipments;
    } catch (e) {
      print('Error searching equipments: $e');
      return [];
    }
  }

  // Obtener estadísticas de equipos por cliente
  Future<Map<String, dynamic>> getEquipmentStatsByClient(String clientId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('clientId', isEqualTo: clientId)
          .get();

      List<Equipment> equipments = snapshot.docs
          .map((doc) => Equipment.fromFirestore(doc))
          .toList();

      int total = equipments.length;
      int active = equipments.where((e) => e.isActive).length;
      int needingMaintenance = equipments.where((e) => e.needsMaintenance).length;
      int overdue = equipments.where((e) => e.isOverdue).length;
      
      double totalCost = equipments.fold(0, (sum, e) => sum + e.totalCost);
      double totalPmCost = equipments.fold(0, (sum, e) => sum + e.totalPmCost);
      double totalCmCost = equipments.fold(0, (sum, e) => sum + e.totalCmCost);
      
      double averageEfficiency = equipments.isEmpty 
          ? 0.0 
          : equipments.fold(0.0, (sum, e) => sum + e.maintenanceEfficiency) / equipments.length;

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
      return {};
    }
  }

  // Generar próximo número de equipo automáticamente - SIN ÍNDICE
  Future<String> generateEquipmentNumber(String clientId) async {
  try {
    // Validar que el clientId tenga al menos 3 caracteres
    if (clientId.length < 3) {
      // Si es muy corto, usar el ID completo o rellenar
      String prefix = clientId.toUpperCase().padRight(3, 'X');
      return '$prefix-001';
    }

    // Obtener todos los equipos del cliente (sin orderBy para evitar índice)
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
      Equipment equipment = Equipment.fromFirestore(doc);
      String equipmentNumber = equipment.equipmentNumber;
      
      if (equipmentNumber.startsWith(prefix)) {
        // Extraer el número del final
        // Expresión regular corregida: busca un guión seguido de dígitos al final
        RegExp regex = RegExp(r'-(\d+)$');
        Match? match = regex.firstMatch(equipmentNumber);
        
        if (match != null) {
          int number = int.parse(match.group(1)!);
          if (number > maxNumber) {
            maxNumber = number;
          }
        }
      }
    }
    
    // Generar el siguiente número
    int nextNumber = maxNumber + 1;
    return '$prefix${nextNumber.toString().padLeft(3, '0')}';
    
  } catch (e) {
    print('Error generating equipment number: $e');
    // Fallback con timestamp para evitar duplicados
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    // Tomar los últimos 6 dígitos del timestamp para mantenerlo corto
    String shortTimestamp = timestamp.substring(timestamp.length - 6);
    
    // Si el clientId es muy corto, usar un prefijo genérico
    String prefix = clientId.length >= 3 
        ? clientId.substring(0, 3).toUpperCase() 
        : 'EQP';
    
    return '$prefix-$shortTimestamp';
  }
}}