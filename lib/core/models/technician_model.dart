import 'package:cloud_firestore/cloud_firestore.dart';

class TechnicianModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String userType;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? hourlyRate;
  final String? specialization;
  final List<String> assignedEquipments;
  final String? profileImageUrl;

  TechnicianModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.userType,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.hourlyRate,
    this.specialization,
    this.assignedEquipments = const [],
    this.profileImageUrl,
  });

  // Factory constructor para crear desde Firestore
  factory TechnicianModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return TechnicianModel(
      id: doc.id,
      fullName: data['name'] ?? '', // Usar 'name' en lugar de 'fullName'
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      userType:
          data['role'] ?? 'technician', // Usar 'role' en lugar de 'userType'
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      hourlyRate: data['hourlyRate']?.toDouble(),
      specialization: data['specialization'],
      assignedEquipments: List<String>.from(data['assignedEquipments'] ?? []),
      profileImageUrl: data['photoUrl'], // Usar 'photoUrl' que es lo que tienes
    );
  }

  // Factory constructor para crear desde Map
  factory TechnicianModel.fromMap(Map<String, dynamic> data, String id) {
    return TechnicianModel(
      id: id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      userType: data['userType'] ?? 'Técnico',
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      hourlyRate: data['hourlyRate']?.toDouble(),
      specialization: data['specialization'],
      assignedEquipments: List<String>.from(data['assignedEquipments'] ?? []),
      profileImageUrl: data['profileImageUrl'],
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': fullName, // Usar 'name' en lugar de 'fullName'
      'email': email,
      'phone': phone,
      'role': userType, // Usar 'role' en lugar de 'userType'
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'hourlyRate': hourlyRate,
      'specialization': specialization,
      'assignedEquipments': assignedEquipments,
      'photoUrl': profileImageUrl, // Usar 'photoUrl'
    };
  }

  // Método copyWith para actualizaciones
  TechnicianModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? userType,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? hourlyRate,
    String? specialization,
    List<String>? assignedEquipments,
    String? profileImageUrl,
  }) {
    return TechnicianModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      specialization: specialization ?? this.specialization,
      assignedEquipments: assignedEquipments ?? this.assignedEquipments,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  // Obtener iniciales para avatar
  String get initials {
    final names = fullName.split(' ');
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

  // Número de equipos asignados
  int get assignedEquipmentsCount => assignedEquipments.length;

  @override
  String toString() {
    return 'TechnicianModel(id: $id, fullName: $fullName, email: $email, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TechnicianModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
