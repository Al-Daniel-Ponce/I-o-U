// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'recovery_screen.dart';
import 'security_question_setup_screen.dart';

/// PIN entry / setup screen.
///
/// Setup flow : Create PIN → Confirm PIN → Security Question Setup.
/// Login flow : Enter PIN → Dashboard (with Forgot PIN? link).
class PinScreen extends StatefulWidget {
  final bool isSetup;
  const PinScreen({super.key, required this.isSetup});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _errorMessage = '';

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // ── Input ──────────────────────────────────────────────────────────────────

  void _onDigitPressed(String digit) {
    if (_pin.length >= 4) return;
    setState(() { _pin += digit; _errorMessage = ''; });
    if (_pin.length == 4) _handlePinComplete();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = '';
    });
  }

  Future<void> _handlePinComplete() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (widget.isSetup) {
      await _handleSetup();
    } else {
      await _handleLogin();
    }
  }

  // ── Setup flow ─────────────────────────────────────────────────────────────

  Future<void> _handleSetup() async {
    if (!_isConfirming) {
      setState(() { _confirmPin = _pin; _pin = ''; _isConfirming = true; });
    } else if (_pin == _confirmPin) {
      await ServiceLocator.instance.authService.setupPin(_pin);
      // After PIN saved → go to security question setup
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                const SecurityQuestionSetupScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } else {
      _shake('PINs do not match. Try again.');
      setState(() { _confirmPin = ''; _isConfirming = false; });
    }
  }

  // ── Login flow ─────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    final valid =
        await ServiceLocator.instance.authService.authenticate(_pin);
    if (valid) {
      _navigateToDashboard();
    } else {
      _shake('Incorrect PIN. Please try again.');
    }
  }

  void _shake(String message) {
    _shakeController.forward(from: 0);
    setState(() { _errorMessage = message; _pin = ''; });
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  // ── Labels ─────────────────────────────────────────────────────────────────

  String get _title => widget.isSetup
      ? (_isConfirming ? 'Confirm your PIN' : 'Create a 4-digit PIN')
      : 'Enter your PIN';

  String get _subtitle => widget.isSetup
      ? (_isConfirming
          ? 'Re-enter your PIN to confirm'
          : 'Secure your debt records')
      : 'Welcome back!';

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary   = isDark ? AppTheme.textPrimary   : AppTheme.lTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lTextSecondary;
    final textMuted     = isDark ? AppTheme.textMuted     : AppTheme.lTextMuted;
    final surfaceLight  = isDark ? AppTheme.surfaceLight  : AppTheme.lSurfaceLight;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBrandMark(textPrimary, textSecondary),
                const SizedBox(height: 40),

                Text(_title,
                    style: GoogleFonts.dmSans(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 28),

                _buildPinDots(),

                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage,
                      style: GoogleFonts.dmSans(
                          color: AppTheme.error, fontSize: 13),
                      textAlign: TextAlign.center),
                ],

                const SizedBox(height: 40),
                _buildNumpad(surfaceLight, textPrimary),

                // ── Forgot PIN? (login mode only) ───────────────────────
                if (!widget.isSetup) ...[
                  const SizedBox(height: 28),
                  _buildForgotPin(textMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildBrandMark(Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: AppTheme.primary.withOpacity(0.4), width: 1.5),
          ),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: AppTheme.primaryLight, size: 40),
        ),
        const SizedBox(height: 24),
        Text('I owe U',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            )),
        const SizedBox(height: 6),
        Text(_subtitle,
            style:
                GoogleFonts.dmSans(color: textSecondary, fontSize: 14)),
      ],
    );
  }

  Widget _buildPinDots() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (_, child) {
        final offset = _shakeAnimation.value *
            10 *
            (1 - _shakeAnimation.value) *
            (_shakeController.value < 0.5 ? 1 : -1);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final filled = i < _pin.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppTheme.primary : Colors.transparent,
              border: Border.all(
                color: filled ? AppTheme.primary : AppTheme.textMuted,
                width: 2,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNumpad(Color surfaceLight, Color textPrimary) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: rows.map((row) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((label) {
            if (label.isEmpty) return const SizedBox(width: 80, height: 64);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _NumpadButton(
                label: label,
                surfaceColor: surfaceLight,
                textColor: textPrimary,
                onTap: () =>
                    label == '⌫' ? _onBackspace() : _onDigitPressed(label),
              ),
            );
          }).toList(),
        ),
      )).toList(),
    );
  }

  Widget _buildForgotPin(Color textMuted) {
    return Column(
      children: [
        Container(
          height: 1,
          color: AppTheme.textMuted.withOpacity(0.15),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecoveryScreen()),
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.help_outline_rounded,
                    color: AppTheme.accent, size: 18),
                const SizedBox(width: 8),
                Text('Forgot PIN?',
                    style: GoogleFonts.dmSans(
                      color: AppTheme.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NumpadButton extends StatelessWidget {
  final String label;
  final Color surfaceColor;
  final Color textColor;
  final VoidCallback onTap;

  const _NumpadButton({
    required this.label,
    required this.surfaceColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 64,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.textMuted.withOpacity(0.2)),
        ),
        child: Center(
          child: label == '⌫'
              ? Icon(Icons.backspace_outlined,
                  color: textColor.withOpacity(0.6), size: 22)
              : Text(label,
                  style: GoogleFonts.spaceGrotesk(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  )),
        ),
      ),
    );
  }
}