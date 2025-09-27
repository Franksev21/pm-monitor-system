enum UserRole { admin, supervisor, technician, client }

class UserModel {
  final String id;
  final String email;
  final String name;
  final String phone;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;
  final bool emailVerified;
  final String? profileImageUrl;
  final DateTime? lastLogin;
  final Map<String, dynamic>? metadata;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    DateTime? createdAt,
    this.isActive = true,
    this.emailVerified = false,
    this.profileImageUrl,
    this.lastLogin,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convertir a JSON/Map para Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'emailVerified': emailVerified,
      'profileImageUrl': profileImageUrl,
      'lastLogin': lastLogin?.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Alias para compatibilidad
  Map<String, dynamic> toMap() => toJson();

  // Crear desde JSON/Map de Firestore
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.client,
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isActive: json['isActive'] ?? true,
      emailVerified: json['emailVerified'] ?? false,
      profileImageUrl: json['profileImageUrl'],
      lastLogin:
          json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
      metadata: json['metadata'],
    );
  }

  // Alias para compatibilidad
  factory UserModel.fromMap(Map<String, dynamic> map) =>
      UserModel.fromJson(map);

  // Copiar con modificaciones
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
    bool? isActive,
    bool? emailVerified,
    String? profileImageUrl,
    DateTime? lastLogin,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      emailVerified: emailVerified ?? this.emailVerified,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      lastLogin: lastLogin ?? this.lastLogin,
      metadata: metadata ?? this.metadata,
    );
  }

  // Obtener nombre del rol en español
  String get roleDisplayName {
    switch (role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.technician:
        return 'Técnico';
      case UserRole.client:
        return 'Cliente';
    }
  }

  // Obtener iniciales para avatar
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $name, role: ${role.toString()})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
