import '../models/debt.dart';
import '../repositories/i_debt_repositories.dart';
import 'interest_service.dart';
import 'logger.dart';
import 'notification_service.dart';

/// Encapsulates all business logic for debt management.
class DebtService {
  final IDebtRepository _repository;
  final InterestService _interestService;
  final NotificationService _notificationService;
  final Logger _logger;

  DebtService(this._repository, this._interestService,
      {NotificationService? notificationService, Logger? logger})
      : _notificationService =
            notificationService ?? NotificationService(),
        _logger = logger ?? const Logger('DebtService');

  /// Saves a new debt and schedules its reminder when enabled.
  ///
  /// Returns the persisted [Debt] (with its database id) so callers — e.g.
  /// the QR sharing screen — can act on the saved record. Throws the
  /// underlying repository error if persistence fails.
  Future<Debt> addDebt({
    required String lenderName,
    required double amount,
    required DateTime transactionDate,
    String? notes,
    double? interestRate,
    InterestType? interestType,
    InterestMode? interestMode,
    int? interestFrequencyDays,
    DateTime? interestStartDate,
    bool reminderEnabled = true,
    DateTime? reminderStartDate,
    int reminderIntervalDays = 1,
  }) async {
    try {
      // Calculate next interest date for automatic debts
      DateTime? nextInterestDate;
      if (interestMode == InterestMode.automatic &&
          interestStartDate != null &&
          interestFrequencyDays != null) {
        nextInterestDate = interestStartDate;
      }

      // Calculate next reminder date
      DateTime? nextReminderDate;
      if (reminderEnabled && reminderStartDate != null) {
        nextReminderDate = reminderStartDate;
      }

      final debt = Debt(
        lenderName: lenderName.trim(),
        amount: amount,
        transactionDate: transactionDate,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        status: DebtStatus.unpaid,
        remainingBalance: amount,
        createdAt: DateTime.now(),
        interestRate: interestRate,
        interestType: interestType,
        interestMode: interestMode,
        interestFrequencyDays: interestFrequencyDays,
        interestStartDate: interestStartDate,
        nextInterestDate: nextInterestDate,
        reminderEnabled: reminderEnabled,
        reminderStartDate: reminderStartDate,
        reminderIntervalDays: reminderIntervalDays,
        nextReminderDate: nextReminderDate,
      );
      final id = await _repository.insertDebt(debt);
      final savedDebt = debt.copyWith(id: id);

      // Schedule reminder if enabled
      if (reminderEnabled) {
        await _notificationService.scheduleDebtReminder(savedDebt);
      }

      return savedDebt;
    } catch (e, stack) {
      _logger.error('Failed to add debt', e, stack);
      rethrow;
    }
  }

