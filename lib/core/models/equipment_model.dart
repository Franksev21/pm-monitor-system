import 'package:cloud_firestore/cloud_firestore.dart';

class Equipment {
  final String? id;
  final String clientId;
  final String equipmentNumber; // Número de identificación único
  final String rfidTag; // Tag RFID asociado
  final String qrCode; // Código QR generado

  // Información básica del equipo
  final String name;
  final String description;
  final String brand; // Marca
  final String model; // Modelo
  final String category; // AA, Panel Eléctrico, Generador, UPS, etc.
  final double capacity; // Capacidad (BTU, KW, etc.)
  final String capacityUnit; // BTU, KW, HP, etc.
  final String serialNumber; // Número de serie del fabricante

  // Ubicación y localización
  final String
      location; // Ubicación específica (Oficina 1, Sala de servidores, etc.)
  final String branch; // Sucursal
  final String country; // País
  final String region; // Región
  final String address; // Dirección completa
  final double? latitude; // Coordenadas GPS
  final double? longitude;

  // Estado y condición
  final String condition; // Excelente, Bueno, Regular, Malo
  final int lifeScale; // Escala 1-10 de vida útil
  final bool isActive; // Si está activo/operativo
  final String status; // Operativo, Fuera de servicio, En mantenimiento

  // Información financiera
  final double equipmentCost; // Costo del equipo
  final double totalPmCost; // Costo total de mantenimientos preventivos
  final double totalCmCost; // Costo total de mantenimientos correctivos
  final String currency; // Moneda (USD, DOP, etc.)

  // Mantenimiento programado
  final String maintenanceFrequency; // semanal, mensual, trimestral, etc.
  final int frequencyDays; // Días entre mantenimientos
  final DateTime? lastMaintenanceDate; // Último mantenimiento realizado
  final DateTime? nextMaintenanceDate; // Próximo mantenimiento programado
  final int estimatedMaintenanceHours; // Horas estimadas por mantenimiento

  // Técnico asignado
  final String? assignedTechnicianId;
  final String? assignedTechnicianName;
  final String? assignedSupervisorId;
  final String? assignedSupervisorName;

  // Multimedia y documentación
  final List<String> photoUrls; // URLs de fotos del equipo
  final List<String> documentUrls; // Manuales, garantías, etc.
  final String? videoStreamUrl; // URL de cámara de monitoreo si aplica

  // Especificaciones técnicas adicionales
  final Map<String, dynamic>
      technicalSpecs; // Especificaciones técnicas variables
  final Map<String, dynamic> customFields; // Campos personalizados por cliente

  // Control de temperaturas (para monitoreo)
  final double? minTemperature;
  final double? maxTemperature;
  final double? currentTemperature;
  final bool hasTemperatureMonitoring;

  // Historial y estadísticas
  final int totalMaintenances; // Total de mantenimientos realizados
  final int totalFailures; // Total de fallas reportadas
  final double averageResponseTime; // Tiempo promedio de respuesta en horas
  final double maintenanceEfficiency; // Porcentaje de eficiencia

  // Metadatos del sistema
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy; // ID del usuario que creó el equipo
  final String? updatedBy; // ID del último usuario que actualizó

  // Configuración de alertas
  final bool enableMaintenanceAlerts;
  final bool enableFailureAlerts;
  final bool enableTemperatureAlerts;
  final List<String> alertEmails; // Emails para notificaciones
  final List<String> alertPhones; // Teléfonos para SMS/WhatsApp

