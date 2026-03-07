import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CompletedMaintenancesScreen extends StatefulWidget {
  const CompletedMaintenancesScreen({super.key});

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
      userRole = 'technician';
    }
  }

  Future<void> _loadCompletedMaintenances() async {
    if (currentUserId == null) return;
    setState(() => isLoading = true);

    try {
      Query query = _firestore.collection('maintenanceSchedules');

      if (userRole == 'technician') {
        query = query.where('technicianId', isEqualTo: currentUserId);
      }
      query = query.where('status', whereIn: ['executed', 'completed']);

      QuerySnapshot querySnapshot = await query.get();

      List<Map<String, dynamic>> allDocs = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        DateTime? completedDate;
        if (data['completedAt'] != null) {
          completedDate = (data['completedAt'] as Timestamp).toDate();
        } else if (data['completedDate'] != null) {
          completedDate = (data['completedDate'] as Timestamp).toDate();
        } else if (data['updatedAt'] != null) {
          completedDate = (data['updatedAt'] as Timestamp).toDate();
        } else if (data['startedAt'] != null) {
          completedDate = (data['startedAt'] as Timestamp).toDate();
        } else if (data['scheduledDate'] != null) {
          completedDate = (data['scheduledDate'] as Timestamp).toDate();
        }

        return {
          'id': doc.id,
          ...data,
          '_sortDate': completedDate ?? DateTime(2020),
        };
      }).toList();

      if (startDate != null) {
        allDocs = allDocs.where((doc) {
          final sortDate = doc['_sortDate'] as DateTime;
          return sortDate.isAfter(startDate!) ||
              sortDate.isAtSameMomentAs(startDate!);
        }).toList();
      }

      if (endDate != null) {
        final endDateTime =
            DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
        allDocs = allDocs.where((doc) {
          final sortDate = doc['_sortDate'] as DateTime;
          return sortDate.isBefore(endDateTime) ||
              sortDate.isAtSameMomentAs(endDateTime);
        }).toList();
      }

      allDocs.sort((a, b) {
        final dateA = a['_sortDate'] as DateTime;
        final dateB = b['_sortDate'] as DateTime;
        return dateB.compareTo(dateA);
      });

      completedMaintenances = allDocs.map((doc) {
        doc.remove('_sortDate');
        return doc;
      }).toList();
    } catch (e) {
      _showErrorMessage('Error al cargar mantenimientos completados: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadCompletedMaintenances();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Lista actualizada'),
                      duration: Duration(seconds: 1)),
                );
              }
            },
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Cargando mantenimientos completados...'),
                      ],
                    ),
                  )
                : completedMaintenances.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadCompletedMaintenances,
                        child: _buildMaintenancesList(),
                      ),
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
              offset: const Offset(0, 1))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.filter_alt, color: Colors.grey),
                const SizedBox(width: 8),
                Text(_getFilterText(),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${completedMaintenances.length} resultado${completedMaintenances.length != 1 ? 's' : ''}',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay mantenimientos completados',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              selectedPeriod == 'all'
                  ? 'Los mantenimientos completados aparecerán aquí'
                  : 'No hay mantenimientos en el período seleccionado',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (selectedPeriod != 'all')
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    selectedPeriod = 'all';
                    startDate = null;
                    endDate = null;
                  });
                  _loadCompletedMaintenances();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Mostrar todos'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenancesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedMaintenances.length,
      itemBuilder: (context, index) =>
          _buildMaintenanceCard(completedMaintenances[index]),
    );
  }

  Widget _buildMaintenanceCard(Map<String, dynamic> maintenance) {
    DateTime? completedDate;
    if (maintenance['completedAt'] != null) {
      completedDate = (maintenance['completedAt'] as Timestamp).toDate();
    } else if (maintenance['completedDate'] != null) {
      completedDate = (maintenance['completedDate'] as Timestamp).toDate();
    } else if (maintenance['updatedAt'] != null) {
      completedDate = (maintenance['updatedAt'] as Timestamp).toDate();
    } else if (maintenance['startedAt'] != null) {
      completedDate = (maintenance['startedAt'] as Timestamp).toDate();
    }

    final scheduledDate = maintenance['scheduledDate'] != null
        ? (maintenance['scheduledDate'] as Timestamp).toDate()
        : null;

    num completionPercentage = maintenance['completionPercentage'] ?? 100;

    if (completionPercentage == 0) {
      final tasks = maintenance['tasks'] as List? ?? [];
      final taskCompletion = maintenance['taskCompletion'] as Map? ?? {};
      if (tasks.isNotEmpty && taskCompletion.isNotEmpty) {
        int completedTasks = 0;
        for (String task in tasks) {
          if (taskCompletion[task] == true) completedTasks++;
        }
        completionPercentage = ((completedTasks / tasks.length) * 100).round();
      } else if (maintenance['status'] == 'completed' ||
          maintenance['status'] == 'executed') {
        completionPercentage = 100;
      }
    }

    final photoCount = (maintenance['photoUrls'] as List?)?.length ?? 0;
    final notes = maintenance['notes'] as String? ??
        maintenance['technicianNotes'] as String? ??
        '';

    // ── Calcular eficiencia para la tarjeta ──
    double? cardEfficiency;
    String cardEffLabel = '';
    Color cardEffColor = Colors.grey;

    if (scheduledDate != null) {
      DateTime? startedAtCard;
      DateTime? completedDateCard;
      if (maintenance['startedAt'] != null) {
        startedAtCard = (maintenance['startedAt'] as Timestamp).toDate();
      }
      if (maintenance['completedAt'] != null) {
        completedDateCard = (maintenance['completedAt'] as Timestamp).toDate();
      } else if (maintenance['completedDate'] != null) {
        completedDateCard =
            (maintenance['completedDate'] as Timestamp).toDate();
      }
      final estHrs = (maintenance['estimatedHours'] as num?)?.toDouble() ?? 0.0;
      if (startedAtCard != null && completedDateCard != null && estHrs > 0) {
        final realH =
            completedDateCard.difference(startedAtCard).inMinutes / 60;
        cardEfficiency = (realH / estHrs) * 100;
        if (cardEfficiency >= 85 && cardEfficiency <= 115) {
          cardEffLabel = 'Eficiente';
          cardEffColor = Colors.green;
        } else if (cardEfficiency >= 50 && cardEfficiency < 85) {
          cardEffLabel = 'Regular';
          cardEffColor = Colors.blue;
        } else if (cardEfficiency < 50) {
          cardEffLabel = 'Revisar';
          cardEffColor = Colors.orange;
        } else {
          cardEffLabel = 'Deficiente';
          cardEffColor = Colors.red;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: const Color(0xFF4CAF50).withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        onTap: () => _showMaintenanceDetails(maintenance),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: izquierda info / derecha badge+círculo ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF4CAF50), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maintenance['equipmentName'] ?? 'Equipo sin nombre',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          maintenance['clientName'] ?? 'Cliente',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        // Ubicación
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                maintenance['location'] ?? 'Sin ubicación',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (scheduledDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.schedule,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Programado: ${DateFormat('dd/MM/yy HH:mm').format(scheduledDate)}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                        if (completedDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Completado: ${DateFormat('dd/MM/yy HH:mm').format(completedDate)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ✅ Columna derecha: COMPLETADO badge + círculo + etiqueta
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF4CAF50).withOpacity(0.3)),
                        ),
                        child: const Text('COMPLETADO',
                            style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (cardEfficiency != null) ...[
                        const SizedBox(height: 10),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 54,
                              height: 54,
                              child: CircularProgressIndicator(
                                value: (cardEfficiency / 100).clamp(0.0, 1.5),
                                strokeWidth: 5,
                                backgroundColor: Colors.grey[200],
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(cardEffColor),
                              ),
                            ),
                            Text(
                              '${cardEfficiency.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: cardEffColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cardEffLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cardEffColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildProgressBar(completionPercentage.toInt())),
                  if (photoCount > 0) ...[
                    const SizedBox(width: 12),
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
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          notes,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showMaintenanceDetails(maintenance),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Ver detalles'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4285F4),
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                  if (userRole == 'admin')
                    TextButton.icon(
                      onPressed: () => _generateMaintenancePDF(maintenance),
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('PDF'),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(int percentage) {
    final color = percentage == 100 ? const Color(0xFF4CAF50) : Colors.orange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Progreso',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            Text('$percentage%',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  void _showMaintenanceDetails(Map<String, dynamic> maintenance) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: Column(
            children: [
              // Header verde
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
                            fontWeight: FontWeight.bold),
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
                  child: _buildDetailContent(maintenance),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailContent(Map<String, dynamic> maintenance) {
    final tasks = maintenance['tasks'] as List? ?? [];
    final taskCompletion = maintenance['taskCompletion'] as Map? ?? {};
    final skipReasons = (maintenance['skipReasons'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
        {};
    final photoUrls = maintenance['photoUrls'] as List? ?? [];

    // ── Fechas y duración ──
    DateTime? scheduledDate;
    DateTime? startedAt;
    DateTime? completedDate;

    if (maintenance['scheduledDate'] != null) {
      scheduledDate = (maintenance['scheduledDate'] as Timestamp).toDate();
    }
    if (maintenance['startedAt'] != null) {
      startedAt = (maintenance['startedAt'] as Timestamp).toDate();
    }
    if (maintenance['completedAt'] != null) {
      completedDate = (maintenance['completedAt'] as Timestamp).toDate();
    } else if (maintenance['completedDate'] != null) {
      completedDate = (maintenance['completedDate'] as Timestamp).toDate();
    }

    final estimatedHours =
        (maintenance['estimatedHours'] as num?)?.toDouble() ?? 0.0;

    final estimatedText = estimatedHours > 0
        ? '${estimatedHours.toStringAsFixed(1)} hrs'
        : 'No especificado';

    // ── Calcular eficiencia ──
    double? efficiency;
    String efficiencyLabel = '';
    Color efficiencyColor = Colors.grey;
    IconData efficiencyIcon = Icons.help_outline;

    if (startedAt != null && completedDate != null && estimatedHours > 0) {
      final realDuration = completedDate.difference(startedAt);
      final realHours = realDuration.inMinutes / 60;
      efficiency = (realHours / estimatedHours) * 100;

      if (efficiency >= 85 && efficiency <= 115) {
        efficiencyLabel = 'Eficiente (Excelente)';
        efficiencyColor = Colors.green;
        efficiencyIcon = Icons.check_circle;
      } else if (efficiency >= 50 && efficiency < 85) {
        efficiencyLabel = 'Regular';
        efficiencyColor = Colors.blue;
        efficiencyIcon = Icons.bolt;
      } else if (efficiency < 50) {
        efficiencyLabel = 'Regular — revisar calidad';
        efficiencyColor = Colors.orange;
        efficiencyIcon = Icons.warning_amber;
      } else {
        efficiencyLabel = 'Deficiente';
        efficiencyColor = Colors.red;
        efficiencyIcon = Icons.schedule;
      }
    }

    final notes = maintenance['notes'] as String? ??
        maintenance['technicianNotes'] as String? ??
        '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── INFORMACIÓN GENERAL ──
        _buildDetailSection('Información General', [
          _buildDetailRow('Cliente', maintenance['clientName']),
          _buildDetailRow('Ubicación', maintenance['location']),
          _buildDetailRow('Equipo', maintenance['equipmentName']),
          _buildDetailRow('Categoría', maintenance['equipmentCategory']),
          if (maintenance['technicianName'] != null)
            _buildDetailRow('Técnico', maintenance['technicianName']),
        ]),

        const SizedBox(height: 16),

        // ── FECHAS ──
        _buildDetailSection('Fechas', [
          // Programado + badge tiempo estimado
          if (scheduledDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text('Programado:',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(scheduledDate),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (estimatedHours > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 13, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            estimatedText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          // Iniciado
          if (startedAt != null)
            _buildDetailRow(
                'Iniciado', DateFormat('dd/MM/yyyy HH:mm').format(startedAt)),
          // Completado + badge duración real
          if (completedDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text('Completado:',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(completedDate),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (startedAt != null)
                    Builder(builder: (context) {
                      final dur = completedDate!.difference(startedAt!);
                      final h = dur.inHours;
                      final m = dur.inMinutes.remainder(60);
                      final dText = h > 0 ? '${h}h ${m}min' : '${m}min';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule,
                                size: 13, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              dText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
        ]),

        // ── NOTAS ──
        if (notes.isNotEmpty)
          _buildDetailSection('Notas', [
            Text(notes, style: const TextStyle(fontSize: 14, height: 1.5)),
          ]),

        if (notes.isNotEmpty) const SizedBox(height: 16),

        // ── TAREAS ──
        if (tasks.isNotEmpty) ...[
          _buildDetailSection('Tareas Realizadas', [
            ...tasks.map((task) => _buildTaskRow(
                  task.toString(),
                  taskCompletion[task.toString()] == true,
                  skipReasons[task.toString()],
                )),
          ]),
          const SizedBox(height: 16),
        ],

        // ── FOTOS ──
        if (photoUrls.isNotEmpty) ...[
          _buildDetailSection('Evidencias Fotográficas', [
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: photoUrls.length,
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _showFullScreenImage(context, photoUrls[index]),
                  child: Image.network(
                    photoUrls[index],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.red)),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ],
    );
  }

  // ✅ Círculo de eficiencia con etiqueta debajo
  Widget _buildEfficiencyWidget(
      double efficiency, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          // Círculo con porcentaje + etiqueta debajo
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: (efficiency / 100).clamp(0.0, 1.5),
                      strokeWidth: 5,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Text(
                    '${efficiency.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 70,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Detalle a la derecha
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Eficiencia del Técnico',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _efficiencyDescription(efficiency),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600], height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _efficiencyDescription(double e) {
    if (e >= 85 && e <= 115) {
      return 'Completado dentro del tiempo estimado ✓ (Excelente)';
    } else if (e >= 50 && e < 85) {
      return 'Regular — más rápido de lo esperado.\nFavor prestar atención a los detalles.';
    } else if (e < 50) {
      return 'Muy rápido — favor revisar calidad del trabajo.';
    } else {
      return 'Deficiente — Tomó más tiempo de lo estimado.\nAgradecemos que prestes atención a los detalles.';
    }
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50))),
        const Divider(height: 12),
        const SizedBox(height: 4),
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
            width: 110,
            child: Text('$label:',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value ?? 'No especificado',
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ✅ Tarea con razón de no ejecución
  Widget _buildTaskRow(String task, bool completed, String? skipReason) {
    final wasSkipped = skipReason != null && skipReason.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: wasSkipped
              ? Colors.red[50]
              : completed
                  ? Colors.green[50]
                  : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: wasSkipped
                ? Colors.red[200]!
                : completed
                    ? Colors.green[200]!
                    : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    wasSkipped
                        ? Icons.block
                        : completed
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                    size: 18,
                    color: wasSkipped
                        ? Colors.red[600]
                        : completed
                            ? const Color(0xFF4CAF50)
                            : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      task,
                      style: TextStyle(
                        fontSize: 13,
                        color: wasSkipped
                            ? Colors.red[800]
                            : completed
                                ? Colors.grey[600]
                                : Colors.black87,
                      ),
                    ),
                  ),
                  // Badge de estado
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: wasSkipped
                          ? Colors.red[100]
                          : completed
                              ? Colors.green[100]
                              : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      wasSkipped
                          ? 'No realizada'
                          : completed
                              ? 'Completada'
                              : 'Pendiente',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: wasSkipped
                            ? Colors.red[700]
                            : completed
                                ? Colors.green[700]
                                : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ✅ Razón del técnico si la hay
            if (wasSkipped) ...[
              Divider(height: 1, color: Colors.red[200]),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.red[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motivo reportado por el técnico:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            skipReason,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red[900],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
                onChanged: (v) => setDialogState(() => selectedPeriod = v!),
              ),
              RadioListTile<String>(
                title: const Text('Última semana'),
                value: 'week',
                groupValue: selectedPeriod,
                onChanged: (v) => setDialogState(() => selectedPeriod = v!),
              ),
              RadioListTile<String>(
                title: const Text('Último mes'),
                value: 'month',
                groupValue: selectedPeriod,
                onChanged: (v) => setDialogState(() => selectedPeriod = v!),
              ),
              RadioListTile<String>(
                title: const Text('Período personalizado'),
                value: 'custom',
                groupValue: selectedPeriod,
                onChanged: (v) => setDialogState(() => selectedPeriod = v!),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white),
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

  void _generatePDFReport() => _showComingSoon('Reporte PDF general');

  void _generateMaintenancePDF(Map<String, dynamic> maintenance) =>
      _showComingSoon('PDF del mantenimiento');

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature estará disponible pronto'),
        backgroundColor: const Color(0xFF4285F4),
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3)),
      );
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.white, size: 48),
                        SizedBox(height: 8),
                        Text('Error al cargar imagen',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
