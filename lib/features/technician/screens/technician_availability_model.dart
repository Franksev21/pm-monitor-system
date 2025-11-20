class TechnicianAvailability {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isActive;

  // Carga horaria
  final double assignedHours; // Horas ya asignadas
  final double maxWeeklyHours; // Límite semanal (default: 60)
  final double regularHours; // Horas regulares (default: 49)

  // Mantenimientos
  final int activeMaintenances; // Cantidad de mantenimientos activos

  TechnicianAvailability({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.isActive,
    required this.assignedHours,
    this.maxWeeklyHours = 60.0,
    this.regularHours = 49.0,
    required this.activeMaintenances,
  });

  // Getters calculados
  double get availableHours => maxWeeklyHours - assignedHours;
  double get utilizationPercentage => (assignedHours / maxWeeklyHours) * 100;
  bool get isOverloaded => assignedHours >= maxWeeklyHours;
  bool get isNearLimit => assignedHours >= (maxWeeklyHours * 0.9);

  String get availabilityStatus {
    if (isOverloaded) return 'Sobrecargado';
    if (isNearLimit) return 'Casi lleno';
    if (assignedHours > regularHours) return 'Horas extra';
    return 'Disponible';
  }

  /// Verificar si puede aceptar más horas
  bool canAcceptHours(double hours) {
    return (assignedHours + hours) <= maxWeeklyHours;
  }

  /// Copiar con nuevas horas
  TechnicianAvailability copyWith({
    double? assignedHours,
    int? activeMaintenances,
  }) {
    return TechnicianAvailability(
      id: id,
      name: name,
      email: email,
      photoUrl: photoUrl,
      isActive: isActive,
      assignedHours: assignedHours ?? this.assignedHours,
      maxWeeklyHours: maxWeeklyHours,
      regularHours: regularHours,
      activeMaintenances: activeMaintenances ?? this.activeMaintenances,
    );
  }
}