  Equipment({
    this.id,
    required this.clientId,
    required this.equipmentNumber,
    required this.rfidTag,
    required this.qrCode,
    required this.name,
    required this.description,
    required this.brand,
    required this.model,
    required this.category,
    required this.capacity,
    required this.capacityUnit,
    required this.serialNumber,
    required this.location,
    required this.branch,
    required this.country,
    required this.region,
    required this.address,
    this.latitude,
    this.longitude,
    required this.condition,
    required this.lifeScale,
    required this.isActive,
    required this.status,
    required this.equipmentCost,
    this.totalPmCost = 0.0,
    this.totalCmCost = 0.0,
    this.currency = 'USD',
    required this.maintenanceFrequency,
    required this.frequencyDays,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    required this.estimatedMaintenanceHours,
    this.assignedTechnicianId,
    this.assignedTechnicianName,
    this.assignedSupervisorId,
    this.assignedSupervisorName,
    this.photoUrls = const [],
    this.documentUrls = const [],
    this.videoStreamUrl,
    this.technicalSpecs = const {},
    this.customFields = const {},
    this.minTemperature,
    this.maxTemperature,
    this.currentTemperature,
    this.hasTemperatureMonitoring = false,
    this.totalMaintenances = 0,
    this.totalFailures = 0,
    this.averageResponseTime = 0.0,
    this.maintenanceEfficiency = 0.0,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.updatedBy,
    this.enableMaintenanceAlerts = true,
    this.enableFailureAlerts = true,
    this.enableTemperatureAlerts = false,
    this.alertEmails = const [],
    this.alertPhones = const [],
  });

