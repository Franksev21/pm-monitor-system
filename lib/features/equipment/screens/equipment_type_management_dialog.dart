// lib/shared/widgets/equipment_type_management_dialog.dart

import 'package:flutter/material.dart';
import 'package:pm_monitor/core/models/equipment_type_model.dart';
import 'package:pm_monitor/core/services/equipment_type_service.dart';

class EquipmentTypeManagementDialog extends StatefulWidget {
  const EquipmentTypeManagementDialog({super.key});

  @override
  State<EquipmentTypeManagementDialog> createState() =>
      _EquipmentTypeManagementDialogState();
}

class _EquipmentTypeManagementDialogState
    extends State<EquipmentTypeManagementDialog> {
  final EquipmentTypeService _typeService = EquipmentTypeService();
  List<EquipmentType> _types = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    try {
      final types = await _typeService.getEquipmentTypes();
      setState(() {
        _types = types;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showError('Error cargando tipos: $e');
      }
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading ? _buildLoadingState() : _buildTypesList(),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestionar Tipos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Agregar, editar o eliminar tipos de equipos',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando tipos...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTypesList() {
    if (_types.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay tipos de equipos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega el primer tipo para comenzar',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _types.length,
      itemBuilder: (context, index) {
        final type = _types[index];
        return _buildTypeCard(type);
      },
    );
  }

  Widget _buildTypeCard(EquipmentType type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(type.icon, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(
          type.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${type.categories.length} categoría${type.categories.length != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (type.categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ...type.categories.take(3).map(
                        (cat) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  if (type.categories.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+${type.categories.length - 3}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Orden ${type.order}',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditTypeDialog(type);
                } else if (value == 'categories') {
                  _showCategoriesDialog(type);
                } else if (value == 'delete') {
                  _confirmDelete(type);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Editar tipo'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'categories',
                  child: Row(
                    children: [
                      Icon(Icons.list, size: 18, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Gestionar categorías'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar'),
                    ],
                  ),
                ),
              ],
            ),
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
              child: const Text('Cerrar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showAddTypeDialog,
              icon: const Icon(Icons.add),
              label: const Text('Agregar Tipo'),
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
      ),
    );
  }

  // ==================== AGREGAR TIPO ====================
  void _showAddTypeDialog() {
    final nameController = TextEditingController();
    final iconController = TextEditingController();
    final categoriesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Tipo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Tipo *',
                  hintText: 'Ej: Refrigeración Industrial',
                  prefixIcon: Icon(Icons.label),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: iconController,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'Icono (Emoji) *',
                  hintText: 'Ej: 🔧',
                  prefixIcon: Icon(Icons.emoji_emotions),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoriesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Categorías (separadas por coma)',
                  hintText: 'Ej: Tipo A, Tipo B, Tipo C',
                  prefixIcon: Icon(Icons.list),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Las categorías se pueden editar después',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final icon = iconController.text.trim();
              final categoriesText = categoriesController.text.trim();

              if (name.isEmpty || icon.isEmpty) {
                _showError('El nombre y el icono son requeridos');
                return;
              }

              final categories = categoriesText.isEmpty
                  ? <String>[]
                  : categoriesText
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

              Navigator.pop(context);

              try {
                await _typeService.addEquipmentType(
                  name: name,
                  icon: icon,
                  categories: categories,
                );
                _showSuccess('Tipo agregado exitosamente');
                _loadTypes();
              } catch (e) {
                _showError('Error agregando tipo: $e');
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  // ==================== EDITAR TIPO ====================
  void _showEditTypeDialog(EquipmentType type) {
    final nameController = TextEditingController(text: type.name);
    final iconController = TextEditingController(text: type.icon);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Tipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del Tipo *',
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: iconController,
              maxLength: 2,
              decoration: const InputDecoration(
                labelText: 'Icono (Emoji) *',
                prefixIcon: Icon(Icons.emoji_emotions),
                border: OutlineInputBorder(),
              ),
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
              final name = nameController.text.trim();
              final icon = iconController.text.trim();

              if (name.isEmpty || icon.isEmpty) {
                _showError('El nombre y el icono son requeridos');
                return;
              }

              Navigator.pop(context);

              try {
                final updatedType = type.copyWith(name: name, icon: icon);
                await _typeService.updateEquipmentType(updatedType);
                _showSuccess('Tipo actualizado exitosamente');
                _loadTypes();
              } catch (e) {
                _showError('Error actualizando tipo: $e');
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ==================== GESTIONAR CATEGORÍAS ====================
  void _showCategoriesDialog(EquipmentType type) {
    showDialog(
      context: context,
      builder: (context) => _CategoriesDialog(
        type: type,
        onSave: (categories) async {
          try {
            final updatedType = type.copyWith(categories: categories);
            await _typeService.updateEquipmentType(updatedType);
            _showSuccess('Categorías actualizadas');
            _loadTypes();
          } catch (e) {
            _showError('Error actualizando categorías: $e');
          }
        },
      ),
    );
  }

  // ==================== ELIMINAR TIPO ====================
  void _confirmDelete(EquipmentType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Tipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Estás seguro de eliminar el tipo "${type.name}"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No se puede eliminar si hay equipos usando este tipo',
                      style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
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
              Navigator.pop(context);
              try {
                await _typeService.deleteEquipmentType(type.id);
                _showSuccess('Tipo eliminado exitosamente');
                _loadTypes();
              } catch (e) {
                _showError('Error eliminando tipo: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ==================== DIÁLOGO DE CATEGORÍAS ====================
class _CategoriesDialog extends StatefulWidget {
  final EquipmentType type;
  final Function(List<String>) onSave;

  const _CategoriesDialog({required this.type, required this.onSave});

  @override
  State<_CategoriesDialog> createState() => _CategoriesDialogState();
}

class _CategoriesDialogState extends State<_CategoriesDialog> {
  late List<String> categories;
  final TextEditingController _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    categories = List.from(widget.type.categories);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  void _addCategory() {
    final category = _categoryController.text.trim();
    if (category.isNotEmpty && !categories.contains(category)) {
      setState(() {
        categories.add(category);
        _categoryController.clear();
      });
    }
  }

  void _removeCategory(String category) {
    setState(() {
      categories.remove(category);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Categorías de ${widget.type.name}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nueva categoría',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addCategory(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add_circle),
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (categories.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Sin categorías',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.category, color: Colors.blue),
                        ),
                        title: Text(category),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeCategory(category),
                        ),
                      ),
                    );
                  },
                ),
              ),
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
            widget.onSave(categories);
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
