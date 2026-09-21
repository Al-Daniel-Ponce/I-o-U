import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/services/auth_service.dart';

import '../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSettingsRepository mockRepo;
  late AuthService authService;

  setUp(() {
    mockRepo = MockSettingsRepository();
    authService = AuthService(mockRepo);
  });

  group('PIN management', () {
    test('isPinSet returns false initially', () async {
      expect(await authService.isPinSet(), false);
    });

    test('setupPin hashes and stores the PIN', () async {
      await authService.setupPin('1234');
      expect(await authService.isPinSet(), true);
    });

    test('authenticate succeeds with correct PIN', () async {
      await authService.setupPin('1234');
      expect(await authService.authenticate('1234'), true);
    });

    test('authenticate fails with wrong PIN', () async {
      await authService.setupPin('1234');
      expect(await authService.authenticate('0000'), false);
    });

    test('resetPin replaces the stored hash', () async {
      await authService.setupPin('1234');
      await authService.resetPin('5678');
      expect(await authService.authenticate('1234'), false);
      expect(await authService.authenticate('5678'), true);
    });
  });

  group('Security question', () {
    test('isSecurityQuestionSet returns false initially', () async {
      expect(await authService.isSecurityQuestionSet(), false);
    });

    test('save and verify answer', () async {
      // Need PIN set first because settings row must exist
      await authService.setupPin('1234');
      await authService.saveSecurityAnswer(
        questionId: 'pet',
        answer: '  Fluffy  ',
      );
      expect(await authService.isSecurityQuestionSet(), true);
      expect(await authService.verifySecurityAnswer('fluffy'), true);
      expect(await authService.verifySecurityAnswer('Fluffy'), true);
      expect(await authService.verifySecurityAnswer('wrong'), false);
    });
  });

  group('Wipe all data', () {
    test('wipeAllData clears everything', () async {
      await authService.setupPin('1234');
      await authService.saveSecurityAnswer(
        questionId: 'pet',
        answer: 'Fluffy',
      );
      await authService.wipeAllData();
      expect(await authService.isPinSet(), false);
      expect(await authService.isSecurityQuestionSet(), false);
    });
  });
}
