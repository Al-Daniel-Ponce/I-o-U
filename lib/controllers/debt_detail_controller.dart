import 'package:flutter/material.dart';

import '../models/debt.dart';
import '../services/debt_service.dart';
import '../services/logger.dart';

/// Manages state and logic for the Debt Detail screen.
class DebtDetailController extends ChangeNotifier {
  final DebtService _debtService;
  final Logger _logger;

  DebtDetailController(this._debtService, {Logger? logger})
      : _logger = logger ?? const Logger('DebtDetailController');

  Debt? _debt;
  List<PaymentHistory> _payments = [];
  List<InterestTransaction> _interestHistory = [];
  bool _isLoading = false;
  bool _isApplyingInterest = false;
  String? _errorMessage;

  Debt? get debt => _debt;
  List<PaymentHistory> get payments => List.unmodifiable(_payments);
  List<InterestTransaction> get interestHistory =>
      List.unmodifiable(_interestHistory);
  bool get isLoading => _isLoading;
  bool get isApplyingInterest => _isApplyingInterest;
  String? get errorMessage => _errorMessage;

  Future<void> loadData(int debtId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final debtFuture = _debtService.getDebtById(debtId);
      final paymentsFuture = _debtService.getPaymentHistory(debtId);
      final interestFuture = _debtService.getInterestHistory(debtId);

      _debt = await debtFuture;
      _payments = await paymentsFuture;
      _interestHistory = await interestFuture;
    } catch (e, stack) {
      _logger.error('Failed to load debt details', e, stack);
      _errorMessage = 'Failed to load debt details.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Processes any missed automatic interest, then reloads data.
  Future<void> processMissedInterest(int debtId) async {
    try {
      final debt = await _debtService.getDebtById(debtId);
      if (debt != null && debt.isAutomaticInterest && !debt.isPaid) {
        final applied = await _debtService.processAllMissedInterest();
        if (applied > 0) {
          _logger.info('Applied $applied in catch-up interest');
        }
        // Reload data after catch-up
        await loadData(debtId);
      }
    } catch (e, stack) {
      _logger.error('Failed to process missed interest', e, stack);
    }
  }

  Future<void> recordPayment({
    required double amount,
    String? note,
  }) async {
    if (_debt == null) return;
    try {
      await _debtService.recordPayment(
          debt: _debt!, amount: amount, note: note);
      await loadData(_debt!.id!);
    } catch (e, stack) {
      _logger.error('Failed to record payment', e, stack);
      _errorMessage = 'Failed to record payment.';
      notifyListeners();
    }
  }

  Future<double> applyInterest() async {
    if (_debt == null || _isApplyingInterest) return 0.0;
    _isApplyingInterest = true;
    notifyListeners();

    try {
      final amount = await _debtService.applyInterest(_debt!);
      await loadData(_debt!.id!);
      return amount;
    } catch (e, stack) {
      _logger.error('Failed to apply interest', e, stack);
      _errorMessage = 'Failed to apply interest.';
      notifyListeners();
      return 0.0;
    } finally {
      _isApplyingInterest = false;
      notifyListeners();
    }
  }

  /// Toggles reminder on/off for the current debt.
  Future<void> toggleReminder(bool enabled) async {
    if (_debt == null || _debt!.id == null) return;
    try {
      await _debtService.toggleReminder(_debt!.id!, enabled);
      await loadData(_debt!.id!);
    } catch (e, stack) {
      _logger.error('Failed to toggle reminder', e, stack);
      _errorMessage = 'Failed to update reminder.';
      notifyListeners();
    }
  }
}
