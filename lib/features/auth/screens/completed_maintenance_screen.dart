import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CompletedMaintenancesScreen extends StatefulWidget {
  @override
  _CompletedMaintenancesScreenState createState() =>
      _CompletedMaintenancesScreenState();
}

class _CompletedMaintenancesScreenState
    extends State<CompletedMaintenancesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> completedMaintenances = [];
  bool isLoading = true;
  String? currentUserId;
  String? userRole;

  // Filtros
  DateTime? startDate;
  DateTime? endDate;
  String selectedPeriod = 'all';

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser?.uid;
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _getUserRole();
    await _loadCompletedMaintenances();
  }

  Future<void> _getUserRole() async {
    if (currentUserId == null) return;

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        userRole = userData['role'] ?? 'technician';
      } else {
        userRole = 'technician';
      }
    } catch (e) {
      print('Error getting user role: $e');
      userRole = 'technician';
    }
  }

  Future<void> _loadCompletedMaintenances() async {
    if (currentUserId == null) return;

    setState(() => isLoading = true);

    try {
      Query query = _firestore
          .collection('maintenanceSchedules')
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true);

      // Solo técnicos ven sus propios mantenimientos
      if (userRole == 'technician') {
        query = query.where('technicianId', isEqualTo: currentUserId);
      }

      // Aplicar filtros de fecha
      if (startDate != null) {
        query = query.where('completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!));
      }
      if (endDate != null) {
        query = query.where('completedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
      }

      QuerySnapshot querySnapshot = await query.get();

      completedMaintenances = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error loading completed maintenances: $e');
      _showErrorMessage('Error al cargar mantenimientos completados');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenimientos Completados'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          if (userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _generatePDFReport,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersBar(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : completedMaintenances.isEmpty
                    ? _buildEmptyState()
                    : _buildMaintenancesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.filter_alt, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _getFilterText(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${completedMaintenances.length} resultado${completedMaintenances.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _getFilterText() {
    switch (selectedPeriod) {
      case 'week':
        return 'Última semana';
      case 'month':
        return 'Último mes';
      case 'custom':
        if (startDate != null && endDate != null) {
          return '${DateFormat('dd/MM/yy').format(startDate!)} - ${DateFormat('dd/MM/yy').format(endDate!)}';
        }
        return 'Período personalizado';
      default:
        return 'Todos los períodos';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay mantenimientos completados',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedPeriod == 'all'
                ? 'Los mantenimientos completados aparecerán aquí'
                : 'No hay mantenimientos en el período seleccionado',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                selectedPeriod = 'all';
                startDate = null;
                endDate = null;
              });
              _loadCompletedMaintenances();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Mostrar todos'),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenancesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedMaintenances.length,
      itemBuilder: (context, index) {
        return _buildMaintenanceCard(completedMaintenances[index]);
      },
    );
  }

  Widget _buildMaintenanceCard(Map<String, dynamic> maintenance) {
    // Obtener fechas de manera flexible
    DateTime? completedDate;
    if (maintenance['completedAt'] != null) {
      completedDate = (maintenance['completedAt'] as Timestamp).toDate();
    } else if (maintenance['startedAt'] != null) {
      completedDate = (maintenance['startedAt'] as Timestamp).toDate();
    }

    final scheduledDate = maintenance['scheduledDate'] != null
        ? (maintenance['scheduledDate'] as Timestamp).toDate()
        : null;

    // Calcular progreso dinámicamente
    num completionPercentage = maintenance['completionPercentage'] ?? 0;

    // Si no hay percentage o es 0, intentar calcularlo de las tareas
    if (completionPercentage == 0) {
      final tasks = maintenance['tasks'] as List? ?? [];
      final taskCompletion = maintenance['taskCompletion'] as Map? ?? {};

      if (tasks.isNotEmpty && taskCompletion.isNotEmpty) {
        int completedTasks = 0;
        for (String task in tasks) {
          if (taskCompletion[task] == true) {
            completedTasks++;
          }
        }
        completionPercentage = ((completedTasks / tasks.length) * 100).round();
      } else if (maintenance['status'] == 'completed') {
        // Si está marcado como completado pero no hay datos de tareas, asumir 100%
        completionPercentage = 100;
      }
    }

    final photoCount = (maintenance['photoUrls'] as List?)?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showMaintenanceDetails(maintenance),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maintenance['equipmentName'] ?? 'Equipo',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          maintenance['clientName'] ?? 'Cliente',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (userRole == 'admin' &&
                            maintenance['technicianName'] != null)
                          Text(
                            'Técnico: ${maintenance['technicianName']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'COMPLETADO',
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (scheduledDate != null)
                _buildInfoChip(
                  Icons.schedule,
                  'Programado: ${DateFormat('dd/MM/yy HH:mm').format(scheduledDate)}',
                ),
              const SizedBox(height: 4),
              if (completedDate != null)
                _buildInfoChip(
                  Icons.check_circle,
                  'Completado: ${DateFormat('dd/MM/yy HH:mm').format(completedDate)}',
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildProgressIndicator(completionPercentage.toInt()),
                  ),
                  const SizedBox(width: 12),
                  if (photoCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt,
                              size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '$photoCount foto${photoCount != 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (userRole == 'admin') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _generateMaintenancePDF(maintenance),
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('PDF'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showMaintenanceDetails(maintenance),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('Ver detalles'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4285F4),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(int percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Progreso',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color:
                    percentage == 100 ? const Color(0xFF4CAF50) : Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            percentage == 100 ? const Color(0xFF4CAF50) : Colors.orange,
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar mantenimientos'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Todos'),
                value: 'all',
                groupValue: selectedPeriod,
                onChanged: (value) =>
                    setDialogState(() => selectedPeriod = value!),
              ),
              RadioListTile<String>(
                title: const Text('Última semana'),
                value: 'week',
                groupValue: selectedPeriod,
                onChanged: (value) =>
                    setDialogState(() => selectedPeriod = value!),
              ),
              RadioListTile<String>(
                title: const Text('Último mes'),
                value: 'month',
                groupValue: selectedPeriod,
                onChanged: (value) =>
                    setDialogState(() => selectedPeriod = value!),
              ),
              RadioListTile<String>(
                title: const Text('Período personalizado'),
                value: 'custom',
                groupValue: selectedPeriod,
                onChanged: (value) =>
                    setDialogState(() => selectedPeriod = value!),
              ),
              if (selectedPeriod == 'custom') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setDialogState(() => startDate = date);
                          }
                        },
                        child: Text(startDate != null
                            ? DateFormat('dd/MM/yyyy').format(startDate!)
                            : 'Fecha inicio'),
                      ),
                    ),
                    const Text(' - '),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: startDate ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setDialogState(() => endDate = date);
                          }
                        },
                        child: Text(endDate != null
                            ? DateFormat('dd/MM/yyyy').format(endDate!)
                            : 'Fecha fin'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    final now = DateTime.now();

    switch (selectedPeriod) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
        break;
      case 'month':
        startDate = DateTime(now.year, now.month - 1, now.day);
        endDate = now;
        break;
      case 'all':
        startDate = null;
        endDate = null;
        break;
    }

    _loadCompletedMaintenances();
  }

  void _showMaintenanceDetails(Map<String, dynamic> maintenance) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        maintenance['equipmentName'] ?? 'Mantenimiento',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildMaintenanceDetailContent(maintenance),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaintenanceDetailContent(Map<String, dynamic> maintenance) {
    final tasks = maintenance['tasks'] as List? ?? [];
    final taskCompletion = maintenance['taskCompletion'] as Map? ?? {};
    final photoUrls = maintenance['photoUrls'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailSection('Información General', [
          _buildDetailRow('Cliente', maintenance['clientName']),
          _buildDetailRow('Ubicación', maintenance['location']),
          _buildDetailRow('Técnico', maintenance['technicianName']),
          _buildDetailRow('Duración estimada',
              '${maintenance['estimatedDurationMinutes'] ?? 0} min'),
          if (maintenance['notes'] != null)
            _buildDetailRow('Notas', maintenance['notes']),
        ]),
        const SizedBox(height: 20),
        _buildDetailSection('Fechas', [
          _buildDetailRow(
              'Programado', _formatDateTime(maintenance['scheduledDate'])),
          _buildDetailRow(
              'Completado', _formatDateTime(maintenance['completedAt'])),
        ]),
        const SizedBox(height: 20),
        if (tasks.isNotEmpty) ...[
          _buildDetailSection('Tareas Realizadas', [
            ...tasks.map((task) => _buildTaskRow(
                  task.toString(),
                  taskCompletion[task.toString()] == true,
                )),
          ]),
          const SizedBox(height: 20),
        ],
        if (photoUrls.isNotEmpty) ...[
          _buildDetailSection('Evidencias Fotográficas', [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: photoUrls.length,
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: const Center(
                  child: Icon(Icons.image, size: 40, color: Colors.grey),
                ),
              ),
            ),
          ]),
        ],
      ],
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value ?? 'No especificado'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(String task, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: completed ? const Color(0xFF4CAF50) : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task,
              style: TextStyle(
                decoration: completed ? TextDecoration.lineThrough : null,
                color: completed ? Colors.grey : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'No disponible';
    final dateTime = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.parse(timestamp.toString());
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  void _generatePDFReport() {
    _showComingSoon('Reporte PDF general');
  }

  void _generateMaintenancePDF(Map<String, dynamic> maintenance) {
    _showComingSoon('PDF del mantenimiento');
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature estará disponible pronto'),
        backgroundColor: const Color(0xFF4285F4),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
