import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/client_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/client_model.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/widgets/custom_widgets.dart';

class AddClientScreen extends StatefulWidget {
  final ClientModel? client; // Para editar cliente existente

  const AddClientScreen({super.key, this.client});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;

  // Controllers para información básica
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _notesController = TextEditingController();

  // Controllers para dirección
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _zipCodeController = TextEditingController();

  // Variables de estado
  ClientType _selectedType = ClientType.small;
  ClientStatus _selectedStatus = ClientStatus.active;

  @override
  void initState() {
    super.initState();
    _countryController.text = 'República Dominicana';

    // Si estamos editando, cargar datos
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _notesController.dispose();
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
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildBasicInfoPage(),
                  _buildAddressPage(),
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

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Información', Icons.business),
          _buildStepConnector(0),
          _buildStepIndicator(1, 'Dirección', Icons.location_on),
          _buildStepConnector(1),
          _buildStepIndicator(2, 'Resumen', Icons.check_circle),
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
            width: 40,
            height: 40,
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
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(
              color: isActive ? AppTheme.primaryColor : Colors.grey[600],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
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

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información Básica',
            style: AppTheme.headingMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresa los datos principales del cliente',
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 16),
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
            onChanged: (type) {
              setState(() {
                _selectedType = type!;
              });
            },
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
            onChanged: (status) {
              setState(() {
                _selectedStatus = status!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddressPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dirección Principal',
            style: AppTheme.headingMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Ubicación de la oficina principal del cliente',
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
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

  Widget _buildSummaryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen del Cliente',
            style: AppTheme.headingMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa la información antes de guardar',
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
          ),
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
            if (_websiteController.text.isNotEmpty)
              _buildSummaryItem(
                  'Website', _websiteController.text, Icons.language),
            _buildSummaryItem('RNC/Cédula', _taxIdController.text, Icons.badge),
            _buildSummaryItem(
                'Tipo', _selectedType.displayName, _getTypeIcon(_selectedType)),
            _buildSummaryItem('Estado', _selectedStatus.displayName, Icons.info,
                color: _getStatusColor(_selectedStatus)),
            const Divider(height: 24),
            Text(
              'Dirección',
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${_streetController.text}\n${_cityController.text}, ${_stateController.text}\n${_countryController.text} ${_zipCodeController.text}',
              style: AppTheme.bodyMedium,
            ),
            if (_notesController.text.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Notas',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _notesController.text,
                style: AppTheme.bodyMedium,
              ),
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
                Text(
                  label,
                  style: AppTheme.bodySmall.copyWith(color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style:
                      AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                if (_currentPage < 2) {
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
    if (_currentPage == 0) {
      // Validar página de información básica
      return _formKey.currentState!.validate();
    } else if (_currentPage == 1) {
      // Validar página de dirección
      return _formKey.currentState!.validate();
    }
    return true;
  }

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

    final now = DateTime.now();
    late ClientModel client;

    if (widget.client != null) {
      // Actualizar cliente existente
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
        notes: _notesController.text.trim(),
        updatedAt: now,
      );
    } else {
      // Crear nuevo cliente
      client = ClientModel(
        id: '', // Firestore generará el ID
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
      Navigator.of(context).pop();
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