  Future<void> updateDebt(
    Debt existing, {
    required String lenderName,
    required double amount,
    required DateTime transactionDate,
    String? notes,
    double? interestRate,
    InterestType? interestType,
    InterestMode? interestMode,
    int? interestFrequencyDays,
    DateTime? interestStartDate,
    DateTime? nextInterestDate,
    bool clearInterest = false,
    bool? reminderEnabled,
    DateTime? reminderStartDate,
    int? reminderIntervalDays,
    DateTime? nextReminderDate,
    bool clearReminder = false,
  }) async {
    try {
      Debt updated;

      if (clearInterest && clearReminder) {
        updated = existing.copyWith(
          lenderName: lenderName.trim(),
          amount: amount,
          transactionDate: transactionDate,
          notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
          clearInterest: true,
          clearReminder: true,
        );
        await _repository.updateDebt(updated);
        await _notificationService.cancelDebtReminder(existing.id!);
        return;
      }

      if (clearInterest) {
        updated = existing.copyWith(
          lenderName: lenderName.trim(),
          amount: amount,
          transactionDate: transactionDate,
          notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
          clearInterest: true,
          reminderEnabled: reminderEnabled ?? existing.reminderEnabled,
          reminderStartDate:
              reminderStartDate ?? existing.reminderStartDate,
          reminderIntervalDays:
              reminderIntervalDays ?? existing.reminderIntervalDays,
          nextReminderDate: nextReminderDate ?? existing.nextReminderDate,
        );
        await _repository.updateDebt(updated);
        await _handleReminderUpdate(updated, existing);
        return;
      }

      final hasInterest = interestRate != null && interestRate > 0;

      // Preserve the running automatic-interest schedule. Resetting the next
      // due date to [interestStartDate] on every edit re-applied all past
      // cycles on the next catch-up run, so the schedule only restarts when
      // the user actually changes start date or frequency.
      DateTime? finalNextDate = nextInterestDate;
      if (hasInterest &&
          interestMode == InterestMode.automatic &&
          interestStartDate != null &&
          interestFrequencyDays != null) {
        final scheduleChanged =
            interestStartDate != existing.interestStartDate ||
                interestFrequencyDays != existing.interestFrequencyDays;
        if (scheduleChanged) {
          finalNextDate = interestStartDate;
        } else if (nextInterestDate == null) {
          finalNextDate = existing.nextInterestDate ?? interestStartDate;
        }
      }

      // Handle reminder settings
      final bool finalReminderEnabled =
          reminderEnabled ?? existing.reminderEnabled;
      final DateTime? finalReminderStartDate =
          reminderStartDate ?? existing.reminderStartDate;
      final int finalReminderIntervalDays =
          reminderIntervalDays ?? existing.reminderIntervalDays;
      // A changed reminder schedule must not keep the old due date, or the
      // first notification still fires on the stale schedule.
      final bool reminderScheduleChanged =
          finalReminderStartDate != existing.reminderStartDate ||
              finalReminderIntervalDays != existing.reminderIntervalDays;
      final DateTime? finalNextReminderDate = reminderScheduleChanged
          ? finalReminderStartDate
          : (nextReminderDate ?? existing.nextReminderDate);

      // Reconcile the balance with an amount change: a correction cancels
      // part of what is still owed, never the progress already paid.
      final amountChanged = amount != existing.amount;
      double finalRemainingBalance = existing.remainingBalance;
      DebtStatus finalStatus = existing.status;
      if (amountChanged) {
        finalRemainingBalance = (finalRemainingBalance + (amount - existing.amount))
            .clamp(0.0, amount);
        if (finalRemainingBalance <= 0) {
          finalStatus = DebtStatus.paid;
        } else if (finalRemainingBalance < amount) {
          finalStatus = DebtStatus.partial;
        } else {
          finalStatus = DebtStatus.unpaid;
        }
      }

      updated = Debt(
        id: existing.id,
        lenderName: lenderName.trim(),
        amount: amount,
        transactionDate: transactionDate,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        status: finalStatus,
        remainingBalance: finalRemainingBalance,
        createdAt: existing.createdAt,
        interestRate: hasInterest ? interestRate : null,
        interestType: hasInterest ? interestType : null,
        interestMode: hasInterest ? interestMode : null,
        interestFrequencyDays:
            hasInterest && interestMode == InterestMode.automatic
                ? interestFrequencyDays
                : null,
        interestStartDate:
            hasInterest && interestMode == InterestMode.automatic
                ? interestStartDate
                : null,
        nextInterestDate: hasInterest ? finalNextDate : null,
        reminderEnabled: finalReminderEnabled,
        reminderStartDate: finalReminderStartDate,
        reminderIntervalDays: finalReminderIntervalDays,
        nextReminderDate: finalNextReminderDate,
      );
      await _repository.updateDebt(updated);
      await _handleReminderUpdate(updated, existing);
    } catch (e, stack) {
      _logger.error('Failed to update debt', e, stack);
      rethrow;
    }
  }

  /// Handles reminder rescheduling/cancellation after a debt update.
  Future<void> _handleReminderUpdate(Debt updated, Debt existing) async {
    if (updated.id == null) return;

    // If reminder was disabled or debt is paid, cancel
    if (!updated.reminderEnabled || updated.isPaid) {
      await _notificationService.cancelDebtReminder(updated.id!);
      return;
    }

    // If reminder settings changed, reschedule
    final settingsChanged =
        updated.reminderStartDate != existing.reminderStartDate ||
            updated.reminderIntervalDays != existing.reminderIntervalDays ||
            updated.reminderEnabled != existing.reminderEnabled;

    if (settingsChanged) {
      await _notificationService.rescheduleDebtReminder(updated);
    }
  }

  Future<void> deleteDebt(int id) async {
    try {
      await _notificationService.cancelDebtReminder(id);
      await _repository.deleteDebt(id);
    } catch (e, stack) {
      _logger.error('Failed to delete debt', e, stack);
      rethrow;
    }
  }

  Future<List<Debt>> getDebts({
    DebtStatus? statusFilter,
    String? search,
  }) async {
    try {
      return await _repository.getAllDebts(
          statusFilter: statusFilter, search: search);
    } catch (e, stack) {
      _logger.error('Failed to get debts', e, stack);
      rethrow;
    }
  }

  Future<Debt?> getDebtById(int id) async {
    try {
      return await _repository.getDebtById(id);
    } catch (e, stack) {
      _logger.error('Failed to get debt by id', e, stack);
      rethrow;
    }
  }

