import 'package:flutter_test/flutter_test.dart';
import 'package:pm_monitor/core/services/workload_calculator.dart';

// Las funciones probadas aquí son puras; no tocan Firestore.
void main() {
  group('WorkloadCalculator (lógica pura)', () {
    final calc = WorkloadCalculator();

    test('reconoce estados activos de asignación y ejecución', () {
      expect(
        WorkloadCalculator.activeStatuses,
        containsAll(
            ['assigned', 'scheduled', 'inProgress', 'in_progress', 'overdue']),
      );
    });

    test('weekStartOf devuelve el lunes a las 00:00', () {
      // Miércoles 8 oct 2026
      expect(WorkloadCalculator.weekStartOf(DateTime(2026, 10, 8, 15, 30)),
          DateTime(2026, 10, 5));
      // Domingo 11 oct 2026 -> lunes 5
      expect(WorkloadCalculator.weekStartOf(DateTime(2026, 10, 11, 23)),
          DateTime(2026, 10, 5));
      // Lunes ya es inicio
      expect(WorkloadCalculator.weekStartOf(DateTime(2026, 10, 12, 8)),
          DateTime(2026, 10, 12));
    });

    test('isoWeekNumber cumple ISO 8601', () {
      expect(WorkloadCalculator.isoWeekNumber(DateTime(2026, 1, 1)), 1);
      expect(WorkloadCalculator.isoWeekNumber(DateTime(2027, 1, 1)), 53);
      expect(WorkloadCalculator.isoWeekNumber(DateTime(2024, 12, 30)), 1);
      expect(WorkloadCalculator.isoWeekNumber(DateTime(2026, 10, 11)), 41);
    });

    test('todo en horario regular (martes 9:00, 3h)', () {
      final h = calc.calculateMaintenanceHours(DateTime(2026, 10, 6, 9), 3);
      expect(h.regular, 3);
      expect(h.overtime, 0);
    });

    test('parte regular y parte extra (viernes 16:00, 3h)', () {
      final h = calc.calculateMaintenanceHours(DateTime(2026, 10, 9, 16), 3);
      expect(h.regular, 1);
      expect(h.overtime, 2);
    });

    test('empieza antes de las 8 (lunes 7:00, 3h)', () {
      final h = calc.calculateMaintenanceHours(DateTime(2026, 10, 5, 7), 3);
      expect(h.regular, 2);
      expect(h.overtime, 1);
    });

    test('sábado termina a las 12 (sábado 11:00, 2h)', () {
      final h = calc.calculateMaintenanceHours(DateTime(2026, 10, 10, 11), 2);
      expect(h.regular, 1);
      expect(h.overtime, 1);
    });

    test('domingo es todo extra', () {
      final h = calc.calculateMaintenanceHours(DateTime(2026, 10, 11, 10), 4);
      expect(h.regular, 0);
      expect(h.overtime, 4);
    });

    test('WeeklyWorkload marca límite y casi-límite', () {
      WeeklyWorkload week(double current, double add) => WeeklyWorkload(
            weekStart: DateTime(2026, 10, 5),
            current: WorkHours(regular: current),
            additional: WorkHours(regular: add),
            newMaintenances: 1,
            maxWeeklyHours: 44,
            nearLimitRatio: 0.9,
          );

      expect(week(30, 5).exceedsLimit, isFalse);
      expect(week(30, 5).isNearLimit, isFalse);
      expect(week(38, 2).isNearLimit, isTrue); // 40 >= 39.6
      expect(week(40, 6).exceedsLimit, isTrue);
      expect(week(40, 6).isNearLimit, isFalse);
    });
  });
}
