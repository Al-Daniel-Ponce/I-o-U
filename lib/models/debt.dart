
import 'reminder_frequency.dart';

enum DebtStatus {
  unpaid,
  partial,
  paid;

  static DebtStatus fromString(String value) {
    return DebtStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DebtStatus.unpaid,
    );
  }

  String get label {
    switch (this) {
      case DebtStatus.unpaid:
        return 'Unpaid';
      case DebtStatus.partial:
        return 'Partial';
      case DebtStatus.paid:
        return 'Paid';
    }
  }
}

enum InterestType {
  simple,
  compound;

  static InterestType fromString(String value) {
    return InterestType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => InterestType.simple,
    );
  }

  String get label {
    switch (this) {
      case InterestType.simple:
        return 'Simple Interest';
      case InterestType.compound:
        return 'Compound Interest';
    }
  }
}

enum InterestMode {
  manual,
  automatic;

  static InterestMode fromString(String value) {
    return InterestMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => InterestMode.manual,
    );
  }

  String get label {
    switch (this) {
      case InterestMode.manual:
        return 'Manual';
      case InterestMode.automatic:
        return 'Automatic';
    }
  }
}

/// Immutable value object representing a single debt record.
class Debt {
  final int? id;
  final String lenderName;
  final double amount;
  final DateTime transactionDate;
  final String? notes;
  final DebtStatus status;
  final double remainingBalance;
  final DateTime createdAt;
  final double? interestRate;
  final InterestType? interestType;
  final InterestMode? interestMode;
  final int? interestFrequencyDays;
  final DateTime? interestStartDate;
  final DateTime? nextInterestDate;

  final bool reminderEnabled;
  final DateTime? reminderStartDate;
  final int reminderIntervalDays;
  final DateTime? nextReminderDate;

  const Debt({
    this.id,
    required this.lenderName,
    required this.amount,
    required this.transactionDate,
    this.notes,
    this.status = DebtStatus.unpaid,
    required this.remainingBalance,
    required this.createdAt,
    this.interestRate,
    this.interestType,
    this.interestMode,
    this.interestFrequencyDays,
    this.interestStartDate,
    this.nextInterestDate,
    this.reminderEnabled = true,
    this.reminderStartDate,
    this.reminderIntervalDays = 1,
    this.nextReminderDate,
  });

  // ── Computed properties ──────────────────────────────────────────────────

  double get amountPaid => amount - remainingBalance;

  double get progress =>
      amount > 0 ? (amountPaid / amount).clamp(0.0, 1.0) : 0.0;

  bool get isPaid => status == DebtStatus.paid;

  bool get hasInterest => interestRate != null && interestRate! > 0;

  bool get isAutomaticInterest =>
      hasInterest && interestMode == InterestMode.automatic;

  bool get hasActiveReminder => reminderEnabled && !isPaid;

  String get reminderFrequencyLabel =>
      ReminderFrequency.labelForDays(reminderIntervalDays);

  String get avatarInitial => lenderName.isNotEmpty
      ? lenderName.substring(0, 1).toUpperCase()
      : '?';

  String get frequencyLabel {
    if (interestFrequencyDays == null) return '';
    final days = interestFrequencyDays!;
    if (days == 1) return 'Every day';
    if (days == 7) return 'Every week';
    if (days == 14) return 'Every 2 weeks';
    if (days == 30) return 'Every month';
    return 'Every $days days';
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'lender_name': lenderName,
        'amount': amount,
        'transaction_date': transactionDate.toIso8601String(),
        'notes': notes,
        'status': status.name,
        'remaining_balance': remainingBalance,
        'created_at': createdAt.toIso8601String(),
        'interest_rate': interestRate,
        'interest_type': interestType?.name,
        'interest_mode': interestMode?.name,
        'interest_frequency_days': interestFrequencyDays,
        'interest_start_date': interestStartDate?.toIso8601String(),
        'next_interest_date': nextInterestDate?.toIso8601String(),
        'reminder_enabled': reminderEnabled ? 1 : 0,
        'reminder_start_date': reminderStartDate?.toIso8601String(),
        'reminder_interval_days': reminderIntervalDays,
        'next_reminder_date': nextReminderDate?.toIso8601String(),
      };

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'] as int?,
      lenderName: map['lender_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      notes: map['notes'] as String?,
      status: DebtStatus.fromString(map['status'] as String),
      remainingBalance: (map['remaining_balance'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      interestRate: (map['interest_rate'] as num?)?.toDouble(),
      interestType: map['interest_type'] != null
          ? InterestType.fromString(map['interest_type'] as String)
          : null,
      interestMode: map['interest_mode'] != null
          ? InterestMode.fromString(map['interest_mode'] as String)
          : null,
      interestFrequencyDays: map['interest_frequency_days'] as int?,
      interestStartDate: map['interest_start_date'] != null
          ? DateTime.parse(map['interest_start_date'] as String)
          : null,
      nextInterestDate: map['next_interest_date'] != null
          ? DateTime.parse(map['next_interest_date'] as String)
          : null,
      reminderEnabled: (map['reminder_enabled'] as int? ?? 1) == 1,
      reminderStartDate: map['reminder_start_date'] != null
          ? DateTime.parse(map['reminder_start_date'] as String)
          : null,
      reminderIntervalDays: map['reminder_interval_days'] as int? ?? 1,
      nextReminderDate: map['next_reminder_date'] != null
          ? DateTime.parse(map['next_reminder_date'] as String)
          : null,
    );
  }

  Debt copyWith({
    int? id,
    String? lenderName,
    double? amount,
    DateTime? transactionDate,
    String? notes,
    DebtStatus? status,
    double? remainingBalance,
    DateTime? createdAt,
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
  }) =>
      Debt(
        id: id ?? this.id,
        lenderName: lenderName ?? this.lenderName,
        amount: amount ?? this.amount,
        transactionDate: transactionDate ?? this.transactionDate,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        remainingBalance: remainingBalance ?? this.remainingBalance,
        createdAt: createdAt ?? this.createdAt,
        interestRate: clearInterest ? null : (interestRate ?? this.interestRate),
        interestType: clearInterest ? null : (interestType ?? this.interestType),
        interestMode: clearInterest ? null : (interestMode ?? this.interestMode),
        interestFrequencyDays: clearInterest
            ? null
            : (interestFrequencyDays ?? this.interestFrequencyDays),
        interestStartDate:
            clearInterest ? null : (interestStartDate ?? this.interestStartDate),
        nextInterestDate:
            clearInterest ? null : (nextInterestDate ?? this.nextInterestDate),
        reminderEnabled:
            clearReminder ? false : (reminderEnabled ?? this.reminderEnabled),
        reminderStartDate:
            clearReminder ? null : (reminderStartDate ?? this.reminderStartDate),
        reminderIntervalDays: clearReminder
            ? 1
            : (reminderIntervalDays ?? this.reminderIntervalDays),
        nextReminderDate:
            clearReminder ? null : (nextReminderDate ?? this.nextReminderDate),
      );

  @override
  String toString() =>
      'Debt(id: $id, lender: $lenderName, amount: $amount, status: ${status.name})';
}

/// Immutable value object representing a single interest application event.
class InterestTransaction {
  final int? id;
  final int debtId;
  final DateTime appliedAt;
  final double interestRate;
  final double interestAmount;
  final double balanceBefore;
  final double balanceAfter;
  final String type; // 'manual' or 'automatic'

