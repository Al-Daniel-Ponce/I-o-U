import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/debt.dart';
import 'package:iou_debt_tracker/screens/debt_qr_screen.dart';
import 'package:iou_debt_tracker/services/profile_service.dart';
import 'package:iou_debt_tracker/services/service_locator.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

Debt _debt() => Debt(
      id: 7,
      lenderName: 'Maria Santos',
      amount: 1500,
      transactionDate: DateTime(2026, 2, 14),
      notes: 'For the repair',
      status: DebtStatus.unpaid,
      remainingBalance: 750,
      createdAt: DateTime(2026, 2, 14, 9, 30),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Mock preferences *before* the profile service reads them, then build.
  Future<void> pumpQr(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    Debt? debt,
    SharePlus? sharePlus,
    ReceiptCapturer? receiptCapturer,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    ServiceLocator.configure(
      profileService: ProfileService(SharedPreferences.getInstance()),
    );

    await tester.pumpWidget(MaterialApp(
      home: DebtQrScreen(
        debt: debt ?? _debt(),
        sharePlus: sharePlus,
        receiptCapturer: receiptCapturer,
      ),
    ));
    await tester.pumpAndSettle();
  }

  tearDown(() => ServiceLocator.configure());

  group('DebtQrScreen', () {
    testWidgets('shows the QR plus who lent and who owes', (tester) async {
      await pumpQr(tester, prefs: {'profile_name': 'Marco Cruz'});

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Share this debt'), findsOneWidget);
      expect(find.text('Lent by'), findsOneWidget);
      expect(find.text('Marco Cruz'), findsOneWidget);
      expect(find.text('Owed by'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('₱1,500.00'), findsOneWidget);
      expect(find.text('OUTSTANDING'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('asks for the profile name the first time and uses it',
        (tester) async {
      await pumpQr(tester);

      expect(find.text('What should we call you?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Angela Cruz');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('What should we call you?'), findsNothing);
      expect(find.text('Angela Cruz'), findsOneWidget);

      // The name is persisted for the next share, too.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_name'), 'Angela Cruz');
    });

    testWidgets('keeps working when the user skips naming themselves',
        (tester) async {
      await pumpQr(tester);

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('What should we call you?'), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Your name is not on the code yet.'), findsOneWidget);

      // The hint card sits below the QR, off the default test surface.
      await tester.ensureVisible(find.text('Add your name'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add your name'));
      await tester.pumpAndSettle();
      expect(find.text('What should we call you?'), findsOneWidget);
    });

    testWidgets('an unnamed lender code hides sharing and explains why',
        (tester) async {
      await pumpQr(tester);

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      // Without the lender's name every scan would reject the code, so the
      // share/copy controls never appear and a banner explains instead.
      expect(find.text('Save receipt'), findsNothing);
      expect(find.text('Copy text'), findsNothing);
      expect(
        find.text(
            'Add your name first — a code without it cannot be imported.'),
        findsOneWidget,
      );
    });

    testWidgets('Done returns to the caller', (tester) async {
      await pumpQr(tester, prefs: {'profile_name': 'Marco Cruz'});

      // The Done button sits below the fold on the default test surface.
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(DebtQrScreen), findsNothing);
    });

    testWidgets('renders a paper receipt with a numbered header',
        (tester) async {
      await pumpQr(tester, prefs: {'profile_name': 'Marco Cruz'});

      expect(find.text('DEBT RECEIPT'), findsOneWidget);
      // Receipt number: first six hex characters of the payload uid.
      expect(find.textContaining(RegExp(r'^#[0-9A-F]{6}$')), findsOneWidget);
      expect(find.text('Scan to import'), findsOneWidget);
    });

    testWidgets('itemizes owed, remaining, interest and notes',
        (tester) async {
      await pumpQr(tester, prefs: {'profile_name': 'Marco Cruz'});

      expect(find.text('₱1,500.00'), findsOneWidget);
      expect(find.text('Lent by'), findsOneWidget);
      expect(find.text('Owed by'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('₱750.00'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('For the repair'), findsOneWidget);
      // No interest configured on this seed debt.
      expect(find.text('Interest'), findsNothing);
    });

    testWidgets('shows the interest line for an interest-bearing debt',
        (tester) async {
      await pumpQr(
        tester,
        prefs: {'profile_name': 'Marco Cruz'},
        debt: Debt(
          id: 9,
          lenderName: 'Maria Santos',
          amount: 1500,
          transactionDate: DateTime(2026, 2, 14),
          status: DebtStatus.unpaid,
          remainingBalance: 1500,
          interestRate: 5,
          interestType: InterestType.simple,
          interestMode: InterestMode.automatic,
          interestFrequencyDays: 7,
          interestStartDate: DateTime(2026, 2, 21),
          createdAt: DateTime(2026, 2, 14, 9, 30),
        ),
      );

      expect(find.text('Interest'), findsOneWidget);
      expect(find.text('5% simple · automatic · weekly'), findsOneWidget);
      // Fully outstanding debt has no partial remaining row.
      expect(find.text('Remaining'), findsNothing);
    });

    testWidgets('save receipt rasterises a PNG and opens the share sheet',
        (tester) async {
      final sharePlatform = _RecordingSharePlatform();
      var capturedKeys = 0;
      await pumpQr(
        tester,
        prefs: {'profile_name': 'Marco Cruz'},
        sharePlus: SharePlus.custom(sharePlatform),
        receiptCapturer: (key) async {
          capturedKeys++;
          return XFile.fromData(
            Uint8List.fromList(const [137, 80, 78, 71]),
            name: 'iou-receipt.png',
            mimeType: 'image/png',
          );
        },
      );

      expect(find.text('Save receipt'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Save receipt'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Save receipt'));
      await tester.pumpAndSettle();

      expect(capturedKeys, 1);
      expect(sharePlatform.shareCalls, 1);
      final files = sharePlatform.lastParams!.files!;
      expect(files.length, 1);
      expect(files.single.mimeType, 'image/png');
      expect(find.text('Receipt shared'), findsOneWidget);
    });

    testWidgets('save receipt explains itself when capture fails',
        (tester) async {
      await pumpQr(
        tester,
        prefs: {'profile_name': 'Marco Cruz'},
        sharePlus: SharePlus.custom(_RecordingSharePlatform()),
        receiptCapturer: (key) async => throw StateError('no boundary'),
      );

      await tester.scrollUntilVisible(
        find.text('Save receipt'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Save receipt'));
      await tester.pumpAndSettle();

      expect(find.text('Could not share the receipt.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('save receipt is disabled while the image is prepared',
        (tester) async {
      final captured = Completer<void>();
      await pumpQr(
        tester,
        prefs: {'profile_name': 'Marco Cruz'},
        sharePlus: SharePlus.custom(_RecordingSharePlatform()),
        receiptCapturer: (key) => captured.future.then(
          (_) => XFile.fromData(Uint8List.fromList(const [1])),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Save receipt'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Save receipt'));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save receipt'),
      );
      expect(button.onPressed, isNull);

      captured.complete();
      await tester.pumpAndSettle();
      expect(find.text('Receipt shared'), findsOneWidget);
    });

    testWidgets('copy text puts a plain-text receipt on the clipboard',
        (tester) async {
      Object? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map<String, Object?>)['text'];
          }
          return null;
        },
      );

      await pumpQr(tester, prefs: {'profile_name': 'Marco Cruz'});

      await tester.scrollUntilVisible(
        find.text('Copy text'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Copy text'));
      await tester.pumpAndSettle();

      expect(clipboardText, isNotNull);
      final text = clipboardText! as String;
      expect(text, contains('IOU DEBT RECEIPT'));
      expect(text, contains('#'));
      expect(text, contains('Marco Cruz'));
      expect(text, contains('Maria Santos'));
      expect(text, contains('₱1,500.00'));
      expect(find.text('Receipt copied'), findsOneWidget);
    });
  });
}

/// Share sheet stand-in that remembers every request.
class _RecordingSharePlatform extends SharePlatform {
  int shareCalls = 0;
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    shareCalls++;
    lastParams = params;
    return const ShareResult('test', ShareResultStatus.success);
  }
}
