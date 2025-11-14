import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:pm_monitor/core/models/maintenance_task_template.dart';

/// Servicio para gestionar las tareas maestras (templates) de mantenimiento
class TaskTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'maintenance_task_templates';

  // ========================================
  // 📝 CRUD BÁSICO
  // ========================================

  /// Crear una nueva tarea template
  Future<String> createTemplate(dynamic template) async {
    try {
      debugPrint('📝 Creando nuevo template: ${template.name}');

      final docRef = await _firestore.collection(_collection).add(
            template.toFirestore(),
          );

      debugPrint('✅ Template creado con ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creando template: $e');
      rethrow;
    }
  }

  /// Actualizar una tarea template existente
  Future<void> updateTemplate(String id, dynamic template) async {
    try {
      debugPrint('📝 Actualizando template: $id');

      await _firestore.collection(_collection).doc(id).update(
            template.toFirestore(),
          );

      debugPrint('✅ Template actualizado correctamente');
    } catch (e) {
      debugPrint('❌ Error actualizando template: $e');
      rethrow;
    }
  }

  /// Eliminar una tarea template
  Future<void> deleteTemplate(String id) async {
    try {
      debugPrint('🗑️ Eliminando template: $id');

      await _firestore.collection(_collection).doc(id).delete();

      debugPrint('✅ Template eliminado correctamente');
    } catch (e) {
      debugPrint('❌ Error eliminando template: $e');
      rethrow;
    }
  }

  /// Obtener una tarea template por ID
  Future<dynamic> getTemplate(String id) async {
    try {
      debugPrint('🔍 Buscando template: $id');

      final doc = await _firestore.collection(_collection).doc(id).get();

      if (!doc.exists) {
        debugPrint('⚠️ Template no encontrado');
        return null;
      }

      return MaintenanceTaskTemplate.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error obteniendo template: $e');
      rethrow;
    }
  }

  // ========================================
  // 🔍 CONSULTAS Y FILTROS
  // ========================================

  /// Obtener todos los templates (Stream en tiempo real)
  Stream<List<dynamic>> getAllTemplates() {
    try {
      debugPrint('📡 Escuchando todos los templates');

      return _firestore
          .collection(_collection)
          .orderBy('order', descending: false)
          .orderBy('name', descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => MaintenanceTaskTemplate.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      debugPrint('❌ Error en stream de templates: $e');
      rethrow;
    }
  }

  /// Obtener templates por tipo de mantenimiento
  Stream<List<dynamic>> getTemplatesByType(String type) {
    try {
      debugPrint('📡 Escuchando templates por tipo: $type');

      return _firestore
          .collection(_collection)
          .where('type', isEqualTo: type)
          .orderBy('order', descending: false)
          .orderBy('name', descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => MaintenanceTaskTemplate.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      debugPrint('❌ Error en stream de templates por tipo: $e');
      rethrow;
    }
  }

  /// Obtener templates que aplican a un tipo de equipo específico
  Stream<List<dynamic>> getTemplatesByEquipmentType(String equipmentType) {
    try {
      debugPrint('📡 Escuchando templates por equipo: $equipmentType');

      return _firestore
          .collection(_collection)
          .where('equipmentTypes', arrayContains: equipmentType)
          .orderBy('order', descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => MaintenanceTaskTemplate.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      debugPrint('❌ Error en stream de templates por equipo: $e');
      rethrow;
    }
  }

  /// Obtener solo templates activos
  Stream<List<dynamic>> getActiveTemplates() {
    try {
      debugPrint('📡 Escuchando templates activos');

      return _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('order', descending: false)
          .orderBy('name', descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => MaintenanceTaskTemplate.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      debugPrint('❌ Error en stream de templates activos: $e');
      rethrow;
    }
  }
Stream<List<dynamic>> getActiveTemplatesByType(String type) {
    try {
      debugPrint('📡 Escuchando templates activos por tipo: $type');

      return _firestore
          .collection(_collection)
          .where('type', isEqualTo: type)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        debugPrint(
            '🔥 SNAPSHOT RECIBIDO: ${snapshot.docs.length} documentos'); // ← NUEVO

        if (snapshot.docs.isEmpty) {
          debugPrint(
              '⚠️ NO HAY DOCUMENTOS CON type="$type" y isActive=true'); // ← NUEVO
        }

        final templates = snapshot.docs.map((doc) {
          debugPrint(
              '📄 Doc: ${doc.id}, type=${doc.data()['type']}, name=${doc.data()['name']}'); // ← NUEVO
          return MaintenanceTaskTemplate.fromFirestore(doc);
        }).toList();

        // Ordenar en memoria
        templates.sort((a, b) {
          final orderCompare = a.order.compareTo(b.order);
          if (orderCompare != 0) return orderCompare;
          return a.name.compareTo(b.name);
        });

        debugPrint(
            '✅ Retornando ${templates.length} templates ordenados'); // ← NUEVO
        return templates;
      });
    } catch (e) {
      debugPrint('❌ Error en stream de templates activos por tipo: $e');
      rethrow;
    }
  }

  // ========================================
  // 🛠️ UTILIDADES
  // ========================================

  /// Reordenar templates (actualizar campo 'order')
  Future<void> reorderTemplates(List<String> orderedIds) async {
    try {
      debugPrint('🔄 Reordenando ${orderedIds.length} templates');

      final batch = _firestore.batch();

      for (int i = 0; i < orderedIds.length; i++) {
        final docRef = _firestore.collection(_collection).doc(orderedIds[i]);
        batch.update(docRef, {
          'order': i,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ Templates reordenados correctamente');
    } catch (e) {
      debugPrint('❌ Error reordenando templates: $e');
      rethrow;
    }
  }

  /// Activar/Desactivar un template
  Future<void> toggleTemplateStatus(String id, bool isActive) async {
    try {
      debugPrint('🔄 Cambiando estado de template: $id → $isActive');

      await _firestore.collection(_collection).doc(id).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Estado actualizado correctamente');
    } catch (e) {
      debugPrint('❌ Error actualizando estado: $e');
      rethrow;
    }
  }

  /// Obtener el siguiente número de orden para un tipo específico
  Future<int> getNextOrder(String type) async {
    try {
      debugPrint('🔢 Obteniendo siguiente orden para tipo: $type');

      final query = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: type)
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        debugPrint('✅ Primera tarea de este tipo, orden = 0');
        return 0;
      }

      final maxOrder = query.docs.first.data()['order'] as int? ?? 0;
      debugPrint('✅ Siguiente orden: ${maxOrder + 1}');
      return maxOrder + 1;
    } catch (e) {
      debugPrint('❌ Error obteniendo siguiente orden: $e');
      return 0;
    }
  }

  /// Obtener conteo de templates por tipo
  Future<Map<String, int>> getTemplateCountByType() async {
    try {
      debugPrint('📊 Obteniendo conteo de templates por tipo');

      final snapshot = await _firestore.collection(_collection).get();

      final counts = <String, int>{};

      for (var doc in snapshot.docs) {
        final type = doc.data()['type'] as String? ?? 'unknown';
        counts[type] = (counts[type] ?? 0) + 1;
      }

      debugPrint('✅ Conteo obtenido: $counts');
      return counts;
    } catch (e) {
      debugPrint('❌ Error obteniendo conteo: $e');
      return {};
    }
  }

  /// Buscar templates por nombre (búsqueda simple)
  Future<List<dynamic>> searchTemplatesByName(String searchTerm) async {
    try {
      debugPrint('🔍 Buscando templates: $searchTerm');

      final snapshot = await _firestore.collection(_collection).get();

      final results = snapshot.docs.where((doc) {
        final name = doc.data()['name'] as String? ?? '';
        return name.toLowerCase().contains(searchTerm.toLowerCase());
      }).toList();

      debugPrint('✅ Encontrados ${results.length} resultados');
      return snapshot.docs
          .map((doc) => MaintenanceTaskTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error buscando templates: $e');
      rethrow;
    }
  }

  /// Verificar si existe un template con el mismo nombre
  Future<bool> templateNameExists(String name, {String? excludeId}) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('name', isEqualTo: name)
          .get();

      if (excludeId != null) {
        // Excluir el ID actual (para edición)
        return query.docs.any((doc) => doc.id != excludeId);
      }

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error verificando nombre: $e');
      return false;
    }
  }

  // ========================================
  // 📦 OPERACIONES EN LOTE
  // ========================================

  /// Crear múltiples templates en batch (útil para migración inicial)
  Future<void> createMultipleTemplates(List<dynamic> templates) async {
    try {
      debugPrint('📦 Creando ${templates.length} templates en lote');

      final batch = _firestore.batch();

      for (var template in templates) {
        final docRef = _firestore.collection(_collection).doc();
        batch.set(docRef, template.toFirestore());
      }

      await batch.commit();
      debugPrint('✅ Templates creados en lote correctamente');
    } catch (e) {
      debugPrint('❌ Error creando templates en lote: $e');
      rethrow;
    }
  }

  /// Eliminar todos los templates de un tipo específico
  Future<void> deleteTemplatesByType(String type) async {
    try {
      debugPrint('🗑️ Eliminando todos los templates de tipo: $type');

      final snapshot = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: type)
          .get();

      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ Templates eliminados correctamente');
    } catch (e) {
      debugPrint('❌ Error eliminando templates por tipo: $e');
      rethrow;
    }
  }
}
