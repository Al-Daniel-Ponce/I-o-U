import 'package:flutter_test/flutter_test.dart';
import 'package:iou_debt_tracker/models/debt.dart';
import 'package:iou_debt_tracker/services/auth_service.dart';
import 'package:iou_debt_tracker/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

class _FakeNotificationService extends NotificationService {
  int cancelAllCalls = 0;

  @override
  Future<void> cancelAllReminders() async => cancelAllCalls++;

  @override
  Future<void> scheduleDebtReminder(Debt debt) async {}

  @override
  Future<void> cancelDebtReminder(int debtId) async {}

  @override
  Future<void> rescheduleDebtReminder(Debt debt) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AuthService', () {
    test('PIN authenticates only for the right code', () async {
      final auth = AuthService(MockSettingsRepository());
      await auth.setupPin('1234');
      expect(await auth.authenticate('1234'), isTrue);
      expect(await auth.authenticate('9999'), isFalse);
    });

    test('failed attempts persist and are counted per flow', () async {
      final auth = AuthService(MockSettingsRepository());
      expect(await auth.recordFailedAttempt(recovery: false), 1);
      expect(await auth.recordFailedAttempt(recovery: false), 2);
      expect(await auth.recordFailedAttempt(recovery: true), 1);

      // A brand-new service instance reads the same persisted counters,
      // so restarting the app cannot reset the barrier.
      final fresh = AuthService(MockSettingsRepository());
      expect(await fresh.failedAttempts(recovery: false), 2);
      expect(await fresh.failedAttempts(recovery: true), 1);
    });

    test('successful verification resets the counter', () async {
      final auth = AuthService(MockSettingsRepository());
      await auth.recordFailedAttempt(recovery: true);
      await auth.resetFailedAttempts(recovery: true);
      expect(await auth.failedAttempts(recovery: true), 0);
    });

    test('lockout persists across instances and clears on null', () async {
      final auth = AuthService(MockSettingsRepository());
      expect(await auth.lockRemaining(recovery: true), isNull);

      await auth.lockUntil(
        recovery: true,
        until: DateTime.now().add(const Duration(seconds: 30)),
      );

      final remaining = await auth.lockRemaining(recovery: true);
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, lessThanOrEqualTo(30));

      final fresh = AuthService(MockSettingsRepository());
      expect(await fresh.lockRemaining(recovery: true), isNotNull);

      final pinLock = DateTime.now().add(const Duration(seconds: 45));
      await auth.lockUntil(recovery: false, until: pinLock);
      expect(await auth.lockRemaining(recovery: false), isNotNull);

      // The flows are independent.
      expect(await auth.lockRemaining(recovery: true), isNotNull);
      await auth.lockUntil(recovery: true, until: null);
      expect(await auth.lockRemaining(recovery: true), isNull);
      expect(await auth.lockRemaining(recovery: false), isNotNull);
    });

    test('expired locks report null', () async {
      final auth = AuthService(MockSettingsRepository());
      await auth.lockUntil(
        recovery: true,
        until: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(await auth.lockRemaining(recovery: true), isNull);
    });

    test('security answers trim and lowercase before matching', () async {
      final settings = MockSettingsRepository();
      final auth = AuthService(settings);
      await auth.saveSecurityAnswer(questionId: 'q1', answer: '  Fluffy  ');
      expect(await auth.verifySecurityAnswer('fluffy'), isTrue);
      expect(await auth.verifySecurityAnswer('FLUFFY'), isTrue);
      expect(await auth.verifySecurityAnswer('dog'), isFalse);
      expect(await auth.verifySecurityAnswer(''), isFalse);
    });

    test('wipe clears counters, locks, biometrics and cancels alarms',
        () async {
      final notifications = _FakeNotificationService();
      final auth = AuthService(MockSettingsRepository(),
          notificationService: notifications);
      await auth.recordFailedAttempt(recovery: true);
      await auth.lockUntil(
          recovery: false, until: DateTime.now().add(const Duration(hours: 1)));
      await auth.setBiometricsEnabled(true);

      await auth.wipeAllData();

      expect(notifications.cancelAllCalls, 1);
      expect(await auth.failedAttempts(recovery: true), 0);
      expect(await auth.lockRemaining(recovery: false), isNull);
      expect(await auth.isBiometricsEnabled(), isFalse);
    });
  });
}
