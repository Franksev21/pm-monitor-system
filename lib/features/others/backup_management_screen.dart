import 'package:flutter/material.dart';
import 'package:pm_monitor/core/services/simple_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupManagementScreen extends StatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  _BackupManagementScreenState createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends State<BackupManagementScreen> {
  final SimpleBackupService _backupService = SimpleBackupService();
  bool _isCreatingBackup = false;
  List<BackupInfo> _availableBackups = [];
  bool _isLoadingBackups = true;
  String _lastBackupInfo = 'Cargando...';
  String _storageUsage = 'Calculando...';

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    setState(() => _isLoadingBackups = true);

    try {
      final backups = await _backupService.getAvailableBackups();
      final lastBackup = await _backupService.getLastBackupInfo();
      final usage = await _backupService.getBackupStorageUsage();

      setState(() {
        _availableBackups = backups;
        _lastBackupInfo = lastBackup;
        _storageUsage = usage;
        _isLoadingBackups = false;
      });
    } catch (e) {
      setState(() => _isLoadingBackups = false);
      _showErrorSnackBar('Error cargando información de backups: $e');
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isCreatingBackup = true);

    try {
      final success = await _backupService.createManualBackup();

      if (success) {
        _showSuccessSnackBar('Backup creado exitosamente');
        await _loadBackupInfo(); // Recargar lista
      } else {
        _showErrorSnackBar('Error creando backup');
      }
    } catch (e) {
      _showErrorSnackBar('Error creando backup: $e');
    } finally {
      setState(() => _isCreatingBackup = false);
    }
  }

  Future<void> _shareBackup(String fileName) async {
    try {
      await _backupService.shareBackup(fileName);
    } catch (e) {
      _showErrorSnackBar('Error compartiendo backup: $e');
    }
  }

  Future<void> _downloadBackup(String fileName) async {
    try {
      final file = await _backupService.downloadBackup(fileName);
      if (file != null) {
        _showSuccessSnackBar('Backup descargado: ${file.path}');
      } else {
        _showErrorSnackBar('Error descargando backup');
      }
    } catch (e) {
      _showErrorSnackBar('Error descargando backup: $e');
    }
  }

  Future<void> _cleanupOldBackups() async {
    final confirm = await _showConfirmDialog(
      'Limpiar Backups Antiguos',
      '¿Deseas eliminar backups antiguos? Se mantendrán solo los 5 más recientes.',
    );

    if (confirm) {
      try {
        await _backupService.cleanupOldBackups();
        _showSuccessSnackBar('Backups antiguos eliminados');
        await _loadBackupInfo();
      } catch (e) {
        _showErrorSnackBar('Error limpiando backups: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Gestión de Backups'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBackupInfo,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBackupInfo,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Sección de información general
            _buildInfoSection(),
            const SizedBox(height: 16),

            // Botón para crear backup
            _buildCreateBackupSection(),
            const SizedBox(height: 16),

            // Lista de backups disponibles
            _buildBackupsList(),
            const SizedBox(height: 16),

            // Acciones adicionales
            _buildAdditionalActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF1976D2)),
                SizedBox(width: 8),
                Text(
                  'Información de Backups',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Último backup:', _lastBackupInfo),
            _buildInfoRow('Espacio utilizado:', _storageUsage),
            _buildInfoRow(
                'Backups disponibles:', '${_availableBackups.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateBackupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.backup, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Crear Nuevo Backup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Respalda todos los datos importantes: mantenimientos, equipos, clientes y usuarios.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreatingBackup ? null : _createBackup,
                icon: _isCreatingBackup
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.backup),
                label: Text(_isCreatingBackup
                    ? 'Creando backup...'
                    : 'Crear Backup Ahora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupsList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.folder, color: Color(0xFF1976D2)),
                SizedBox(width: 8),
                Text(
                  'Backups Disponibles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingBackups)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (_availableBackups.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_off,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay backups disponibles',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crea tu primer backup usando el botón de arriba',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...(_availableBackups
                  .map((backup) => _buildBackupItem(backup))
                  .toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupItem(BackupInfo backup) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.insert_drive_file,
            color: Color(0xFF1976D2),
          ),
        ),
        title: Text(
          backup.formattedDate,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${backup.formattedSize} • ${backup.fileName}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'download':
                _downloadBackup(backup.fileName);
                break;
              case 'share':
                _shareBackup(backup.fileName);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'download',
              child: Row(
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 8),
                  Text('Descargar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 20),
                  SizedBox(width: 8),
                  Text('Compartir'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Acciones Adicionales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cleanupOldBackups,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Limpiar Backups Antiguos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Esto eliminará backups antiguos, manteniendo solo los 5 más recientes para ahorrar espacio.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
