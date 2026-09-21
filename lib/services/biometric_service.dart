import 'package:local_auth/local_auth.dart';

import 'logger.dart';

/// Encapsulates biometric (fingerprint) authentication logic.
///
/// Uses the `local_auth` plugin to check device support and trigger
/// the fingerprint prompt. Only fingerprint is supported — devices
/// with only Face ID will report biometrics as unavailable.
class BiometricService {
  final LocalAuthentication _localAuth;
  final Logger _logger;

  BiometricService({LocalAuthentication? localAuth, Logger? logger})
      : _localAuth = localAuth ?? LocalAuthentication(),
        _logger = logger ?? const Logger('BiometricService');

  /// Returns true if the device has a fingerprint sensor and the
  /// OS supports biometric auth.
  Future<bool> isFingerprintAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;

      final available = await _localAuth.getAvailableBiometrics();
      final hasFingerprint = available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong);
      _logger.info(
          'Fingerprint available: $hasFingerprint (all: $available)');
      return hasFingerprint;
    } catch (e, stack) {
      _logger.error('Failed to check biometric availability', e, stack);
      return false;
    }
  }

  /// Shows the fingerprint authentication prompt.
  ///
  /// Returns `true` if the user authenticated successfully.
  /// Returns `false` on failure, cancellation, or error.
  Future<bool> authenticate({
    String reason = 'Authenticate to access your debts',
  }) async {
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
          biometricOnly: true,
        ),
      );
      _logger.info('Biometric auth result: $didAuth');
      return didAuth;
    } catch (e, stack) {
      _logger.error('Biometric authentication failed', e, stack);
      return false;
    }
  }
}
