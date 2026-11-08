import '../models/debt.dart';
import '../models/received_debt.dart';
import '../models/security_question.dart';

/// Abstract contract for all debt-related data operations.
///
/// OOP principles:
/// - Abstraction: callers depend on this interface, not on a concrete DB class.
/// - Dependency Inversion: high-level modules (controllers) depend on this
///   abstraction; low-level modules (SQLite impl) implement it.
abstract class IDebtRepository {
  Future<int> insertDebt(Debt debt);
  Future<List<Debt>> getAllDebts({DebtStatus? statusFilter, String? search});
  Future<Debt?> getDebtById(int id);
  Future<int> updateDebt(Debt debt);
  Future<int> deleteDebt(int id);

  Future<int> insertPayment(PaymentHistory payment);
  Future<List<PaymentHistory>> getPaymentsByDebtId(int debtId);

  Future<int> insertInterestTransaction(InterestTransaction transaction);
  Future<List<InterestTransaction>> getInterestTransactionsByDebtId(int debtId);
  Future<InterestTransaction?> getLastInterestTransaction(int debtId);
  Future<bool> hasInterestTransactionOnDate(int debtId, DateTime date);
  Future<List<DateTime>> getAppliedInterestDates(int debtId);

  /// Records a payment row and the resulting debt state in one transaction,
  /// so a crash can never leave the balance without its history row.
  Future<void> recordPaymentAtomic({
    required PaymentHistory payment,
    required Debt updatedDebt,
  });

  /// Persists interest rows and the resulting debt state in one transaction
  /// ([transactions] may be empty when only the schedule advances).
  Future<void> applyInterestAtomic({
    required Debt updatedDebt,
    required List<InterestTransaction> transactions,
  });

  Future<DebtSummary> getSummary();

  Future<List<Debt>> getDebtsWithAutomaticInterest();
}

/// Abstract contract for debts received by scanning a lender's QR code.
///
/// OOP principles:
/// - Interface Segregation : borrowing is a different responsibility from
///   owning a debt, so it gets its own small contract instead of growing
///   [IDebtRepository].
/// - Dependency Inversion : screens depend on this interface; the SQLite
///   implementation and the in-memory test mock are both free to change.
abstract class IReceivedDebtRepository {
  /// Inserts the record, or updates the existing one when [recordUid] was
  /// already imported (a lender re-sharing an edited debt).
  ///
  /// Returns the stored id and whether this was a brand-new record.
  Future<({int id, bool inserted})> upsert(ReceivedDebt record);

  /// All received records, newest first.
  Future<List<ReceivedDebt>> getAll();
}

/// Abstract contract for PIN / app-settings / security-question persistence.
///
/// OOP principle: Interface Segregation — PIN + recovery concerns are isolated
/// from debt concerns so neither interface grows beyond its responsibility.
abstract class ISettingsRepository {
  // ── PIN ────────────────────────────────────────────────────────────────────
  Future<bool> isPinSet();
  Future<void> setPin(String pin);
  Future<bool> verifyPin(String pin);

  // ── Security question ──────────────────────────────────────────────────────
  Future<bool> isSecurityQuestionSet();
  Future<void> saveSecurityAnswer(SecurityAnswer answer);
  Future<SecurityAnswer?> getSecurityAnswer();

  // ── Nuclear option ─────────────────────────────────────────────────────────
  /// Deletes every row in every table and resets the in-memory DB reference
  /// so the next [_db] access re-initialises cleanly.
  Future<void> wipeAllData();
}
