import 'package:flutter/material.dart';
import 'package:pm_monitor/shared/widgets/branch_management_widget.dart';
import 'package:pm_monitor/shared/widgets/map_picker_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/client_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/client_model.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/widgets/custom_widgets.dart';

class AddClientScreen extends StatefulWidget {
  final ClientModel? client;

  const AddClientScreen({super.key, this.client});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;

  // Empresa
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _notesController = TextEditingController();

  // Representante
  final _repNameController = TextEditingController();
  final _repPositionController = TextEditingController();

  // Dirección
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _zipCodeController = TextEditingController();

  ClientType _selectedType = ClientType.small;
  ClientStatus _selectedStatus = ClientStatus.active;
  List<BranchModel> _branches = [];

  @override
  void initState() {
    super.initState();
    _countryController.text = 'República Dominicana';
    if (widget.client != null) {
      _loadClientData(widget.client!);
    }
  }

  void _loadClientData(ClientModel client) {
    _nameController.text = client.name;
    _emailController.text = client.email;
    _phoneController.text = client.phone;
    _websiteController.text = client.website ?? '';
    _taxIdController.text = client.taxId;
    _notesController.text = client.notes;

    _streetController.text = client.mainAddress.street;
    _cityController.text = client.mainAddress.city;
    _stateController.text = client.mainAddress.state;
    _countryController.text = client.mainAddress.country;
    _zipCodeController.text = client.mainAddress.zipCode;

    _selectedType = client.type;
    _selectedStatus = client.status;
    _branches = List.from(client.branches);

    // Cargar datos del representante principal
    if (client.contacts.isNotEmpty) {
      final primary = client.contacts.firstWhere(
        (c) => c.isPrimary,
        orElse: () => client.contacts.first,
      );
      _repNameController.text = primary.name;
      _repPositionController.text = primary.position;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _notesController.dispose();
    _repNameController.dispose();
    _repPositionController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _zipCodeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.client != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Cliente' : 'Nuevo Cliente'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildProgressIndicator(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildBasicInfoPage(),
                  _buildAddressPage(),
                  _buildBranchesPage(),
                  _buildSummaryPage(),
                ],
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  // ─── Progress indicator ──────────────────────────────────────────────────
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Info', Icons.business),
          _buildStepConnector(0),
          _buildStepIndicator(1, 'Dirección', Icons.location_on),
          _buildStepConnector(1),
          _buildStepIndicator(2, 'Sucursales', Icons.store),
          _buildStepConnector(2),
          _buildStepIndicator(3, 'Resumen', Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String title, IconData icon) {
    final isActive = _currentPage == step;
    final isCompleted = _currentPage > step;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? AppTheme.successColor
                  : isActive
                      ? AppTheme.primaryColor
                      : Colors.grey[300],
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: isCompleted || isActive ? Colors.white : Colors.grey[600],
              size: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(
              fontSize: 11,
              color: isActive ? AppTheme.primaryColor : Colors.grey[600],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isCompleted = _currentPage > step;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        color: isCompleted ? AppTheme.successColor : Colors.grey[300],
      ),
    );
  }

  // ─── Página 1: Info básica ───────────────────────────────────────────────
  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Información Básica', style: AppTheme.headingMedium),
          const SizedBox(height: 8),
          Text('Ingresa los datos principales del cliente',
              style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 24),

          // ── Empresa ──
          CustomTextField(
            label: 'Nombre de la Empresa *',
            hint: 'Ej: Banco Popular Dominicano',
            controller: _nameController,
            prefixIcon: const Icon(Icons.business),
            validator: (value) =>
                context.read<ClientProvider>().validateClientName(value),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Correo Electrónico *',
            hint: 'contacto@empresa.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email),
            validator: (value) =>
                context.read<ClientProvider>().validateEmail(value),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Teléfono *',
            hint: '+1-809-555-0000',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(Icons.phone),
            validator: (value) =>
                context.read<ClientProvider>().validatePhone(value),
          ),

          // ── Separador Representante ──
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Representante Principal',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Aparecerá en el dashboard y perfil del cliente',
            style: AppTheme.bodySmall.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          CustomTextField(
            label: 'Nombre del Representante',
            hint: 'Ej: Juan Pérez',
            controller: _repNameController,
            prefixIcon: const Icon(Icons.person),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Cargo del Representante',
            hint: 'Ej: Gerente General',
            controller: _repPositionController,
            prefixIcon: const Icon(Icons.work_outline),
          ),

