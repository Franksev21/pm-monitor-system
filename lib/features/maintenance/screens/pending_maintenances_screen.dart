import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pm_monitor/features/maintenance/screens/maintenance_execution_screen.dart';

class PendingMaintenancesScreen extends StatefulWidget {
  @override
  _PendingMaintenancesScreenState createState() =>
      _PendingMaintenancesScreenState();
}

class _PendingMaintenancesScreenState extends State<PendingMaintenancesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> pendingMaintenances = [];
  List<Map<String, dynamic>> allMaintenances = [];
  bool isLoading = true;
  String? currentUserId;
  String? currentUserEmail;

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser?.uid;
    currentUserEmail = _auth.currentUser?.email;
    _loadPendingMaintenances();
  }

  Future<void> _loadPendingMaintenances() async {
    if (currentUserId == null) return;

    setState(() => isLoading = true);

    try {
      // Debug: Primero obtener TODOS los mantenimientos para ver qué hay
      QuerySnapshot allMaintenancesSnapshot =
          await _firestore.collection('maintenanceSchedules').get();

      allMaintenances = allMaintenancesSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Ahora la consulta original
      QuerySnapshot querySnapshot = await _firestore
          .collection('maintenanceSchedules')
          .where('technicianId', isEqualTo: currentUserId)
          .where('status', whereIn: ['scheduled', 'in_progress']).get();

      print(
          'Filtered maintenances for current user: ${querySnapshot.docs.length}');

      pendingMaintenances = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Si no hay resultados, intentar una consulta alternativa
      if (pendingMaintenances.isEmpty) {
        print('No maintenances found, trying alternative queries...');

        // Intentar buscar por email del técnico
        QuerySnapshot emailQuery = await _firestore
            .collection('maintenanceSchedules')
            .where('technicianEmail', isEqualTo: currentUserEmail)
            .where('status', whereIn: ['scheduled', 'in_progress']).get();

        print('Maintenances found by email: ${emailQuery.docs.length}');

        if (emailQuery.docs.isNotEmpty) {
          pendingMaintenances = emailQuery.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
        }
      }
    } catch (e) {
      print('Error loading maintenances: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mantenimientos Pendientes'),
        backgroundColor: Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: pendingMaintenances.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: pendingMaintenances.length,
                          itemBuilder: (context, index) {
                            return _buildMaintenanceCard(
                                pendingMaintenances[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No tienes mantenimientos pendientes',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Los mantenimientos asignados aparecerán aquí',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadPendingMaintenances,
            child: Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(Map<String, dynamic> maintenance) {
    DateTime scheduledDate =
        (maintenance['scheduledDate'] as Timestamp).toDate();
    String status = maintenance['status'] ?? 'scheduled';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _showDetails(maintenance),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maintenance['equipmentName'] ?? 'Equipo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          maintenance['clientName'] ?? 'Cliente',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          status == 'in_progress' ? Colors.orange : Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status == 'in_progress' ? 'EN PROGRESO' : 'PROGRAMADO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(scheduledDate),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              if (maintenance['location'] != null) ...[
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      maintenance['location'],
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'scheduled')
                    ElevatedButton(
                      onPressed: () => _startMaintenance(maintenance['id']),
                      child: Text('Iniciar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  if (status == 'in_progress') ...[
                    ElevatedButton(
                      onPressed: () => _executeMaintenanceButton(maintenance),
                      child: Text('Ejecutar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _completeMaintenance(maintenance['id']),
                      child: Text('Completar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> maintenance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(maintenance['equipmentName'] ?? 'Mantenimiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${maintenance['clientName'] ?? ''}'),
            Text('Ubicación: ${maintenance['location'] ?? ''}'),
            Text(
                'Duración: ${maintenance['estimatedDurationMinutes'] ?? 0} min'),
            Text('Técnico ID: ${maintenance['technicianId'] ?? ''}'),
            Text('Técnico Nombre: ${maintenance['technicianName'] ?? ''}'),
            if (maintenance['tasks'] != null) ...[
              SizedBox(height: 8),
              Text('Tareas:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...((maintenance['tasks'] as List)
                  .map((task) => Text('• $task'))),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _startMaintenance(String maintenanceId) async {
    try {
      await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .update({
        'status': 'in_progress',
        'startedAt': Timestamp.now(),
      });

      _loadPendingMaintenances();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mantenimiento iniciado')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _executeMaintenanceButton(Map<String, dynamic> maintenance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MaintenanceExecutionScreen(maintenance: maintenance),
      ),
    ).then((completed) {
      if (completed == true) {
        _loadPendingMaintenances();
      }
    });
  }

  Future<void> _completeMaintenance(String maintenanceId) async {
    try {
      await _firestore
          .collection('maintenanceSchedules')
          .doc(maintenanceId)
          .update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
      });

      _loadPendingMaintenances();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mantenimiento completado')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
