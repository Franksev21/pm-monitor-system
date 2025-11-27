// lib/shared/widgets/equipment_type_search_dialog.dart

import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/equipment_type_model.dart';
import 'package:pm_monitor/core/services/equipment_type_service.dart';
import 'package:pm_monitor/features/equipment/screens/equipment_type_management_dialog.dart';

class EquipmentTypeSearchDialog extends StatefulWidget {
  final String? selectedType; // Nombre del tipo seleccionado
  final bool showManagementButton;

  const EquipmentTypeSearchDialog({
    super.key,
    this.selectedType,
    this.showManagementButton = true,
  });

  @override
  State<EquipmentTypeSearchDialog> createState() =>
      _EquipmentTypeSearchDialogState();
}

class _EquipmentTypeSearchDialogState extends State<EquipmentTypeSearchDialog> {
  final EquipmentTypeService _typeService = EquipmentTypeService();
  final TextEditingController _searchController = TextEditingController();
  List<EquipmentType> _allTypes = [];
  List<EquipmentType> _filteredTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    try {
      final types = await _typeService.getEquipmentTypes();
      setState(() {
        _allTypes = types;
        _filteredTypes = types;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando tipos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterTypes(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTypes = _allTypes;
      } else {
        String normalizedQuery = query.toLowerCase().trim();
        _filteredTypes = _allTypes.where((type) {
          return type.name.toLowerCase().contains(normalizedQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (_searchController.text.isNotEmpty) _buildResultsCounter(),
            Flexible(
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredTypes.isEmpty
                      ? _buildEmptyState()
                      : _buildTypesList(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Tipo de Equipo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (widget.showManagementButton)
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: _navigateToManagement,
                  tooltip: 'Gestionar tipos',
                ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _filterTypes,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar tipo...',
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _searchController.clear();
                        _filterTypes('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCounter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.grey[100],
      child: Text(
        '${_filteredTypes.length} tipo${_filteredTypes.length != 1 ? 's' : ''} encontrado${_filteredTypes.length != 1 ? 's' : ''}',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Cargando tipos...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypesList() {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredTypes.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 76,
        color: Colors.grey[200],
      ),
      itemBuilder: (context, index) {
        final type = _filteredTypes[index];
        final isSelected = widget.selectedType == type.name;
        return _buildTypeTile(type, isSelected);
      },
    );
  }

  Widget _buildTypeTile(EquipmentType type, bool isSelected) {
    return InkWell(
      onTap: () => Navigator.pop(context, type.name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: isSelected ? Colors.blue.withOpacity(0.08) : Colors.transparent,
        child: Row(
          children: [
            // Icono del tipo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSelected
                      ? [const Color(0xFF2196F3), const Color(0xFF1976D2)]
                      : [Colors.grey[300]!, Colors.grey[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? Colors.blue.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  type.icon,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Información del tipo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color:
                          isSelected ? const Color(0xFF2196F3) : Colors.black87,
                    ),
                  ),
                  if (type.categories.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${type.categories.length} categoría${type.categories.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Indicador de selección
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF2196F3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No se encontraron tipos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otro término',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            if (widget.showManagementButton) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToManagement,
                icon: const Icon(Icons.add),
                label: const Text('Agregar Tipo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          if (widget.showManagementButton) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _navigateToManagement,
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Gestionar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✨ MÉTODO ACTUALIZADO PARA ABRIR EL DIÁLOGO DE GESTIÓN
  void _navigateToManagement() async {
    // Cerrar el diálogo actual
    Navigator.pop(context);

    // Abrir diálogo de gestión
    await showDialog(
      context: context,
      builder: (context) => const EquipmentTypeManagementDialog(),
    );

    // Opcional: Si quieres reabrir el selector después de gestionar
    // Descomenta las siguientes líneas:
    // if (mounted) {
    //   _loadTypes(); // Recargar tipos actualizados
    // }
  }
}
