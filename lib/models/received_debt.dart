import 'debt.dart';
import 'debt_share_payload.dart';

/// A debt received by scanning a lender's QR code, as stored on this device.
///
/// Deliberately a different type from [Debt]: a received record is a
/// read-only *copy* of someone else's ledger entry. It cannot accept
/// payments, cannot accrue interest and never triggers reminders, so it
/// lives in its own table and its own model rather than being jammed into
/// the `debts` schema.
///
/// OOP principles:
/// - Single Responsibility : model + derived display state only.
/// - Open/Closed             : built from a [DebtSharePayload] without the
///   repository or screens knowing the JSON wire format.
class ReceivedDebt {
  final int? id;

  /// Stable id from the lender's device; re-sharing the same debt upserts.
  final String recordUid;

  /// The lender's profile name (who lent the money).
  final String lenderName;

  /// The counterparty as the lender typed it (who owes). May be blank.
  final String? borrowerName;

  final double amount;
  final double remainingBalance;
  final DebtStatus status;
  final DateTime transactionDate;
  final String? notes;
  final double? interestRate;
  final InterestType? interestType;
  final InterestMode? interestMode;
  final int? interestFrequencyDays;
  final DateTime? interestStartDate;

  /// When the lender created the record (used for stable uid derivation).
  final DateTime createdAt;

  /// When *this* device imported it — newest first in the list.
  final DateTime receivedAt;

  const ReceivedDebt({
    this.id,
    required this.recordUid,
    required this.lenderName,
    required this.borrowerName,
    required this.amount,
    required this.remainingBalance,
    required this.transactionDate,
    required this.notes,
    required this.interestRate,
    required this.interestType,
    required this.interestMode,
    required this.interestFrequencyDays,
    required this.interestStartDate,
    required this.createdAt,
    required this.receivedAt,
    this.status = DebtStatus.unpaid,
  });

  // ── Creation ───────────────────────────────────────────────────────────────

  factory ReceivedDebt.fromPayload({
    required DebtSharePayload payload,
    int? id,
    DateTime? receivedAt,
  }) {
    return ReceivedDebt(
      id: id,
      recordUid: payload.uid,
      lenderName: payload.lenderName,
      borrowerName: payload.borrowerName,
      amount: payload.amount,
      remainingBalance: payload.remainingBalance,
      status: payload.status,
      transactionDate: payload.transactionDate,
      notes: payload.notes,
      interestRate: payload.interestRate,
      interestType: payload.interestType,
      interestMode: payload.interestMode,
      interestFrequencyDays: payload.interestFrequencyDays,
      interestStartDate: payload.interestStartDate,
      createdAt: payload.createdAt,
      receivedAt: receivedAt ?? DateTime.now(),
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'record_uid': recordUid,
        'lender_name': lenderName,
        'borrower_name': borrowerName,
        'amount': amount,
        'remaining_balance': remainingBalance,
        'transaction_date': transactionDate.toIso8601String(),
        'notes': notes,
        'status': status.name,
        'interest_rate': interestRate,
        'interest_type': interestType?.name,
        'interest_mode': interestMode?.name,
        'interest_frequency_days': interestFrequencyDays,
        'interest_start_date': interestStartDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'received_at': receivedAt.toIso8601String(),
      };

  factory ReceivedDebt.fromMap(Map<String, Object?> map) => ReceivedDebt(
        id: map['id'] as int?,
        recordUid: map['record_uid'] as String,
        lenderName: map['lender_name'] as String,
        borrowerName: map['borrower_name'] as String?,
        amount: (map['amount'] as num).toDouble(),
        remainingBalance: (map['remaining_balance'] as num).toDouble(),
        status: DebtStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => DebtStatus.unpaid,
        ),
        transactionDate: DateTime.parse(map['transaction_date'] as String),
        notes: map['notes'] as String?,
        interestRate: (map['interest_rate'] as num?)?.toDouble(),
        interestType: InterestType.values.cast<InterestType?>().firstWhere(
              (t) => t!.name == map['interest_type'],
              orElse: () => null,
            ),
        interestMode: InterestMode.values.cast<InterestMode?>().firstWhere(
              (m) => m!.name == map['interest_mode'],
              orElse: () => null,
            ),
        interestFrequencyDays: map['interest_frequency_days'] as int?,
        interestStartDate: map['interest_start_date'] == null
            ? null
            : DateTime.parse(map['interest_start_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        receivedAt: DateTime.parse(map['received_at'] as String),
      );

  // ── Derived display state ──────────────────────────────────────────────────

  /// Same record with the database id assigned by the repository.
  ReceivedDebt withId(int newId) => ReceivedDebt(
        id: newId,
        recordUid: recordUid,
        lenderName: lenderName,
        borrowerName: borrowerName,
        amount: amount,
        remainingBalance: remainingBalance,
        status: status,
        transactionDate: transactionDate,
        notes: notes,
        interestRate: interestRate,
        interestType: interestType,
        interestMode: interestMode,
        interestFrequencyDays: interestFrequencyDays,
        interestStartDate: interestStartDate,
        createdAt: createdAt,
        receivedAt: receivedAt,
      );

  bool get isPaid => status == DebtStatus.paid;

  bool get isPartial => status == DebtStatus.partial;

  double get amountPaid =>
      (amount - remainingBalance).clamp(0, double.infinity).toDouble();

  /// 0.0 – 1.0 share of the debt already settled.
  double get progress => amount <= 0 ? 0 : (amountPaid / amount).clamp(0, 1);

  String get lenderAvatarInitial =>
      lenderDisplay.isEmpty ? '?' : lenderDisplay.substring(0, 1).toUpperCase();

  String get lenderDisplay => lenderName.trim().isEmpty ? 'Lender' : lenderName;

  String get borrowerDisplay =>
      borrowerName == null || borrowerName!.trim().isEmpty
          ? '—'
          : borrowerName!.trim();

  bool get hasInterest =>
      interestRate != null && interestRate! > 0 && interestType != null;
}

/// Aggregates shown on the borrower dashboard.
///
/// OOP principle: Information Expert — the list of records owns the data
/// needed to summarise itself, so the dashboard stays layout-only.
class ReceivedSummary {
  final int totalCount;
  final int unpaidCount;
  final int paidCount;
  final int partialCount;
  final double totalAmount;
  final double totalOwed;
  final int lenderCount;

  const ReceivedSummary({
    required this.totalCount,
    required this.unpaidCount,
    required this.paidCount,
    required this.partialCount,
    required this.totalAmount,
    required this.totalOwed,
    required this.lenderCount,
  });

  factory ReceivedSummary.fromList(List<ReceivedDebt> records) {
    final lenders = <String>{};
    double totalAmount = 0;
    double totalOwed = 0;
    var unpaid = 0;
    var paid = 0;
    var partial = 0;

    for (final r in records) {
      lenders.add(r.lenderName.trim().toLowerCase());
      totalAmount += r.amount;
      totalOwed += r.remainingBalance;
      if (r.isPaid) {
        paid++;
      } else if (r.isPartial) {
        partial++;
      } else {
        unpaid++;
      }
    }

    return ReceivedSummary(
      totalCount: records.length,
      unpaidCount: unpaid,
      paidCount: paid,
      partialCount: partial,
      totalAmount: totalAmount,
      totalOwed: totalOwed,
      lenderCount: lenders.length,
    );
  }

  double get progress =>
      totalAmount <= 0 ? 0 : ((totalAmount - totalOwed) / totalAmount).clamp(0, 1);

  bool get isEmpty => totalCount == 0;
}
