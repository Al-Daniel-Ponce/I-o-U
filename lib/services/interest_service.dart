import '../models/debt.dart';
import '../repositories/i_debt_repositories.dart';
import 'interest_calculator.dart';
import 'logger.dart';

/// Orchestrates interest operations: apply, catch-up, auto-check.
///
/// Uses [InterestCalculator] for pure math and the repository for persistence.
class InterestService {
  final IDebtRepository _repository;
  final Logger _logger;

  InterestService(this._repository, {Logger? logger})
      : _logger = logger ?? const Logger('InterestService');

  /// Manually applies one period of interest to a debt.
  ///
  /// Returns the interest amount applied, or 0.0 if nothing was applied.
  Future<double> applyInterest(Debt debt) async {
    if (!debt.hasInterest || debt.isPaid) return 0.0;

    final type = debt.interestType ?? InterestType.simple;
    final rate = debt.interestRate!;

    final interestAmount = InterestCalculator.calculate(
      type: type,
      rate: rate,
      originalAmount: debt.amount,
      currentBalance: debt.remainingBalance,
    );

    if (interestAmount <= 0) return 0.0;

    final balanceBefore = debt.remainingBalance;
    final balanceAfter = balanceBefore + interestAmount;

    // Record the interest transaction
    final transaction = InterestTransaction(
      debtId: debt.id!,
      appliedAt: DateTime.now(),
      interestRate: rate,
      interestAmount: interestAmount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      type: 'manual',
    );

    // Calculate next interest date for automatic debts
    DateTime? nextDate;
    if (debt.isAutomaticInterest &&
        debt.interestStartDate != null &&
        debt.interestFrequencyDays != null) {
      nextDate = InterestCalculator.calculateNextDate(
        startDate: debt.interestStartDate!,
        frequencyDays: debt.interestFrequencyDays!,
        fromDate: DateTime.now(),
        currentNextDate: debt.nextInterestDate,
      );
    }

    // Update the debt balance
    final updated = debt.copyWith(
      remainingBalance: balanceAfter,
      nextInterestDate: nextDate,
    );
    await _repository.applyInterestAtomic(
      updatedDebt: updated,
      transactions: [transaction],
    );

    _logger.info(
        'Applied ${type.name} interest: $interestAmount on debt ${debt.id}');
    return interestAmount;
  }

  /// Processes missed interest periods for a single debt.
  ///
  /// Called on app launch/resume and debt detail open.
  /// Calculates how many periods were missed and applies them all.
  /// Returns the total interest applied across all catch-up periods.
  Future<double> processMissedInterest(Debt debt) async {
    if (!debt.isAutomaticInterest || debt.isPaid) return 0.0;
    if (debt.interestStartDate == null || debt.interestFrequencyDays == null) {
      return 0.0;
    }

    final now = DateTime.now();
    final nextDate = debt.nextInterestDate;

    // If no next date set or it's in the future, nothing to do
    if (nextDate == null || !nextDate.isBefore(now)) return 0.0;

    final missed = InterestCalculator.missedPeriods(
      startDate: debt.interestStartDate!,
      frequencyDays: debt.interestFrequencyDays!,
      lastAppliedDate: nextDate,
      now: now,
    );

    if (missed <= 0) return 0.0;

    _logger.info(
        'Processing $missed missed interest periods for debt ${debt.id}');

    var totalInterest = 0.0;
    var currentBalance = debt.remainingBalance;
    var currentDate = nextDate;
    final type = debt.interestType ?? InterestType.simple;
    final rate = debt.interestRate!;

    // Dates that already carry a history row: when one exists for a due
    // date the interest was already counted once, so the accrual itself
    // must be skipped - not just the row insert.
    final appliedDates =
        (await _repository.getAppliedInterestDates(debt.id!)).toSet();

    final transactions = <InterestTransaction>[];

    for (var i = 0; i < missed; i++) {
      if (currentBalance <= 0) break;

      final dueDate =
          DateTime(currentDate.year, currentDate.month, currentDate.day);
      final alreadyRecorded = appliedDates.contains(dueDate);
      if (!alreadyRecorded) {
        final interestAmount = InterestCalculator.calculate(
          type: type,
          rate: rate,
          originalAmount: debt.amount,
          currentBalance: currentBalance,
        );

        if (interestAmount <= 0) break;

        final balanceBefore = currentBalance;
        currentBalance += interestAmount;
        totalInterest += interestAmount;

        transactions.add(InterestTransaction(
          debtId: debt.id!,
          appliedAt: currentDate,
          interestRate: rate,
          interestAmount: interestAmount,
          balanceBefore: balanceBefore,
          balanceAfter: currentBalance,
          type: 'automatic',
        ));
      }

      // Advance to next period
      currentDate = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day + debt.interestFrequencyDays!,
      );
    }

    // Always persist the schedule advance even when every examined date was
    // already recorded, otherwise the same catch-up window re-processes
    // forever. Freshly calculated amounts and rows go out in one atomic
    // batch with the balance so a crash cannot half-apply.
    final finalNextDate = InterestCalculator.calculateNextDate(
      startDate: debt.interestStartDate!,
      frequencyDays: debt.interestFrequencyDays!,
      fromDate: now,
      currentNextDate: currentDate,
    );

    final updated = debt.copyWith(
      remainingBalance: currentBalance,
      nextInterestDate: finalNextDate,
    );
    await _repository.applyInterestAtomic(
      updatedDebt: updated,
      transactions: transactions,
    );

    return totalInterest;
  }

  /// Processes missed interest for ALL debts with automatic interest.
  ///
  /// Called on app launch/resume. Returns the total interest applied
  /// across all debts.
  Future<double> processAllMissedInterest() async {
    final debts = await _repository.getDebtsWithAutomaticInterest();
    var totalApplied = 0.0;

    for (final debt in debts) {
      final applied = await processMissedInterest(debt);
      totalApplied += applied;
    }

    if (totalApplied > 0) {
      _logger.info(
          'Total automatic interest applied across all debts: $totalApplied');
    }

    return totalApplied;
  }

  /// Calculates what the next interest amount would be (preview).
  ///
  /// Does NOT apply anything — purely informational for the UI.
  double previewNextInterest({
    required InterestType type,
    required double rate,
    required double originalAmount,
    required double currentBalance,
  }) {
    return InterestCalculator.calculate(
      type: type,
      rate: rate,
      originalAmount: originalAmount,
      currentBalance: currentBalance,
    );
  }

  /// Gets all interest transactions for a debt.
  Future<List<InterestTransaction>> getInterestHistory(int debtId) async {
    return await _repository.getInterestTransactionsByDebtId(debtId);
  }
}
