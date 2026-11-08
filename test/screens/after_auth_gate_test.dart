import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/user_role.dart';
import 'package:iou_debt_tracker/screens/after_auth_gate.dart';
import 'package:iou_debt_tracker/screens/borrower_dashboard_screen.dart';
import 'package:iou_debt_tracker/screens/dashboard_screen.dart';
import 'package:iou_debt_tracker/screens/role_selection_screen.dart';
import 'package:iou_debt_tracker/services/debt_service.dart';
import 'package:iou_debt_tracker/services/interest_service.dart';
import 'package:iou_debt_tracker/services/role_service.dart';
import 'package:iou_debt_tracker/services/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const roleService = RoleService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    // Dashboards resolve their service through the locator; hand them an
    // in-memory repository so no platform database is touched.
    final debtRepo = MockDebtRepository();
    ServiceLocator.configure(
      debtService: DebtService(debtRepo, InterestService(debtRepo)),
    );
  });

  tearDown(() => ServiceLocator.configure());

  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AfterAuthGate()));
    await tester.pumpAndSettle();
  }

  group('AfterAuthGate', () {
    testWidgets('shows the role picker when no role has been saved',
        (tester) async {
      await pumpGate(tester);

      expect(find.byType(RoleSelectionScreen), findsOneWidget);
      expect(find.text('Choose a role'), findsOneWidget);
      expect(find.text('Lender'), findsOneWidget);
      expect(find.text('Borrower'), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(find.byType(BorrowerDashboardScreen), findsNothing);
    });

    testWidgets('goes straight to the lender dashboard when that role is saved',
        (tester) async {
      await roleService.saveRole(UserRole.lender);

      await pumpGate(tester);

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(RoleSelectionScreen), findsNothing);
    });

    testWidgets(
        'goes straight to the borrower dashboard when that role is saved',
        (tester) async {
      await roleService.saveRole(UserRole.borrower);

      await pumpGate(tester);

      expect(find.byType(BorrowerDashboardScreen), findsOneWidget);
      expect(find.byType(RoleSelectionScreen), findsNothing);
    });
  });

  group('Picking a role', () {
    testWidgets('choosing Lender persists the role and opens its dashboard',
        (tester) async {
      await pumpGate(tester);

      await tester.tap(find.text('Lender'));
      await tester.pumpAndSettle();

      expect(await roleService.getSavedRole(), UserRole.lender);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('choosing Borrower persists the role and opens its dashboard',
        (tester) async {
      await pumpGate(tester);

      await tester.tap(find.text('Borrower'));
      await tester.pumpAndSettle();

      expect(await roleService.getSavedRole(), UserRole.borrower);
      expect(find.byType(BorrowerDashboardScreen), findsOneWidget);
    });
  });
}
