import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/security_question.dart';
import '../repositories/i_debt_repositories.dart';
import 'notification_service.dart';

/// Handles all authentication, PIN, and recovery logic.
///
/// OOP principle: Single Responsibility — auth concerns only.
///
/// PINs are hashed with SHA-256 before they reach the repository layer,
/// so plaintext PINs are never stored or transmitted.
///
/// Failed-authentication counters and lockout timers persist through
/// SharedPreferences (barrier-type security has no value if a restart
/// resets it), powering the recovery tiers (5→30 s, 10→60 s, 15→lock)
/// and a matching brake on PIN login brute-force.
class AuthService {
  final ISettingsRepository _settings;
  final NotificationService? _notifications;

  const AuthService(this._settings, {NotificationService? notificationService})
      : _notifications = notificationService;

  static const _biometricsKey = 'biometrics_enabled';

  // ── Attempt / lockout persistence keys ─────────────────────────────────────
  static const _pinAttemptsKey = 'pin_failed_attempts';
  static const _recoveryAttemptsKey = 'recovery_failed_attempts';
  static const _pinLockUntilKey = 'pin_lock_until';
  static const _recoveryLockUntilKey = 'recovery_lock_until';

  /// Total failed attempts at which the recovery flow becomes permanent.
  static const int permanentLockAttempts = 15;

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  // ── PIN ────────────────────────────────────────────────────────────────────

  Future<bool> isPinSet() => _settings.isPinSet();
  Future<void> setupPin(String pin) => _settings.setPin(_hashPin(pin));
  Future<bool> authenticate(String pin) => _settings.verifyPin(_hashPin(pin));

  // ── Security question ──────────────────────────────────────────────────────

  Future<bool> isSecurityQuestionSet() => _settings.isSecurityQuestionSet();

  Future<void> saveSecurityAnswer({
    required String questionId,
    required String answer,
  }) =>
      _settings.saveSecurityAnswer(SecurityAnswer(
        questionId: questionId,
        answer: answer.trim().toLowerCase(),
      ));

  Future<SecurityAnswer?> getSecurityAnswer() => _settings.getSecurityAnswer();

  Future<bool> verifySecurityAnswer(String input) async {
    final stored = await _settings.getSecurityAnswer();
    if (stored == null) return false;
    return stored.matches(input);
  }

  Future<void> resetPin(String newPin) => _settings.setPin(_hashPin(newPin));

  // ── Biometrics ─────────────────────────────────────────────────────────────

  Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricsKey) ?? false;
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricsKey, enabled);
  }

  // ── Nuclear option ─────────────────────────────────────────────────────────

  Future<void> wipeAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_biometricsKey);
      await prefs.remove(_pinAttemptsKey);
      await prefs.remove(_recoveryAttemptsKey);
      await prefs.remove(_pinLockUntilKey);
      await prefs.remove(_recoveryLockUntilKey);
    } catch (_) {
      // SharedPreferences may not be available in tests; non-critical.
    }
    // OS alarm queue still holds per-debt reminders; clearing it here keeps
    // wiped debts from firing ghost notifications once more.
    try {
      await _notifications?.cancelAllReminders();
    } catch (_) {
      // Failure to cancel alarms must not block the wipe itself.
    }
    return _settings.wipeAllData();
  }

  // ── Failed-attempt bookkeeping (persistent) ────────────────────────────────

  /// Current number of persisted failures for PIN login or recovery.
  Future<int> failedAttempts({required bool recovery}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(recovery ? _recoveryAttemptsKey : _pinAttemptsKey) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  /// Records one failed attempt and returns the new persisted total.
  Future<int> recordFailedAttempt({required bool recovery}) async {
    final count = await failedAttempts(recovery: recovery) + 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          recovery ? _recoveryAttemptsKey : _pinAttemptsKey, count);
    } catch (_) {
      // Storage hiccup: the in-session caller still receives the count.
    }
    return count;
  }

  /// Clears the persisted failures after a successful verification.
  Future<void> resetFailedAttempts({required bool recovery}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(
          recovery ? _recoveryAttemptsKey : _pinAttemptsKey);
    } catch (_) {
      // Non-critical.
    }
  }

  /// Marks the flow as locked until [until] (epoch millis, persisted).
  Future<void> lockUntil({required bool recovery, DateTime? until}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = recovery ? _recoveryLockUntilKey : _pinLockUntilKey;
      if (until == null) {
        await prefs.remove(key);
      } else {
        await prefs.setInt(key, until.millisecondsSinceEpoch);
      }
    } catch (_) {
      // Non-critical.
    }
  }

  /// Remaining lockout for the flow, or null when not locked.
  Future<Duration?> lockRemaining({required bool recovery}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(
          recovery ? _recoveryLockUntilKey : _pinLockUntilKey);
      if (millis == null) return null;
      final remaining = DateTime.fromMillisecondsSinceEpoch(millis)
          .difference(DateTime.now());
      return remaining.isNegative ? null : remaining;
    } catch (_) {
      return null;
    }
  }
}
