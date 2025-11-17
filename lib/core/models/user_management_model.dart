import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserManagementModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? photoUrl;

  // Campos específicos para técnicos y supervisores
  final double? hourlyRate;
  final String? specialization;
  final List<String> assignedEquipments;
  final List<String> assignedTechnicians; // Para supervisores
  final String? supervisorId; // Para técnicos

  // Campos específicos para clientes
  final String? company;
  final String? address;
  final List<String> locations;

  UserManagementModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.photoUrl,
    this.hourlyRate,
    this.specialization,
    this.assignedEquipments = const [],
    this.assignedTechnicians = const [],
    this.supervisorId,
    this.company,
    this.address,
    this.locations = const [],
  });

  // Factory constructor para crear desde Firestore
  factory UserManagementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Detectar si es un cliente de la colección 'clients' verificando estructura
    bool isClientCollection = data.containsKey('mainAddress') ||
        data.containsKey('branches') ||
        !data.containsKey('role');

    if (isClientCollection) {
      // Cliente de la colección 'clients'
      final mainAddress = data['mainAddress'] as Map<String, dynamic>?;
      final branches = data['branches'] as List<dynamic>?;

      String address = '';
      if (mainAddress != null) {
        final street = mainAddress['street'] ?? '';
        final city = mainAddress['city'] ?? '';
        final state = mainAddress['state'] ?? '';
        final country = mainAddress['country'] ?? '';
        address = '$street, $city, $state, $country'
            .replaceAll(RegExp(r',\s*,'), ',')
            .trim();
        if (address.startsWith(',')) address = address.substring(1).trim();
        if (address.endsWith(',')) {
          address = address.substring(0, address.length - 1);
        }
      }

      List<String> locationsList = [];
      if (branches != null) {
        locationsList = branches.map((branch) => branch.toString()).toList();
      }

      return UserManagementModel(
        id: doc.id,
        name: data['name'] ?? 'Sin nombre',
        email: data['email'] ?? 'Sin email',
        phone: data['phone'] ?? '',
        role: 'client',
        isActive: true, // Clientes existentes son activos por defecto
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : null,
        updatedAt: data['updatedAt'] != null
            ? (data['updatedAt'] as Timestamp).toDate()
            : null,
        photoUrl: data['photoUrl'],
        company: data['name'], // Usar name como company para clientes
        address: address,
        locations: locationsList,
      );
    } else {
      // Usuario de la colección 'users'
      return UserManagementModel(
        id: doc.id,
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        role: data['role'] ?? '',
        isActive: data['isActive'] ?? true,
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : null,
        updatedAt: data['updatedAt'] != null
            ? (data['updatedAt'] as Timestamp).toDate()
            : null,
        photoUrl: data['photoUrl'],
        hourlyRate: data['hourlyRate']?.toDouble(),
        specialization: data['specialization'],
        assignedEquipments: List<String>.from(data['assignedEquipments'] ?? []),
        assignedTechnicians:
            List<String>.from(data['assignedTechnicians'] ?? []),
        supervisorId: data['supervisorId'],
        company: data['company'],
        address: data['address'],
        locations: List<String>.from(data['locations'] ?? []),
      );
    }
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'photoUrl': photoUrl,
    };

    // Agregar campos específicos según el rol
    if (role == 'technician' || role == 'supervisor') {
      map['hourlyRate'] = hourlyRate;
      map['specialization'] = specialization;
      map['assignedEquipments'] = assignedEquipments;
    }

    if (role == 'supervisor') {
      map['assignedTechnicians'] = assignedTechnicians;
    }

    if (role == 'technician') {
      map['supervisorId'] = supervisorId;
    }

    if (role == 'client') {
      map['company'] = company;
      map['address'] = address;
      map['locations'] = locations;
    }

    return map;
  }

  // Obtener iniciales para avatar
  String get initials {
    final names = name.split(' ');
    return names
        .take(2)
        .map((name) => name.isNotEmpty ? name[0] : '')
        .join()
        .toUpperCase();
  }

  // Formatear fecha de creación
  String get formattedCreatedDate {
    if (createdAt == null) return 'N/A';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }

  // Estado como string
  String get statusText => isActive ? 'Activo' : 'Inactivo';

  // Tipo de usuario en español
  String get roleInSpanish {
    switch (role) {
      case 'technician':
        return 'Técnico';
      case 'supervisor':
        return 'Supervisor';
      case 'client':
        return 'Cliente';
      case 'admin':
        return 'Administrador';
      default:
        return role;
    }
  }

  // Color según el rol
  Color get roleColor {
    switch (role) {
      case 'technician':
        return Colors.orange;
      case 'supervisor':
        return Colors.blue;
      case 'client':
        return Colors.purple;
      case 'admin':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Icono según el rol
  IconData get roleIcon {
    switch (role) {
      case 'technician':
        return Icons.engineering;
      case 'supervisor':
        return Icons.supervisor_account;
      case 'client':
        return Icons.business;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  // Número de asignaciones
  int get assignmentsCount {
    switch (role) {
      case 'technician':
        return assignedEquipments.length;
      case 'supervisor':
        return assignedTechnicians.length;
      case 'client':
        return locations.length;
      default:
        return 0;
    }
  }

  // Texto de asignaciones
  String get assignmentsText {
    switch (role) {
      case 'technician':
        return '${assignedEquipments.length} equipos asignados';
      case 'supervisor':
        return '${assignedTechnicians.length} técnicos supervisados';
      case 'client':
        return '${locations.length} ubicaciones';
      default:
        return '';
    }
  }

  // Método copyWith
  UserManagementModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? photoUrl,
    double? hourlyRate,
    String? specialization,
    List<String>? assignedEquipments,
    List<String>? assignedTechnicians,
    String? supervisorId,
    String? company,
    String? address,
    List<String>? locations,
  }) {
    return UserManagementModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoUrl: photoUrl ?? this.photoUrl,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      specialization: specialization ?? this.specialization,
      assignedEquipments: assignedEquipments ?? this.assignedEquipments,
      assignedTechnicians: assignedTechnicians ?? this.assignedTechnicians,
      supervisorId: supervisorId ?? this.supervisorId,
      company: company ?? this.company,
      address: address ?? this.address,
      locations: locations ?? this.locations,
    );
  }

  @override
  String toString() {
    return 'UserManagementModel(id: $id, name: $name, role: $role, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserManagementModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
