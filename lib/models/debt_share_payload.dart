import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'debt.dart';

/// A serialisable snapshot of a debt, small enough to fit inside a QR code.
///
/// IMPORTANT — name mapping: [Debt.lenderName] is this app's *counterparty*
/// field (the person who owes, from the lender's point of view), so it maps
/// to [borrowerName] here. The lender's own identity is supplied separately
/// as [lenderName], because the Add Debt form never asks for it.
///
/// OOP principles:
/// - Single Responsibility : encode / validate / decode only — storage is
///   handled by the received-debt repository, rendering by the QR screen.
/// - Information Expert : the payload knows its own wire format, so no
///   screen has to know which JSON keys exist.
class DebtSharePayload {
  /// Marker so a scanned QR that is not one of ours is rejected politely.
  static const String kind = 'iou_debt';

  /// Bump when the wire format changes incompatibly. Older payloads keep
  /// decoding; newer ones are refused instead of half-read.
  static const int version = 1;

  /// Keeps the note from growing the QR past a comfortable scan size.
  static const int maxNotesLength = 300;

  final String uid;
  final String lenderName;
  final String? borrowerName;
  final double amount;
  final DebtStatus status;
  final double remainingBalance;
  final DateTime transactionDate;
  final String? notes;
  final double? interestRate;
  final InterestType? interestType;
  final InterestMode? interestMode;
  final int? interestFrequencyDays;
  final DateTime? interestStartDate;
  final DateTime createdAt;

  const DebtSharePayload({
    required this.uid,
    required this.lenderName,
    required this.borrowerName,
    required this.amount,
    required this.status,
    required this.remainingBalance,
    required this.transactionDate,
    required this.notes,
    required this.interestRate,
    required this.interestType,
    required this.interestMode,
    required this.interestFrequencyDays,
    required this.interestStartDate,
    required this.createdAt,
  });

  // ── Creation ───────────────────────────────────────────────────────────────

  /// Builds a payload from a saved [debt].
  ///
  /// The uid is derived from the lender's name, the local debt id and its
  /// creation time, so re-sharing the *same* debt produces the *same* uid
  /// (the borrower's copy is updated in place) while the same local id from
  /// two different lenders can never collide.
  factory DebtSharePayload.fromDebt({
    required Debt debt,
    required String lenderName,
  }) {
    final note = debt.notes;
    return DebtSharePayload(
      uid: _uidFor(
        lenderName: lenderName,
        debtId: debt.id ?? 0,
        createdAt: debt.createdAt,
      ),
      lenderName: lenderName.trim(),
      borrowerName: debt.lenderName.trim(),
      amount: debt.amount,
      status: debt.status,
      remainingBalance: debt.remainingBalance,
      transactionDate: debt.transactionDate,
      notes: note == null || note.isEmpty
          ? null
          : (note.length > maxNotesLength
              ? '${note.substring(0, maxNotesLength)}…'
              : note),
      interestRate: debt.interestRate,
      interestType: debt.interestType,
      interestMode: debt.interestMode,
      interestFrequencyDays: debt.interestFrequencyDays,
      interestStartDate: debt.interestStartDate,
      createdAt: debt.createdAt,
    );
  }

  static String _uidFor({
    required String lenderName,
    required int debtId,
    required DateTime createdAt,
  }) {
    final seed =
        '${lenderName.trim().toLowerCase()}|$debtId|${createdAt.toIso8601String()}';
    final digest = sha256.convert(utf8.encode(seed)).toString();
    return digest.substring(0, 20);
  }

  // ── Wire format ────────────────────────────────────────────────────────────

  String encode() => jsonEncode({
        'kind': kind,
        'version': version,
        'uid': uid,
        'lender_name': lenderName,
        if (borrowerName != null && borrowerName!.isNotEmpty)
          'borrower_name': borrowerName,
        'amount': amount,
        'status': status.name,
        'remaining_balance': remainingBalance,
        'transaction_date': transactionDate.toIso8601String(),
        if (notes != null) 'notes': notes,
        if (interestRate != null) 'interest_rate': interestRate,
        if (interestType != null) 'interest_type': interestType!.name,
        if (interestMode != null) 'interest_mode': interestMode!.name,
        if (interestFrequencyDays != null)
          'interest_frequency_days': interestFrequencyDays,
        if (interestStartDate != null)
          'interest_start_date': interestStartDate!.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      });

  /// Decodes arbitrary scanned text.
  ///
  /// Returns `null` for anything that is not a well-formed I owe U debt code:
  /// malformed JSON, another app's QR, a missing required field, or a format
  /// newer than this build understands. Never throws — a bad scan is a normal
  /// event, not an error.
  static DebtSharePayload? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map) return null;
      if (decoded['kind'] != kind) return null;

      final payloadVersion = decoded['version'];
      if (payloadVersion is! int || payloadVersion < 1) return null;
      if (payloadVersion > version) return null;

      final uid = decoded['uid'];
      final amount = decoded['amount'];
      final lenderName = decoded['lender_name'];
      final transactionDate = _date(decoded['transaction_date']);

      if (uid is! String || uid.isEmpty) return null;
      if (amount is! num) return null;
      if (lenderName is! String || lenderName.trim().isEmpty) return null;
      if (transactionDate == null) return null;

      final remaining = decoded['remaining_balance'];
      final remainingBalance =
          remaining is num ? remaining.toDouble() : amount.toDouble();

      return DebtSharePayload(
        uid: uid,
        lenderName: lenderName.trim(),
        borrowerName: decoded['borrower_name'] is String
            ? decoded['borrower_name'] as String
            : null,
        amount: amount.toDouble().clamp(0, double.infinity).toDouble(),
        status: _status(decoded['status']),
        remainingBalance:
            remainingBalance.clamp(0, double.infinity).toDouble(),
        transactionDate: transactionDate,
        notes: decoded['notes'] is String ? decoded['notes'] as String : null,
        interestRate: decoded['interest_rate'] is num
            ? (decoded['interest_rate'] as num).toDouble()
            : null,
        interestType: _interestType(decoded['interest_type']),
        interestMode: _interestMode(decoded['interest_mode']),
        interestFrequencyDays: decoded['interest_frequency_days'] is int
            ? decoded['interest_frequency_days'] as int
            : null,
        interestStartDate: _date(decoded['interest_start_date']),
        createdAt: _date(decoded['created_at']) ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  static DebtStatus _status(Object? raw) {
    final value = raw is String ? raw : '';
    return DebtStatus.values.cast<DebtStatus?>().firstWhere(
          (e) => e!.name == value,
          orElse: () => null,
        ) ?? DebtStatus.unpaid;
  }

  static InterestType? _interestType(Object? raw) => raw is String
      ? InterestType.values.cast<InterestType?>().firstWhere(
            (e) => e!.name == raw,
            orElse: () => null,
          )
      : null;

  static InterestMode? _interestMode(Object? raw) => raw is String
      ? InterestMode.values.cast<InterestMode?>().firstWhere(
            (e) => e!.name == raw,
            orElse: () => null,
          )
      : null;

  // ── Presentation ───────────────────────────────────────────────────────────

  /// Who lent the money — never empty by the time a QR is rendered, because
  /// the QR screen asks for the profile name first.
  String get lenderDisplay => lenderName.trim().isEmpty ? 'Lender' : lenderName;

  String get borrowerDisplay =>
      borrowerName == null || borrowerName!.trim().isEmpty
          ? 'Borrower'
          : borrowerName!.trim();

  bool get isPaid => status == DebtStatus.paid;
}
