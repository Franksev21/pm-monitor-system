import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/client_model.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/widgets/custom_widgets.dart';

/// Widget para gestionar sucursales/ubicaciones del cliente
class BranchManagementWidget extends StatefulWidget {
  final List<BranchModel> branches;
  final Function(List<BranchModel>) onBranchesChanged;
  final bool showMainAddress;

  const BranchManagementWidget({
    super.key,
    required this.branches,
    required this.onBranchesChanged,
    this.showMainAddress = false,
  });

  @override
  State<BranchManagementWidget> createState() => _BranchManagementWidgetState();
}

class _BranchManagementWidgetState extends State<BranchManagementWidget> {
  late List<BranchModel> _branches;

  @override
  void initState() {
    super.initState();
    _branches = List.from(widget.branches);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sucursales',
              style: AppTheme.headingMedium,
            ),
            TextButton.icon(
              onPressed: _addBranch,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Agregar Sucursal'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Agrega las ubicaciones adicionales del cliente',
          style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        if (_branches.isEmpty)
          _buildEmptyState()
        else
          ..._branches.asMap().entries.map((entry) {
            return _buildBranchCard(entry.value, entry.key);
          }),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(
            Icons.store_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Sin sucursales agregadas',
            style: AppTheme.bodyLarge.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega las ubicaciones adicionales de tu cliente',
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(BranchModel branch, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: branch.isActive
              ? AppTheme.primaryColor.withOpacity(0.3)
              : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: branch.isActive
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.store,
                    color: branch.isActive
                        ? AppTheme.primaryColor
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              branch.isActive ? Colors.black : Colors.grey[600],
                        ),
                      ),
                      Text(
                        branch.address.city,
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: branch.isActive
                        ? AppTheme.successColor.withOpacity(0.1)
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    branch.isActive ? 'Activa' : 'Inactiva',
                    style: AppTheme.bodySmall.copyWith(
                      color: branch.isActive
                          ? AppTheme.successColor
                          : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Dirección
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    branch.address.fullAddress,
                    style: AppTheme.bodyMedium,
                  ),
                ),
              ],
            ),

            // Manager info
            if (branch.managerName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gerente: ${branch.managerName}',
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],

            if (branch.managerPhone != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    branch.managerPhone!,
                    style: AppTheme.bodyMedium,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Acciones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editBranch(index),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteBranch(index),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addBranch() {
    _showBranchDialog(null, null);
  }

  void _editBranch(int index) {
    _showBranchDialog(_branches[index], index);
  }

  void _deleteBranch(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Sucursal'),
        content: Text('¿Estás seguro de eliminar "${_branches[index].name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _branches.removeAt(index);
                widget.onBranchesChanged(_branches);
              });
              Navigator.pop(context);
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showBranchDialog(BranchModel? branch, int? index) {
    showDialog(
      context: context,
      builder: (context) => _BranchDialog(
        branch: branch,
        onSave: (newBranch) {
          setState(() {
            if (index != null) {
              _branches[index] = newBranch;
            } else {
              _branches.add(newBranch);
            }
            widget.onBranchesChanged(_branches);
          });
        },
      ),
    );
  }
}

/// Dialog para agregar/editar sucursal
class _BranchDialog extends StatefulWidget {
  final BranchModel? branch;
  final Function(BranchModel) onSave;

  const _BranchDialog({
    this.branch,
    required this.onSave,
  });

  @override
  State<_BranchDialog> createState() => _BranchDialogState();
}

class _BranchDialogState extends State<_BranchDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _zipCodeController;
  late TextEditingController _managerNameController;
  late TextEditingController _managerPhoneController;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final branch = widget.branch;

    _nameController = TextEditingController(text: branch?.name ?? '');
    _streetController =
        TextEditingController(text: branch?.address.street ?? '');
    _cityController = TextEditingController(text: branch?.address.city ?? '');
    _stateController = TextEditingController(text: branch?.address.state ?? '');
    _countryController = TextEditingController(
        text: branch?.address.country ?? 'República Dominicana');
    _zipCodeController =
        TextEditingController(text: branch?.address.zipCode ?? '');
    _managerNameController =
        TextEditingController(text: branch?.managerName ?? '');
    _managerPhoneController =
        TextEditingController(text: branch?.managerPhone ?? '');
    _isActive = branch?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _zipCodeController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.store, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.branch == null
                          ? 'Nueva Sucursal'
                          : 'Editar Sucursal',
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

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(
                        label: 'Nombre de la Sucursal *',
                        hint: 'Ej: Sucursal Centro',
                        controller: _nameController,
                        prefixIcon: const Icon(Icons.store),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Dirección',
                        style: AppTheme.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        label: 'Calle *',
                        hint: 'Av. Principal No. 123',
                        controller: _streetController,
                        prefixIcon: const Icon(Icons.location_on),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La dirección es requerida';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: CustomTextField(
                              label: 'Ciudad *',
                              hint: 'Santo Domingo',
                              controller: _cityController,
                              prefixIcon: const Icon(Icons.location_city),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'La ciudad es requerida';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              label: 'Código Postal',
                              hint: '10205',
                              controller: _zipCodeController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Provincia/Estado *',
                        hint: 'Distrito Nacional',
                        controller: _stateController,
                        prefixIcon: const Icon(Icons.map),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La provincia es requerida';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'País *',
                        hint: 'República Dominicana',
                        controller: _countryController,
                        prefixIcon: const Icon(Icons.flag),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El país es requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Información del Gerente (Opcional)',
                        style: AppTheme.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        label: 'Nombre del Gerente',
                        hint: 'Juan Pérez',
                        controller: _managerNameController,
                        prefixIcon: const Icon(Icons.person),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Teléfono del Gerente',
                        hint: '+1-809-555-0000',
                        controller: _managerPhoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Sucursal Activa'),
                        subtitle: Text(
                          _isActive
                              ? 'Esta sucursal está operativa'
                              : 'Esta sucursal está inactiva',
                          style: AppTheme.bodySmall
                              .copyWith(color: Colors.grey[600]),
                        ),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        activeColor: AppTheme.successColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Cancelar',
                      isOutlined: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Guardar',
                      onPressed: _saveBranch,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveBranch() {
    if (!_formKey.currentState!.validate()) return;

    final address = AddressModel(
      street: _streetController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      country: _countryController.text.trim(),
      zipCode: _zipCodeController.text.trim(),
    );

    final branch = BranchModel(
      id: widget.branch?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      address: address,
      managerName: _managerNameController.text.trim().isEmpty
          ? null
          : _managerNameController.text.trim(),
      managerPhone: _managerPhoneController.text.trim().isEmpty
          ? null
          : _managerPhoneController.text.trim(),
      isActive: _isActive,
    );

    widget.onSave(branch);
    Navigator.pop(context);
  }
}
