import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/security_question.dart';
import '../repositories/i_debt_repositories.dart';

/// Handles all authentication, PIN, and recovery logic.
///
/// OOP principle: Single Responsibility — auth concerns only.
///
/// PINs are hashed with SHA-256 before they reach the repository layer,
/// so plaintext PINs are never stored or transmitted.
class AuthService {
  final ISettingsRepository _settings;

  const AuthService(this._settings);

  static const _biometricsKey = 'biometrics_enabled';

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
    } catch (_) {
      // SharedPreferences may not be available in tests; non-critical.
    }
    return _settings.wipeAllData();
  }
}
