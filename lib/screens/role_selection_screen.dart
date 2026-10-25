// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_role.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import 'borrower_dashboard_screen.dart';
import 'dashboard_screen.dart';

/// "Choose a role" — shown once the user has unlocked the app and no role
/// has been remembered yet (first run, after a wipe, or via Switch Role).
///
/// Picking a card persists the choice and lands the user on that role's
/// dashboard; subsequent unlocks skip this screen until the role is switched.
///
/// OOP principles:
/// - Single Responsibility : only presents the two roles and reports the
///   choice — persistence lives in RoleService, routing in the screens.
/// - Open/Closed : adding a third role means one enum value and one card;
///   the card builder maps over [UserRole.values] untouched.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  /// Role already on record, if any — highlighted so a user arriving via
  /// "Switch Role" can see their current mode at a glance.
  UserRole? _currentRole;

  /// Guards against a double-tap pushing two dashboards.
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentRole();
  }

  Future<void> _loadCurrentRole() async {
    final role = await ServiceLocator.instance.roleService.getSavedRole();
    if (mounted) setState(() => _currentRole = role);
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  Future<void> _select(UserRole role) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    // Fire-and-forget — a haptic must never gate the save or the
    // navigation that follows it.
    HapticFeedback.mediumImpact();

    await ServiceLocator.instance.roleService.saveRole(role);

    if (!mounted) return;

    final destination = role == UserRole.lender
        ? const DashboardScreen()
        : const BorrowerDashboardScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lTextPrimary;
    final textSecondary =
        isDark ? AppTheme.textSecondary : AppTheme.lTextSecondary;
    final textMuted = isDark ? AppTheme.textMuted : AppTheme.lTextMuted;
    final bg = isDark ? AppTheme.background : AppTheme.lBackground;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBrandMark(),
                const SizedBox(height: 24),
                Text(
                  'Choose a role',
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'How will you use I owe U today?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(color: textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 36),
                for (final role in UserRole.values) ...[
                  _RoleCard(
                    role: role,
                    isCurrent: _currentRole == role,
                    isEnabled: !_isNavigating,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    textMuted: textMuted,
                    onTap: () => _select(role),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
                _buildFooterNote(textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildBrandMark() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1.5),
      ),
      child: const Icon(Icons.account_balance_wallet_rounded,
          color: AppTheme.primaryLight, size: 38),
    );
  }

  Widget _buildFooterNote(Color textMuted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.swap_horiz_rounded, color: textMuted, size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'You can switch roles anytime in Settings.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ── Role card ─────────────────────────────────────────────────────────────────

/// One large tappable card per [UserRole].
class _RoleCard extends StatelessWidget {
  final UserRole role;
  final bool isCurrent;
  final bool isEnabled;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.isCurrent,
    required this.isEnabled,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.onTap,
  });

  /// Lender stays on the app's teal; borrower takes the amber accent so the
  /// two modes stay visually distinct on every screen that shows them.
  bool get _isBorrower => role == UserRole.borrower;
  Color get _accent => _isBorrower ? AppTheme.accent : AppTheme.primaryLight;

  @override
  Widget build(BuildContext context) {
    // The InkWell below owns the semantics: it merges the card's visible
    // text into the accessible name and supplies the tap action, so an
    // extra wrapper here would only produce a second, actionless node.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isCurrent
            ? _accent.withOpacity(0.08)
            : (Theme.of(context).brightness == Brightness.dark
                ? AppTheme.cardBg
                : AppTheme.lSurface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? _accent : textMuted.withOpacity(0.2),
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: _accent.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            child: Opacity(
              opacity: isEnabled ? 1 : 0.5,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    // ── Icon badge ────────────────────────────────────
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(role.icon, color: _accent, size: 26),
                    ),
                    const SizedBox(width: 16),
                    // ── Copy ──────────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role.label,
                            style: GoogleFonts.dmSans(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role.tagline,
                            style: GoogleFonts.dmSans(
                                color: textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // ── Current chip / chevron ────────────────────────
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Current',
                          style: GoogleFonts.dmSans(
                            color: _accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: textMuted, size: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
