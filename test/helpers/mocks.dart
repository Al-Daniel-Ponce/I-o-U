import 'package:iou_debt_tracker/models/debt.dart';
import 'package:iou_debt_tracker/models/received_debt.dart';
import 'package:iou_debt_tracker/models/security_question.dart';
import 'package:iou_debt_tracker/repositories/i_debt_repositories.dart';

/// In-memory mock implementation of [IDebtRepository] for unit tests.
class MockDebtRepository implements IDebtRepository {
  final List<Debt> _debts = [];
  final List<PaymentHistory> _payments = [];
  final List<InterestTransaction> _interestTransactions = [];
  int _nextDebtId = 1;
  int _nextPaymentId = 1;
  int _nextInterestId = 1;

  void reset() {
    _debts.clear();
    _payments.clear();
    _interestTransactions.clear();
    _nextDebtId = 1;
    _nextPaymentId = 1;
    _nextInterestId = 1;
  }

  @override
  Future<int> insertDebt(Debt debt) async {
    final id = _nextDebtId++;
    _debts.add(Debt(
      id: id,
      lenderName: debt.lenderName,
      amount: debt.amount,
      transactionDate: debt.transactionDate,
      notes: debt.notes,
      status: debt.status,
      remainingBalance: debt.remainingBalance,
      createdAt: debt.createdAt,
      interestRate: debt.interestRate,
      interestType: debt.interestType,
      interestMode: debt.interestMode,
      interestFrequencyDays: debt.interestFrequencyDays,
      interestStartDate: debt.interestStartDate,
      nextInterestDate: debt.nextInterestDate,
      reminderEnabled: debt.reminderEnabled,
      reminderStartDate: debt.reminderStartDate,
      reminderIntervalDays: debt.reminderIntervalDays,
      nextReminderDate: debt.nextReminderDate,
    ));
    return id;
  }