          // ── Datos adicionales ──
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Datos Adicionales',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomTextField(
            label: 'Sitio Web',
            hint: 'www.empresa.com',
            controller: _websiteController,
            keyboardType: TextInputType.url,
            prefixIcon: const Icon(Icons.language),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'RNC / Cédula *',
            hint: '101-12345-6',
            controller: _taxIdController,
            prefixIcon: const Icon(Icons.badge),
            validator: (value) =>
                context.read<ClientProvider>().validateTaxId(value),
          ),
          const SizedBox(height: 16),
          CustomDropdown<ClientType>(
            label: 'Tipo de Cliente',
            hint: 'Selecciona el tipo',
            value: _selectedType,
            items: ClientType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Icon(_getTypeIcon(type),
                        size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(type.displayName),
                  ],
                ),
              );
            }).toList(),
            onChanged: (type) => setState(() => _selectedType = type!),
          ),
          const SizedBox(height: 16),
          CustomDropdown<ClientStatus>(
            label: 'Estado',
            hint: 'Selecciona el estado',
            value: _selectedStatus,
            items: ClientStatus.values.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStatusColor(status),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(status.displayName),
                  ],
                ),
              );
            }).toList(),
            onChanged: (status) => setState(() => _selectedStatus = status!),
          ),
        ],
      ),
    );
  }

  // ─── Página 2: Dirección ─────────────────────────────────────────────────
  Widget _buildAddressPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dirección Principal', style: AppTheme.headingMedium),
          const SizedBox(height: 8),
          Text('Ubicación de la oficina principal del cliente',
              style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 16),

          // ── Botón seleccionar en mapa ──
          OutlinedButton.icon(
            onPressed: _openMapPicker,
            icon: const Icon(Icons.map_outlined, color: Color(0xFF1976D2)),
            label: const Text(
              'Seleccionar en Google Maps',
              style: TextStyle(
                  color: Color(0xFF1976D2), fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'o ingresa la dirección manualmente',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: 'Dirección *',
            hint: 'Av. John F. Kennedy No. 20',
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
              const SizedBox(width: 16),
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
          const SizedBox(height: 24),
          CustomTextField(
            label: 'Notas Adicionales',
            hint: 'Información relevante sobre el cliente...',
            controller: _notesController,
            prefixIcon: const Icon(Icons.note),
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const MapPickerScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _streetController.text = result.street;
        _cityController.text = result.city;
        _stateController.text = result.state;
        _countryController.text =
            result.country.isNotEmpty ? result.country : 'República Dominicana';
        _zipCodeController.text = result.zipCode;
      });
    }
  }

  // ─── Página 3: Sucursales ────────────────────────────────────────────────
  Widget _buildBranchesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: BranchManagementWidget(
        branches: _branches,
        onBranchesChanged: (branches) => setState(() => _branches = branches),
      ),
    );
  }

  // ─── Página 4: Resumen ───────────────────────────────────────────────────
  Widget _buildSummaryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen del Cliente', style: AppTheme.headingMedium),
          const SizedBox(height: 8),
          Text('Revisa la información antes de guardar',
              style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 24),
          _buildSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryItem('Empresa', _nameController.text, Icons.business),
            _buildSummaryItem('Email', _emailController.text, Icons.email),
            _buildSummaryItem('Teléfono', _phoneController.text, Icons.phone),
            if (_repNameController.text.isNotEmpty) ...[
              _buildSummaryItem(
                  'Representante', _repNameController.text, Icons.person),
              if (_repPositionController.text.isNotEmpty)
                _buildSummaryItem(
                    'Cargo', _repPositionController.text, Icons.work_outline),
            ],
            if (_websiteController.text.isNotEmpty)
              _buildSummaryItem(
                  'Website', _websiteController.text, Icons.language),
            _buildSummaryItem('RNC/Cédula', _taxIdController.text, Icons.badge),
            _buildSummaryItem(
                'Tipo', _selectedType.displayName, _getTypeIcon(_selectedType)),
            _buildSummaryItem(
              'Estado',
              _selectedStatus.displayName,
              Icons.info,
              color: _getStatusColor(_selectedStatus),
            ),
            const Divider(height: 24),
            Text('Dirección Principal',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '${_streetController.text}\n${_cityController.text}, ${_stateController.text}\n${_countryController.text} ${_zipCodeController.text}',
              style: AppTheme.bodyMedium,
            ),
            if (_branches.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.store,
                      size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Text('Sucursales (${_branches.length})',
                      style: AppTheme.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              ..._branches.map((branch) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: branch.isActive
                                ? AppTheme.successColor
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${branch.name} - ${branch.address.city}',
                            style: AppTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            if (_notesController.text.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Notas',
                  style: AppTheme.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_notesController.text, style: AppTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        AppTheme.bodySmall.copyWith(color: Colors.grey[600])),
                Text(value,
                    style: AppTheme.bodyMedium
                        .copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Botones ─────────────────────────────────────────────────────────────
  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0) ...[
            Expanded(
              child: CustomButton(
                text: 'Anterior',
                isOutlined: true,
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Consumer<ClientProvider>(
              builder: (context, clientProvider, child) {
                if (_currentPage < 3) {
                  return CustomButton(
                    text: 'Siguiente',
                    onPressed: () {
                      if (_validateCurrentPage()) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  );
                } else {
                  return CustomButton(
                    text: widget.client != null
                        ? 'Actualizar'
                        : 'Guardar Cliente',
                    isLoading: clientProvider.isLoading,
                    onPressed: _saveClient,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _validateCurrentPage() {
    if (_currentPage == 0 || _currentPage == 1) {
      return _formKey.currentState!.validate();
    }
    return true;
  }

  // ─── Guardar ─────────────────────────────────────────────────────────────
  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    final clientProvider = context.read<ClientProvider>();
    final authProvider = context.read<AuthProvider>();

    final address = AddressModel(
      street: _streetController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      country: _countryController.text.trim(),
      zipCode: _zipCodeController.text.trim(),
    );

    // Construir lista de contactos con el representante principal
    List<ContactModel> contacts = [];
    final repName = _repNameController.text.trim();
    if (repName.isNotEmpty) {
      contacts = [
        ContactModel(
          id: 'primary_${DateTime.now().millisecondsSinceEpoch}',
          name: repName,
          position: _repPositionController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          type: ContactType.management,
          isPrimary: true,
        ),
        // Mantener contactos existentes que no sean el principal
        if (widget.client != null)
          ...widget.client!.contacts.where((c) => !c.isPrimary),
      ];
    } else if (widget.client != null) {
      contacts = widget.client!.contacts;
    }

    final now = DateTime.now();
    late ClientModel client;

    if (widget.client != null) {
      client = widget.client!.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        taxId: _taxIdController.text.trim(),
        type: _selectedType,
        status: _selectedStatus,
        mainAddress: address,
        branches: _branches,
        contacts: contacts,
        notes: _notesController.text.trim(),
        updatedAt: now,
      );
    } else {
      client = ClientModel(
        id: '',
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        taxId: _taxIdController.text.trim(),
        type: _selectedType,
        status: _selectedStatus,
        mainAddress: address,
        branches: _branches,
        contacts: contacts,
        notes: _notesController.text.trim(),
        createdAt: now,
        updatedAt: now,
        createdBy: authProvider.currentUser!.id,
      );
    }

    bool success;
    if (widget.client != null) {
      success = await clientProvider.updateClient(client);
    } else {
      success = await clientProvider.createClient(client);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.client != null
              ? 'Cliente actualizado exitosamente'
              : 'Cliente creado exitosamente'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.of(context).pop(true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(clientProvider.errorMessage ?? 'Error desconocido'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  IconData _getTypeIcon(ClientType type) {
    switch (type) {
      case ClientType.small:
        return Icons.store;
      case ClientType.medium:
        return Icons.business;
      case ClientType.large:
        return Icons.apartment;
      case ClientType.enterprise:
        return Icons.domain;
    }
  }

  Color _getStatusColor(ClientStatus status) {
    switch (status) {
      case ClientStatus.active:
        return AppTheme.successColor;
      case ClientStatus.inactive:
        return Colors.grey;
      case ClientStatus.prospect:
        return AppTheme.primaryColor;
      case ClientStatus.suspended:
        return AppTheme.errorColor;
    }
  }
}
