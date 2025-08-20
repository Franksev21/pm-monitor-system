// Crear este archivo: lib/features/auth/widgets/technician_equipment_count.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TechnicianEquipmentCount extends StatelessWidget {
  final String technicianId;
  final TextStyle? style;

  const TechnicianEquipmentCount({
    Key? key,
    required this.technicianId,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('equipments')
          .where('assignedTechnicianId', isEqualTo: technicianId)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error', style: style);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1,
              color: style?.color ?? Colors.grey,
            ),
          );
        }

        final count = snapshot.data?.docs.length ?? 0;
        return Text(
          '$count equipos asignados',
          style: style,
        );
      },
    );
  }
}
