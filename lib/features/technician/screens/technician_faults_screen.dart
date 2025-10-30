import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/core/models/fault_report_model.dart';
import 'package:intl/intl.dart';

class TechnicianFaultsScreen extends StatefulWidget {
  const TechnicianFaultsScreen({super.key});

  @override
  State<TechnicianFaultsScreen> createState() => _TechnicianFaultsScreenState();
}

class _TechnicianFaultsScreenState extends State<TechnicianFaultsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Reportes de Fallas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Mis Asignadas'),
            Tab(text: 'Completadas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingFaults(),
          _buildMyAssignedFaults(),
          _buildCompletedFaults(),
        ],
      ),
    );
  }

  // Tab 1: Fallas Pendientes (sin asignar)
  // ULTRA-SIMPLIFICADO: Solo filtra por status (índice automático)
  Widget _buildPendingFaults() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('faultReports')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filtrar y ordenar en memoria
        final allFaults = snapshot.data?.docs ?? [];
        final pendingFaults = allFaults.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['assignedTechnicianId'] == null;
        }).toList();

        // Ordenar por fecha en memoria
        pendingFaults.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['reportedAt'] as Timestamp?;
          final bTime = bData['reportedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Más reciente primero
        });

        if (pendingFaults.isEmpty) {
          return _buildEmptyView(
            icon: Icons.check_circle_outline,
            title: 'No hay fallas pendientes',
            subtitle: '¡Excelente! Todo está bajo control',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingFaults.length,
          itemBuilder: (context, index) {
            final fault = FaultReport.fromFirestore(pendingFaults[index]);
            return _buildFaultCard(
              fault: fault,
              showAssignButton: true,
            );
          },
        );
      },
    );
  }

  // Tab 2: Mis Fallas Asignadas
  // ULTRA-SIMPLIFICADO: Solo filtra por técnico (índice automático)
  Widget _buildMyAssignedFaults() {
    final currentUserId = _auth.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('faultReports')
          .where('assignedTechnicianId', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filtrar y ordenar en memoria
        final allFaults = snapshot.data?.docs ?? [];
        final assignedFaults = allFaults.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          return status == 'pending' || status == 'in_progress';
        }).toList();

        // Ordenar por fecha en memoria
        assignedFaults.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['reportedAt'] as Timestamp?;
          final bTime = bData['reportedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (assignedFaults.isEmpty) {
          return _buildEmptyView(
            icon: Icons.assignment_outlined,
            title: 'No tienes fallas asignadas',
            subtitle: 'Las fallas que te asignes aparecerán aquí',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: assignedFaults.length,
          itemBuilder: (context, index) {
            final fault = FaultReport.fromFirestore(assignedFaults[index]);
            return _buildFaultCard(
              fault: fault,
              showActionButtons: true,
            );
          },
        );
      },
    );
  }

  // Tab 3: Fallas Completadas
  // ULTRA-SIMPLIFICADO: Solo filtra por técnico (índice automático)
  Widget _buildCompletedFaults() {
    final currentUserId = _auth.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('faultReports')
          .where('assignedTechnicianId', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filtrar y ordenar en memoria
        final allFaults = snapshot.data?.docs ?? [];
        final completedFaults = allFaults.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'resolved';
        }).toList();

        // Ordenar por fecha de resolución en memoria
        completedFaults.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['resolvedAt'] as Timestamp? ??
              aData['reportedAt'] as Timestamp?;
          final bTime = bData['resolvedAt'] as Timestamp? ??
              bData['reportedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        // Limitar a las últimas 20
        final limitedFaults = completedFaults.take(20).toList();

        if (limitedFaults.isEmpty) {
          return _buildEmptyView(
            icon: Icons.task_alt,
            title: 'Aún no has completado fallas',
            subtitle: 'Las fallas resueltas aparecerán aquí',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: limitedFaults.length,
          itemBuilder: (context, index) {
            final fault = FaultReport.fromFirestore(limitedFaults[index]);
            return _buildFaultCard(fault: fault);
          },
        );
      },
    );
  }

  Widget _buildFaultCard({
    required FaultReport fault,
    bool showAssignButton = false,
    bool showActionButtons = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(fault),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con severidad y estado
              Row(
                children: [
                  _buildSeverityBadge(fault.severity),
                  const SizedBox(width: 8),
                  _buildStatusBadge(fault.status),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 12),

              // Equipo
              Row(
                children: [
                  Icon(Icons.build_circle, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${fault.equipmentNumber} - ${fault.equipmentName}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Cliente
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    fault.clientName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Descripción
              Text(
                fault.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Footer
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Reportado ${fault.timeElapsed}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (fault.severity == 'CRITICA')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.priority_high,
                              size: 12, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            '¡URGENTE!',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Botones de acción
              if (showAssignButton || showActionButtons) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
              ],

              if (showAssignButton)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _assignToMe(fault),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Asignarme esta falla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

              if (showActionButtons)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateStatus(fault, 'in_progress'),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Iniciar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showResolveDialog(fault),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Resolver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildSeverityBadge(String severity) {
    Color color;
    switch (severity.toUpperCase()) {
      case 'CRITICA':
        color = Colors.red;
        break;
      case 'ALTA':
        color = Colors.deepOrange;
        break;
      case 'MEDIA':
        color = Colors.orange;
        break;
      case 'BAJA':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            severity,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'resolved':
        color = Colors.green;
        label = 'Resuelto';
        icon = Icons.check_circle;
        break;
      case 'in_progress':
        color = Colors.blue;
        label = 'En Proceso';
        icon = Icons.autorenew;
        break;
      case 'pending':
      default:
        color = Colors.orange;
        label = 'Pendiente';
        icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // Asignar falla al técnico actual
  Future<void> _assignToMe(FaultReport fault) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Obtener nombre del técnico
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final technicianName = userDoc.data()?['name'] ?? '';

      // Actualizar falla
      await _firestore.collection('faultReports').doc(fault.id).update({
        'assignedTechnicianId': currentUser.uid,
        'assignedTechnicianName': technicianName,
        'respondedAt': FieldValue.serverTimestamp(),
        'status': 'in_progress',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Falla asignada exitosamente!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Actualizar estado de la falla
  Future<void> _updateStatus(FaultReport fault, String newStatus) async {
    try {
      await _firestore.collection('faultReports').doc(fault.id).update({
        'status': newStatus,
        if (newStatus == 'in_progress')
          'respondedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estado actualizado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mostrar diálogo para resolver falla
  Future<void> _showResolveDialog(FaultReport fault) async {
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolver Falla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Deseas marcar esta falla como resuelta?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Describe lo que hiciste para resolver la falla',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Resolver'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _resolveFault(fault, notesController.text.trim());
    }

    notesController.dispose();
  }

  // Resolver falla
  Future<void> _resolveFault(FaultReport fault, String notes) async {
    try {
      await _firestore.collection('faultReports').doc(fault.id).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        if (notes.isNotEmpty) 'responseNotes': notes,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Falla resuelta exitosamente!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToDetail(FaultReport fault) {
    // TODO: Implementar pantalla de detalle
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pantalla de detalle próximamente'),
      ),
    );
  }
}
