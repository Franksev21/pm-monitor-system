import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para las tareas maestras (templates) de mantenimiento
/// Estas tareas se usan como base para crear mantenimientos
class MaintenanceTaskTemplate {
  final String? id;
  final String name; // "Limpieza de filtros"
  final String description; // Descripción detallada
  final String type; // "preventive", "corrective", etc.
  final List<String> equipmentTypes; // ["Aire Acondicionado", "UPS"]
  final int estimatedMinutes; // Tiempo estimado en minutos
  final bool isActive; // Activo/Inactivo
  final int order; // Orden de visualización
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  MaintenanceTaskTemplate({
    this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.equipmentTypes,
    required this.estimatedMinutes,
    this.isActive = true,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  /// Crear desde documento de Firestore
  factory MaintenanceTaskTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MaintenanceTaskTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'preventive',
      equipmentTypes: List<String>.from(data['equipmentTypes'] ?? []),
      estimatedMinutes: data['estimatedMinutes'] ?? 30,
      isActive: data['isActive'] ?? true,
      order: data['order'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
    );
  }

  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'type': type,
      'equipmentTypes': equipmentTypes,
      'estimatedMinutes': estimatedMinutes,
      'isActive': isActive,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  /// Crear copia con cambios
  MaintenanceTaskTemplate copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    List<String>? equipmentTypes,
    int? estimatedMinutes,
    bool? isActive,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return MaintenanceTaskTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      equipmentTypes: equipmentTypes ?? this.equipmentTypes,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isActive: isActive ?? this.isActive,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Obtener nombre display del tipo de mantenimiento
  String get typeDisplayName {
    switch (type) {
      case 'preventive':
        return 'Preventivo';
      case 'corrective':
        return 'Correctivo';
      case 'emergency':
        return 'Emergencia';
      case 'inspection':
        return 'Inspección';
      case 'technicalAssistance':
        return 'Asistencia Técnica';
      default:
        return type;
    }
  }

  /// Obtener color según tipo
  int get typeColor {
    switch (type) {
      case 'preventive':
        return 0xFF4CAF50; // Verde
      case 'corrective':
        return 0xFFFF9800; // Naranja
      case 'emergency':
        return 0xFFF44336; // Rojo
      case 'inspection':
        return 0xFF2196F3; // Azul
      case 'technicalAssistance':
        return 0xFF9C27B0; // Púrpura
      default:
        return 0xFF757575; // Gris
    }
  }

  /// Obtener tiempo estimado formateado
  String get estimatedTimeFormatted {
    if (estimatedMinutes < 60) {
      return '$estimatedMinutes min';
    } else {
      final hours = estimatedMinutes ~/ 60;
      final minutes = estimatedMinutes % 60;
      if (minutes == 0) {
        return '$hours h';
      }
      return '$hours h $minutes min';
    }
  }

  @override
  String toString() {
    return 'MaintenanceTaskTemplate(id: $id, name: $name, type: $type, isActive: $isActive)';
  }
}
