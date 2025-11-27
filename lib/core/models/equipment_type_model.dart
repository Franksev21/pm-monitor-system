// lib/core/models/equipment_type.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentType {
  final String id;
  final String name;
  final String icon;
  final int order;
  final List<String> categories;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  EquipmentType({
    required this.id,
    required this.name,
    this.icon = '🔧',
    required this.order,
    this.categories = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'icon': icon,
      'order': order,
      'categories': categories,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isActive': isActive,
    };
  }

  factory EquipmentType.fromFirestore(Map<String, dynamic> data, String id) {
    return EquipmentType(
      id: id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '🔧',
      order: data['order'] ?? 0,
      categories: List<String>.from(data['categories'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  EquipmentType copyWith({
    String? id,
    String? name,
    String? icon,
    int? order,
    List<String>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return EquipmentType(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      order: order ?? this.order,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
