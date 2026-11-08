import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/borrower_group.dart';
import 'package:iou_debt_tracker/models/debt.dart';

Debt _debt({
  int? id,
  required String lenderName,
  required double amount,
  double? remainingBalance,
  DebtStatus status = DebtStatus.unpaid,
  DateTime? createdAt,
}) {
  return Debt(
    id: id,
    lenderName: lenderName,
    amount: amount,
    transactionDate: DateTime(2026, 1, 1),
    notes: null,
    status: status,
    remainingBalance: remainingBalance ?? amount,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('BorrowerGroup.fromDebts', () {
    test('clusters debts by counterparty name', () {
      final groups = BorrowerGroup.fromDebts([
        _debt(id: 1, lenderName: 'Maria Santos', amount: 500),
        _debt(id: 2, lenderName: 'Maria Santos', amount: 300),
        _debt(id: 3, lenderName: 'Juan Dela Cruz', amount: 1000),
      ]);

      expect(groups, hasLength(2));

      final maria = groups.firstWhere((g) => g.name == 'Maria Santos');
      expect(maria.count, 2);
      expect(maria.totalRemaining, 800);

      final juan = groups.firstWhere((g) => g.name == 'Juan Dela Cruz');
      expect(juan.count, 1);
      expect(juan.totalRemaining, 1000);
    });

    test('trims names so "Maria" and "Maria " group together', () {
      final groups = BorrowerGroup.fromDebts([
        _debt(id: 1, lenderName: 'Maria', amount: 100),
        _debt(id: 2, lenderName: 'Maria ', amount: 200),
      ]);

      expect(groups, hasLength(1));
      expect(groups.first.count, 2);
    });

    test('orders the biggest outstanding balance first', () {
      final groups = BorrowerGroup.fromDebts([
        _debt(id: 1, lenderName: 'Small', amount: 100),
        _debt(id: 2, lenderName: 'Large', amount: 9000),
        _debt(id: 3, lenderName: 'Medium', amount: 5000),
      ]);

      expect(
        groups.map((g) => g.name).toList(),
        ['Large', 'Medium', 'Small'],
      );
    });

    test('counts open vs settled debts and derives progress', () {
      final groups = BorrowerGroup.fromDebts([
        _debt(id: 1, lenderName: 'Maria', amount: 400),
        _debt(id: 2, lenderName: 'Maria', amount: 600, status: DebtStatus.paid,
            remainingBalance: 0),
      ]);

      final maria = groups.single;

      expect(maria.count, 2);
      expect(maria.paidCount, 1);
      expect(maria.openCount, 1);
      expect(maria.totalAmount, 1000);
      expect(maria.totalRemaining, 400);
      expect(maria.progress, closeTo(0.6, 0.001));
    });

    test('an empty list yields no groups', () {
      expect(BorrowerGroup.fromDebts([]), isEmpty);
    });

    test('reports the newest debt as most recent', () {
      final groups = BorrowerGroup.fromDebts([
        _debt(id: 1, lenderName: 'Maria', amount: 100,
            createdAt: DateTime(2026, 1, 1)),
        _debt(id: 2, lenderName: 'Maria', amount: 100,
            createdAt: DateTime(2026, 3, 9)),
      ]);

      expect(groups.single.mostRecent, DateTime(2026, 3, 9));
    });

    test('gives a usable display name when the field is blank', () {
      final groups = BorrowerGroup.fromDebts([
        _debt(id: 1, lenderName: '   ', amount: 100),
      ]);

      expect(groups.single.displayName, 'Unknown borrower');
      expect(groups.single.avatarInitial, 'U');
    });
  });
}
