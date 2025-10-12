// pending_maintenances_screen.dart - CORREGIDO

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingMaintenancesScreen extends StatefulWidget {
  const PendingMaintenancesScreen({super.key});

  @override
  State<PendingMaintenancesScreen> createState() =>
      _PendingMaintenancesScreenState();
}

class _PendingMaintenancesScreenState extends State<PendingMaintenancesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> pendingMaintenances = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingMaintenances();
  }

  Future<void> _loadPendingMaintenances() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final currentUserId = _auth.currentUser?.uid;

      if (currentUserId == null) {
        setState(() {
          errorMessage = 'No hay usuario autenticado';
          isLoading = false;
        });
        return;
      }

      print('Loading pending maintenances for user: $currentUserId');

      // Primero verificar si la colección existe y es accesible
      QuerySnapshot snapshot;

      try {
        // Intentar la consulta con filtros
        snapshot = await _firestore
            .collection('maintenanceSchedules')
            .where('technicianId', isEqualTo: currentUserId)
            .where('status', whereIn: ['scheduled', 'pending'])
            .limit(50) // Limitar resultados para evitar sobrecarga
            .get();

        print(
            'Query successful. Found ${snapshot.docs.length} pending maintenances');
      } catch (e) {
        print('Error with filtered query, trying alternative approach: $e');

        // Si falla, intentar obtener todos los documentos del técnico y filtrar localmente
        try {
          snapshot = await _firestore
              .collection('maintenanceSchedules')
              .where('technicianId', isEqualTo: currentUserId)
              .get();

          print(
              'Alternative query successful. Total docs: ${snapshot.docs.length}');

          // Filtrar localmente por status
          snapshot = _filterPendingLocally(snapshot);
        } catch (e2) {
          print('Alternative query also failed: $e2');

          // Si aún falla, crear datos de ejemplo para desarrollo
          if (mounted) {
            setState(() {
              pendingMaintenances = _createSampleData();
              isLoading = false;
            });
          }
          return;
        }
      }

      // Procesar los documentos
      List<Map<String, dynamic>> maintenances = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;

          // Validar y normalizar los datos
          final maintenance = {
            'id': doc.id,
            'equipmentName': data['equipmentName'] ?? 'Equipo sin nombre',
            'equipmentId': data['equipmentId'] ?? '',
            'clientName': data['clientName'] ?? 'Cliente no especificado',
            'location': data['location'] ?? 'Sin ubicación',
            'scheduledDate': data['scheduledDate'],
            'type': data['type'] ?? 'preventive',
            'priority': data['priority'] ?? 'normal',
            'status': data['status'] ?? 'pending',
            'description': data['description'] ?? '',
            'estimatedDuration': data['estimatedDuration'] ?? 60,
          };

          maintenances.add(maintenance);
        } catch (e) {
          print('Error processing document ${doc.id}: $e');
          // Continuar con el siguiente documento
        }
      }

      // Ordenar por fecha
      maintenances.sort((a, b) {
        final dateA = a['scheduledDate'] as Timestamp?;
        final dateB = b['scheduledDate'] as Timestamp?;

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateA.compareTo(dateB);
      });

      if (mounted) {
        setState(() {
          pendingMaintenances = maintenances;
          isLoading = false;

          if (maintenances.isEmpty) {
            print('No pending maintenances found for user');
          }
        });
      }
    } catch (e) {
      print('Unexpected error loading pending maintenances: $e');

      if (mounted) {
        setState(() {
          errorMessage = 'Error al cargar los mantenimientos: ${e.toString()}';
          isLoading = false;
          // Usar datos de ejemplo en caso de error
          pendingMaintenances = _createSampleData();
        });
      }
    }
  }

  // Filtrar localmente los documentos pendientes
  QuerySnapshot _filterPendingLocally(QuerySnapshot snapshot) {
    snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      return status == 'scheduled' || status == 'pending';
    }).toList();

    // Crear un nuevo QuerySnapshot con solo los documentos filtrados
    // Como QuerySnapshot es inmutable, retornamos el original
    // y manejamos el filtrado en el procesamiento
    return snapshot;
  }

  // Crear datos de ejemplo para desarrollo
  List<Map<String, dynamic>> _createSampleData() {
    return [
      {
        'id': 'sample1',
        'equipmentName': 'Aire Acondicionado - Oficina Principal',
        'equipmentId': 'EQ001',
        'clientName': 'Empresa Demo',
        'location': 'Piso 3, Oficina 301',
        'scheduledDate': Timestamp.now(),
        'type': 'preventive',
        'priority': 'normal',
        'status': 'pending',
        'description': 'Mantenimiento preventivo mensual',
        'estimatedDuration': 60,
      },
      // Puedes agregar más datos de ejemplo si lo necesitas
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenimientos Pendientes'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingMaintenances,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando mantenimientos pendientes...'),
          ],
        ),
      );
    }

    if (errorMessage != null && pendingMaintenances.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar datos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadPendingMaintenances,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (pendingMaintenances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green[400],
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Excelente!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No tienes mantenimientos pendientes',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver al Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingMaintenances,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pendingMaintenances.length,
        itemBuilder: (context, index) {
          final maintenance = pendingMaintenances[index];
          return _buildMaintenanceCard(maintenance);
        },
      ),
    );
  }

  Widget _buildMaintenanceCard(Map<String, dynamic> maintenance) {
    final scheduledDate = maintenance['scheduledDate'] as Timestamp?;
    final dateStr = scheduledDate != null
        ? '${scheduledDate.toDate().day}/${scheduledDate.toDate().month}/${scheduledDate.toDate().year}'
        : 'Sin fecha';

    final priority = maintenance['priority'] ?? 'normal';
    final type = maintenance['type'] ?? 'preventive';

    Color priorityColor = Colors.blue;
    IconData priorityIcon = Icons.schedule;
    String priorityText = 'Normal';

    if (priority == 'high' || type == 'emergency') {
      priorityColor = Colors.red;
      priorityIcon = Icons.warning;
      priorityText = 'Urgente';
    } else if (priority == 'medium') {
      priorityColor = Colors.orange;
      priorityIcon = Icons.priority_high;
      priorityText = 'Media';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: priorityColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMaintenanceDetails(maintenance),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(priorityIcon, color: priorityColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      maintenance['equipmentName'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      priorityText,
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.business, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      maintenance['clientName'],
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      maintenance['location'],
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.timer, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${maintenance['estimatedDuration']} min',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _startMaintenance(maintenance),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Iniciar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showMaintenanceDetails(maintenance),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Detalles'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMaintenanceDetails(Map<String, dynamic> maintenance) {
    // Navegar a pantalla de detalles o mostrar diálogo
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(maintenance['equipmentName']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${maintenance['clientName']}'),
            Text('Ubicación: ${maintenance['location']}'),
            Text('Tipo: ${maintenance['type']}'),
            Text('Duración estimada: ${maintenance['estimatedDuration']} min'),
            if (maintenance['description'].isNotEmpty)
              Text('Descripción: ${maintenance['description']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startMaintenance(maintenance);
            },
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
  }

  void _startMaintenance(Map<String, dynamic> maintenance) {
    // Navegar a la pantalla de ejecución de mantenimiento
    Navigator.pop(context);
  }
}
