// lib/shared/widgets/equipment_type_selector_field.dart

import 'package:flutter/material.dart';
import 'package:pm_monitor/features/equipment/screens/equipment_search_dialog_screen.dart';

class EquipmentTypeSelectorField extends StatelessWidget {
  final String? selectedType;
  final Function(String typeName) onTypeSelected;
  final bool enabled;
  final String? labelText;
  final String? hintText;
  final bool showManagementButton; // ✨ AÑADIDO

  const EquipmentTypeSelectorField({
    super.key,
    this.selectedType,
    required this.onTypeSelected,
    this.enabled = true,
    this.labelText = 'Tipo de Equipo',
    this.hintText = 'Selecciona un tipo',
    this.showManagementButton = true, // ✨ VALOR POR DEFECTO
  });

  // Iconos para cada tipo
  static const Map<String, String> _typeIcons = {
    'Climatización': '❄️',
    'Equipos Eléctricos': '⚡',
    'Paneles Eléctricos': '🔌',
    'Generadores': '🔋',
    'UPS': '🔌',
    'Equipos de Cocina': '🍳',
    'Facilidades': '🏢',
    'Otros': '🔧',
  };

  @override
  Widget build(BuildContext context) {
    final icon =
        selectedType != null ? (_typeIcons[selectedType] ?? '🔧') : '🔧';

    return InkWell(
      onTap: enabled ? () => _showTypePicker(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedType != null
                ? const Color(0xFF2196F3)
                : Theme.of(context).colorScheme.outlineVariant,
            width: selectedType != null ? 2 : 1,
          ),
          boxShadow: selectedType != null
              ? [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icono
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: selectedType != null
                      ? [const Color(0xFF2196F3), const Color(0xFF1976D2)]
                      : [
                          Theme.of(context).colorScheme.outlineVariant,
                          Theme.of(context).colorScheme.onSurfaceVariant
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (labelText != null)
                    Text(
                      labelText!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    selectedType ?? hintText ?? 'Selecciona un tipo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selectedType != null
                          ? Colors.black87
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Icono de acción
            Icon(
              enabled ? Icons.arrow_drop_down : Icons.lock,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTypePicker(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => EquipmentTypeSearchDialog(
        selectedType: selectedType,
        showManagementButton: showManagementButton, // ✨ PASAR EL PARÁMETRO
      ),
    );

    if (result != null) {
      onTypeSelected(result);
    }
  }
}
