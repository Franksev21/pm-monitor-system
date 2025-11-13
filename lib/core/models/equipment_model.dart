import 'package:cloud_firestore/cloud_firestore.dart';

class Equipment {
  final String? id;
  final String clientId;
  final String? branchId; // ID de la sucursal específica (opcional)
  final String equipmentNumber; // Número de identificación único
  final String rfidTag; // Tag RFID asociado
  final String qrCode; // Código QR generado

  // Información básica del equipo
  final String name;
  final String description;
  final String brand; // Marca
  final String model; // Modelo
  final String
      tipo; // Categoría principal: Climatización, Equipos Eléctricos, etc.
  final String category; // Subcategoría: Split Pared, Panel Principal, etc.
  final double capacity; // Capacidad (BTU, KW, etc.)
  final String capacityUnit; // BTU, KW, HP, etc.
  final String serialNumber; // Número de serie del fabricante

  // Ubicación y localización
  final String
      location; // Ubicación específica (Oficina 1, Sala de servidores, etc.)
  final String branch; // Nombre de la sucursal
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
    this.branchId,
    required this.equipmentNumber,
    required this.rfidTag,
    required this.qrCode,
    required this.name,
    required this.description,
    required this.brand,
    required this.model,
    required this.tipo,
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

  factory Equipment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Función helper local para double
    double safeDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Función helper local para int
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Equipment(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      branchId: data['branchId'],
      equipmentNumber: data['equipmentNumber'] ?? '',
      rfidTag: data['rfidTag'] ?? '',
      qrCode: data['qrCode'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      tipo: data['tipo'] ?? 'Climatización', // Default para compatibilidad
      category: data['category'] ?? '',
      capacity: safeDouble(data['capacity']),
      capacityUnit: data['capacityUnit'] ?? '',
      serialNumber: data['serialNumber'] ?? '',
      location: data['location'] ?? '',
      branch: data['branch'] ?? '',
      country: data['country'] ?? '',
      region: data['region'] ?? '',
      address: data['address'] ?? '',
      latitude: safeDouble(data['latitude']),
      longitude: safeDouble(data['longitude']),
      condition: data['condition'] ?? 'Bueno',
      lifeScale:
          safeInt(data['lifeScale']) == 0 ? 5 : safeInt(data['lifeScale']),
      isActive: data['isActive'] ?? true,
      status: data['status'] ?? 'Operativo',
      equipmentCost: safeDouble(data['equipmentCost']),
      totalPmCost: safeDouble(data['totalPmCost']),
      totalCmCost: safeDouble(data['totalCmCost']),
      currency: data['currency'] ?? 'USD',
      maintenanceFrequency: data['maintenanceFrequency'] ?? 'mensual',
      frequencyDays: safeInt(data['frequencyDays']) == 0
          ? 30
          : safeInt(data['frequencyDays']),
      lastMaintenanceDate: data['lastMaintenanceDate']?.toDate(),
      nextMaintenanceDate: data['nextMaintenanceDate']?.toDate(),
      estimatedMaintenanceHours: safeInt(data['estimatedMaintenanceHours']) == 0
          ? 2
          : safeInt(data['estimatedMaintenanceHours']),
      assignedTechnicianId: data['assignedTechnicianId'],
      assignedTechnicianName: data['assignedTechnicianName'],
      assignedSupervisorId: data['assignedSupervisorId'],
      assignedSupervisorName: data['assignedSupervisorName'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      documentUrls: List<String>.from(data['documentUrls'] ?? []),
      videoStreamUrl: data['videoStreamUrl'],
      technicalSpecs: Map<String, dynamic>.from(data['technicalSpecs'] ?? {}),
      customFields: Map<String, dynamic>.from(data['customFields'] ?? {}),
      minTemperature: safeDouble(data['minTemperature']),
      maxTemperature: safeDouble(data['maxTemperature']),
      currentTemperature: safeDouble(data['currentTemperature']),
      hasTemperatureMonitoring: data['hasTemperatureMonitoring'] ?? false,
      totalMaintenances: safeInt(data['totalMaintenances']),
      totalFailures: safeInt(data['totalFailures']),
      averageResponseTime: safeDouble(data['averageResponseTime']),
      maintenanceEfficiency: safeDouble(data['maintenanceEfficiency']),
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
      'branchId': branchId,
      'equipmentNumber': equipmentNumber,
      'rfidTag': rfidTag,
      'qrCode': qrCode,
      'name': name,
      'description': description,
      'brand': brand,
      'model': model,
      'tipo': tipo,
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
    String? branchId,
    String? equipmentNumber,
    String? rfidTag,
    String? qrCode,
    String? name,
    String? description,
    String? brand,
    String? model,
    String? tipo,
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
      branchId: branchId ?? this.branchId,
      equipmentNumber: equipmentNumber ?? this.equipmentNumber,
      rfidTag: rfidTag ?? this.rfidTag,
      qrCode: qrCode ?? this.qrCode,
      name: name ?? this.name,
      description: description ?? this.description,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      tipo: tipo ?? this.tipo,
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

  String get tipoDisplayName => tipo;

  String get categoryDisplayName => category;

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

// Constantes para los tipos de equipos
class EquipmentTypes {
  static const String climatizacion = 'Climatización';
  static const String equiposElectricos = 'Equipos Eléctricos';
  static const String panelesElectricos = 'Paneles Eléctricos';
  static const String generadores = 'Generadores';
  static const String ups = 'UPS';
  static const String equiposCocina = 'Equipos de Cocina';
  static const String facilidades = 'Facilidades';
  static const String otros = 'Otros';

  static List<String> get all => [
        climatizacion,
        equiposElectricos,
        panelesElectricos,
        generadores,
        ups,
        equiposCocina,
        facilidades,
        otros,
      ];
}

// Mapeo de tipos a categorías (subcategorías)
class EquipmentCategories {
  // Climatización
  static const List<String> climatizacion = [
    'Split Pared',
    'Split Piso/Techo',
    'Cassette',
    'Ducto',
    'Ventana',
    'Portátil',
    'Chiller',
    'Fan Coil',
    'Manejadora de Aire',
    'Unidad Condensadora',
  ];

  // Equipos Eléctricos
  static const List<String> equiposElectricos = [
    'Transformador',
    'Tablero de Distribución',
    'Breaker',
    'Interruptor',
    'Toma Corriente',
    'Iluminación LED',
    'Balasto',
    'Otro Equipo Eléctrico',
  ];

  // Paneles Eléctricos
  static const List<String> panelesElectricos = [
    'Panel Principal',
    'Panel de Distribución',
    'Panel de Control',
    'Panel de Transferencia',
    'Panel de Medición',
  ];

  // Generadores
  static const List<String> generadores = [
    'Generador Diésel',
    'Generador Gas',
    'Generador Gasolina',
    'Generador Emergencia',
    'Generador Standby',
  ];

  // UPS
  static const List<String> ups = [
    'UPS Línea Interactiva',
    'UPS Online',
    'UPS Offline',
    'UPS Modular',
  ];

  // Equipos de Cocina
  static const List<String> equiposCocina = [
    'Refrigerador',
    'Congelador',
    'Horno',
    'Estufa',
    'Microondas',
    'Lavavajillas',
    'Campana Extractora',
    'Freidora',
    'Plancha',
    'Otro Equipo de Cocina',
  ];

  // Facilidades
  static const List<String> facilidades = [
    'Bomba de Agua',
    'Sistema de Incendio',
    'Ascensor',
    'Portón Automático',
    'Sistema de Acceso',
    'Cámaras de Seguridad',
    'Iluminación',
    'Ventilación',
  ];

  // Otros
  static const List<String> otros = [
    'Otro',
  ];

  static Map<String, List<String>> get all => {
        EquipmentTypes.climatizacion: climatizacion,
        EquipmentTypes.equiposElectricos: equiposElectricos,
        EquipmentTypes.panelesElectricos: panelesElectricos,
        EquipmentTypes.generadores: generadores,
        EquipmentTypes.ups: ups,
        EquipmentTypes.equiposCocina: equiposCocina,
        EquipmentTypes.facilidades: facilidades,
        EquipmentTypes.otros: otros,
      };
}
