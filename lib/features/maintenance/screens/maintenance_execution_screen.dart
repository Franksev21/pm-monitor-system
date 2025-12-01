import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:pm_monitor/core/services/maintenance_execution_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class MaintenanceExecutionScreen extends StatefulWidget {
  final Map<String, dynamic> maintenance;

  const MaintenanceExecutionScreen({super.key, required this.maintenance});

  @override
  _MaintenanceExecutionScreenState createState() =>
      _MaintenanceExecutionScreenState();
}

class _MaintenanceExecutionScreenState
    extends State<MaintenanceExecutionScreen> {
  final MaintenanceExecutionService _service = MaintenanceExecutionService();
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Map<String, String> taskSkipReasons = {};

  Map<String, bool> taskCompletion = {};
  List<File> selectedImages = [];
  bool isLoading = false;
  bool isSaving = false;
  Map<String, dynamic>? equipmentData;

  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _selectedCondition = 'Bueno';

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 Iniciando MaintenanceExecutionScreen');
    debugPrint('📦 Datos recibidos: ${widget.maintenance}');
    debugPrint('📎 photoUrls: ${widget.maintenance['photoUrls']}');
    _loadMaintenanceDetails();
  }

  Future<void> _loadMaintenanceDetails() async {
    setState(() => isLoading = true);

    try {
      debugPrint(
          '🔄 Cargando detalles del mantenimiento ID: ${widget.maintenance['id']}');

      List<dynamic> tasks = widget.maintenance['tasks'] ?? [];

      debugPrint(
          '📋 Tareas recibidas directamente: $tasks (${tasks.length} tareas)');

      if (tasks.isEmpty) {
        debugPrint(
            '⚠️ No hay tareas en los datos recibidos, cargando desde Firestore...');
        Map<String, dynamic>? details =
            await _service.getMaintenanceDetails(widget.maintenance['id']);

        if (details != null) {
          tasks = details['tasks'] ?? [];
          debugPrint(
              '📋 Tareas cargadas desde Firestore: $tasks (${tasks.length} tareas)');
        }
      }

      if (tasks.isEmpty) {
        String category = widget.maintenance['equipmentCategory'] ?? 'AC';
        debugPrint(
            '⚠️ Sin tareas específicas, cargando tareas por defecto para categoría: $category');
        tasks = await _service.getDefaultTasks(category);
        debugPrint(
            '📋 Tareas por defecto cargadas: $tasks (${tasks.length} tareas)');
      }

      _initializeTaskCompletion(tasks);

      if (widget.maintenance['equipmentId'] != null) {
        debugPrint(
            '🔧 Cargando datos del equipo ID: ${widget.maintenance['equipmentId']}');
        equipmentData =
            await _service.getEquipmentData(widget.maintenance['equipmentId']);

        if (equipmentData != null) {
          debugPrint('✅ Datos del equipo cargados: $equipmentData');
          _loadEquipmentData();
        } else {
          debugPrint('⚠️ No se encontraron datos del equipo');
        }
      }

      Map<String, dynamic>? savedProgress =
          await _service.getMaintenanceProgress(widget.maintenance['id']);

      if (savedProgress != null) {
        debugPrint('💾 Progreso previo encontrado');

        if (savedProgress['taskCompletion'] != null) {
          taskCompletion =
              Map<String, bool>.from(savedProgress['taskCompletion']);
          debugPrint(
              '✅ Tareas completadas previas cargadas: ${taskCompletion.length}');
        }

        if (savedProgress['notes'] != null) {
          _notesController.text = savedProgress['notes'];
        }
      }

      debugPrint('✅ Carga de detalles completada');
      debugPrint('📊 Resumen: ${taskCompletion.length} tareas inicializadas');
    } catch (e) {
      debugPrint('❌ Error cargando detalles del mantenimiento: $e');
      _showErrorDialog('Error cargando detalles del mantenimiento: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _initializeTaskCompletion(List<dynamic> tasks) {
    debugPrint('🔧 Inicializando ${tasks.length} tareas...');

    for (var task in tasks) {
      String taskKey = task.toString();
      if (!taskCompletion.containsKey(taskKey)) {
        taskCompletion[taskKey] = false;
        debugPrint('  ➕ Tarea agregada: $taskKey');
      }
    }

    debugPrint('✅ ${taskCompletion.length} tareas inicializadas');
  }

  void _loadEquipmentData() {
    if (equipmentData != null) {
      _capacityController.text = equipmentData!['capacity']?.toString() ?? '';
      _modelController.text = equipmentData!['model']?.toString() ?? '';
      _brandController.text = equipmentData!['brand']?.toString() ?? '';
      _locationController.text = equipmentData!['location']?.toString() ?? '';
      _selectedCondition = equipmentData!['condition']?.toString() ?? 'Bueno';

      debugPrint('✅ Datos del equipo cargados en controllers');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cargando...'),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando detalles del mantenimiento...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejecutar Mantenimiento'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: isSaving ? null : _saveProgress,
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ))
                : const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pause',
                child: Row(
                  children: [
                    Icon(Icons.pause, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Pausar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report_issue',
                child: Row(
                  children: [
                    Icon(Icons.report_problem, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Reportar Problema'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMaintenanceHeader(),
            const SizedBox(height: 20),
            _buildTaskChecklist(),
            const SizedBox(height: 20),
            _buildAttachedFiles(),
            const SizedBox(height: 20),
            _buildEquipmentDataSection(),
            const SizedBox(height: 20),
            _buildPhotosSection(),
            const SizedBox(height: 20),
            _buildNotesSection(),
            const SizedBox(height: 20),
            _buildProgressIndicator(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.maintenance['equipmentName'] ?? 'Equipo',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'EN EJECUCIÓN',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
                Icons.business, 'Cliente:', widget.maintenance['clientName']),
            _buildInfoRow(Icons.location_on, 'Ubicación:',
                widget.maintenance['location']),
            if (widget.maintenance['equipmentNumber'] != null)
              _buildInfoRow(Icons.tag, 'Equipo ID:',
                  widget.maintenance['equipmentNumber']),
            if (widget.maintenance['equipmentCategory'] != null)
              _buildInfoRow(Icons.category, 'Categoría:',
                  widget.maintenance['equipmentCategory']),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            '$label ',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'No especificado',
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskChecklist() {
    List<String> tasks = taskCompletion.keys.toList();
    int completedCount = taskCompletion.values.where((v) => v).length;
    bool allSelected = tasks.isNotEmpty && completedCount == tasks.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                const Text(
                  'Actividades a Realizar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '$completedCount/${tasks.length}',
                  style: const TextStyle(
                    color: Color(0xFF1976D2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      final newValue = !allSelected;
                      for (var task in tasks) {
                        if (!taskSkipReasons.containsKey(task)) {
                          taskCompletion[task] = newValue;
                        }
                      }
                    });
                  },
                  icon: Icon(
                    allSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 20,
                  ),
                  label: Text(allSelected
                      ? 'Deseleccionar Todas'
                      : 'Seleccionar Todas'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1976D2),
                    side: const BorderSide(color: Color(0xFF1976D2)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (tasks.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  border: Border.all(color: Colors.amber[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No hay tareas definidas para este mantenimiento.\nPuedes completarlo agregando fotos y notas.',
                        style: TextStyle(
                          color: Colors.amber[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...tasks.map((task) => _buildTaskItem(task)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(String task) {
    final isCompleted = taskCompletion[task] ?? false;
    final isSkipped = taskSkipReasons.containsKey(task);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      color: isSkipped ? Colors.red[50] : null,
      child: Column(
        children: [
          ListTile(
            leading: Checkbox(
              value: isCompleted,
              onChanged: isSkipped
                  ? null
                  : (bool? value) {
                      setState(() {
                        taskCompletion[task] = value ?? false;
                      });
                    },
              activeColor: const Color(0xFF1976D2),
            ),
            title: Text(
              task,
              style: TextStyle(
                fontSize: 14,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isSkipped
                    ? Colors.red[700]
                    : (isCompleted ? Colors.grey[600] : Colors.black87),
              ),
            ),
            trailing: isSkipped
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        taskSkipReasons.remove(task);
                        taskCompletion[task] = false;
                      });
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.block, color: Colors.red),
                    onPressed: () => _showSkipReasonDialog(task),
                    tooltip: 'No se pudo realizar',
                  ),
            dense: true,
          ),
          if (isSkipped) ...[
            const Divider(height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Text(
                        'No se pudo realizar:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    taskSkipReasons[task] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSkipReasonDialog(String task) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Por qué no se pudo realizar?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Ej: Falta material, equipo inaccesible...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  taskSkipReasons[task] = controller.text.trim();
                  taskCompletion[task] = false;
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachedFiles() {
    final photoUrls = widget.maintenance['photoUrls'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description, color: Color(0xFF2196F3)),
              const SizedBox(width: 8),
              const Text(
                'Instrucciones Adjuntas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (photoUrls.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${photoUrls.length}',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Documentos adjuntados por el administrador',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (photoUrls.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text(
                    'No hay archivos adjuntos',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: photoUrls.length,
              itemBuilder: (context, index) {
                final url = photoUrls[index] as String;
                final fileName = url.split('/').last.split('?').first;
                final isPdf = fileName.toLowerCase().endsWith('.pdf');

                return GestureDetector(
                  onTap: () => _showFilePreview(url, index),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isPdf ? Colors.red[50] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPdf ? Colors.red[200]! : Colors.grey[300]!,
                          ),
                        ),
                        child: isPdf
                            ? Center(
                                child: Icon(
                                  Icons.picture_as_pdf,
                                  size: 48,
                                  color: Colors.red[700],
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.error,
                                      color: Colors.red[300],
                                    );
                                  },
                                ),
                              ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.visibility,
                            size: 16,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ✅ ÚNICO MÉTODO DE VISTA PREVIA
  void _showFilePreview(String url, int index) async {
    final fileName = url.split('/').last.split('?').first;
    final isPdf = fileName.toLowerCase().endsWith('.pdf');

    if (isPdf) {
      // Vista previa de PDF con Syncfusion
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName.replaceAll('.pdf.pdf', '.pdf'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Vista previa PDF directamente desde URL
                Expanded(
                  child: SfPdfViewer.network(
                    url,
                    onDocumentLoadFailed: (details) {
                      debugPrint('❌ Error cargando PDF: ${details.error}');
                      debugPrint('❌ Descripción: ${details.description}');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Error cargando PDF: ${details.description}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Botón para abrir en navegador
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Abrir en navegador'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Vista previa de imagen
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.image),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(Icons.error,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text('Error cargando imagen'),
                            const SizedBox(height: 8),
                            Text(
                              error.toString(),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.link, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        url,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
  }

  Widget _buildEquipmentDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                const Text(
                  'Datos del Equipo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Opcional',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(_capacityController, 'Capacidad', Icons.speed),
            const SizedBox(height: 12),
            _buildTextField(_modelController, 'Modelo', Icons.info),
            const SizedBox(height: 12),
            _buildTextField(_brandController, 'Marca', Icons.business),
            const SizedBox(height: 12),
            _buildTextField(
                _locationController, 'Ubicación', Icons.location_on),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                const Text(
                  'Fotos de Evidencia',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  selectedImages.length < 3
                      ? 'Requerido (${selectedImages.length}/3)'
                      : '${selectedImages.length} foto(s)',
                  style: TextStyle(
                    color:
                        selectedImages.length < 3 ? Colors.red : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Tomar Foto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (selectedImages.isEmpty)
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.red[50],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.red[400], size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Se requieren al menos 3 fotos\npara completar el mantenimiento',
                      style: TextStyle(color: Colors.red[600], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          selectedImages[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removePhoto(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note_alt, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                const Text(
                  'Notas Adicionales',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Opcional',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Observaciones, problemas encontrados, recomendaciones...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    int totalTasks = taskCompletion.length;
    int completedTasks =
        taskCompletion.values.where((completed) => completed).length;
    double progress = totalTasks > 0 ? completedTasks / totalTasks : 0;
    bool hasPhotos = selectedImages.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                const Text(
                  'Progreso del Mantenimiento',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: progress == 1.0
                        ? Colors.green
                        : const Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : const Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 8),
            if (totalTasks > 0)
              Text(
                '$completedTasks de $totalTasks tareas completadas',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              Text(
                'Sin tareas definidas - Agregar fotos y notas',
                style: TextStyle(color: Colors.grey[600]),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  hasPhotos ? Icons.check_circle : Icons.camera_alt,
                  color: hasPhotos ? Colors.green : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  hasPhotos
                      ? '${selectedImages.length} foto(s) adjunta(s)'
                      : 'Fotos requeridas',
                  style: TextStyle(
                    color: hasPhotos ? Colors.green : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    int totalTasks = taskCompletion.length;
    int completedTasks =
        taskCompletion.values.where((completed) => completed).length;
    int skippedTasks = taskSkipReasons.length;

    bool hasEnoughPhotos = selectedImages.length >= 3;
    bool tasksRequirementMet = totalTasks == 0 ||
        completedTasks > 0 ||
        (completedTasks + skippedTasks) == totalTasks;

    bool canComplete = hasEnoughPhotos && tasksRequirementMet;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (isSaving || isLoading) ? null : _saveProgress,
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(isSaving ? 'Guardando...' : 'Guardar Progreso'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (canComplete && !isLoading && !isSaving)
                ? _completeMaintenance
                : null,
            icon: Icon(canComplete ? Icons.check_circle : Icons.lock),
            label: Text(canComplete
                ? 'Completar Mantenimiento'
                : 'Completa los requisitos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: canComplete ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        if (!canComplete)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                border: Border.all(color: Colors.amber[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Para completar necesitas:',
                          style: TextStyle(
                            color: Colors.amber[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (totalTasks > 0 &&
                            completedTasks == 0 &&
                            skippedTasks < totalTasks)
                          Text(
                            '• Completar al menos una tarea',
                            style: TextStyle(
                                color: Colors.amber[700], fontSize: 11),
                          ),
                        if (selectedImages.length < 3)
                          Text(
                            '• Agregar al menos 3 fotos de evidencia (${selectedImages.length}/3)',
                            style: TextStyle(
                                color: Colors.amber[700], fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'pause':
        _showPauseDialog();
        break;
      case 'report_issue':
        _showReportIssueDialog();
        break;
    }
  }

  void _showPauseDialog() {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pausar Mantenimiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Por qué deseas pausar este mantenimiento?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Razón de la pausa...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                bool success = await _service.pauseMaintenance(
                    widget.maintenance['id'], reasonController.text.trim());
                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mantenimiento pausado')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Pausar'),
          ),
        ],
      ),
    );
  }

  void _showReportIssueDialog() {
    TextEditingController issueController = TextEditingController();
    String selectedSeverity = 'Media';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Reportar Problema'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: issueController,
                decoration: const InputDecoration(
                  hintText: 'Describe el problema encontrado...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSeverity,
                decoration: const InputDecoration(
                  labelText: 'Severidad',
                  border: OutlineInputBorder(),
                ),
                items: ['Baja', 'Media', 'Alta', 'Crítica']
                    .map((severity) => DropdownMenuItem(
                          value: severity,
                          child: Text(severity),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSeverity = value ?? 'Media';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (issueController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  bool success = await _service.reportIssue(
                    widget.maintenance['id'],
                    issueController.text.trim(),
                    selectedSeverity,
                  );
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Problema reportado correctamente')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reportar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          selectedImages.add(File(photo.path));
        });
        debugPrint('📷 Foto agregada: ${selectedImages.length} fotos totales');
      }
    } catch (e) {
      debugPrint('❌ Error al capturar foto: $e');
      _showErrorDialog('Error al capturar foto: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      selectedImages.removeAt(index);
      debugPrint(
          '🗑️ Foto eliminada: ${selectedImages.length} fotos restantes');
    });
  }

  Future<void> _saveProgress() async {
    setState(() => isSaving = true);
    debugPrint('💾 Guardando progreso...');

    try {
      bool success = await _service.updateTaskProgress(
        widget.maintenance['id'],
        taskCompletion,
      );

      if (success) {
        debugPrint('✅ Progreso guardado correctamente');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Progreso guardado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Error al guardar progreso');
      }
    } catch (e) {
      debugPrint('❌ Error al guardar progreso: $e');
      _showErrorDialog('Error al guardar progreso: $e');
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> _completeMaintenance() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Completar Mantenimiento'),
        content: const Text(
            '¿Estás seguro de que deseas completar este mantenimiento? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Completar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);
    debugPrint('🏁 Completando mantenimiento...');

    try {
      Map<String, dynamic> equipmentDataToUpdate = {
        'equipmentId': widget.maintenance['equipmentId'],
        'capacity': _capacityController.text.trim(),
        'model': _modelController.text.trim(),
        'brand': _brandController.text.trim(),
        'location': _locationController.text.trim(),
        'condition': _selectedCondition,
      };

      bool success = await _service.completeMaintenance(
        widget.maintenance['id'],
        taskCompletion: taskCompletion,
        photos: selectedImages,
        notes: _notesController.text.trim(),
        equipmentData: equipmentDataToUpdate,
      );

      if (success) {
        debugPrint('✅ Mantenimiento completado exitosamente');
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mantenimiento completado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Error al completar mantenimiento');
      }
    } catch (e) {
      debugPrint('❌ Error al completar mantenimiento: $e');
      _showErrorDialog('Error al completar mantenimiento: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _capacityController.dispose();
    _modelController.dispose();
    _brandController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
