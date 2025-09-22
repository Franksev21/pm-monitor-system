import 'package:flutter/material.dart';

class UnifiedMaintenanceScreen extends StatefulWidget {
  final int initialTab;

  UnifiedMaintenanceScreen({this.initialTab = 0});

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
        title: Text('Mis Mantenimientos'),
        backgroundColor: Color(0xFF1976D2),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Pendientes'),
            Tab(text: 'En Progreso'),
            Tab(text: 'Completados'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Center(child: Text('Pendientes')),
          Center(child: Text('En Progreso')),
          Center(child: Text('Completados')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
