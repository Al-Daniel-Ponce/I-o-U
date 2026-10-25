import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/services/auth_service.dart';
import 'package:iou_debt_tracker/services/profile_service.dart';
import 'package:iou_debt_tracker/services/service_locator.dart';
import 'package:iou_debt_tracker/widgets/common/settings_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => ServiceLocator.configure());

  Future<void> pumpDrawer(WidgetTester tester, {String? name}) async {
    SharedPreferences.setMockInitialValues(
        name == null ? {} : {'profile_name': name});
    ServiceLocator.configure(
      authService: AuthService(MockSettingsRepository()),
      profileService: ProfileService(SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(drawer: SettingsDrawer()),
    ));
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
  }

  group('SettingsDrawer profile name', () {
    testWidgets('saving a new name persists it and tears the dialog down '
        'without controller errors', (tester) async {
      await pumpDrawer(tester, name: 'Marco');

      await tester.tap(find.text('Your Name'));
      await tester.pumpAndSettle();

      expect(find.text('Your name'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Angela Cruz');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Regression: the controller must outlive the dialog's exit
      // transition (disposing it right after showDialog returned threw
      // "A TextEditingController was used after being disposed").
      expect(tester.takeException(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_name'), 'Angela Cruz');
      expect(find.text('Angela Cruz'), findsWidgets);
    });

    testWidgets('cancel leaves the stored name untouched', (tester) async {
      await pumpDrawer(tester, name: 'Marco');

      await tester.tap(find.text('Your Name'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Discarded');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_name'), 'Marco');
    });
  });
}
