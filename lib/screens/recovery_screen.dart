// ignore_for_file: deprecated_member_use, prefer_const_constructors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/service_locator.dart';
import '../../theme/app_theme.dart';
import '../../screens/pin_screen.dart';

/// Offline recovery screen — lets the user reset their PIN by answering
/// their pre-set security question.
///
/// OOP principle: Single Responsibility — only recovery flow lives here;
/// verification and PIN reset delegated to [AuthService].
///
/// Lockout tiers:
///   •  5 wrong answers → 30-second countdown lockout
///   • 10 wrong answers → 60-second countdown lockout
///   • 15 wrong answers → permanent lock + "NUKE" button that wipes all data
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

enum _RecoveryStep { answer, newPin, confirmPin }

/// Describes the current lockout state of the answer field.
enum _LockState { open, countdown, permanent }

class _RecoveryScreenState extends State<RecoveryScreen>
    with TickerProviderStateMixin {
  _RecoveryStep _step = _RecoveryStep.answer;

  final _answerController = TextEditingController();
  bool _obscureAnswer = true;
  bool _isVerifying = false;
  String _answerError = '';

  // ── Attempt tracking ───────────────────────────────────────────────────────
  int _failedAttempts = 0;

  // ── Lockout state ──────────────────────────────────────────────────────────
  _LockState _lockState = _LockState.open;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;

  // New PIN entry
  String _pin = '';
  String _confirmPin = '';
  String _pinError = '';

  // Shake animation for wrong answer
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  // Nuke button pulse animation
  late final AnimationController _pulseCtrl;

  String? _questionText;

  // ── Lockout thresholds ─────────────────────────────────────────────────────
  static const int _tier1Attempts  = 5;   // → 30 s lockout
  static const int _tier2Attempts  = 10;  // → 60 s lockout
  static const int _tier3Attempts  = 15;  // → permanent lock + nuke

  static const int _tier1Seconds   = 30;
  static const int _tier2Seconds   = 60;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _loadQuestion();
  }

  Future<void> _loadQuestion() async {
    final authService = ServiceLocator.instance.authService;
    final answer = await authService.getSecurityAnswer();
    // Restore the persisted attempt count and any active lockout so the
    // 30s/60s/permanent tiers survive app restarts.
    final attempts = await authService.failedAttempts(recovery: true);
    final remaining = await authService.lockRemaining(recovery: true);
    if (!mounted) return;
    setState(() {
      _questionText = answer?.question?.question ?? 'Security question not set.';
      _failedAttempts = attempts;
      if (attempts >= _tier3Attempts) {
        _lockState = _LockState.permanent;
      } else if (remaining != null) {
        _startCountdown(remaining.inSeconds < 1 ? 1 : remaining.inSeconds,
            persist: false);
      }
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    _countdownTimer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  // ── Lockout helpers ────────────────────────────────────────────────────────

  /// Called after every failed attempt. Persists the counter, determines
  /// whether a lockout tier should activate, and starts the countdown.
  Future<void> _handleFailedAttempt() async {
    final authService = ServiceLocator.instance.authService;
    _failedAttempts =
        await authService.recordFailedAttempt(recovery: true);
    if (!mounted) return;

    if (_failedAttempts >= _tier3Attempts) {
      // Permanent lock — show nuke button.
      _countdownTimer?.cancel();
      setState(() {
        _lockState = _LockState.permanent;
        _answerError = 'Account locked. Too many failed attempts.';
      });
      return;
    }

    if (_failedAttempts == _tier2Attempts) {
      _startCountdown(_tier2Seconds);
      return;
    }

    if (_failedAttempts == _tier1Attempts) {
      _startCountdown(_tier1Seconds);
      return;
    }

    // Normal failure — just show the error.
    setState(() => _answerError = 'Incorrect answer. Please try again.');
    _shakeCtrl.forward(from: 0);
  }

  void _startCountdown(int seconds, {bool persist = true}) {
    if (persist) {
      ServiceLocator.instance.authService
          .lockUntil(
              recovery: true,
              until: DateTime.now().add(Duration(seconds: seconds)));
    }
    _countdownTimer?.cancel();
    setState(() {
      _lockState = _LockState.countdown;
      _secondsRemaining = seconds;
      _answerError = '';
    });

    _shakeCtrl.forward(from: 0);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          timer.cancel();
          _lockState = _LockState.open;
          _answerError = '';
          ServiceLocator.instance.authService
              .lockUntil(recovery: true, until: null);
        }
      });
    });
  }

  bool get _isLocked => _lockState != _LockState.open;

  // ── Nuke action ────────────────────────────────────────────────────────────

  Future<void> _confirmAndWipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.error, size: 26),
            const SizedBox(width: 10),
            Text('Wipe All Data?',
                style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'This will permanently delete all your debts, settings, and credentials. '
          'This action cannot be undone.',
          style: GoogleFonts.dmSans(
              color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Wipe Everything',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ServiceLocator.instance.authService.wipeAllData();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const PinScreen(isSetup: true),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    }
  }

  // ── Step 1: verify answer ──────────────────────────────────────────────────

  Future<void> _verifyAnswer() async {
    if (_isLocked) return;
    if (_answerController.text.trim().isEmpty) {
      setState(() => _answerError = 'Please enter your answer.');
      return;
    }
    setState(() { _isVerifying = true; _answerError = ''; });
    final ok = await ServiceLocator.instance.authService
        .verifySecurityAnswer(_answerController.text);
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (ok) {
      // Correct answer: clear the persisted attempt count and lock state.
      final authService = ServiceLocator.instance.authService;
      await authService.resetFailedAttempts(recovery: true);
      await authService.lockUntil(recovery: true, until: null);
      if (!mounted) return;
      setState(() => _step = _RecoveryStep.newPin);
    } else {
      await _handleFailedAttempt();
    }
  }

  // ── Step 2 & 3: new PIN entry ──────────────────────────────────────────────

  void _onDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() { _pin += digit; _pinError = ''; });
    if (_pin.length == 4) _handlePinStep();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _handlePinStep() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (_step == _RecoveryStep.newPin) {
      setState(() {
        _confirmPin = _pin;
        _pin = '';
        _step = _RecoveryStep.confirmPin;
      });
    } else {
      if (_pin == _confirmPin) {
        await ServiceLocator.instance.authService.resetPin(_pin);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const PinScreen(isSetup: false),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('PIN reset successfully! Please log in.',
                style: GoogleFonts.dmSans(color: Colors.white)),
            backgroundColor: AppTheme.paidColor,
          ));
        }
      } else {
        _shakeCtrl.forward(from: 0);
        setState(() {
          _pinError = 'PINs do not match. Try again.';
          _pin = '';
          _confirmPin = '';
          _step = _RecoveryStep.newPin;
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary   = isDark ? AppTheme.textPrimary   : AppTheme.lTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lTextSecondary;
    final textMuted     = isDark ? AppTheme.textMuted     : AppTheme.lTextMuted;
    final surfaceLight  = isDark ? AppTheme.surfaceLight  : AppTheme.lSurfaceLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Recovery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _step == _RecoveryStep.answer
            ? _buildAnswerStep(textPrimary, textSecondary, textMuted)
            : _buildNewPinStep(textPrimary, textSecondary, textMuted, surfaceLight),
      ),
    );
  }

  // ── Answer step ────────────────────────────────────────────────────────────

  Widget _buildAnswerStep(
      Color textPrimary, Color textSecondary, Color textMuted) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _lockState == _LockState.permanent
                        ? AppTheme.error.withOpacity(0.12)
                        : AppTheme.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _lockState == _LockState.permanent
                            ? AppTheme.error.withOpacity(0.4)
                            : AppTheme.accent.withOpacity(0.4),
                        width: 1.5),
                  ),
                  child: Icon(
                    _lockState == _LockState.permanent
                        ? Icons.lock_rounded
                        : Icons.help_center_rounded,
                    color: _lockState == _LockState.permanent
                        ? AppTheme.error
                        : AppTheme.accent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text('Forgot your PIN?',
                    style: GoogleFonts.spaceGrotesk(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Answer your security question\nto reset your PIN.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      color: textSecondary, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Question display
          if (_questionText != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Security Question',
                      style: GoogleFonts.dmSans(
                          color: AppTheme.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Text(_questionText!,
                      style: GoogleFonts.dmSans(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Countdown banner (tier 1 / tier 2) ────────────────────────────
          if (_lockState == _LockState.countdown) ...[
            _buildCountdownBanner(),
            const SizedBox(height: 16),
          ],

          // Answer field with shake
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) {
              final offset = _shakeAnim.value *
                  8 *
                  (1 - _shakeAnim.value) *
                  (_shakeCtrl.value < 0.5 ? 1 : -1);
              return Transform.translate(
                  offset: Offset(offset, 0), child: child);
            },
            child: TextField(
              controller: _answerController,
              obscureText: _obscureAnswer,
              enabled: !_isLocked, // disabled during lockout & permanent lock
              textCapitalization: TextCapitalization.none,
              style: GoogleFonts.dmSans(color: textPrimary),
              onSubmitted: (_) => _verifyAnswer(),
              decoration: InputDecoration(
                labelText: 'Your answer',
                hintText: _lockState == _LockState.countdown
                    ? 'Locked — wait for countdown…'
                    : _lockState == _LockState.permanent
                        ? 'Permanently locked'
                        : 'Type your answer here…',
                errorText: _answerError.isNotEmpty ? _answerError : null,
                prefixIcon: Icon(
                  _isLocked
                      ? Icons.lock_outline_rounded
                      : Icons.shield_outlined,
                  color: _isLocked ? AppTheme.error : AppTheme.textMuted,
                ),
                suffixIcon: _lockState != _LockState.permanent
                    ? IconButton(
                        icon: Icon(
                          _obscureAnswer
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureAnswer = !_obscureAnswer),
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 8),
          if (_lockState == _LockState.open)
            Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppTheme.textMuted, size: 13),
              const SizedBox(width: 6),
              Text('Not case-sensitive',
                  style: GoogleFonts.dmSans(color: textMuted, fontSize: 12)),
            ]),

          // ── Attempts remaining hint ────────────────────────────────────────
          if (_failedAttempts > 0 && _lockState == _LockState.open) ...[
            const SizedBox(height: 6),
            _buildAttemptsHint(textMuted),
          ],

          const SizedBox(height: 28),

          // ── Primary action button ──────────────────────────────────────────
          if (_lockState != _LockState.permanent)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isVerifying || _isLocked) ? null : _verifyAnswer,
                icon: _isVerifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(_isVerifying
                    ? 'Verifying…'
                    : _lockState == _LockState.countdown
                        ? 'Locked ($_secondsRemaining s)'
                        : 'Verify Answer'),
              ),
            ),

          // ── NUKE button (permanent lock only) ─────────────────────────────
          if (_lockState == _LockState.permanent) ...[
            _buildPermanentLockBanner(),
            const SizedBox(height: 20),
            _buildNukeButton(),
          ],
        ],
      ),
    );
  }

  // ── Countdown banner ───────────────────────────────────────────────────────

  Widget _buildCountdownBanner() {
    final isLong = _secondsRemaining > 30;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withOpacity(0.40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppTheme.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLong ? 'Too many attempts' : 'Slow down!',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Try again in $_secondsRemaining second${_secondsRemaining == 1 ? '' : 's'}.',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.warning.withOpacity(0.85), fontSize: 12),
                ),
              ],
            ),
          ),
          // Circular countdown ring
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _secondsRemaining /
                      (_failedAttempts >= _tier2Attempts
                          ? _tier2Seconds
                          : _tier1Seconds),
                  color: AppTheme.warning,
                  backgroundColor: AppTheme.warning.withOpacity(0.2),
                  strokeWidth: 3,
                ),
                Text(
                  '$_secondsRemaining',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Permanent lock banner ──────────────────────────────────────────────────

  Widget _buildPermanentLockBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.error.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dangerous_rounded,
                  color: AppTheme.error, size: 20),
              const SizedBox(width: 8),
              Text('Account Permanently Locked',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You have exceeded the maximum number of recovery attempts. '
            'Your only option is to wipe all app data and start fresh.',
            style: GoogleFonts.dmSans(
                color: AppTheme.error.withOpacity(0.8),
                fontSize: 12,
                height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Nuke button ────────────────────────────────────────────────────────────

  Widget _buildNukeButton() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, child) {
        final glow = _pulseCtrl.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.error.withOpacity(0.25 + glow * 0.25),
                blurRadius: 12 + glow * 12,
                spreadRadius: glow * 4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _confirmAndWipe,
          icon: const Icon(Icons.whatshot_rounded, size: 22),
          label: Text(
            'WIPE ALL DATA',
            style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.2),
          ),
        ),
      ),
    );
  }

  // ── Attempts hint ──────────────────────────────────────────────────────────

  Widget _buildAttemptsHint(Color textMuted) {
    // Show how many attempts until next lockout tier.
    int attemptsUntilNext;
    String nextConsequence;

    if (_failedAttempts < _tier1Attempts) {
      attemptsUntilNext = _tier1Attempts - _failedAttempts;
      nextConsequence = '${_tier1Seconds}s lockout';
    } else if (_failedAttempts < _tier2Attempts) {
      attemptsUntilNext = _tier2Attempts - _failedAttempts;
      nextConsequence = '${_tier2Seconds}s lockout';
    } else {
      attemptsUntilNext = _tier3Attempts - _failedAttempts;
      nextConsequence = 'permanent lock';
    }

    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 13),
        const SizedBox(width: 6),
        Text(
          '$attemptsUntilNext more wrong attempt${attemptsUntilNext == 1 ? '' : 's'} → $nextConsequence',
          style: GoogleFonts.dmSans(color: AppTheme.warning, fontSize: 12),
        ),
      ],
    );
  }

  // ── New PIN step ───────────────────────────────────────────────────────────

  Widget _buildNewPinStep(Color textPrimary, Color textSecondary,
      Color textMuted, Color surfaceLight) {
    final isConfirming = _step == _RecoveryStep.confirmPin;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.paidColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AppTheme.paidColor.withOpacity(0.4), width: 1.5),
              ),
              child: const Icon(Icons.lock_open_rounded,
                  color: AppTheme.paidColor, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              isConfirming ? 'Confirm New PIN' : 'Set New PIN',
              style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              isConfirming
                  ? 'Re-enter your new PIN'
                  : 'Choose a new 4-digit PIN',
              style: GoogleFonts.dmSans(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 36),

            // PIN dots with shake
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) {
                final offset = _shakeAnim.value *
                    10 *
                    (1 - _shakeAnim.value) *
                    (_shakeCtrl.value < 0.5 ? 1 : -1);
                return Transform.translate(
                    offset: Offset(offset, 0), child: child);
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
            ),

            if (_pinError.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_pinError,
                  style: GoogleFonts.dmSans(
                      color: AppTheme.error, fontSize: 13)),
            ],

            const SizedBox(height: 40),
            _buildNumpad(surfaceLight, textPrimary),
          ],
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
            if (label.isEmpty) return const SizedBox(width: 72, height: 64);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onTap: () => label == '⌫' ? _onBackspace() : _onDigit(label),
                child: Container(
                  width: 72,
                  height: 64,
                  decoration: BoxDecoration(
                    color: surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.textMuted.withOpacity(0.2)),
                  ),
                  child: Center(
                    child: label == '⌫'
                        ? Icon(Icons.backspace_outlined,
                            color: textPrimary.withOpacity(0.6), size: 22)
                        : Text(label,
                            style: GoogleFonts.spaceGrotesk(
                                color: textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      )).toList(),
    );
  }
}