  @override
  Future<List<Debt>> getAllDebts({
    DebtStatus? statusFilter,
    String? search,
  }) async {
    var results = List<Debt>.from(_debts);

    // Auto-correct statuses (mimic the real repo behavior)
    for (var i = 0; i < results.length; i++) {
      final d = results[i];
      if (d.remainingBalance <= 0 && d.status != DebtStatus.paid) {
        results[i] = d.copyWith(status: DebtStatus.paid);
        _debts[i] = results[i];
      } else if (d.remainingBalance > 0 &&
          d.remainingBalance < d.amount &&
          d.status == DebtStatus.unpaid) {
        results[i] = d.copyWith(status: DebtStatus.partial);
        _debts[i] = results[i];
      }
    }

    if (statusFilter != null) {
      results = results.where((d) => d.status == statusFilter).toList();
    }
    if (search != null && search.isNotEmpty) {
      results = results
          .where(
              (d) => d.lenderName.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<Debt?> getDebtById(int id) async {
    try {
      return _debts.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> updateDebt(Debt debt) async {
    final idx = _debts.indexWhere((d) => d.id == debt.id);
    if (idx == -1) return 0;
    _debts[idx] = debt;
    return 1;
  }

  @override
  Future<int> deleteDebt(int id) async {
    _debts.removeWhere((d) => d.id == id);
    _payments.removeWhere((p) => p.debtId == id);
    _interestTransactions.removeWhere((t) => t.debtId == id);
    return 1;
  }

  @override
  Future<int> insertPayment(PaymentHistory payment) async {
    final id = _nextPaymentId++;
    _payments.add(PaymentHistory(
      id: id,
      debtId: payment.debtId,
      paymentAmount: payment.paymentAmount,
      paymentDate: payment.paymentDate,
      paymentNote: payment.paymentNote,
    ));
    return id;
  }

  @override
  Future<List<PaymentHistory>> getPaymentsByDebtId(int debtId) async {
    final results = _payments.where((p) => p.debtId == debtId).toList();
    results.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return results;
  }

  @override
  Future<int> insertInterestTransaction(InterestTransaction transaction) async {
    final id = _nextInterestId++;
    _interestTransactions.add(InterestTransaction(
      id: id,
      debtId: transaction.debtId,
      appliedAt: transaction.appliedAt,
      interestRate: transaction.interestRate,
      interestAmount: transaction.interestAmount,
      balanceBefore: transaction.balanceBefore,
      balanceAfter: transaction.balanceAfter,
      type: transaction.type,
    ));
    return id;
  }

  @override
  Future<List<InterestTransaction>> getInterestTransactionsByDebtId(
      int debtId) async {
    final results =
        _interestTransactions.where((t) => t.debtId == debtId).toList();
    results.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    return results;
  }

  @override
  Future<InterestTransaction?> getLastInterestTransaction(int debtId) async {
    final results =
        _interestTransactions.where((t) => t.debtId == debtId).toList();
    if (results.isEmpty) return null;
    results.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    return results.first;
  }

  @override
  Future<bool> hasInterestTransactionOnDate(
      int debtId, DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final nextDay = DateTime(date.year, date.month, date.day + 1);
    return _interestTransactions.any((t) =>
        t.debtId == debtId &&
        !t.appliedAt.isBefore(dateOnly) &&
        t.appliedAt.isBefore(nextDay));
  }

  @override
  Future<List<DateTime>> getAppliedInterestDates(int debtId) async {
    return _interestTransactions
        .where((t) => t.debtId == debtId)
        .map((t) =>
            DateTime(t.appliedAt.year, t.appliedAt.month, t.appliedAt.day))
        .toList();
  }

  @override
  Future<void> recordPaymentAtomic({
    required PaymentHistory payment,
    required Debt updatedDebt,
  }) async {
    final paymentId = _nextPaymentId++;
    _payments.add(PaymentHistory(
      id: paymentId,
      debtId: payment.debtId,
      paymentAmount: payment.paymentAmount,
      paymentDate: payment.paymentDate,
      paymentNote: payment.paymentNote,
    ));
    final idx = _debts.indexWhere((d) => d.id == updatedDebt.id);
    if (idx != -1) _debts[idx] = updatedDebt;
  }

  @override
  Future<void> applyInterestAtomic({
    required Debt updatedDebt,
    required List<InterestTransaction> transactions,
  }) async {
    for (final transaction in transactions) {
      final interestId = _nextInterestId++;
      _interestTransactions.add(InterestTransaction(
        id: interestId,
        debtId: transaction.debtId,
        appliedAt: transaction.appliedAt,
        interestRate: transaction.interestRate,
        interestAmount: transaction.interestAmount,
        balanceBefore: transaction.balanceBefore,
        balanceAfter: transaction.balanceAfter,
        type: transaction.type,
      ));
    }
    final idx = _debts.indexWhere((d) => d.id == updatedDebt.id);
    if (idx != -1) _debts[idx] = updatedDebt;
  }

  @override
  Future<DebtSummary> getSummary() async {
    double totalBorrowed = 0;
    double totalRemaining = 0;
    int unpaidCount = 0;
    int partialCount = 0;
    int paidCount = 0;

    for (final d in _debts) {
      totalBorrowed += d.amount;
      totalRemaining += d.remainingBalance;
      switch (d.status) {
        case DebtStatus.unpaid:
          unpaidCount++;
          break;
        case DebtStatus.partial:
          partialCount++;
          break;
        case DebtStatus.paid:
          paidCount++;
          break;
      }
    }

    return DebtSummary(
      totalBorrowed: totalBorrowed,
      totalRemaining: totalRemaining,
      unpaidCount: unpaidCount,
      partialCount: partialCount,
      paidCount: paidCount,
    );
  }

  @override
  Future<List<Debt>> getDebtsWithAutomaticInterest() async {
    return _debts
        .where((d) =>
            d.hasInterest &&
            d.interestMode == InterestMode.automatic &&
            !d.isPaid)
        .toList();
  }
}

/// In-memory mock implementation of [ISettingsRepository] for unit tests.
class MockSettingsRepository implements ISettingsRepository {
  String? _pin;
  bool _securityQuestionSet = false;
  String? _securityQId;
  String? _securityAnswer;

  void reset() {
    _pin = null;
    _securityQuestionSet = false;
    _securityQId = null;
    _securityAnswer = null;
  }

  @override
  Future<bool> isPinSet() async => _pin != null;

  @override
  Future<void> setPin(String pin) async => _pin = pin;

  @override
  Future<bool> verifyPin(String pin) async => _pin == pin;

  @override
  Future<bool> isSecurityQuestionSet() async => _securityQuestionSet;

  @override
  Future<void> saveSecurityAnswer(SecurityAnswer answer) async {
    _securityQuestionSet = true;
    _securityQId = answer.questionId;
    _securityAnswer = answer.answer;
  }

  @override
  Future<SecurityAnswer?> getSecurityAnswer() async {
    if (!_securityQuestionSet) return null;
    return SecurityAnswer(
        questionId: _securityQId!, answer: _securityAnswer!);
  }

  @override
  Future<void> wipeAllData() async {
    reset();
  }
}

/// In-memory mock implementation of [IReceivedDebtRepository] for unit tests.
class MockReceivedDebtRepository implements IReceivedDebtRepository {
  final List<ReceivedDebt> _records = [];
  int _nextId = 1;

  void reset() {
    _records.clear();
    _nextId = 1;
  }

  @override
  Future<({int id, bool inserted})> upsert(ReceivedDebt record) async {
    final idx = _records.indexWhere((r) => r.recordUid == record.recordUid);
    if (idx != -1) {
      final id = _records[idx].id!;
      _records[idx] = record.withId(id);
      return (id: id, inserted: false);
    }
    final id = _nextId++;
    _records.add(record.withId(id));
    return (id: id, inserted: true);
  }

  @override
  Future<List<ReceivedDebt>> getAll() async {
    final results = List<ReceivedDebt>.from(_records);
    results.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return results;
  }
}
