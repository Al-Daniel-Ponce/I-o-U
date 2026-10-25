import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/user_role.dart';

void main() {
  group('UserRole serialization', () {
    test('storageValue round-trips through fromStorage', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromStorage(role.storageValue), role);
      }
    });

    test('storageValue is stable and explicit', () {
      expect(UserRole.lender.storageValue, 'lender');
      expect(UserRole.borrower.storageValue, 'borrower');
    });

    test('fromStorage returns null for unknown values', () {
      expect(UserRole.fromStorage('admin'), isNull);
      expect(UserRole.fromStorage(''), isNull);
      expect(UserRole.fromStorage('LENDER'), isNull);
    });

    test('fromStorage returns null when value is absent', () {
      expect(UserRole.fromStorage(null), isNull);
    });
  });

  group('UserRole presentation', () {
    test('every role has a label and tagline', () {
      for (final role in UserRole.values) {
        expect(role.label, isNotEmpty);
        expect(role.tagline, isNotEmpty);
        expect(role.icon, isNotNull);
      }
    });

    test('roles have distinct labels', () {
      final labels = UserRole.values.map((r) => r.label).toSet();
      expect(labels.length, UserRole.values.length);
    });
  });
}
