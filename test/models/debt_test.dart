import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/debt.dart';

void main() {
  group('Debt', () {
    final jan2024 = DateTime(2024, 1, 15);
    final sample = Debt(
      id: 1,
      lenderName: 'Alice',
      amount: 1000.0,
      transactionDate: jan2024,
      notes: 'Lunch money',
      status: DebtStatus.unpaid,
      remainingBalance: 750.0,
      createdAt: jan2024,
    );

    test('toMap contains all fields', () {
      final map = sample.toMap();
      expect(map['lender_name'], 'Alice');
      expect(map['amount'], 1000.0);
      expect(map['status'], 'unpaid');
      expect(map['remaining_balance'], 750.0);
      expect(map['interest_rate'], isNull);
      expect(map['next_interest_date'], isNull);
    });

    test('toMap includes interest fields when set', () {
      final withInterest = sample.copyWith(
        interestRate: 5.0,
        interestType: InterestType.simple,
        interestMode: InterestMode.manual,
        nextInterestDate: DateTime(2024, 6, 15),
      );
      final map = withInterest.toMap();
      expect(map['interest_rate'], 5.0);
      expect(map['interest_type'], 'simple');
      expect(map['interest_mode'], 'manual');
      expect(map['next_interest_date'], '2024-06-15T00:00:00.000');
    });

    test('fromMap reconstructs Debt correctly', () {
      final map = sample.toMap();
      final restored = Debt.fromMap(map);
      expect(restored.id, sample.id);
      expect(restored.lenderName, sample.lenderName);
      expect(restored.amount, sample.amount);
      expect(restored.remainingBalance, sample.remainingBalance);
      expect(restored.status, sample.status);
      expect(restored.interestRate, isNull);
    });

    test('fromMap handles interest fields', () {
      final withInterest = sample.copyWith(
        interestRate: 5.0,
        interestType: InterestType.simple,
        interestMode: InterestMode.automatic,
        interestFrequencyDays: 7,
        interestStartDate: DateTime(2024, 3, 1),
        nextInterestDate: DateTime(2024, 6, 15),
      );
      final map = withInterest.toMap();
      final restored = Debt.fromMap(map);
      expect(restored.interestRate, 5.0);
      expect(restored.interestType, InterestType.simple);
      expect(restored.interestMode, InterestMode.automatic);
      expect(restored.interestFrequencyDays, 7);
      expect(restored.interestStartDate, DateTime(2024, 3, 1));
      expect(restored.nextInterestDate, DateTime(2024, 6, 15));
    });

    test('amountPaid returns difference', () {
      expect(sample.amountPaid, 250.0);
    });

    test('progress is correct for partial payment', () {
      expect(sample.progress, closeTo(0.25, 0.001));
    });

    test('progress is 0 when amount is 0', () {
      final zero = sample.copyWith(amount: 0, remainingBalance: 0);
      expect(zero.progress, 0.0);
    });

    test('isPaid is false for unpaid', () {
      expect(sample.isPaid, false);
    });

    test('isPaid is true for paid status', () {
      final paid =
          sample.copyWith(status: DebtStatus.paid, remainingBalance: 0);
      expect(paid.isPaid, true);
    });

    test('avatarInitial returns first letter uppercase', () {
      expect(sample.avatarInitial, 'A');
    });

    test('avatarInitial returns ? for empty name', () {
      final d = sample.copyWith(lenderName: '');
      expect(d.avatarInitial, '?');
    });

    test('copyWith preserves unchanged fields', () {
      final modified = sample.copyWith(amount: 2000.0);
      expect(modified.id, 1);
      expect(modified.lenderName, 'Alice');
      expect(modified.amount, 2000.0);
      expect(modified.remainingBalance, 750.0);
      expect(modified.interestRate, isNull);
    });

    test('copyWith handles interest fields', () {
      final modified = sample.copyWith(
        interestRate: 5.0,
        interestType: InterestType.compound,
        interestMode: InterestMode.automatic,
        interestFrequencyDays: 14,
        nextInterestDate: DateTime(2024, 6, 15),
      );
      expect(modified.interestRate, 5.0);
      expect(modified.interestType, InterestType.compound);
      expect(modified.interestMode, InterestMode.automatic);
      expect(modified.interestFrequencyDays, 14);
      expect(modified.nextInterestDate, DateTime(2024, 6, 15));
    });

    test('copyWith clearInterest clears interest fields', () {
      final withInterest = sample.copyWith(
        interestRate: 5.0,
        interestType: InterestType.simple,
        interestMode: InterestMode.automatic,
        interestFrequencyDays: 7,
        interestStartDate: DateTime(2024, 3, 1),
        nextInterestDate: DateTime(2024, 6, 15),
      );
      final cleared = withInterest.copyWith(clearInterest: true);
      expect(cleared.interestRate, isNull);
      expect(cleared.interestType, isNull);
      expect(cleared.interestMode, isNull);
      expect(cleared.interestFrequencyDays, isNull);
      expect(cleared.interestStartDate, isNull);
      expect(cleared.nextInterestDate, isNull);
      expect(cleared.amount, 1000.0);
    });

    test('hasInterest is false when rate is null', () {
      expect(sample.hasInterest, false);
    });

    test('hasInterest is false when rate is 0', () {
      final zero = sample.copyWith(interestRate: 0);
      expect(zero.hasInterest, false);
    });

    test('hasInterest is true when rate is positive', () {
      final withInt = sample.copyWith(interestRate: 5.0);
      expect(withInt.hasInterest, true);
    });

    test('frequencyLabel returns correct labels', () {
      expect(
          sample.copyWith(interestFrequencyDays: 1).frequencyLabel, 'Every day');
      expect(
          sample.copyWith(interestFrequencyDays: 2).frequencyLabel, 'Every 2 days');
      expect(
          sample.copyWith(interestFrequencyDays: 7).frequencyLabel, 'Every week');
      expect(sample.copyWith(interestFrequencyDays: 14).frequencyLabel,
          'Every 2 weeks');
      expect(sample.copyWith(interestFrequencyDays: 30).frequencyLabel,
          'Every month');
      expect(sample.copyWith(interestFrequencyDays: 5).frequencyLabel,
          'Every 5 days');
    });

    test('isAutomaticInterest returns true only for automatic mode with rate',
        () {
      final automatic = sample.copyWith(
        interestRate: 5.0,
        interestMode: InterestMode.automatic,
      );
      expect(automatic.isAutomaticInterest, true);

      final manual = sample.copyWith(
        interestRate: 5.0,
        interestMode: InterestMode.manual,
      );
      expect(manual.isAutomaticInterest, false);

      expect(sample.isAutomaticInterest, false);
    });
  });

  group('InterestTransaction', () {
    test('toMap / fromMap round-trip', () {
      final t = InterestTransaction(
        debtId: 1,
        appliedAt: DateTime(2024, 6, 15, 10, 30),
        interestRate: 5.0,
        interestAmount: 50.0,
        balanceBefore: 1000.0,
        balanceAfter: 1050.0,
        type: 'manual',
      );
      final map = t.toMap();
      final restored = InterestTransaction.fromMap(map);
      expect(restored.debtId, 1);
      expect(restored.interestRate, 5.0);
      expect(restored.interestAmount, 50.0);
      expect(restored.balanceBefore, 1000.0);
      expect(restored.balanceAfter, 1050.0);
      expect(restored.type, 'manual');
      expect(restored.isManual, true);
      expect(restored.isAutomatic, false);
    });

    test('automatic type properties', () {
      final t = InterestTransaction(
        debtId: 1,
        appliedAt: DateTime.now(),
        interestRate: 5.0,
        interestAmount: 50.0,
        balanceBefore: 1000.0,
        balanceAfter: 1050.0,
        type: 'automatic',
      );
      expect(t.isAutomatic, true);
      expect(t.isManual, false);
    });
  });

  group('PaymentHistory', () {
    final jan2024 = DateTime(2024, 1, 15);

    test('displayNote falls back to Payment', () {
      final p = PaymentHistory(
        debtId: 1,
        paymentAmount: 100,
        paymentDate: jan2024,
      );
      expect(p.displayNote, 'Payment');
    });

    test('displayNote shows Interest accrued for negative amounts', () {
      final p = PaymentHistory(
        debtId: 1,
        paymentAmount: -50,
        paymentDate: jan2024,
      );
      expect(p.displayNote, 'Interest accrued');
      expect(p.isInterest, true);
    });

    test('displayNote uses custom note', () {
      final p2 = PaymentHistory(
        debtId: 1,
        paymentAmount: 100,
        paymentDate: jan2024,
        paymentNote: 'Cash',
      );
      expect(p2.displayNote, 'Cash');
    });

    test('toMap / fromMap round-trip', () {
      final p2 = PaymentHistory(
        debtId: 1,
        paymentAmount: 250.0,
        paymentDate: jan2024,
        paymentNote: 'Test',
      );
      final map = p2.toMap();
      final restored = PaymentHistory.fromMap(map);
      expect(restored.debtId, p2.debtId);
      expect(restored.paymentAmount, p2.paymentAmount);
      expect(restored.paymentNote, p2.paymentNote);
    });
  });

  group('DebtSummary', () {
    test('totalPaid and overallProgress', () {
      const summary = DebtSummary(
        totalBorrowed: 1000,
        totalRemaining: 400,
        unpaidCount: 1,
        partialCount: 1,
        paidCount: 1,
      );
      expect(summary.totalPaid, 600);
      expect(summary.overallProgress, closeTo(0.6, 0.001));
    });

    test('empty has all zeros', () {
      expect(DebtSummary.empty.totalBorrowed, 0);
      expect(DebtSummary.empty.overallProgress, 0);
    });
  });

  group('InterestType', () {
    test('fromString returns correct enum', () {
      expect(InterestType.fromString('simple'), InterestType.simple);
      expect(InterestType.fromString('compound'), InterestType.compound);
      expect(InterestType.fromString('invalid'), InterestType.simple);
    });

    test('label returns correct string', () {
      expect(InterestType.simple.label, 'Simple Interest');
      expect(InterestType.compound.label, 'Compound Interest');
    });
  });

  group('InterestMode', () {
    test('fromString returns correct enum', () {
      expect(InterestMode.fromString('manual'), InterestMode.manual);
      expect(InterestMode.fromString('automatic'), InterestMode.automatic);
      expect(InterestMode.fromString('invalid'), InterestMode.manual);
    });

    test('label returns correct string', () {
      expect(InterestMode.manual.label, 'Manual');
      expect(InterestMode.automatic.label, 'Automatic');
    });
  });
}