  const InterestTransaction({
    this.id,
    required this.debtId,
    required this.appliedAt,
    required this.interestRate,
    required this.interestAmount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.type,
  });

  bool get isAutomatic => type == 'automatic';
  bool get isManual => type == 'manual';

  Map<String, dynamic> toMap() => {
        'id': id,
        'debt_id': debtId,
        'applied_at': appliedAt.toIso8601String(),
        'interest_rate': interestRate,
        'interest_amount': interestAmount,
        'balance_before': balanceBefore,
        'balance_after': balanceAfter,
        'type': type,
      };

  factory InterestTransaction.fromMap(Map<String, dynamic> map) =>
      InterestTransaction(
        id: map['id'] as int?,
        debtId: map['debt_id'] as int,
        appliedAt: DateTime.parse(map['applied_at'] as String),
        interestRate: (map['interest_rate'] as num).toDouble(),
        interestAmount: (map['interest_amount'] as num).toDouble(),
        balanceBefore: (map['balance_before'] as num).toDouble(),
        balanceAfter: (map['balance_after'] as num).toDouble(),
        type: map['type'] as String,
      );

  @override
  String toString() =>
      'InterestTransaction(id: $id, debtId: $debtId, amount: $interestAmount, type: $type)';
}

/// Immutable value object representing a single payment event.
class PaymentHistory {
  final int? id;
  final int debtId;
  final double paymentAmount;
  final DateTime paymentDate;
  final String? paymentNote;

  const PaymentHistory({
    this.id,
    required this.debtId,
    required this.paymentAmount,
    required this.paymentDate,
    this.paymentNote,
  });

  /// Positive = payment made. Negative = interest accrued (legacy).
  bool get isInterest => paymentAmount < 0;

  String get displayNote {
    if (paymentNote?.isNotEmpty == true) return paymentNote!;
    return isInterest ? 'Interest accrued' : 'Payment';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'debt_id': debtId,
        'payment_amount': paymentAmount,
        'payment_date': paymentDate.toIso8601String(),
        'payment_note': paymentNote,
      };

  factory PaymentHistory.fromMap(Map<String, dynamic> map) => PaymentHistory(
        id: map['id'] as int?,
        debtId: map['debt_id'] as int,
        paymentAmount: (map['payment_amount'] as num).toDouble(),
        paymentDate: DateTime.parse(map['payment_date'] as String),
        paymentNote: map['payment_note'] as String?,
      );

  @override
  String toString() =>
      'PaymentHistory(id: $id, debtId: $debtId, amount: $paymentAmount)';
}

/// Aggregated summary figures computed from all debt records.
class DebtSummary {
  final double totalBorrowed;
  final double totalRemaining;
  final int unpaidCount;
  final int partialCount;
  final int paidCount;

  const DebtSummary({
    required this.totalBorrowed,
    required this.totalRemaining,
    required this.unpaidCount,
    required this.partialCount,
    required this.paidCount,
  });

  double get totalPaid => totalBorrowed - totalRemaining;
  double get overallProgress =>
      totalBorrowed > 0 ? (totalPaid / totalBorrowed).clamp(0.0, 1.0) : 0.0;

  static const DebtSummary empty = DebtSummary(
    totalBorrowed: 0,
    totalRemaining: 0,
    unpaidCount: 0,
    partialCount: 0,
    paidCount: 0,
  );
}
