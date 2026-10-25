import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/debt.dart';
import 'package:iou_debt_tracker/screens/add_debt_screen.dart';
import 'package:iou_debt_tracker/screens/debt_qr_screen.dart';
import 'package:iou_debt_tracker/services/debt_service.dart';
import 'package:iou_debt_tracker/services/interest_service.dart';
import 'package:iou_debt_tracker/services/notification_service.dart';
import 'package:iou_debt_tracker/services/profile_service.dart';
import 'package:iou_debt_tracker/services/service_locator.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

/// No-ops the local-notification plugin so the flow can save a debt in the
/// test environment (the plugin has no host implementation in widget tests).
class _FakeNotificationService extends NotificationService {
  @override
  Future<void> scheduleDebtReminder(Debt debt) async {}

  @override
  Future<void> cancelDebtReminder(int debtId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDebtRepository repo;

  // Note: SharedPreferences + ServiceLocator wiring happens inside the test
  // body (pumpAdd), not in setUp — getInstance() must be called inside the
  // FakeAsync test zone or its future never resolves during pumpAndSettle.
  tearDown(() => ServiceLocator.configure());

  Future<void> wireServices() async {
    repo = MockDebtRepository();
    // Profile name is preset so the QR screen does not open its name dialog
    // mid-flow; naming itself is covered in debt_qr_screen_test.dart.
    SharedPreferences.setMockInitialValues({'profile_name': 'Marco Cruz'});
    ServiceLocator.configure(
      debtService: DebtService(
        repo,
        InterestService(repo),
        notificationService: _FakeNotificationService(),
      ),
      profileService: ProfileService(SharedPreferences.getInstance()),
    );
  }

  Future<void> pumpAdd(WidgetTester tester) async {
    await wireServices();
    await tester
        .pumpWidget(const MaterialApp(home: AddDebtScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSave(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Maria Santos');
    await tester.enterText(find.byType(TextFormField).at(1), '5000');
    await tester.ensureVisible(find.text('Save Debt Record'));
    await tester.tap(find.text('Save Debt Record'));
    await tester.pumpAndSettle();
  }

  group('Add debt → QR flow', () {
    testWidgets('saving a new debt opens the QR screen with the debt details',
        (tester) async {
      await pumpAdd(tester);
      await fillAndSave(tester);

      // The QR screen takes over, carrying the saved record.
      expect(find.byType(DebtQrScreen), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Share this debt'), findsOneWidget);
      expect(find.text('Lent by'), findsOneWidget);
      expect(find.text('Marco Cruz'), findsOneWidget);
      expect(find.text('Owed by'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('₱5,000.00'), findsOneWidget);

      // The record really landed in storage with the form's values.
      final debts = await repo.getAllDebts();
      expect(debts, hasLength(1));
      expect(debts.first.lenderName, 'Maria Santos');
      expect(debts.first.amount, 5000);
    });

    testWidgets('Done returns out of the add-debt flow', (tester) async {
      await pumpAdd(tester);
      await fillAndSave(tester);
      expect(find.byType(DebtQrScreen), findsOneWidget);

      // D1: the save-confirmation snackbar must not sit under the Done button
      // on the QR screen. Tap Done immediately — no waiting out a snackbar.
      await tester.scrollUntilVisible(
        find.text('Done'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Debt record saved!'), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(DebtQrScreen), findsNothing);
      expect(find.byType(AddDebtScreen), findsNothing);
    });

    testWidgets('automatic interest demands an interest start date',
        (tester) async {
      await pumpAdd(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Maria Santos');
      await tester.enterText(find.byType(TextFormField).at(1), '5000');

      // Turn Interest on (first switch) and set a rate.
      await tester.ensureVisible(find.byType(Switch).at(0));
      await tester.tap(find.byType(Switch).at(0));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(2), '5');

      // Choose Automatic mode. Frequency keeps its preset; the start date is
      // deliberately never picked.
      await tester.tap(find.text('Automatic'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Debt Record'));
      await tester.tap(find.text('Save Debt Record'));
      await tester.pumpAndSettle();

      // The debt must NOT be created (it would silently never accrue
      // interest: interest_service returns 0 when the start date is null).
      expect(find.byType(DebtQrScreen), findsNothing);
      expect(find.text('Pick when interest should start.'), findsOneWidget);
      final debts = await repo.getAllDebts();
      expect(debts, isEmpty);
    });

    testWidgets('editing an existing debt updates without showing the QR',
        (tester) async {
    await wireServices();
      await repo.insertDebt(Debt(
        lenderName: 'Maria Santos',
        amount: 1500,
        transactionDate: DateTime(2026, 2, 14),
        status: DebtStatus.unpaid,
        remainingBalance: 1500,
        createdAt: DateTime(2026, 2, 14, 9, 30),
      ));
      final existing = (await repo.getAllDebts()).first;

      await tester.pumpWidget(MaterialApp(
        home: AddDebtScreen(existingDebt: existing),
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Update Debt'));
      await tester.tap(find.text('Update Debt'));
      await tester.pumpAndSettle();

      expect(find.byType(DebtQrScreen), findsNothing);
      expect(find.byType(AddDebtScreen), findsNothing);
    });
  });
}
