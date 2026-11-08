import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/debt.dart';
import 'package:iou_debt_tracker/screens/dashboard_screen.dart';
import 'package:iou_debt_tracker/services/debt_service.dart';
import 'package:iou_debt_tracker/services/interest_service.dart';
import 'package:iou_debt_tracker/services/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

Debt _debt({required String lenderName, required double amount}) => Debt(
      amount: amount,
      lenderName: lenderName,
      transactionDate: DateTime(2026, 2, 14),
      notes: null,
      status: DebtStatus.unpaid,
      remainingBalance: amount,
      createdAt: DateTime(2026, 2, 14, 9, 30),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDebtRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    repo = MockDebtRepository();
    ServiceLocator.configure(
      debtService: DebtService(repo, InterestService(repo)),
    );

    await repo.insertDebt(
        _debt(lenderName: 'Maria Santos', amount: 500));
    await repo.insertDebt(
        _debt(lenderName: 'Maria Santos', amount: 300));
    await repo.insertDebt(
        _debt(lenderName: 'Juan Dela Cruz', amount: 900));
  });

  tearDown(() => ServiceLocator.configure());

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();
  }

  group('Dashboard Borrowers view', () {
    testWidgets('starts on the Debts list', (tester) async {
      await pumpDashboard(tester);

      expect(find.text('Debts'), findsOneWidget);
      expect(find.text('Borrowers'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // search bar
      expect(find.text('outstanding'), findsNothing); // no group rows yet
    });

    testWidgets('switches to a grouped list of people', (tester) async {
      await pumpDashboard(tester);

      await tester.tap(find.text('Borrowers'));
      await tester.pumpAndSettle();

      // Search + status tabs belong to the Debts view only.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TabBar), findsNothing);

      expect(find.text('outstanding'), findsNWidgets(2));
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('2 debts · 2 open'), findsOneWidget);
      expect(find.text('1 debt · 1 open'), findsOneWidget);

      // Biggest outstanding first: Juan (900) before Maria (800).
      final juanY = tester.getTopLeft(find.text('Juan Dela Cruz')).dy;
      final mariaY = tester.getTopLeft(find.text('Maria Santos')).dy;
      expect(juanY, lessThan(mariaY));
    });

    testWidgets('tapping a borrower filters the Debts list and shows a chip',
        (tester) async {
      await pumpDashboard(tester);

      await tester.tap(find.text('Borrowers'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maria Santos'));
      await tester.pumpAndSettle();

      // Back on the debts list, narrowed to Maria's two records.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('No results found'), findsNothing);

      // Juan's debt is filtered out; Maria's two cards remain.
      expect(find.text('Juan Dela Cruz'), findsNothing);
    });

    testWidgets('clearing the chip restores the full list', (tester) async {
      await pumpDashboard(tester);

      await tester.tap(find.text('Borrowers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maria Santos'));
      await tester.pumpAndSettle();

      // The chip's close button is unique; the search box has its own clear.
      await tester.tap(find.byTooltip('Clear filter'));
      await tester.pumpAndSettle();

      expect(find.text('Only this borrower'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      // The third card sits below the built window of the ListView.
      await tester.scrollUntilVisible(
        find.text('Juan Dela Cruz'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
    });

    testWidgets('typing in search supersedes the borrower chip',
        (tester) async {
      await pumpDashboard(tester);

      await tester.tap(find.text('Borrowers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maria Santos'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Juan');
      await tester.pumpAndSettle();

      expect(find.text('Only this borrower'), findsNothing);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('Maria Santos'), findsNothing);
    });
  });
}
