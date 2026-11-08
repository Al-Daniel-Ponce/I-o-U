import '../models/debt_share_payload.dart';
import '../models/received_debt.dart';
import '../repositories/i_debt_repositories.dart';
import 'logger.dart';

/// Outcome of scanning or decoding a shared debt.
enum QrImportStatus {
  /// Not a valid I owe U debt code — nothing was stored.
  invalid,

  /// A brand-new record was stored.
  imported,

  /// The same debt was re-shared; the stored copy was refreshed.
  updated,
}

class QrImportResult {
  final QrImportStatus status;
  final ReceivedDebt? record;

  const QrImportResult._(this.status, this.record);

  const QrImportResult.invalid() : this._(QrImportStatus.invalid, null);

  const QrImportResult.imported(ReceivedDebt record)
      : this._(QrImportStatus.imported, record);

  const QrImportResult.updated(ReceivedDebt record)
      : this._(QrImportStatus.updated, record);

  bool get isSuccess => status != QrImportStatus.invalid;

  /// User-facing message for the confirmation banner.
  String get message => switch (status) {
        QrImportStatus.invalid =>
          "That doesn't look like an I owe U debt code.",
        QrImportStatus.imported =>
          'Received from ${record!.lenderDisplay}',
        QrImportStatus.updated =>
          'Updated copy from ${record!.lenderDisplay}',
      };
}

/// Business rules for debts this device received by scanning a lender's QR.
///
/// A received record is read-only: this service exposes *import* and *read*
/// operations only — there is deliberately no payment, update or reminder
/// method, so an "I owe" copy can never be mutated from the borrower side.
///
/// OOP principles:
/// - Single Responsibility : decode → persist → report; no UI, no SQL.
/// - Dependency Inversion  : depends on [IReceivedDebtRepository], never on
///   SQLite, so tests swap in the in-memory mock.
class ReceivedDebtService {
  final IReceivedDebtRepository _repository;

  final _logger = const Logger('ReceivedDebtService');

  ReceivedDebtService(this._repository);

  /// Decodes scanned [raw] text and stores the record it describes.
  ///
  /// Returns [QrImportResult.invalid] instead of throwing when [raw] is not
  /// a well-formed debt code — a mis-scan is expected, not exceptional.
  Future<QrImportResult> importFromQr(String raw) async {
    final payload = DebtSharePayload.tryDecode(raw);
    if (payload == null) {
      _logger.warning('QR did not decode to a debt payload');
      return const QrImportResult.invalid();
    }
    return importPayload(payload);
  }

  /// Stores [payload], replacing any previously imported copy with the same
  /// uid (a lender re-sharing an edited debt refreshes the borrower's view).
  Future<QrImportResult> importPayload(DebtSharePayload payload) async {
    try {
      final existing = await _repository.getAll();
      final alreadyImported =
          existing.any((record) => record.recordUid == payload.uid);

      final record = ReceivedDebt.fromPayload(payload: payload);
      await _repository.upsert(record);

      final saved = (await _repository.getAll())
          .firstWhere((r) => r.recordUid == payload.uid);

      return alreadyImported
          ? QrImportResult.updated(saved)
          : QrImportResult.imported(saved);
    } catch (e, stack) {
      _logger.error('Failed to import received debt', e, stack);
      rethrow;
    }
  }

  /// All received records, newest first.
  Future<List<ReceivedDebt>> getRecords() async {
    try {
      return await _repository.getAll();
    } catch (e, stack) {
      _logger.error('Failed to load received debts', e, stack);
      rethrow;
    }
  }

  /// Aggregates for the borrower dashboard, including the empty summary.
  Future<ReceivedSummary> getSummary() async {
    final records = await getRecords();
    return ReceivedSummary.fromList(records);
  }
}
