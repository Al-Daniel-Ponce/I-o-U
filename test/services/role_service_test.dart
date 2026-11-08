import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/user_role.dart';
import 'package:iou_debt_tracker/services/role_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const roleService = RoleService();

  setUp(() {
    // Reset the in-memory store before every test.
    SharedPreferences.setMockInitialValues({});
  });

  group('Reading the saved role', () {
    test('returns null when nothing has been chosen yet', () async {
      expect(await roleService.getSavedRole(), isNull);
    });

    test('returns null when storage holds an unrecognised value', () async {
      SharedPreferences.setMockInitialValues({'selected_role': 'admin'});
      expect(await roleService.getSavedRole(), isNull);
    });
  });

  group('Saving the role', () {
    test('saveRole then getSavedRole returns the lender role', () async {
      await roleService.saveRole(UserRole.lender);
      expect(await roleService.getSavedRole(), UserRole.lender);
    });

    test('saveRole then getSavedRole returns the borrower role', () async {
      await roleService.saveRole(UserRole.borrower);
      expect(await roleService.getSavedRole(), UserRole.borrower);
    });

    test('saveRole overwrites the previous choice', () async {
      await roleService.saveRole(UserRole.lender);
      await roleService.saveRole(UserRole.borrower);
      expect(await roleService.getSavedRole(), UserRole.borrower);
    });
  });

  group('Clearing the role', () {
    test('clearRole forgets a saved choice', () async {
      await roleService.saveRole(UserRole.borrower);
      await roleService.clearRole();
      expect(await roleService.getSavedRole(), isNull);
    });

    test('clearRole is safe when nothing is saved', () async {
      await roleService.clearRole();
      expect(await roleService.getSavedRole(), isNull);
    });
  });
}