  Future<void> recordPayment({
    required Debt debt,
    required double amount,
    String? note,
  }) async {
    try {
      if (debt.id == null) {
        throw ArgumentError('Cannot record a payment on an unsaved debt.');
      }
      if (amount <= 0) {
        throw ArgumentError('Payment amount must be positive.');
      }
      if (amount > debt.remainingBalance + 0.001) {
        throw ArgumentError('Payment exceeds the remaining balance.');
      }

      final payment = PaymentHistory(
        debtId: debt.id!,
        paymentAmount: amount,
        paymentDate: DateTime.now(),
        paymentNote: note?.trim().isEmpty == true ? null : note?.trim(),
      );

      final newRemaining =
          (debt.remainingBalance - amount).clamp(0.0, double.infinity);
      final newStatus =
          newRemaining <= 0 ? DebtStatus.paid : DebtStatus.partial;

      final updatedDebt = debt.copyWith(
        status: newStatus,
        remainingBalance: newRemaining,
      );
      // Persist the payment row and the resulting balance atomically so a
      // crash can never leave one without the other.
      await _repository.recordPaymentAtomic(
        payment: payment,
        updatedDebt: updatedDebt,
      );

      // Cancel reminder if debt is fully paid
      if (newStatus == DebtStatus.paid) {
        await _notificationService.cancelDebtReminder(debt.id!);
      }
    } catch (e, stack) {
      _logger.error('Failed to record payment', e, stack);
      rethrow;
    }
  }

  /// Toggles reminder on/off for a specific debt.
  Future<void> toggleReminder(int debtId, bool enabled) async {
    try {
      final debt = await _repository.getDebtById(debtId);
      if (debt == null) return;

      final updated = debt.copyWith(
        reminderEnabled: enabled,
        reminderStartDate: enabled ? debt.reminderStartDate ?? DateTime.now().add(const Duration(days: 1)) : debt.reminderStartDate,
        nextReminderDate: enabled ? debt.reminderStartDate ?? DateTime.now().add(const Duration(days: 1)) : null,
      );
      await _repository.updateDebt(updated);

      if (enabled) {
        await _notificationService.scheduleDebtReminder(updated);
      } else {
        await _notificationService.cancelDebtReminder(debtId);
      }
    } catch (e, stack) {
      _logger.error('Failed to toggle reminder', e, stack);
      rethrow;
    }
  }

  /// Reschedules the next reminder after a notification fires.
  Future<void> rescheduleNextReminder(int debtId) async {
    try {
      final debt = await _repository.getDebtById(debtId);
      if (debt == null || !debt.reminderEnabled || debt.isPaid) return;

      // Always compute from now so the next notification is for the
      // correct future day, regardless of stale DB values.
      final nextDate = DateTime.now().add(
        Duration(days: debt.reminderIntervalDays),
      );
      final updated = debt.copyWith(nextReminderDate: nextDate);
      await _repository.updateDebt(updated);

      await _notificationService.scheduleNextAfterFired(updated);
    } catch (e, stack) {
      _logger.error('Failed to reschedule next reminder', e, stack);
    }
  }

  /// Persists the next reminder date for a debt (called by NotificationService).
  Future<void> persistNextReminderDate(int debtId, DateTime nextDate) async {
    try {
      final debt = await _repository.getDebtById(debtId);
      if (debt == null) return;
      final updated = debt.copyWith(nextReminderDate: nextDate);
      await _repository.updateDebt(updated);
    } catch (e, stack) {
      _logger.error('Failed to persist next reminder date', e, stack);
    }
  }

  /// Gets all debts with active reminders for rescheduling on app restart.
  Future<List<Debt>> getDebtsWithActiveReminders() async {
    try {
      final allDebts = await _repository.getAllDebts();
      return allDebts
          .where((d) => d.reminderEnabled && !d.isPaid)
          .toList();
    } catch (e, stack) {
      _logger.error('Failed to get debts with active reminders', e, stack);
      return [];
    }
  }

  /// Delegates to InterestService for manual interest application.
  Future<double> applyInterest(Debt debt) async {
    return _interestService.applyInterest(debt);
  }

  /// Gets interest history from the interest_history table.
  Future<List<InterestTransaction>> getInterestHistory(int debtId) async {
    return _interestService.getInterestHistory(debtId);
  }

  /// Processes missed interest for all automatic debts.
  Future<double> processAllMissedInterest() async {
    return _interestService.processAllMissedInterest();
  }

  Future<List<PaymentHistory>> getPaymentHistory(int debtId) async {
    try {
      return await _repository.getPaymentsByDebtId(debtId);
    } catch (e, stack) {
      _logger.error('Failed to get payment history', e, stack);
      rethrow;
    }
  }

  Future<DebtSummary> getSummary() async {
    try {
      return await _repository.getSummary();
    } catch (e, stack) {
      _logger.error('Failed to get summary', e, stack);
      rethrow;
    }
  }
}