  // Factory constructor para crear desde Firestore
  factory Equipment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Equipment(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      equipmentNumber: data['equipmentNumber'] ?? '',
      rfidTag: data['rfidTag'] ?? '',
      qrCode: data['qrCode'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      category: data['category'] ?? '',
      capacity: (data['capacity'] ?? 0).toDouble(),
      capacityUnit: data['capacityUnit'] ?? '',
      serialNumber: data['serialNumber'] ?? '',
      location: data['location'] ?? '',
      branch: data['branch'] ?? '',
      country: data['country'] ?? '',
      region: data['region'] ?? '',
      address: data['address'] ?? '',
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      condition: data['condition'] ?? 'Bueno',
      lifeScale: data['lifeScale'] ?? 5,
      isActive: data['isActive'] ?? true,
      status: data['status'] ?? 'Operativo',
      equipmentCost: (data['equipmentCost'] ?? 0).toDouble(),
      totalPmCost: (data['totalPmCost'] ?? 0).toDouble(),
      totalCmCost: (data['totalCmCost'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'USD',
      maintenanceFrequency: data['maintenanceFrequency'] ?? 'mensual',
      frequencyDays: data['frequencyDays'] ?? 30,
      lastMaintenanceDate: data['lastMaintenanceDate']?.toDate(),
      nextMaintenanceDate: data['nextMaintenanceDate']?.toDate(),
      estimatedMaintenanceHours: data['estimatedMaintenanceHours'] ?? 2,
      assignedTechnicianId: data['assignedTechnicianId'],
      assignedTechnicianName: data['assignedTechnicianName'],
      assignedSupervisorId: data['assignedSupervisorId'],
      assignedSupervisorName: data['assignedSupervisorName'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      documentUrls: List<String>.from(data['documentUrls'] ?? []),
      videoStreamUrl: data['videoStreamUrl'],
      technicalSpecs: Map<String, dynamic>.from(data['technicalSpecs'] ?? {}),
      customFields: Map<String, dynamic>.from(data['customFields'] ?? {}),
      minTemperature: data['minTemperature']?.toDouble(),
      maxTemperature: data['maxTemperature']?.toDouble(),
      currentTemperature: data['currentTemperature']?.toDouble(),
      hasTemperatureMonitoring: data['hasTemperatureMonitoring'] ?? false,
      totalMaintenances: data['totalMaintenances'] ?? 0,
      totalFailures: data['totalFailures'] ?? 0,
      averageResponseTime: (data['averageResponseTime'] ?? 0).toDouble(),
      maintenanceEfficiency: (data['maintenanceEfficiency'] ?? 0).toDouble(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      updatedBy: data['updatedBy'],
      enableMaintenanceAlerts: data['enableMaintenanceAlerts'] ?? true,
      enableFailureAlerts: data['enableFailureAlerts'] ?? true,
      enableTemperatureAlerts: data['enableTemperatureAlerts'] ?? false,
      alertEmails: List<String>.from(data['alertEmails'] ?? []),
      alertPhones: List<String>.from(data['alertPhones'] ?? []),
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'equipmentNumber': equipmentNumber,
      'rfidTag': rfidTag,
      'qrCode': qrCode,
      'name': name,
      'description': description,
      'brand': brand,
      'model': model,
      'category': category,
      'capacity': capacity,
      'capacityUnit': capacityUnit,
      'serialNumber': serialNumber,
      'location': location,
      'branch': branch,
      'country': country,
      'region': region,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'condition': condition,
      'lifeScale': lifeScale,
      'isActive': isActive,
      'status': status,
      'equipmentCost': equipmentCost,
      'totalPmCost': totalPmCost,
      'totalCmCost': totalCmCost,
      'currency': currency,
      'maintenanceFrequency': maintenanceFrequency,
      'frequencyDays': frequencyDays,
      'lastMaintenanceDate': lastMaintenanceDate,
      'nextMaintenanceDate': nextMaintenanceDate,
      'estimatedMaintenanceHours': estimatedMaintenanceHours,
      'assignedTechnicianId': assignedTechnicianId,
      'assignedTechnicianName': assignedTechnicianName,
      'assignedSupervisorId': assignedSupervisorId,
      'assignedSupervisorName': assignedSupervisorName,
      'photoUrls': photoUrls,
      'documentUrls': documentUrls,
      'videoStreamUrl': videoStreamUrl,
      'technicalSpecs': technicalSpecs,
      'customFields': customFields,
      'minTemperature': minTemperature,
      'maxTemperature': maxTemperature,
      'currentTemperature': currentTemperature,
      'hasTemperatureMonitoring': hasTemperatureMonitoring,
      'totalMaintenances': totalMaintenances,
      'totalFailures': totalFailures,
      'averageResponseTime': averageResponseTime,
      'maintenanceEfficiency': maintenanceEfficiency,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'enableMaintenanceAlerts': enableMaintenanceAlerts,
      'enableFailureAlerts': enableFailureAlerts,
      'enableTemperatureAlerts': enableTemperatureAlerts,
      'alertEmails': alertEmails,
      'alertPhones': alertPhones,
    };
  }

  // Método para crear una copia con cambios
  Equipment copyWith({
    String? id,
    String? clientId,
    String? equipmentNumber,
    String? rfidTag,
    String? qrCode,
    String? name,
    String? description,
    String? brand,
    String? model,
    String? category,
    double? capacity,
    String? capacityUnit,
    String? serialNumber,
    String? location,
    String? branch,
    String? country,
    String? region,
    String? address,
    double? latitude,
    double? longitude,
    String? condition,
    int? lifeScale,
    bool? isActive,
    String? status,
    double? equipmentCost,
    double? totalPmCost,
    double? totalCmCost,
    String? currency,
    String? maintenanceFrequency,
    int? frequencyDays,
    DateTime? lastMaintenanceDate,
    DateTime? nextMaintenanceDate,
    int? estimatedMaintenanceHours,
    String? assignedTechnicianId,
    String? assignedTechnicianName,
    String? assignedSupervisorId,
    String? assignedSupervisorName,
    List<String>? photoUrls,
    List<String>? documentUrls,
    String? videoStreamUrl,
    Map<String, dynamic>? technicalSpecs,
    Map<String, dynamic>? customFields,
    double? minTemperature,
    double? maxTemperature,
    double? currentTemperature,
    bool? hasTemperatureMonitoring,
    int? totalMaintenances,
    int? totalFailures,
    double? averageResponseTime,
    double? maintenanceEfficiency,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    bool? enableMaintenanceAlerts,
    bool? enableFailureAlerts,
    bool? enableTemperatureAlerts,
    List<String>? alertEmails,
    List<String>? alertPhones,
  }) {
    return Equipment(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      equipmentNumber: equipmentNumber ?? this.equipmentNumber,
      rfidTag: rfidTag ?? this.rfidTag,
      qrCode: qrCode ?? this.qrCode,
      name: name ?? this.name,
      description: description ?? this.description,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      category: category ?? this.category,
      capacity: capacity ?? this.capacity,
      capacityUnit: capacityUnit ?? this.capacityUnit,
      serialNumber: serialNumber ?? this.serialNumber,
      location: location ?? this.location,
      branch: branch ?? this.branch,
      country: country ?? this.country,
      region: region ?? this.region,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      condition: condition ?? this.condition,
      lifeScale: lifeScale ?? this.lifeScale,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      equipmentCost: equipmentCost ?? this.equipmentCost,
      totalPmCost: totalPmCost ?? this.totalPmCost,
      totalCmCost: totalCmCost ?? this.totalCmCost,
      currency: currency ?? this.currency,
      maintenanceFrequency: maintenanceFrequency ?? this.maintenanceFrequency,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      estimatedMaintenanceHours:
          estimatedMaintenanceHours ?? this.estimatedMaintenanceHours,
      assignedTechnicianId: assignedTechnicianId ?? this.assignedTechnicianId,
      assignedTechnicianName:
          assignedTechnicianName ?? this.assignedTechnicianName,
      assignedSupervisorId: assignedSupervisorId ?? this.assignedSupervisorId,
      assignedSupervisorName:
          assignedSupervisorName ?? this.assignedSupervisorName,
      photoUrls: photoUrls ?? this.photoUrls,
      documentUrls: documentUrls ?? this.documentUrls,
      videoStreamUrl: videoStreamUrl ?? this.videoStreamUrl,
      technicalSpecs: technicalSpecs ?? this.technicalSpecs,
      customFields: customFields ?? this.customFields,
      minTemperature: minTemperature ?? this.minTemperature,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      currentTemperature: currentTemperature ?? this.currentTemperature,
      hasTemperatureMonitoring:
          hasTemperatureMonitoring ?? this.hasTemperatureMonitoring,
      totalMaintenances: totalMaintenances ?? this.totalMaintenances,
      totalFailures: totalFailures ?? this.totalFailures,
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
      maintenanceEfficiency:
          maintenanceEfficiency ?? this.maintenanceEfficiency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      enableMaintenanceAlerts:
          enableMaintenanceAlerts ?? this.enableMaintenanceAlerts,
      enableFailureAlerts: enableFailureAlerts ?? this.enableFailureAlerts,
      enableTemperatureAlerts:
          enableTemperatureAlerts ?? this.enableTemperatureAlerts,
      alertEmails: alertEmails ?? this.alertEmails,
      alertPhones: alertPhones ?? this.alertPhones,
    );
  }

  // Métodos de utilidad
  String get fullLocation => '$location, $branch, $country';

  String get displayName => '$brand $model - $name';

  bool get needsMaintenance {
    if (nextMaintenanceDate == null) return false;
    return DateTime.now().isAfter(nextMaintenanceDate!);
  }

  bool get isOverdue {
    if (nextMaintenanceDate == null) return false;
    return DateTime.now().isAfter(nextMaintenanceDate!.add(Duration(days: 7)));
  }

  String get statusColor {
    switch (status.toLowerCase()) {
      case 'operativo':
        return 'green';
      case 'en mantenimiento':
        return 'orange';
      case 'fuera de servicio':
        return 'red';
      default:
        return 'gray';
    }
  }

  String get conditionIcon {
    switch (condition.toLowerCase()) {
      case 'excelente':
        return '🟢';
      case 'bueno':
        return '🟡';
      case 'regular':
        return '🟠';
      case 'malo':
        return '🔴';
      default:
        return '⚪';
    }
  }

  double get totalCost => equipmentCost + totalPmCost + totalCmCost;

  String get maintenanceStatus {
    if (needsMaintenance) {
      return isOverdue ? 'Vencido' : 'Programado';
    }
    return 'Al día';
  }
}
