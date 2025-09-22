import 'package:flutter/material.dart';
import 'package:pm_monitor/features/others/screens/fault_report_screen.dart';
import 'package:pm_monitor/features/auth/widgets/apple_style_calender.dart';
import 'package:pm_monitor/features/others/screens/qr_display_screen.dart';
import 'package:provider/provider.dart';
import 'package:pm_monitor/core/models/equipment_model.dart';
import 'package:pm_monitor/core/providers/equipment_provider.dart';

class EquipmentDetailScreen extends StatefulWidget {
  final Equipment equipment;

  const EquipmentDetailScreen({
    Key? key,
    required this.equipment,
  }) : super(key: key);

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Equipment? _currentEquipment;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentEquipment = widget.equipment;
    _loadEquipmentDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadEquipmentDetails() {
    final equipmentProvider =
        Provider.of<EquipmentProvider>(context, listen: false);
    equipmentProvider.loadEquipmentById(widget.equipment.id!);
  }

  void _showEditDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente: Editar equipo')),
    );
  }

  void _showReportFailureDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaultReportScreen(equipment: widget.equipment),
      ),
    );
  }

  void _showScheduleMaintenanceDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AppleStyleMaintenanceCalendar(),
      ),
    );
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'DOP':
        return 'RD\$';
      default:
        return '\$';
    }
  }

  String _formatCurrency(double amount, String currency) {
    if (amount == 0) return '${_getCurrencySymbol(currency)}0.00';

    if (amount >= 1000000) {
      return '${_getCurrencySymbol(currency)}${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${_getCurrencySymbol(currency)}${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return '${_getCurrencySymbol(currency)}${amount.toStringAsFixed(2)}';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'operativo':
        return Colors.green;
      case 'en mantenimiento':
        return Colors.orange;
      case 'fuera de servicio':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    String cat = category.toLowerCase();
    if (cat.contains('ac') || cat.contains('aire') || cat.contains('split')) {
      return Icons.ac_unit;
    } else if (cat.contains('panel') || cat.contains('eléctrico')) {
      return Icons.electrical_services;
    } else if (cat.contains('generador')) {
      return Icons.power;
    } else if (cat.contains('ups')) {
      return Icons.battery_charging_full;
    } else if (cat.contains('facilidad')) {
      return Icons.build;
    } else {
      return Icons.settings;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference < 0) {
      return 'Hace ${(-difference)} días';
    } else if (difference == 0) {
      return 'Hoy';
    } else if (difference == 1) {
      return 'Mañana';
    } else if (difference <= 7) {
      return 'En $difference días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildHeaderContent(Equipment equipment) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1976D2),
            const Color(0xFF1565C0),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono de categoría
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getCategoryIcon(equipment.category),
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Badges de número y estado
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        equipment.equipmentNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            _getStatusColor(equipment.status).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        equipment.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Marca y modelo
                Text(
                  '${equipment.brand} ${equipment.model}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Ubicación con manejo de overflow
                Row(
                  children: [
                    const Icon(Icons.place, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${equipment.location}, ${equipment.branch}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon,
      {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: statusColor ?? Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: statusColor ?? Colors.black87,
                fontWeight:
                    statusColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1976D2),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(
      String title, String status, String date, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  date,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostCard(String title, double amount, String currency,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatCurrency(amount, currency),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(
      String label, double amount, String currency, IconData icon, Color color,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                color: isTotal ? Colors.black : Colors.grey[700],
                fontSize: isTotal ? 16 : 14,
              ),
            ),
          ),
          Text(
            _formatCurrency(amount, currency),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(Equipment equipment) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total PM',
            '${equipment.totalMaintenances}',
            Icons.build,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total CM',
            '${equipment.totalFailures}',
            Icons.warning,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Eficiencia',
            '${equipment.maintenanceEfficiency.toStringAsFixed(0)}%',
            Icons.trending_up,
            equipment.maintenanceEfficiency >= 80
                ? Colors.green
                : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildCostSummaryCards(Equipment equipment) {
    return Row(
      children: [
        Expanded(
          child: _buildCostCard(
            'Costo Total',
            equipment.totalCost,
            equipment.currency,
            Icons.calculate,
            const Color(0xFF1976D2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCostCard(
            'PM Cost',
            equipment.totalPmCost,
            equipment.currency,
            Icons.build,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCostCard(
            'CM Cost',
            equipment.totalCmCost,
            equipment.currency,
            Icons.warning,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildInformationTab(Equipment equipment) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(
            'Información General',
            [
              _buildInfoRow(
                  'Número de Equipo', equipment.equipmentNumber, Icons.tag),
              _buildInfoRow('RFID Tag', equipment.rfidTag, Icons.nfc),
              _buildInfoRow('Categoría', equipment.category, Icons.category),
              _buildInfoRow(
                  'Descripción',
                  equipment.description.isNotEmpty
                      ? equipment.description
                      : 'Sin descripción',
                  Icons.description),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoSection(
            'Especificaciones Técnicas',
            [
              _buildInfoRow('Marca', equipment.brand, Icons.business),
              _buildInfoRow('Modelo', equipment.model, Icons.model_training),
              _buildInfoRow(
                  'Capacidad',
                  '${equipment.capacity} ${equipment.capacityUnit}',
                  Icons.power),
              _buildInfoRow(
                  'Número de Serie',
                  equipment.serialNumber.isNotEmpty
                      ? equipment.serialNumber
                      : 'No especificado',
                  Icons.confirmation_number),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoSection(
            'Estado y Condición',
            [
              _buildInfoRow('Estado', equipment.status, Icons.settings,
                  statusColor: _getStatusColor(equipment.status)),
              _buildInfoRow(
                  'Condición',
                  '${equipment.conditionIcon} ${equipment.condition}',
                  Icons.health_and_safety),
              _buildInfoRow(
                  'Vida Útil', '${equipment.lifeScale}/10', Icons.timeline),
              _buildInfoRow('Activo desde', _formatDate(equipment.createdAt),
                  Icons.calendar_today),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoSection(
            'Mantenimiento',
            [
              _buildInfoRow(
                  'Frecuencia', equipment.maintenanceFrequency, Icons.schedule),
              _buildInfoRow('Cada', '${equipment.frequencyDays} días',
                  Icons.event_repeat),
              _buildInfoRow(
                  'Último Mantenimiento',
                  equipment.lastMaintenanceDate != null
                      ? _formatDate(equipment.lastMaintenanceDate!)
                      : 'Nunca',
                  Icons.build),
              _buildInfoRow(
                  'Próximo Mantenimiento',
                  equipment.nextMaintenanceDate != null
                      ? _formatDate(equipment.nextMaintenanceDate!)
                      : 'No programado',
                  Icons.schedule_send,
                  statusColor: equipment.needsMaintenance
                      ? (equipment.isOverdue ? Colors.red : Colors.orange)
                      : Colors.green),
              _buildInfoRow('Horas Estimadas',
                  '${equipment.estimatedMaintenanceHours}h', Icons.access_time),
            ],
          ),
          const SizedBox(height: 24),
          if (equipment.assignedTechnicianName != null ||
              equipment.assignedSupervisorName != null)
            _buildInfoSection(
              'Personal Asignado',
              [
                if (equipment.assignedTechnicianName != null)
                  _buildInfoRow('Técnico Asignado',
                      equipment.assignedTechnicianName!, Icons.person),
                if (equipment.assignedSupervisorName != null)
                  _buildInfoRow('Supervisor', equipment.assignedSupervisorName!,
                      Icons.supervisor_account),
              ],
            ),
          const SizedBox(height: 24),
          _buildInfoSection(
            'Configuración de Alertas',
            [
              _buildInfoRow(
                  'Alertas de Mantenimiento',
                  equipment.enableMaintenanceAlerts
                      ? 'Habilitadas'
                      : 'Deshabilitadas',
                  Icons.notifications,
                  statusColor: equipment.enableMaintenanceAlerts
                      ? Colors.green
                      : Colors.grey),
              _buildInfoRow(
                  'Alertas de Fallas',
                  equipment.enableFailureAlerts
                      ? 'Habilitadas'
                      : 'Deshabilitadas',
                  Icons.warning,
                  statusColor: equipment.enableFailureAlerts
                      ? Colors.green
                      : Colors.grey),
              _buildInfoRow(
                  'Monitoreo de Temperatura',
                  equipment.hasTemperatureMonitoring
                      ? 'Habilitado'
                      : 'Deshabilitado',
                  Icons.thermostat,
                  statusColor: equipment.hasTemperatureMonitoring
                      ? Colors.green
                      : Colors.grey),
              if (equipment.hasTemperatureMonitoring &&
                  equipment.currentTemperature != null)
                _buildInfoRow(
                    'Temperatura Actual',
                    '${equipment.currentTemperature!.toStringAsFixed(1)}°C',
                    Icons.device_thermostat),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(Equipment equipment) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(equipment),
          const SizedBox(height: 24),
          _buildInfoSection(
            'Historial de Mantenimientos Preventivos (PM)',
            [
              _buildHistoryItem(
                'Mantenimiento Mensual',
                'Completado',
                _formatDate(DateTime.now().subtract(const Duration(days: 15))),
                Icons.build_circle,
                Colors.green,
              ),
              _buildHistoryItem(
                'Inspección Trimestral',
                'Completado',
                _formatDate(DateTime.now().subtract(const Duration(days: 45))),
                Icons.search,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoSection(
            'Historial de Mantenimientos Correctivos (CM)',
            [
              _buildHistoryItem(
                'Reparación de compresor',
                'Completado',
                _formatDate(DateTime.now().subtract(const Duration(days: 60))),
                Icons.warning,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostsTab(Equipment equipment) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCostSummaryCards(equipment),
          const SizedBox(height: 24),
          _buildInfoSection(
            'Desglose de Costos',
            [
              _buildCostRow('Costo del Equipo', equipment.equipmentCost,
                  equipment.currency, Icons.shopping_cart, Colors.blue),
              _buildCostRow(
                  'Mantenimientos Preventivos (PM)',
                  equipment.totalPmCost,
                  equipment.currency,
                  Icons.build,
                  Colors.green),
              _buildCostRow(
                  'Mantenimientos Correctivos (CM)',
                  equipment.totalCmCost,
                  equipment.currency,
                  Icons.warning,
                  Colors.orange),
              const Divider(),
              _buildCostRow('Costo Total', equipment.totalCost,
                  equipment.currency, Icons.calculate, const Color(0xFF1976D2),
                  isTotal: true),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoSection(
            'Indicadores de Eficiencia',
            [
              _buildInfoRow(
                  'Eficiencia de Mantenimiento',
                  '${equipment.maintenanceEfficiency.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  statusColor: equipment.maintenanceEfficiency >= 80
                      ? Colors.green
                      : equipment.maintenanceEfficiency >= 60
                          ? Colors.orange
                          : Colors.red),
              _buildInfoRow('Total de Mantenimientos',
                  '${equipment.totalMaintenances}', Icons.build_circle),
              _buildInfoRow('Total de Fallas', '${equipment.totalFailures}',
                  Icons.error_outline),
              _buildInfoRow(
                  'Tiempo Promedio de Respuesta',
                  equipment.averageResponseTime > 0
                      ? '${equipment.averageResponseTime.toStringAsFixed(1)}h'
                      : 'N/A',
                  Icons.timer),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab(Equipment equipment) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQRSection(equipment),
          const SizedBox(height: 24),
          _buildInfoSection(
            'Fotos del Equipo',
            [
              if (equipment.photoUrls.isEmpty)
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library, color: Colors.grey, size: 32),
                        SizedBox(height: 8),
                        Text('No hay fotos disponibles',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: equipment.photoUrls.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(equipment.photoUrls[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoSection(
            'Documentos y Manuales',
            [
              if (equipment.documentUrls.isEmpty)
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Center(
                    child: Text('No hay documentos disponibles',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...equipment.documentUrls
                    .map((url) => ListTile(
                          leading: const Icon(Icons.description,
                              color: Color(0xFF1976D2)),
                          title: Text(
                              'Documento ${equipment.documentUrls.indexOf(url) + 1}'),
                          trailing: const Icon(Icons.download),
                          onTap: () {
                            // TODO: Abrir documento
                          },
                        ))
                    .toList(),
            ],
          ),
          const SizedBox(height: 24),
          if (equipment.technicalSpecs.isNotEmpty)
            _buildInfoSection(
              'Especificaciones Técnicas Adicionales',
              equipment.technicalSpecs.entries
                  .map((entry) => _buildInfoRow(
                      entry.key, entry.value.toString(), Icons.settings))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildQRSection(Equipment equipment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Código QR del Equipo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1976D2),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Icon(
                    Icons.qr_code,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR Code: ${equipment.qrCode}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escanea para acceso rápido a la información del equipo',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _generateQRCode(equipment),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Descargar QR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
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

  void _generateQRCode(Equipment equipment) {
   Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRDisplayScreen(equipment: equipment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<EquipmentProvider>(
        builder: (context, equipmentProvider, child) {
          final equipment =
              equipmentProvider.selectedEquipment ?? _currentEquipment!;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsets.only(left: 56, bottom: 16, right: 16),
                  title: Text(
                    equipment.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3.0,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: _buildHeaderContent(equipment),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _showEditDialog,
                    tooltip: 'Editar',
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'report_failure':
                          _showReportFailureDialog();
                          break;
                        case 'schedule_maintenance':
                          _showScheduleMaintenanceDialog();
                          break;
                        case 'generate_qr':
                          _generateQRCode(equipment);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'report_failure',
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Reportar Falla'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'schedule_maintenance',
                        child: Row(
                          children: [
                            Icon(Icons.schedule, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Programar Mantenimiento'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'generate_qr',
                        child: Row(
                          children: [
                            Icon(Icons.qr_code, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Generar QR'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SliverFillRemaining(
                child: Column(
                  children: [
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF1976D2),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF1976D2),
                        indicatorWeight: 3,
                        tabs: const [
                          Tab(
                              text: 'Información',
                              icon: Icon(Icons.info_outline, size: 20)),
                          Tab(
                              text: 'Historial',
                              icon: Icon(Icons.history, size: 20)),
                          Tab(
                              text: 'Costos',
                              icon: Icon(Icons.attach_money, size: 20)),
                          Tab(
                              text: 'Documentos',
                              icon: Icon(Icons.folder, size: 20)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildInformationTab(equipment),
                          _buildHistoryTab(equipment),
                          _buildCostsTab(equipment),
                          _buildDocumentsTab(equipment),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
