import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/debt.dart';
import 'package:iou_debt_tracker/services/interest_calculator.dart';

void main() {
  group('InterestCalculator.calculate', () {
    test('simple interest uses original amount', () {
      final result = InterestCalculator.calculate(
        type: InterestType.simple,
        rate: 5.0,
        originalAmount: 1000.0,
        currentBalance: 800.0,
      );
      expect(result, 50.0); // 5% of 1000
    });

    test('compound interest uses current balance', () {
      final result = InterestCalculator.calculate(
        type: InterestType.compound,
        rate: 10.0,
        originalAmount: 1000.0,
        currentBalance: 1100.0,
      );
      expect(result, 110.0); // 10% of 1100
    });

    test('returns 0 for zero rate', () {
      final result = InterestCalculator.calculate(
        type: InterestType.simple,
        rate: 0.0,
        originalAmount: 1000.0,
        currentBalance: 1000.0,
      );
      expect(result, 0.0);
    });

    test('returns 0 for negative rate', () {
      final result = InterestCalculator.calculate(
        type: InterestType.simple,
        rate: -5.0,
        originalAmount: 1000.0,
        currentBalance: 1000.0,
      );
      expect(result, 0.0);
    });

    test('handles decimal rates correctly', () {
      final result = InterestCalculator.calculate(
        type: InterestType.simple,
        rate: 3.5,
        originalAmount: 2000.0,
        currentBalance: 2000.0,
      );
      expect(result, 70.0); // 3.5% of 2000
    });
  });

  group('InterestCalculator.newBalance', () {
    test('simple interest adds to current balance', () {
      final result = InterestCalculator.newBalance(
        type: InterestType.simple,
        rate: 5.0,
        originalAmount: 1000.0,
        currentBalance: 800.0,
      );
      expect(result, 850.0); // 800 + 50
    });

    test('compound interest adds to current balance', () {
      final result = InterestCalculator.newBalance(
        type: InterestType.compound,
        rate: 10.0,
        originalAmount: 1000.0,
        currentBalance: 1100.0,
      );
      expect(result, 1210.0); // 1100 + 110
    });
  });

  group('InterestCalculator.calculateNextDate', () {
    test('returns startDate if no currentNextDate and startDate >= fromDate',
        () {
      final result = InterestCalculator.calculateNextDate(
        startDate: DateTime(2024, 3, 1),
        frequencyDays: 7,
        fromDate: DateTime(2024, 2, 15),
      );
      expect(result, DateTime(2024, 3, 1));
    });

    test('advances from startDate when currentNextDate is null', () {
      final result = InterestCalculator.calculateNextDate(
        startDate: DateTime(2024, 1, 1),
        frequencyDays: 7,
        fromDate: DateTime(2024, 1, 20),
      );
      expect(result, DateTime(2024, 1, 22)); // 1 + 21 = 22
    });

    test('advances from currentNextDate', () {
      final result = InterestCalculator.calculateNextDate(
        startDate: DateTime(2024, 1, 1),
        frequencyDays: 2,
        fromDate: DateTime(2024, 1, 10),
        currentNextDate: DateTime(2024, 1, 5),
      );
      expect(result, DateTime(2024, 1, 11)); // 5 + 6 = 11
    });

    test('handles month boundaries', () {
      final result = InterestCalculator.calculateNextDate(
        startDate: DateTime(2024, 1, 28),
        frequencyDays: 7,
        fromDate: DateTime(2024, 2, 10),
      );
      expect(result, DateTime(2024, 2, 11)); // Jan 28 + 14 = Feb 11
    });

    test('handles year boundaries', () {
      final result = InterestCalculator.calculateNextDate(
        startDate: DateTime(2024, 12, 25),
        frequencyDays: 14,
        fromDate: DateTime(2025, 1, 10),
      );
      // Dec 25 + 14 = Jan 8 (before Jan 10, continue)
      // Jan 8 + 14 = Jan 22 (on or after Jan 10, stop)
      expect(result, DateTime(2025, 1, 22));
    });

    test('returns fromDate if it matches exactly', () {
      final result = InterestCalculator.calculateNextDate(
        startDate: DateTime(2024, 1, 1),
        frequencyDays: 7,
        fromDate: DateTime(2024, 1, 8),
      );
      expect(result, DateTime(2024, 1, 8));
    });
  });

  group('InterestCalculator.missedPeriods', () {
    test('returns 0 when not enough time has passed', () {
      final result = InterestCalculator.missedPeriods(
        startDate: DateTime(2024, 1, 1),
        frequencyDays: 7,
        lastAppliedDate: DateTime(2024, 1, 5),
        now: DateTime(2024, 1, 10),
      );
      expect(result, 0); // Only 5 days, need 7
    });

    test('returns 1 for exactly one period', () {
      final result = InterestCalculator.missedPeriods(
        startDate: DateTime(2024, 1, 1),
        frequencyDays: 7,
        lastAppliedDate: DateTime(2024, 1, 5),
        now: DateTime(2024, 1, 12),
      );
      expect(result, 1); // 7 days from Jan 5
    });

    test('returns multiple missed periods', () {
      final result = InterestCalculator.missedPeriods(
        startDate: DateTime(2024, 1, 1),
        frequencyDays: 2,
        lastAppliedDate: DateTime(2024, 1, 1),
        now: DateTime(2024, 1, 10),
      );
      expect(result, 4); // 9 days / 2 = 4 complete periods
    });

    test('uses startDate when lastAppliedDate is null', () {
      final result = InterestCalculator.missedPeriods(
        startDate: DateTime(2024, 1, 1),
        frequencyDays: 7,
        now: DateTime(2024, 1, 22),
      );
      expect(result, 3); // 21 days / 7 = 3 periods
    });

    test('returns 0 when fromDate is in the future', () {
      final result = InterestCalculator.missedPeriods(
        startDate: DateTime(2024, 1, 1),
        frequencyDays: 7,
        lastAppliedDate: DateTime(2024, 12, 31),
        now: DateTime(2024, 12, 30),
      );
      expect(result, 0);
    });

    test('daily frequency counts correctly', () {
      final result = InterestCalculator.missedPeriods(
        startDate: DateTime(2024, 1, 1),
        frequencyDays: 1,
        lastAppliedDate: DateTime(2024, 1, 5),
        now: DateTime(2024, 1, 10),
      );
      expect(result, 5); // 5 days / 1 = 5 periods
    });
  });
}
