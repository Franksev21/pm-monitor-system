import 'package:flutter/material.dart';


class UnifiedMaintenanceScreen extends StatefulWidget {
  final int initialTab;

  const UnifiedMaintenanceScreen({super.key, this.initialTab = 0});

  @override
 _UnifiedMaintenanceScreenState createState() =>
      _UnifiedMaintenanceScreenState();
}

class _UnifiedMaintenanceScreenState extends State<UnifiedMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Mantenimientos'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Calendario'), // Cambió de "Pendientes" a "Calendario"
            Tab(text: 'En Progreso'),
            Tab(text: 'Completados'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// Widget temporal para mantenimientos en progreso
class _InProgressMaintenancesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.build,
              size: 80,
              color: Colors.orange[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Mantenimientos en Progreso',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta sección estará disponible pronto',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
