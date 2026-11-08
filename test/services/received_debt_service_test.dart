import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/debt.dart';
import 'package:iou_debt_tracker/models/debt_share_payload.dart';
import 'package:iou_debt_tracker/models/received_debt.dart';
import 'package:iou_debt_tracker/services/received_debt_service.dart';

import '../helpers/mocks.dart';

Debt _debt({String lenderName = 'Maria Santos', double amount = 1500}) =>
    Debt(
      id: 1,
      lenderName: lenderName,
      amount: amount,
      transactionDate: DateTime(2026, 2, 14),
      notes: 'For the repair',
      status: DebtStatus.unpaid,
      remainingBalance: amount,
      createdAt: DateTime(2026, 2, 14, 9, 30),
    );

void main() {
  late MockReceivedDebtRepository repo;
  late ReceivedDebtService service;

  setUp(() {
    repo = MockReceivedDebtRepository();
    service = ReceivedDebtService(repo);
  });

  group('importFromQr', () {
    test('a valid code stores a read-only copy', () async {
      final code = DebtSharePayload.fromDebt(
        debt: _debt(),
        lenderName: 'Marco Cruz',
      ).encode();

      final result = await service.importFromQr(code);

      expect(result.status, QrImportStatus.imported);
      expect(result.isSuccess, isTrue);
      expect(result.message, 'Received from Marco Cruz');

      final records = await service.getRecords();
      expect(records, hasLength(1));
      expect(records.first.lenderName, 'Marco Cruz');
      expect(records.first.borrowerName, 'Maria Santos');
      expect(records.first.amount, 1500);
    });

    test('garbage returns invalid and stores nothing', () async {
      final result = await service.importFromQr('definitely not a qr');

      expect(result.status, QrImportStatus.invalid);
      expect(result.isSuccess, isFalse);
      expect(result.message, contains('debt code'));
      expect(await service.getRecords(), isEmpty);
    });

    test('re-sharing the same debt refreshes it instead of duplicating',
        () async {
      final code = DebtSharePayload.fromDebt(
        debt: _debt(),
        lenderName: 'Marco Cruz',
      ).encode();

      final first = await service.importFromQr(code);
      final second = await service.importFromQr(code);

      expect(first.status, QrImportStatus.imported);
      expect(second.status, QrImportStatus.updated);
      expect(second.message, 'Updated copy from Marco Cruz');
      expect(await service.getRecords(), hasLength(1));
    });

    test('a different lender with the same local id stays a separate record',
        () async {
      final marco = DebtSharePayload.fromDebt(
        debt: _debt(),
        lenderName: 'Marco Cruz',
      ).encode();
      final angela = DebtSharePayload.fromDebt(
        debt: _debt(),
        lenderName: 'Angela Cruz',
      ).encode();

      await service.importFromQr(marco);
      await service.importFromQr(angela);

      expect(await service.getRecords(), hasLength(2));
    });
  });

  group('getSummary', () {
    test('is empty by default', () async {
      final summary = await service.getSummary();

      expect(summary.isEmpty, isTrue);
      expect(summary.totalOwed, 0);
      expect(summary.progress, 0);
    });

    test('totals outstanding balances across received records', () async {
      await service.importFromQr(
        DebtSharePayload.fromDebt(
                debt: _debt(amount: 1000), lenderName: 'Marco')
            .encode(),
      );
      await service.importFromQr(
        DebtSharePayload.fromDebt(
                debt: _debt(lenderName: 'Ana', amount: 500), lenderName: 'Ana')
            .encode(),
      );

      final summary = await service.getSummary();

      expect(summary.totalCount, 2);
      expect(summary.totalOwed, 1500);
      expect(summary.lenderCount, 2);
      expect(summary.unpaidCount, 2);
    });

    test('settled records lower the outstanding total', () async {
      final code = DebtSharePayload.fromDebt(
              debt: _debt(amount: 800), lenderName: 'Marco')
          .encode();
      await service.importFromQr(code);

      final record = (await service.getRecords()).first;
      await repo.upsert(
        ReceivedDebt(
          id: record.id,
          recordUid: record.recordUid,
          lenderName: record.lenderName,
          borrowerName: record.borrowerName,
          amount: record.amount,
          remainingBalance: 0,
          status: DebtStatus.paid,
          transactionDate: record.transactionDate,
          notes: record.notes,
          interestRate: null,
          interestType: null,
          interestMode: null,
          interestFrequencyDays: null,
          interestStartDate: null,
          createdAt: record.createdAt,
          receivedAt: record.receivedAt,
        ),
      );

      final summary = await service.getSummary();

      expect(summary.totalOwed, 0);
      expect(summary.paidCount, 1);
      expect(summary.progress, 1);
    });
  });
}
