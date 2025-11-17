import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:pm_monitor/core/services/maintenance_execution_service.dart';

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

  Map<String, bool> taskCompletion = {};
  List<File> selectedImages = [];
  bool isLoading = false;
  bool isSaving = false;
  Map<String, dynamic>? equipmentData;

  // Datos del equipo para actualizar
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _selectedCondition = 'Bueno';

  @override
  void initState() {
    super.initState();
    _loadMaintenanceDetails();
  }

  Future<void> _loadMaintenanceDetails() async {
    setState(() => isLoading = true);
    
    try {
      // Cargar detalles completos del mantenimiento
      Map<String, dynamic>? details = await _service.getMaintenanceDetails(widget.maintenance['id']);
      
      if (details != null) {
        // Inicializar tareas
        List<dynamic> tasks = details['tasks'] ?? await _service.getDefaultTasks(
          details['equipmentData']?['category'] ?? 'AC'
        );
        
        _initializeTaskCompletion(tasks);
        
        // Cargar datos del equipo si existen
        equipmentData = details['equipmentData'];
        if (equipmentData != null) {
          _loadEquipmentData();
        }
        
        // Cargar progreso previo si existe
        if (details['taskCompletion'] != null) {
          taskCompletion = Map<String, bool>.from(details['taskCompletion']);
        }
        
        if (details['notes'] != null) {
          _notesController.text = details['notes'];
        }
      }
    } catch (e) {
      _showErrorDialog('Error cargando detalles del mantenimiento: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _initializeTaskCompletion(List<dynamic> tasks) {
    for (var task in tasks) {
      if (!taskCompletion.containsKey(task.toString())) {
        taskCompletion[task.toString()] = false;
      }
    }
  }

  void _loadEquipmentData() {
    if (equipmentData != null) {
      _capacityController.text = equipmentData!['capacity']?.toString() ?? '';
      _modelController.text = equipmentData!['model']?.toString() ?? '';
      _brandController.text = equipmentData!['brand']?.toString() ?? '';
      _locationController.text = equipmentData!['location']?.toString() ?? '';
      _selectedCondition = equipmentData!['condition']?.toString() ?? 'Bueno';
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
        body: const Center(child: CircularProgressIndicator()),
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
                  )
                )
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
            _buildEquipmentDataSection(),
            const SizedBox(height: 20),
            _buildPhotosSection(),
            const SizedBox(height: 20),
            _buildNotesSection(),
            const SizedBox(height: 20),
            _buildProgressIndicator(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 50), // Espacio adicional al final
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            _buildInfoRow(Icons.business, 'Cliente:', widget.maintenance['clientName']),
            _buildInfoRow(Icons.location_on, 'Ubicación:', widget.maintenance['location']),
            if (equipmentData != null) ...[
              _buildInfoRow(Icons.tag, 'Equipo ID:', equipmentData!['equipmentNumber']),
              _buildInfoRow(Icons.category, 'Categoría:', equipmentData!['category']),
            ],
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
                  'Lista de Verificación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${taskCompletion.values.where((v) => v).length}/${tasks.length}',
                  style: const TextStyle(
                    color: Color(0xFF1976D2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No hay tareas definidas para este mantenimiento',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...tasks.map((task) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  title: Text(
                    task,
                    style: TextStyle(
                      decoration: taskCompletion[task] == true 
                        ? TextDecoration.lineThrough 
                        : null,
                    ),
                  ),
                  value: taskCompletion[task] ?? false,
                  onChanged: (bool? value) {
                    setState(() {
                      taskCompletion[task] = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFF1976D2),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              )),
          ],
        ),
      ),
    );
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
            _buildTextField(_locationController, 'Ubicación', Icons.location_on),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCondition,
              decoration: const InputDecoration(
                labelText: 'Condición',
                prefixIcon: Icon(Icons.assessment),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                {'value': 'Excelente', 'color': Colors.green},
                {'value': 'Bueno', 'color': Colors.lightGreen},
                {'value': 'Regular', 'color': Colors.orange},
                {'value': 'Malo', 'color': Colors.red},
                {'value': 'Crítico', 'color': Colors.deepOrange},
              ].map((condition) => DropdownMenuItem(
                    value: condition['value'] as String,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: condition['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(condition['value'] as String),
                      ],
                    ),
                  )).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCondition = value ?? 'Bueno';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
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
                  selectedImages.isEmpty ? 'Requerido' : '${selectedImages.length} foto(s)',
                  style: TextStyle(
                    color: selectedImages.isEmpty ? Colors.red : Colors.green,
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
                      'Se requiere al menos una foto\npara completar el mantenimiento',
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                hintText: 'Observaciones, problemas encontrados, recomendaciones...',
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
    int completedTasks = taskCompletion.values.where((completed) => completed).length;
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
                    color: progress == 1.0 ? Colors.green : const Color(0xFF1976D2),
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
            Text(
              '$completedTasks de $totalTasks tareas completadas',
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
    int completedTasks = taskCompletion.values.where((completed) => completed).length;
    bool canComplete = completedTasks == totalTasks && selectedImages.isNotEmpty;

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
                    color: Colors.white, 
                    strokeWidth: 2
                  )
                ) 
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
            onPressed: (canComplete && !isLoading && !isSaving) ? _completeMaintenance : null,
            icon: const Icon(Icons.check_circle),
            label: const Text('Completar Mantenimiento'),
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
                        if (completedTasks < totalTasks)
                          Text(
                            '• Completar todas las tareas (${totalTasks - completedTasks} pendientes)',
                            style: TextStyle(color: Colors.amber[700], fontSize: 11),
                          ),
                        if (selectedImages.isEmpty)
                          Text(
                            '• Agregar al menos una foto de evidencia',
                            style: TextStyle(color: Colors.amber[700], fontSize: 11),
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
                  widget.maintenance['id'], 
                  reasonController.text.trim()
                );
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mantenimiento pausado')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Pausar'),
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
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Problema reportado correctamente')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Reportar'),
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
      }
    } catch (e) {
      _showErrorDialog('Error al capturar foto: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      selectedImages.removeAt(index);
    });
  }

  Future<void> _saveProgress() async {
    setState(() => isSaving = true);

    try {
      bool success = await _service.updateTaskProgress(
        widget.maintenance['id'],
        taskCompletion,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progreso guardado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorDialog('Error al guardar progreso');
      }
    } catch (e) {
      _showErrorDialog('Error al guardar progreso: $e');
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> _completeMaintenance() async {
    // Confirmación antes de completar
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Completar Mantenimiento'),
        content: const Text('¿Estás seguro de que deseas completar este mantenimiento? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Completar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

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
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mantenimiento completado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorDialog('Error al completar mantenimiento');
      }
    } catch (e) {
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
  }}