import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? website;
  final String taxId;
  final ClientType type;
  final ClientStatus status;
  final AddressModel mainAddress;
  final List<BranchModel> branches;
  final List<ContactModel> contacts;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  ClientModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.website,
    required this.taxId,
    required this.type,
    required this.status,
    required this.mainAddress,
    this.branches = const [],
    this.contacts = const [],
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'website': website,
      'taxId': taxId,
      'type': type.name,
      'status': status.name,
      'mainAddress': mainAddress.toJson(),
      'branches': branches.map((b) => b.toJson()).toList(),
      'contacts': contacts.map((c) => c.toJson()).toList(),
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      website: json['website'],
      taxId: json['taxId'] ?? '',
      type: ClientType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ClientType.small,
      ),
      status: ClientStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ClientStatus.active,
      ),
      mainAddress: AddressModel.fromJson(json['mainAddress'] ?? {}),
      branches: (json['branches'] as List?)
              ?.map((b) => BranchModel.fromJson(b))
              .toList() ??
          [],
      contacts: (json['contacts'] as List?)
              ?.map((c) => ContactModel.fromJson(c))
              .toList() ??
          [],
      notes: json['notes'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      createdBy: json['createdBy'] ?? '',
    );
  }

  ClientModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? website,
    String? taxId,
    ClientType? type,
    ClientStatus? status,
    AddressModel? mainAddress,
    List<BranchModel>? branches,
    List<ContactModel>? contacts,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      taxId: taxId ?? this.taxId,
      type: type ?? this.type,
      status: status ?? this.status,
      mainAddress: mainAddress ?? this.mainAddress,
      branches: branches ?? this.branches,
      contacts: contacts ?? this.contacts,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Getters útiles
  String get displayName => name;
  String get fullAddress => mainAddress.fullAddress;
  int get totalBranches => branches.length;
  int get totalContacts => contacts.length;

  // Color según estado
  Color get statusColor {
    switch (status) {
      case ClientStatus.active:
        return const Color(0xFF4CAF50);
      case ClientStatus.inactive:
        return const Color(0xFF9E9E9E);
      case ClientStatus.prospect:
        return const Color(0xFF2196F3);
      case ClientStatus.suspended:
        return const Color(0xFFE91E63);
    }
  }
}

// Modelo de Dirección
class AddressModel {
  final String street;
  final String city;
  final String state;
  final String country;
  final String zipCode;
  final double? latitude;
  final double? longitude;

  AddressModel({
    required this.street,
    required this.city,
    required this.state,
    required this.country,
    required this.zipCode,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'country': country,
      'zipCode': zipCode,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? 'República Dominicana',
      zipCode: json['zipCode'] ?? '',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  String get fullAddress => '$street, $city, $state, $country $zipCode';
}

// Modelo de Sucursal
class BranchModel {
  final String id;
  final String name;
  final AddressModel address;
  final String? managerName;
  final String? managerPhone;
  final bool isActive;

  BranchModel({
    required this.id,
    required this.name,
    required this.address,
    this.managerName,
    this.managerPhone,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address?.toJson(),
      'managerName': managerName,
      'managerPhone': managerPhone,
      'isActive': isActive,
    };
  }

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: AddressModel.fromJson(json['address'] ?? {}),
      managerName: json['managerName'],
      managerPhone: json['managerPhone'],
      isActive: json['isActive'] ?? true,
    );
  }
}

// Modelo de Contacto
class ContactModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String position;
  final ContactType type;
  final bool isPrimary;

  ContactModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.position,
    required this.type,
    this.isPrimary = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'position': position,
      'type': type.name,
      'isPrimary': isPrimary,
    };
  }

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      position: json['position'] ?? '',
      type: ContactType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ContactType.general,
      ),
      isPrimary: json['isPrimary'] ?? false,
    );
  }
}

// Enums
enum ClientType {
  small,
  medium,
  large,
  enterprise,
}

enum ClientStatus {
  active,
  inactive,
  prospect,
  suspended,
}

enum ContactType {
  general,
  technical,
  financial,
  management,
}

// Extensions
extension ClientTypeExtension on ClientType {
  String get displayName {
    switch (this) {
      case ClientType.small:
        return 'Pequeño';
      case ClientType.medium:
        return 'Mediano';
      case ClientType.large:
        return 'Grande';
      case ClientType.enterprise:
        return 'Corporativo';
    }
  }
}

extension ClientStatusExtension on ClientStatus {
  String get displayName {
    switch (this) {
      case ClientStatus.active:
        return 'Activo';
      case ClientStatus.inactive:
        return 'Inactivo';
      case ClientStatus.prospect:
        return 'Prospecto';
      case ClientStatus.suspended:
        return 'Suspendido';
    }
  }
}

extension ContactTypeExtension on ContactType {
  String get displayName {
    switch (this) {
      case ContactType.general:
        return 'General';
      case ContactType.technical:
        return 'Técnico';
      case ContactType.financial:
        return 'Financiero';
      case ContactType.management:
        return 'Gerencia';
    }
  }
}