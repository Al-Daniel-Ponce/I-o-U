import 'package:iou_debt_tracker/models/debt.dart';
import 'package:iou_debt_tracker/models/debt_share_payload.dart';
import 'package:iou_debt_tracker/services/received_debt_service.dart';

/// Convenience: build a payload from a synthetic debt and store it through
/// the real service, as if the user had scanned it.
///
/// The local id is randomised so two seeds for the *same* lender produce
/// two distinct records instead of upserting into one.
Future<void> seedDebt(
  ReceivedDebtService service, {
  required String lenderName,
  required double amount,
}) {
  final payload = DebtSharePayload.fromDebt(
    debt: Debt(
      id: DateTime.now().microsecondsSinceEpoch % 1000000,
      lenderName: 'Juan Dela Cruz',
      amount: amount,
      transactionDate: DateTime(2026, 2, 14),
      notes: null,
      status: DebtStatus.unpaid,
      remainingBalance: amount,
      createdAt: DateTime(2026, 2, 14, 9, 30),
    ),
    lenderName: lenderName,
  );
  return service.importFromQr(payload.encode());
}
