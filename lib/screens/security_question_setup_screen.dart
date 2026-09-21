// ignore_for_file: deprecated_member_use, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/security_question.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import 'fingerprint_setup_screen.dart';

/// Shown once after first PIN setup.
/// The user picks a security question and types their answer.
///
/// OOP principle: Single Responsibility — only handles question/answer
/// collection; persistence delegated to [AuthService].
class SecurityQuestionSetupScreen extends StatefulWidget {
  const SecurityQuestionSetupScreen({super.key});

  @override
  State<SecurityQuestionSetupScreen> createState() =>
      _SecurityQuestionSetupScreenState();
}

class _SecurityQuestionSetupScreenState
    extends State<SecurityQuestionSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _answerController = TextEditingController();

  SecurityQuestion? _selectedQuestion;
  bool _isSaving = false;
  bool _obscureAnswer = true;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedQuestion == null) {
      _showError('Please select a security question.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    await ServiceLocator.instance.authService.saveSecurityAnswer(
      questionId: _selectedQuestion!.id,
      answer: _answerController.text,
    );
    setState(() => _isSaving = false);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const FingerprintSetupScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
      backgroundColor: AppTheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary   = isDark ? AppTheme.textPrimary   : AppTheme.lTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lTextSecondary;
    final textMuted     = isDark ? AppTheme.textMuted     : AppTheme.lTextMuted;
    final cardBg        = isDark ? AppTheme.cardBg        : AppTheme.lSurface;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.success.withOpacity(0.4),
                              width: 1.5),
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: AppTheme.success, size: 36),
                      ),
                      const SizedBox(height: 20),
                      Text('Set Up Recovery',
                          style: GoogleFonts.spaceGrotesk(
                              color: textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 8),
                      Text(
                        'Choose a security question so you can\nrecover access if you forget your PIN.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                            color: textSecondary, fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // ── Step indicator ──────────────────────────────────────────
                _StepBadge(label: 'Step 1 of 2 — Choose a question'),
                const SizedBox(height: 12),

                // ── Question picker ─────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedQuestion != null
                          ? AppTheme.primary.withOpacity(0.5)
                          : AppTheme.textMuted.withOpacity(0.25),
                      width: _selectedQuestion != null ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: SecurityQuestion.catalogue
                        .map((q) => _QuestionOption(
                              question: q,
                              isSelected: _selectedQuestion?.id == q.id,
                              textPrimary: textPrimary,
                              textMuted: textMuted,
                              onTap: () =>
                                  setState(() => _selectedQuestion = q),
                            ))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Answer field ────────────────────────────────────────────
                _StepBadge(label: 'Step 2 of 2 — Type your answer'),
                const SizedBox(height: 12),

                if (_selectedQuestion != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.help_outline_rounded,
                            color: AppTheme.primaryLight, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedQuestion!.question,
                            style: GoogleFonts.dmSans(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.textMuted.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app_rounded,
                            color: textMuted, size: 18),
                        const SizedBox(width: 10),
                        Text('Select a question above first',
                            style: GoogleFonts.dmSans(
                                color: textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _answerController,
                  enabled: _selectedQuestion != null,
                  obscureText: _obscureAnswer,
                  textCapitalization: TextCapitalization.none,
                  style: GoogleFonts.dmSans(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Your answer',
                    hintText: 'Enter your answer (case-insensitive)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppTheme.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureAnswer
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureAnswer = !_obscureAnswer),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Answer cannot be empty';
                    }
                    if (v.trim().length < 2) {
                      return 'Answer must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // Hint about case-insensitivity
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.textMuted, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Answers are not case-sensitive',
                      style: GoogleFonts.dmSans(
                          color: textMuted, fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Save button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isSaving || _selectedQuestion == null)
                        ? null
                        : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(_isSaving ? 'Saving…' : 'Save & Continue'),
                  ),
                ),

                const SizedBox(height: 16),

                // Skip (not recommended)
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => const FingerprintSetupScreen()),
                    ),
                    child: Text(
                      'Skip for now (not recommended)',
                      style: GoogleFonts.dmSans(
                          color: textMuted,
                          fontSize: 13,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────────

class _StepBadge extends StatelessWidget {
  final String label;
  const _StepBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: GoogleFonts.dmSans(
              color: AppTheme.primaryLight,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _QuestionOption extends StatelessWidget {
  final SecurityQuestion question;
  final bool isSelected;
  final Color textPrimary;
  final Color textMuted;
  final VoidCallback onTap;

  const _QuestionOption({
    required this.question,
    required this.isSelected,
    required this.textPrimary,
    required this.textMuted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                question.question,
                style: GoogleFonts.dmSans(
                  color: isSelected ? textPrimary : textMuted,
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}