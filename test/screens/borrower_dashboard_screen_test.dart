import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/screens/borrower_dashboard_screen.dart';
import 'package:iou_debt_tracker/screens/received_debt_screen.dart';
import 'package:iou_debt_tracker/services/profile_service.dart';
import 'package:iou_debt_tracker/services/received_debt_service.dart';
import 'package:iou_debt_tracker/services/service_locator.dart';
import 'package:iou_debt_tracker/widgets/borrower/borrower_summary_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';
import '../helpers/seeds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockReceivedDebtRepository repo;
  late ReceivedDebtService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({'profile_name': 'Juan'});

    repo = MockReceivedDebtRepository();
    service = ReceivedDebtService(repo);
    ServiceLocator.configure(
      receivedDebtService: service,
      profileService: ProfileService(SharedPreferences.getInstance()),
    );
  });

  tearDown(() => ServiceLocator.configure());

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: BorrowerDashboardScreen()));
    await tester.pumpAndSettle();
  }

  group('BorrowerDashboardScreen', () {
    testWidgets('shows the empty state and a scan action when nothing is '
        'received yet', (tester) async {
      await pumpDashboard(tester);

      expect(find.byType(BorrowerSummaryCard), findsOneWidget);
      expect(find.text('No debts yet'), findsOneWidget);
      expect(
        find.text('Scan the QR a lender shares with you\nto keep a read-only copy here.'),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('BORROWER'), findsOneWidget);
    });

    testWidgets('lists received debts with real totals once imported',
        (tester) async {
      await seedDebt(service, lenderName: 'Marco Cruz', amount: 1500);
      await seedDebt(service, lenderName: 'Angela Cruz', amount: 500);

      await pumpDashboard(tester);

      expect(find.text('No debts yet'), findsNothing);
      expect(find.text('Marco Cruz'), findsOneWidget);
      expect(find.text('Angela Cruz'), findsOneWidget);

      // 1,500 + 500 outstanding (shown on the card and in each row)
      expect(find.text('₱2,000.00'), findsWidgets);
      expect(find.text('2 debts'), findsOneWidget);
      expect(find.text('0/2'), findsOneWidget);
    });

    testWidgets('opens the read-only screen for a received debt',
        (tester) async {
      await seedDebt(service, lenderName: 'Marco Cruz', amount: 1500);

      await pumpDashboard(tester);

      await tester.tap(find.text('Marco Cruz'));
      await tester.pumpAndSettle();

      expect(find.byType(ReceivedDebtScreen), findsOneWidget);
      expect(find.text('Read-only copy. Marco Cruz keeps the original '
          'record and sends you updates by sharing the code again.'),
          findsOneWidget);
      // No edit, payment or delete affordances on a borrowed copy.
      expect(find.byIcon(Icons.edit_rounded), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.qr_code_2_rounded), findsNothing);
    });

    testWidgets('summary card reflects an imported debt', (tester) async {
      await seedDebt(service, lenderName: 'Marco Cruz', amount: 1000);

      await pumpDashboard(tester);

      expect(find.text('Total Owed'), findsOneWidget);
      expect(find.text('₱1,000.00'), findsWidgets);
      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('1 debt'), findsOneWidget);
      expect(find.text('0% paid off'), findsOneWidget);
    });
  });
}
