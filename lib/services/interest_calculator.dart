import '../models/debt.dart';

/// Pure interest calculation logic — no DB, no side effects.
///
/// This class is intentionally stateless and testable in isolation.
class InterestCalculator {
  const InterestCalculator._();

  /// Calculates a single interest period amount.
  ///
  /// [type] determines the principal:
  /// - Simple: always uses [originalAmount]
  /// - Compound: uses [currentBalance]
  ///
  /// Returns the interest amount for one period.
  static double calculate({
    required InterestType type,
    required double rate,
    required double originalAmount,
    required double currentBalance,
  }) {
    if (rate <= 0) return 0.0;

    final principal =
        type == InterestType.simple ? originalAmount : currentBalance;
    return principal * rate / 100;
  }

  /// Calculates the new balance after applying interest.
  static double newBalance({
    required InterestType type,
    required double rate,
    required double originalAmount,
    required double currentBalance,
  }) {
    final interest =
        calculate(type: type, rate: rate, originalAmount: originalAmount, currentBalance: currentBalance);
    return currentBalance + interest;
  }

  /// Calculates the next interest date given a start date, frequency, and
  /// the current [nextDate]. Advances by [frequencyDays] until the result
  /// is on or after [fromDate].
  ///
  /// This handles the case where the app was closed for multiple periods.
  static DateTime calculateNextDate({
    required DateTime startDate,
    required int frequencyDays,
    required DateTime fromDate,
    DateTime? currentNextDate,
  }) {
    final anchor = currentNextDate ?? startDate;

    // If anchor is already on or after fromDate, return it
    if (!anchor.isBefore(fromDate)) return anchor;

    // Advance anchor day-by-day until we pass fromDate
    // This handles month boundaries safely
    var candidate = anchor;
    while (candidate.isBefore(fromDate)) {
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day + frequencyDays,
      );
    }
    return candidate;
  }

  /// Returns how many complete interest periods have passed between
  /// [lastAppliedDate] (or [startDate] if null) and [now].
  ///
  /// Useful for catch-up: apply N periods of interest at once.
  static int missedPeriods({
    required DateTime startDate,
    required int frequencyDays,
    DateTime? lastAppliedDate,
    required DateTime now,
  }) {
    final fromDate = lastAppliedDate ?? startDate;
    if (!fromDate.isBefore(now)) return 0;

    final diff = now.difference(fromDate).inDays;
    if (diff < frequencyDays) return 0;
    return diff ~/ frequencyDays;
  }
}
