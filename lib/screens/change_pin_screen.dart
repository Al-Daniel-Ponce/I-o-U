// ignore_for_file: deprecated_member_use, prefer_const_declarations

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/service_locator.dart';
import '../theme/app_theme.dart';

/// Allows the user to change their existing PIN.
///
/// Flow: verify current PIN → enter new PIN → confirm new PIN → save.
///
/// OOP principle: Single Responsibility — only PIN-change logic lives here;
/// authentication is delegated to [AuthService].
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

enum _ChangePinStep { verifyOld, enterNew, confirmNew }

class _ChangePinScreenState extends State<ChangePinScreen>
    with SingleTickerProviderStateMixin {
  _ChangePinStep _step = _ChangePinStep.verifyOld;
  String _pin = '';
  String _newPin = '';
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

  // ── Labels per step ────────────────────────────────────────────────────────

  String get _title {
    switch (_step) {
      case _ChangePinStep.verifyOld: return 'Enter Current PIN';
      case _ChangePinStep.enterNew:  return 'Enter New PIN';
      case _ChangePinStep.confirmNew: return 'Confirm New PIN';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _ChangePinStep.verifyOld:  return 'Verify your identity first';
      case _ChangePinStep.enterNew:   return 'Choose a new 4-digit PIN';
      case _ChangePinStep.confirmNew: return 'Re-enter your new PIN';
    }
  }

  // ── Input handling ─────────────────────────────────────────────────────────

  void _onDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _errorMessage = '';
    });
    if (_pin.length == 4) _handleComplete();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _handleComplete() async {
    await Future.delayed(const Duration(milliseconds: 150));

    switch (_step) {
      case _ChangePinStep.verifyOld:
        final valid = await ServiceLocator.instance.authService.authenticate(_pin);
        if (valid) {
          setState(() { _step = _ChangePinStep.enterNew; _pin = ''; });
        } else {
          _shake('Incorrect PIN. Try again.');
        }
        break;

      case _ChangePinStep.enterNew:
        setState(() { _newPin = _pin; _step = _ChangePinStep.confirmNew; _pin = ''; });
        break;

      case _ChangePinStep.confirmNew:
        if (_pin == _newPin) {
          await ServiceLocator.instance.authService.setupPin(_pin);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PIN changed successfully!',
                    style: GoogleFonts.dmSans(color: Colors.white)),
                backgroundColor: AppTheme.paidColor,
              ),
            );
          }
        } else {
          _shake('PINs do not match. Try again.');
          setState(() { _step = _ChangePinStep.enterNew; _newPin = ''; });
        }
        break;
    }
  }

  void _shake(String message) {
    _shakeController.forward(from: 0);
    setState(() { _errorMessage = message; _pin = ''; });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary   = isDark ? AppTheme.textPrimary   : AppTheme.lTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lTextSecondary;
    final surfaceLight  = isDark ? AppTheme.surfaceLight   : AppTheme.lSurfaceLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change PIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Step indicator
                _StepIndicator(step: _step),
                const SizedBox(height: 32),

                // Lock icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: AppTheme.primaryLight, size: 36),
                ),
                const SizedBox(height: 24),

                Text(_title,
                    style: GoogleFonts.spaceGrotesk(
                        color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(_subtitle,
                    style: GoogleFonts.dmSans(color: textSecondary, fontSize: 14)),
                const SizedBox(height: 36),

                // PIN dots
                _PinDots(pinLength: _pin.length, shakeAnimation: _shakeAnimation,
                    shakeController: _shakeController),

                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage,
                      style: GoogleFonts.dmSans(color: AppTheme.error, fontSize: 13),
                      textAlign: TextAlign.center),
                ],

                const SizedBox(height: 40),
                _buildNumpad(surfaceLight, textPrimary),
              ],
            ),
          ),
        ),
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
              child: _NumpadKey(
                label: label,
                surfaceColor: surfaceLight,
                textColor: textPrimary,
                onTap: () => label == '⌫' ? _onBackspace() : _onDigit(label),
              ),
            );
          }).toList(),
        ),
      )).toList(),
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final _ChangePinStep step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = _ChangePinStep.values;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: steps.map((s) {
        final active = s.index <= step.index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : AppTheme.textMuted.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }).toList(),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int pinLength;
  final Animation<double> shakeAnimation;
  final AnimationController shakeController;

  const _PinDots({
    required this.pinLength,
    required this.shakeAnimation,
    required this.shakeController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shakeAnimation,
      builder: (_, child) {
        final offset = shakeAnimation.value * 10 *
            (1 - shakeAnimation.value) *
            (shakeController.value < 0.5 ? 1 : -1);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final filled = i < pinLength;
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
}

class _NumpadKey extends StatelessWidget {
  final String label;
  final Color surfaceColor;
  final Color textColor;
  final VoidCallback onTap;

  const _NumpadKey({
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
              ? Icon(Icons.backspace_outlined, color: textColor.withOpacity(0.6), size: 22)
              : Text(label,
                  style: GoogleFonts.spaceGrotesk(
                      color: textColor, fontSize: 24, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}