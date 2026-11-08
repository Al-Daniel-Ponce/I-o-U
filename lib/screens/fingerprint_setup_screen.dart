// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import 'after_auth_gate.dart';

/// One-time fingerprint setup screen shown after PIN + security question.
///
/// Checks if the device supports fingerprint. If yes, offers to enable it.
/// If no, shows a message and lets the user continue without it.
class FingerprintSetupScreen extends StatefulWidget {
  const FingerprintSetupScreen({super.key});

  @override
  State<FingerprintSetupScreen> createState() => _FingerprintSetupScreenState();
}

class _FingerprintSetupScreenState extends State<FingerprintSetupScreen> {
  bool _hasFingerprint = false;
  bool _isLoading = true;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final biometricService = ServiceLocator.instance.biometricService;
    final hasFingerprint = await biometricService.isFingerprintAvailable();
    if (mounted) {
      setState(() {
        _hasFingerprint = hasFingerprint;
        _isLoading = false;
      });
    }
  }

  Future<void> _enableBiometrics() async {
    setState(() => _isAuthenticating = true);

    final biometricService = ServiceLocator.instance.biometricService;
    final authenticated = await biometricService.authenticate(
      reason: 'Verify your fingerprint to enable biometric login',
    );

    if (authenticated && mounted) {
      await ServiceLocator.instance.authService.setBiometricsEnabled(true);
      _finishSetup();
    } else if (mounted) {
      setState(() => _isAuthenticating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Fingerprint verification failed. You can enable it later in Settings.',
          style: GoogleFonts.dmSans(color: Colors.white),
        ),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  /// End of first-run setup — hands off to the post-auth route, which asks
  /// for a role on first run and otherwise opens the saved role's dashboard.
  void _finishSetup() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AfterAuthGate(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lTextPrimary;
    final textSecondary =
        isDark ? AppTheme.textSecondary : AppTheme.lTextSecondary;
    final textMuted = isDark ? AppTheme.textMuted : AppTheme.lTextMuted;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ─────────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppTheme.accent.withValues(alpha: 0.4),
                                  width: 1.5),
                            ),
                            child: Icon(
                              _hasFingerprint
                                  ? Icons.fingerprint_rounded
                                  : Icons.phonelink_lock_rounded,
                              color: AppTheme.accent,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _hasFingerprint
                                ? 'Fingerprint Login'
                                : 'Biometrics Not Available',
                            style: GoogleFonts.spaceGrotesk(
                                color: textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hasFingerprint
                                ? 'Use your fingerprint to skip the\nPIN screen for faster access.'
                                : 'Your device doesn\'t have a fingerprint\nsensor. You can still use your PIN to log in.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                                color: textSecondary,
                                fontSize: 14,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    if (_hasFingerprint) ...[
                      // ── Enable button ────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isAuthenticating ? null : _enableBiometrics,
                          icon: _isAuthenticating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.fingerprint_rounded),
                          label: Text(
                            _isAuthenticating
                                ? 'Verifying...'
                                : 'Enable Fingerprint',
                            style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Info box ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: textMuted, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You can enable or disable this anytime in the Settings drawer.',
                                style: GoogleFonts.dmSans(
                                    color: textMuted, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // ── No fingerprint available — show device info ────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.textMuted.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: textMuted, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No fingerprint sensor detected. Register a fingerprint in your device settings, then restart the app to enable this feature.',
                                style: GoogleFonts.dmSans(
                                    color: textSecondary, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ── Skip / Continue button ──────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isAuthenticating ? null : _finishSetup,
                        child: Text(
                          _hasFingerprint ? 'Skip for now' : 'Continue',
                          style: GoogleFonts.dmSans(
                              color: textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
