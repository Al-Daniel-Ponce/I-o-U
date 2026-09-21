import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/debt.dart';
import 'package:iou_debt_tracker/services/debt_service.dart';
import 'package:iou_debt_tracker/services/interest_service.dart';

import '../helpers/mocks.dart';

void main() {
  late MockDebtRepository mockRepo;
  late InterestService interestService;
  late DebtService debtService;

  setUp(() {
    mockRepo = MockDebtRepository();
    interestService = InterestService(mockRepo);
    debtService = DebtService(mockRepo, interestService);
  });

  group('Debt CRUD', () {
    test('addDebt creates a debt record', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 500.0,
        transactionDate: DateTime(2024, 1, 15),
      );
      final debts = await debtService.getDebts();
      expect(debts.length, 1);
      expect(debts.first.lenderName, 'Alice');
      expect(debts.first.amount, 500.0);
      expect(debts.first.status, DebtStatus.unpaid);
      expect(debts.first.remainingBalance, 500.0);
    });

    test('updateDebt modifies existing record', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 500.0,
        transactionDate: DateTime(2024, 1, 15),
      );
      final debts = await debtService.getDebts();
      final existing = debts.first;

      await debtService.updateDebt(
        existing,
        lenderName: 'Alice Smith',
        amount: 600.0,
        transactionDate: DateTime(2024, 1, 15),
      );

      final updated = await debtService.getDebtById(existing.id!);
      expect(updated!.lenderName, 'Alice Smith');
      expect(updated.amount, 600.0);
    });

    test('deleteDebt removes the record', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 500.0,
        transactionDate: DateTime(2024, 1, 15),
      );
      final debts = await debtService.getDebts();
      await debtService.deleteDebt(debts.first.id!);
      expect(await debtService.getDebts(), isEmpty);
    });
  });

  group('Payment recording', () {
    test('partial payment updates remaining balance and status', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 1000.0,
        transactionDate: DateTime(2024, 1, 15),
      );
      final debts = await debtService.getDebts();
      final debt = debts.first;

      await debtService.recordPayment(debt: debt, amount: 300.0);

      final updated = await debtService.getDebtById(debt.id!);
      expect(updated!.remainingBalance, 700.0);
      expect(updated.status, DebtStatus.partial);
      expect(updated.amountPaid, 300.0);
      expect(updated.progress, closeTo(0.3, 0.001));
    });

    test('full payment marks as paid', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 500.0,
        transactionDate: DateTime(2024, 1, 15),
      );
      final debts = await debtService.getDebts();
      final debt = debts.first;

      await debtService.recordPayment(debt: debt, amount: 500.0);

      final updated = await debtService.getDebtById(debt.id!);
      expect(updated!.remainingBalance, 0.0);
      expect(updated.status, DebtStatus.paid);
      expect(updated.isPaid, true);
    });

    test('multiple payments accumulate correctly', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 1000.0,
        transactionDate: DateTime(2024, 1, 15),
      );
      final debts = await debtService.getDebts();
      var debt = debts.first;

      await debtService.recordPayment(debt: debt, amount: 200.0, note: 'First');

      debt = (await debtService.getDebtById(debt.id!))!;
      await debtService.recordPayment(debt: debt, amount: 300.0, note: 'Second');

      final updated = await debtService.getDebtById(debt.id!);
      expect(updated!.remainingBalance, 500.0);
      expect(updated.status, DebtStatus.partial);

      final payments = await debtService.getPaymentHistory(debt.id!);
      expect(payments.length, 2);
      expect(payments.map((p) => p.paymentAmount), containsAll([200.0, 300.0]));
    });
  });

  group('Search and filter', () {
    setUp(() async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 100.0,
        transactionDate: DateTime(2024, 1, 1),
      );
      await debtService.addDebt(
        lenderName: 'Bob',
        amount: 200.0,
        transactionDate: DateTime(2024, 2, 1),
      );
      var debts = await debtService.getDebts();
      for (final d in debts) {
        if (d.lenderName == 'Bob') {
          final fresh = await debtService.getDebtById(d.id!);
          if (fresh != null) {
            await debtService.recordPayment(debt: fresh, amount: 200.0);
          }
        }
      }
    });

    test('search by lender name', () async {
      final results = await debtService.getDebts(search: 'Ali');
      expect(results.length, 1);
      expect(results.first.lenderName, 'Alice');
    });

    test('filter by status', () async {
      final unpaid =
          await debtService.getDebts(statusFilter: DebtStatus.unpaid);
      expect(unpaid.length, 1);
      expect(unpaid.first.lenderName, 'Alice');

      final paid = await debtService.getDebts(statusFilter: DebtStatus.paid);
      expect(paid.length, 1);
      expect(paid.first.lenderName, 'Bob');
    });
  });

  group('Summary', () {
    test('getSummary returns correct aggregates', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 1000.0,
        transactionDate: DateTime(2024, 1, 1),
      );
      await debtService.addDebt(
        lenderName: 'Bob',
        amount: 500.0,
        transactionDate: DateTime(2024, 2, 1),
      );

      var summary = await debtService.getSummary();
      expect(summary.totalBorrowed, 1500.0);
      expect(summary.totalRemaining, 1500.0);
      expect(summary.unpaidCount, 2);

      var debts = await debtService.getDebts();
      for (final d in debts) {
        if (d.lenderName == 'Alice') {
          final fresh = await debtService.getDebtById(d.id!);
          if (fresh != null) {
            await debtService.recordPayment(debt: fresh, amount: 400.0);
          }
        }
      }

      summary = await debtService.getSummary();
      expect(summary.totalRemaining, 1100.0);
      expect(summary.partialCount, 1);
      expect(summary.unpaidCount, 1);
    });
  });

  group('Note trimming', () {
    test('blank notes are stored as null', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 100.0,
        transactionDate: DateTime(2024, 1, 1),
        notes: '   ',
      );
      final debts = await debtService.getDebts();
      expect(debts.first.notes, isNull);
    });

    test('whitespace is trimmed from notes', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 100.0,
        transactionDate: DateTime(2024, 1, 1),
        notes: '  hello  ',
      );
      final debts = await debtService.getDebts();
      expect(debts.first.notes, 'hello');
    });
  });

  group('Interest', () {
    test('addDebt with interest rate stores it', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 1000.0,
        transactionDate: DateTime(2024, 1, 1),
        interestRate: 5.0,
        interestType: InterestType.simple,
        interestMode: InterestMode.manual,
      );
      final debts = await debtService.getDebts();
      expect(debts.first.interestRate, 5.0);
      expect(debts.first.interestType, InterestType.simple);
      expect(debts.first.interestMode, InterestMode.manual);
      expect(debts.first.hasInterest, true);
    });

    test('addDebt with automatic interest stores frequency', () async {
      await debtService.addDebt(
        lenderName: 'Bob',
        amount: 2000.0,
        transactionDate: DateTime(2024, 1, 1),
        interestRate: 5.0,
        interestType: InterestType.compound,
        interestMode: InterestMode.automatic,
        interestFrequencyDays: 7,
        interestStartDate: DateTime(2024, 2, 1),
      );
      final debts = await debtService.getDebts();
      final debt = debts.firstWhere((d) => d.lenderName == 'Bob');
      expect(debt.interestType, InterestType.compound);
      expect(debt.interestMode, InterestMode.automatic);
      expect(debt.interestFrequencyDays, 7);
      expect(debt.interestStartDate, DateTime(2024, 2, 1));
      expect(debt.nextInterestDate, DateTime(2024, 2, 1));
      expect(debt.isAutomaticInterest, true);
    });

    test('addDebt without interest leaves fields null', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 1000.0,
        transactionDate: DateTime(2024, 1, 1),
      );
      final debts = await debtService.getDebts();
      expect(debts.first.interestRate, isNull);
      expect(debts.first.hasInterest, false);
    });

    test('applyInterest adds to remaining balance', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 1000.0,
        transactionDate: DateTime(2024, 1, 1),
        interestRate: 10.0,
      );
      final debt = (await debtService.getDebts()).first;

      final amount = await debtService.applyInterest(debt);
      expect(amount, 100.0); // 10% of 1000

      final updated = await debtService.getDebtById(debt.id!);
      expect(updated!.remainingBalance, 1100.0);
    });

    test('applyInterest records in interest_history', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 500.0,
        transactionDate: DateTime(2024, 1, 1),
        interestRate: 5.0,
      );
      final debt = (await debtService.getDebts()).first;
      await debtService.applyInterest(debt);

      final history = await debtService.getInterestHistory(debt.id!);
      expect(history.length, 1);
      expect(history.first.interestAmount, 25.0);
      expect(history.first.isManual, true);
      expect(history.first.balanceBefore, 500.0);
      expect(history.first.balanceAfter, 525.0);
    });

    test('applyInterest does nothing for paid debts', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 500.0,
        transactionDate: DateTime(2024, 1, 1),
        interestRate: 5.0,
      );
      final debt = (await debtService.getDebts()).first;
      final fresh = await debtService.getDebtById(debt.id!);
      await debtService.recordPayment(
          debt: fresh!, amount: 500.0, note: 'Full');

      final paidDebt = await debtService.getDebtById(debt.id!);
      final amount = await debtService.applyInterest(paidDebt!);
      expect(amount, 0.0);
    });

    test('applyInterest returns 0 for debts without interest', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 500.0,
        transactionDate: DateTime(2024, 1, 1),
      );
      final debt = (await debtService.getDebts()).first;
      final amount = await debtService.applyInterest(debt);
      expect(amount, 0.0);
    });

    test('simple interest uses original amount', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 1000.0,
        transactionDate: DateTime(2024, 1, 1),
        interestRate: 5.0,
        interestType: InterestType.simple,
      );
      var debt = (await debtService.getDebts()).first;

      // Apply first interest
      var amount = await debtService.applyInterest(debt);
      expect(amount, 50.0); // 5% of 1000

      // Pay some
      debt = (await debtService.getDebtById(debt.id!))!;
      await debtService.recordPayment(debt: debt, amount: 200.0);

      // Apply second interest - should still use original 1000
      debt = (await debtService.getDebtById(debt.id!))!;
      amount = await debtService.applyInterest(debt);
      expect(amount, 50.0); // Still 5% of 1000, not 850
    });

    test('compound interest uses current balance', () async {
      await debtService.addDebt(
        lenderName: 'Bob',
        amount: 1000.0,
        transactionDate: DateTime(2024, 1, 1),
        interestRate: 10.0,
        interestType: InterestType.compound,
      );
      var debt = (await debtService.getDebts()).first;

      // First: 10% of 1000 = 100
      var amount = await debtService.applyInterest(debt);
      expect(amount, 100.0);
      expect((await debtService.getDebtById(debt.id!))!.remainingBalance, 1100.0);

      // Second: 10% of 1100 = 110
      debt = (await debtService.getDebtById(debt.id!))!;
      amount = await debtService.applyInterest(debt);
      expect(amount, 110.0);
      expect((await debtService.getDebtById(debt.id!))!.remainingBalance, 1210.0);
    });

    test('updateDebt clears interest when clearInterest is true', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 1000.0,
        transactionDate: DateTime(2024, 1, 1),
        interestRate: 5.0,
        interestType: InterestType.simple,
        interestMode: InterestMode.automatic,
        interestFrequencyDays: 7,
        interestStartDate: DateTime(2024, 2, 1),
      );
      var debt = (await debtService.getDebts()).first;
      expect(debt.hasInterest, true);

      await debtService.updateDebt(
        debt,
        lenderName: 'Alice',
        amount: 1000.0,
        transactionDate: DateTime(2024, 1, 1),
        clearInterest: true,
      );
      debt = (await debtService.getDebts()).first;
      expect(debt.interestRate, isNull);
      expect(debt.hasInterest, false);
      expect(debt.interestMode, isNull);
    });

    test('getInterestHistory returns transactions', () async {
      await debtService.addDebt(
        lenderName: 'Alice',
        amount: 1000.0,
        transactionDate: DateTime(2024, 1, 1),
        interestRate: 5.0,
      );
      final debt = (await debtService.getDebts()).first;

      await debtService.applyInterest(debt);
      await debtService.applyInterest(
          (await debtService.getDebtById(debt.id!))!);

      final history = await debtService.getInterestHistory(debt.id!);
      expect(history.length, 2);
    });
  });
}
