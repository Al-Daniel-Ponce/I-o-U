import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/debt.dart';
import 'package:iou_debt_tracker/models/debt_share_payload.dart';

Debt _debt({
  int? id = 1,
  String lenderName = 'Maria Santos',
  double amount = 1500,
  String? notes,
}) {
  return Debt(
    id: id,
    lenderName: lenderName,
    amount: amount,
    transactionDate: DateTime(2026, 2, 14),
    notes: notes,
    status: DebtStatus.unpaid,
    remainingBalance: amount,
    createdAt: DateTime(2026, 2, 14, 9, 30),
  );
}

void main() {
  group('DebtSharePayload round trip', () {
    test('encode → tryDecode preserves every shared field', () {
      final original = DebtSharePayload.fromDebt(
        debt: _debt(notes: 'For the repair', amount: 2750.5),
        lenderName: 'Marco Cruz',
      );

      final decoded = DebtSharePayload.tryDecode(original.encode());

      expect(decoded, isNotNull);
      expect(decoded!.uid, original.uid);
      expect(decoded.lenderName, 'Marco Cruz');
      expect(decoded.amount, 2750.5);
      expect(decoded.status, DebtStatus.unpaid);
      expect(decoded.remainingBalance, 2750.5);
      expect(decoded.transactionDate, DateTime(2026, 2, 14));
      expect(decoded.notes, 'For the repair');
      expect(decoded.createdAt, DateTime(2026, 2, 14, 9, 30));
    });

    test('carries interest terms across the wire', () {
      final payload = DebtSharePayload.fromDebt(
        debt: Debt(
          id: 5,
          lenderName: 'Ana',
          amount: 1000,
          transactionDate: DateTime(2026, 1, 1),
          notes: null,
          status: DebtStatus.unpaid,
          remainingBalance: 1000,
          createdAt: DateTime(2026, 1, 1),
          interestRate: 5,
          interestType: InterestType.compound,
          interestMode: InterestMode.automatic,
          interestFrequencyDays: 30,
          interestStartDate: DateTime(2026, 1, 31),
        ),
        lenderName: 'Marco',
      );

      final decoded = DebtSharePayload.tryDecode(payload.encode());

      expect(decoded!.interestRate, 5);
      expect(decoded.interestType, InterestType.compound);
      expect(decoded.interestMode, InterestMode.automatic);
      expect(decoded.interestFrequencyDays, 30);
      expect(decoded.interestStartDate, DateTime(2026, 1, 31));
    });
  });

  group('DebtSharePayload name mapping', () {
    test("the debt's counterparty becomes the payload's borrower", () {
      final payload = DebtSharePayload.fromDebt(
        debt: _debt(lenderName: 'Juan Dela Cruz'),
        lenderName: 'Marco Cruz',
      );

      expect(payload.borrowerName, 'Juan Dela Cruz');
      expect(payload.lenderName, 'Marco Cruz');
      expect(payload.borrowerDisplay, 'Juan Dela Cruz');
      expect(payload.lenderDisplay, 'Marco Cruz');
    });

    test('falls back to friendly labels when a name is missing', () {
      final payload = DebtSharePayload.fromDebt(
        debt: _debt(lenderName: '   '),
        lenderName: '',
      );

      expect(payload.lenderDisplay, 'Lender');
      expect(payload.borrowerDisplay, 'Borrower');
    });
  });

  group('DebtSharePayload uid', () {
    test('is stable for the same debt, so a re-share upserts', () {
      final first = DebtSharePayload.fromDebt(
          debt: _debt(), lenderName: 'Marco');
      final second = DebtSharePayload.fromDebt(
          debt: _debt(), lenderName: 'Marco');

      expect(first.uid, second.uid);
    });

    test('differs across lenders, so the same local id cannot collide', () {
      final a = DebtSharePayload.fromDebt(debt: _debt(), lenderName: 'Marco');
      final b = DebtSharePayload.fromDebt(debt: _debt(), lenderName: 'Angela');

      expect(a.uid, isNot(b.uid));
      expect(a.uid.length, 20);
    });
  });

  group('DebtSharePayload.tryDecode rejects', () {
    test('random text', () {
      expect(DebtSharePayload.tryDecode('hello world'), isNull);
      expect(DebtSharePayload.tryDecode(''), isNull);
    });

    test('valid JSON that is not one of our codes', () {
      expect(
        DebtSharePayload.tryDecode('{"kind":"wifi","version":1}'),
        isNull,
      );
    });

    test('a payload from a newer app version', () {
      final future = DebtSharePayload.fromDebt(
              debt: _debt(), lenderName: 'Marco')
          .encode()
          .replaceAll('"version":1', '"version":99');

      expect(DebtSharePayload.tryDecode(future), isNull);
    });

    test('missing required fields', () {
      expect(
        DebtSharePayload.tryDecode('{"kind":"iou_debt","version":1}'),
        isNull,
      );
      expect(
        DebtSharePayload.tryDecode(
            '{"kind":"iou_debt","version":1,"uid":"abc"}'),
        isNull,
      );
    });
  });

  group('DebtSharePayload notes', () {
    test('are truncated so the QR stays scannable', () {
      final payload = DebtSharePayload.fromDebt(
        debt: _debt(notes: 'x' * 400),
        lenderName: 'Marco',
      );

      expect(payload.notes!.length, DebtSharePayload.maxNotesLength + 1);
      expect(payload.notes, endsWith('…'));
      expect(DebtSharePayload.tryDecode(payload.encode()), isNotNull);
    });

    test('are dropped entirely when the debt has none', () {
      final payload = DebtSharePayload.fromDebt(
        debt: _debt(notes: null),
        lenderName: 'Marco',
      );

      expect(payload.notes, isNull);
      expect(payload.encode().contains('notes'), isFalse);
    });
  });
}
