import 'package:flutter/material.dart';

import '../models/debt.dart';
import '../services/debt_service.dart';
import '../services/logger.dart';

/// Manages form state and save logic for Add / Edit Debt screen.
class AddDebtController extends ChangeNotifier {
  final DebtService _debtService;
  final Logger _logger;
  final Debt? existingDebt;

  AddDebtController(this._debtService, {this.existingDebt, Logger? logger})
      : _logger = logger ?? const Logger('AddDebtController');

  bool _isSaving = false;
  bool get isSaving => _isSaving;
  bool get isEditing => existingDebt != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> save({
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
    bool reminderEnabled = true,
    DateTime? reminderStartDate,
    int reminderIntervalDays = 1,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (isEditing) {
        await _debtService.updateDebt(
          existingDebt!,
          lenderName: lenderName,
          amount: amount,
          transactionDate: transactionDate,
          notes: notes,
          interestRate: interestRate,
          interestType: interestType,
          interestMode: interestMode,
          interestFrequencyDays: interestFrequencyDays,
          interestStartDate: interestStartDate,
          nextInterestDate: nextInterestDate,
          clearInterest: clearInterest,
          reminderEnabled: reminderEnabled,
          reminderStartDate: reminderStartDate,
          reminderIntervalDays: reminderIntervalDays,
        );
      } else {
        await _debtService.addDebt(
          lenderName: lenderName,
          amount: amount,
          transactionDate: transactionDate,
          notes: notes,
          interestRate: interestRate,
          interestType: interestType,
          interestMode: interestMode,
          interestFrequencyDays: interestFrequencyDays,
          interestStartDate: interestStartDate,
          reminderEnabled: reminderEnabled,
          reminderStartDate: reminderStartDate,
          reminderIntervalDays: reminderIntervalDays,
        );
      }
    } catch (e, stack) {
      _logger.error('Failed to save debt', e, stack);
      _errorMessage = 'Failed to save debt. Please try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
