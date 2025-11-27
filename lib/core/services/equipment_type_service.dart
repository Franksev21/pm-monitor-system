// lib/core/services/equipment_type_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/core/models/equipment_type_model.dart';



class EquipmentTypeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'equipmentTypes';

  // ========== INICIALIZACIÓN ==========

  /// Migra los tipos estáticos a Firebase (solo una vez)
  Future<void> initializeDefaultTypes() async {
    try {
      print('🔄 Verificando tipos en Firebase...');

      final snapshot = await _firestore.collection(_collection).get();

      if (snapshot.docs.isEmpty) {
        print('📝 Migrando tipos por defecto a Firebase...');

        final batch = _firestore.batch();
        int order = 1;

        // Mapeo de iconos
        const icons = {
          'Climatización': '❄️',
          'Equipos Eléctricos': '⚡',
          'Paneles Eléctricos': '🔌',
          'Generadores': '🔋',
          'UPS': '🔌',
          'Equipos de Cocina': '🍳',
          'Facilidades': '🏢',
          'Otros': '🔧',
        };

        // Migrar cada tipo
        for (final typeName in EquipmentTypes.all) {
          final doc = _firestore.collection(_collection).doc();
          final type = EquipmentType(
            id: doc.id,
            name: typeName,
            icon: icons[typeName] ?? '🔧',
            order: order++,
            categories: EquipmentCategories.all[typeName] ?? [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          batch.set(doc, type.toFirestore());
          print('  ✓ Tipo agregado: $typeName');
        }

        await batch.commit();
        print('✅ Migración completada: ${EquipmentTypes.all.length} tipos');
      } else {
        print('✅ Tipos ya inicializados: ${snapshot.docs.length} tipos');
      }
    } catch (e) {
      print('❌ Error en inicialización: $e');
      rethrow;
    }
  }

  // ========== CONSULTAS ==========

  /// Obtener todos los tipos activos (Stream en tiempo real)
  Stream<List<EquipmentType>> getEquipmentTypesStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EquipmentType.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  /// Obtener todos los tipos activos (Future para uso único)
  Future<List<EquipmentType>> getEquipmentTypes() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      return snapshot.docs
          .map((doc) => EquipmentType.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo tipos: $e');
      return [];
    }
  }

  /// Obtener un tipo específico por ID
  Future<EquipmentType?> getTypeById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return EquipmentType.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo tipo: $e');
      return null;
    }
  }

  /// Obtener un tipo por nombre (para compatibilidad con Equipment.tipo)
  Future<EquipmentType?> getTypeByName(String name) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('name', isEqualTo: name)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return EquipmentType.fromFirestore(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      print('❌ Error buscando tipo: $e');
      return null;
    }
  }

  // ========== OPERACIONES CRUD ==========

  /// Agregar nuevo tipo
  Future<String> addEquipmentType({
    required String name,
    String icon = '🔧',
    List<String> categories = const [],
  }) async {
    try {
      // Verificar que no exista
      final existing = await getTypeByName(name);
      if (existing != null) {
        throw Exception('Ya existe un tipo con ese nombre');
      }

      // Obtener el último order
      final lastDoc = await _firestore
          .collection(_collection)
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      final nextOrder = lastDoc.docs.isEmpty
          ? 1
          : (lastDoc.docs.first.data()['order'] as int) + 1;

      // Crear nuevo tipo
      final doc = _firestore.collection(_collection).doc();
      final type = EquipmentType(
        id: doc.id,
        name: name,
        icon: icon,
        order: nextOrder,
        categories: categories,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await doc.set(type.toFirestore());
      print('✅ Tipo agregado: $name (ID: ${doc.id})');
      return doc.id;
    } catch (e) {
      print('❌ Error agregando tipo: $e');
      rethrow;
    }
  }

  /// Actualizar tipo existente
  Future<void> updateEquipmentType(EquipmentType type) async {
    try {
      final updatedType = type.copyWith(updatedAt: DateTime.now());

      await _firestore
          .collection(_collection)
          .doc(type.id)
          .update(updatedType.toFirestore());

      print('✅ Tipo actualizado: ${type.name}');
    } catch (e) {
      print('❌ Error actualizando tipo: $e');
      rethrow;
    }
  }


  Future<void> deleteEquipmentType(String id) async {
    try {
      // Verificar si hay equipos usando este tipo
      final type = await getTypeById(id);
      if (type == null) throw Exception('Tipo no encontrado');

      final equipmentSnapshot = await _firestore
          .collection('equipments')
          .where('tipo', isEqualTo: type.name)
          .limit(1)
          .get();

      if (equipmentSnapshot.docs.isNotEmpty) {
        throw Exception(
            'No se puede eliminar. Hay ${equipmentSnapshot.docs.length} equipo(s) usando este tipo.');
      }

      // Soft delete
      await _firestore.collection(_collection).doc(id).update({
        'isActive': false,
        'updatedAt': DateTime.now(),
      });

      print('✅ Tipo desactivado: ${type.name}');
    } catch (e) {
      print('❌ Error eliminando tipo: $e');
      rethrow;
    }
  }

  /// Reordenar tipos (drag & drop)
  Future<void> reorderTypes(List<EquipmentType> types) async {
    try {
      final batch = _firestore.batch();

      for (int i = 0; i < types.length; i++) {
        final ref = _firestore.collection(_collection).doc(types[i].id);
        batch.update(ref, {
          'order': i + 1,
          'updatedAt': DateTime.now(),
        });
      }

      await batch.commit();
      print('✅ Tipos reordenados');
    } catch (e) {
      print('❌ Error reordenando: $e');
      rethrow;
    }
  }

  // ========== CATEGORÍAS ==========

  /// Obtener categorías de un tipo específico
  Future<List<String>> getCategoriesForType(String typeName) async {
    try {
      final type = await getTypeByName(typeName);
      return type?.categories ?? [];
    } catch (e) {
      print('❌ Error obteniendo categorías: $e');
      return [];
    }
  }

  /// Agregar categoría a un tipo
  Future<void> addCategoryToType(String typeId, String category) async {
    try {
      final type = await getTypeById(typeId);
      if (type == null) throw Exception('Tipo no encontrado');

      if (type.categories.contains(category)) {
        throw Exception('La categoría ya existe');
      }

      final updatedCategories = [...type.categories, category];
      await updateEquipmentType(
        type.copyWith(categories: updatedCategories),
      );

      print('✅ Categoría agregada: $category a ${type.name}');
    } catch (e) {
      print('❌ Error agregando categoría: $e');
      rethrow;
    }
  }

  /// Eliminar categoría de un tipo
  Future<void> removeCategoryFromType(String typeId, String category) async {
    try {
      final type = await getTypeById(typeId);
      if (type == null) throw Exception('Tipo no encontrado');

      final updatedCategories =
          type.categories.where((c) => c != category).toList();

      await updateEquipmentType(
        type.copyWith(categories: updatedCategories),
      );

      print('✅ Categoría eliminada: $category de ${type.name}');
    } catch (e) {
      print('❌ Error eliminando categoría: $e');
      rethrow;
    }
  }
}
