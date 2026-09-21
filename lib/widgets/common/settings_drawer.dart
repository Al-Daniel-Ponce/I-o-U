// ignore_for_file: deprecated_member_use, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/theme_controller.dart';
import '../../screens/change_pin_screen.dart';
import '../../screens/pin_screen.dart';
import '../../services/service_locator.dart';
import '../../theme/app_theme.dart';

/// Side drawer containing app settings: theme toggle, PIN change,
/// and a hidden developer option (go to lock screen).
///
/// OOP principles:
/// - Single Responsibility : only renders settings; logic is in controllers.
/// - Encapsulation : dev-mode tap counter is private state, invisible to callers.
/// - Open/Closed : new settings rows added via _SettingsTile without touching
///   existing tiles.
class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({super.key});

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer>
    with SingleTickerProviderStateMixin {

  // ── Developer mode state ───────────────────────────────────────────────────
  static const int _tapsRequired = 5;
  int _tapCount = 0;
  bool _devModeUnlocked = false;

  // ── Biometrics state ───────────────────────────────────────────────────────
  bool _biometricsEnabled = false;
  bool _hasFingerprint = false;
  bool _biometricsLoading = true;

  // Countdown toast animation
  late final AnimationController _toastCtrl;
  late final Animation<double> _toastFade;

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChange);
    _loadBiometricsState();

    _toastCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _toastFade = CurvedAnimation(parent: _toastCtrl, curve: Curves.easeOut);
  }

  Future<void> _loadBiometricsState() async {
    final authService = ServiceLocator.instance.authService;
    final biometricService = ServiceLocator.instance.biometricService;

    final enabled = await authService.isBiometricsEnabled();
    final hasFingerprint = await biometricService.isFingerprintAvailable();

    if (mounted) {
      setState(() {
        _biometricsEnabled = enabled;
        _hasFingerprint = hasFingerprint;
        _biometricsLoading = false;
      });
    }
  }

  void _onThemeChange() => setState(() {});

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChange);
    _toastCtrl.dispose();
    super.dispose();
  }

  // ── Developer tap handler ──────────────────────────────────────────────────

  void _onHeaderTap() {
    if (_devModeUnlocked) return; // already unlocked, ignore extra taps

    setState(() => _tapCount++);

    final remaining = _tapsRequired - _tapCount;

    if (_tapCount >= _tapsRequired) {
      // Unlock dev mode
      HapticFeedback.heavyImpact();
      setState(() => _devModeUnlocked = true);
      _toastCtrl.forward(from: 0);
    } else if (remaining <= 3) {
      // Show countdown after 2 taps
      HapticFeedback.lightImpact();
      _toastCtrl.forward(from: 0).then((_) async {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) _toastCtrl.reverse();
      });
    }
  }

  // ── Lock screen navigation ─────────────────────────────────────────────────

  void _goToLockScreen() {
    Navigator.pop(context); // close drawer
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PinScreen(isSetup: false),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false, // clear entire stack → fresh lock screen
    );
  }

  // ── Biometrics toggle ─────────────────────────────────────────────────────

  Future<void> _onBiometricsToggle(bool value) async {
    final authService = ServiceLocator.instance.authService;

    if (value) {
      // Verify fingerprint works before enabling
      final biometricService = ServiceLocator.instance.biometricService;
      final authenticated = await biometricService.authenticate(
        reason: 'Verify your fingerprint to enable biometric login',
      );
      if (!authenticated) return; // user cancelled or failed
    }

    await authService.setBiometricsEnabled(value);
    setState(() => _biometricsEnabled = value);
  }

  // ── Wipe all data ──────────────────────────────────────────────────────────

  Future<void> _wipeAllData() async {
    // Capture the navigator BEFORE any async gap.
    // After Navigator.pop the drawer widget is disposed and `mounted` becomes
    // false, so we must not rely on `context` or `mounted` after that point.
    final nav = Navigator.of(context);

    // Step 1: show confirmation WHILE the drawer is still in the tree so
    // `context` is valid. Do NOT pop the drawer yet.
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _WipeConfirmDialog(),
    );

    if (confirmed != true) return;

    // Step 2: wipe every table and reset the DB connection.
    await ServiceLocator.instance.authService.wipeAllData();

    // Step 3: use the captured navigator to clear the entire stack and push
    // the fresh PIN setup screen.  This also implicitly closes the drawer
    // because it removes all routes beneath it.
    nav.pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PinScreen(isSetup: true),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark      = ThemeController.instance.isDark;
    final bg          = isDark ? AppTheme.surface      : AppTheme.lSurface;
    final cardBg      = isDark ? AppTheme.surfaceLight  : AppTheme.lSurfaceLight;
    final textPrimary = isDark ? AppTheme.textPrimary   : AppTheme.lTextPrimary;
    final textMuted   = isDark ? AppTheme.textMuted     : AppTheme.lTextMuted;

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header (tap 5× to unlock dev mode) ───────────────────────
            _buildDrawerHeader(),

            // ── Countdown / unlocked toast ────────────────────────────────
            _buildDevToast(textMuted),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'SETTINGS',
                style: GoogleFonts.dmSans(
                  color: textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Theme toggle ──────────────────────────────────────────────
            _ThemeToggleTile(
              isDark: isDark,
              cardBg: cardBg,
              textPrimary: textPrimary,
              textMuted: textMuted,
              onToggle: (_) => ThemeController.instance.toggle(),
            ),

            const SizedBox(height: 6),

            // ── Fingerprint toggle ──────────────────────────────────────
            if (!_biometricsLoading)
              _BiometricToggleTile(
                isEnabled: _biometricsEnabled,
                isAvailable: _hasFingerprint,
                cardBg: cardBg,
                textPrimary: textPrimary,
                textMuted: textMuted,
                onToggle: _onBiometricsToggle,
              ),

            const SizedBox(height: 6),

            // ── Change PIN ────────────────────────────────────────────────
            _SettingsTile(
              icon: Icons.lock_reset_rounded,
              iconColor: AppTheme.accent,
              label: 'Change PIN',
              subtitle: 'Update your security code',
              cardBg: cardBg,
              textPrimary: textPrimary,
              textMuted: textMuted,
              trailing: Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: textMuted),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChangePinScreen()));
              },
            ),

            const SizedBox(height: 6),

            // ── Developer: Go to Lock Screen (hidden until 5 taps) ────────
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              child: _devModeUnlocked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'DEV',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: AppTheme.error,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Developer Options',
                                style: GoogleFonts.dmSans(
                                  color: textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.lock_outline_rounded,
                          iconColor: AppTheme.error,
                          label: 'Go to Lock Screen',
                          subtitle: 'Return to PIN entry without closing app',
                          cardBg: cardBg,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          trailing: Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: textMuted),
                          onTap: _goToLockScreen,
                        ),
                        const SizedBox(height: 6),
                        _SettingsTile(
                          icon: Icons.delete_forever_rounded,
                          iconColor: AppTheme.error,
                          label: 'Wipe All Data',
                          subtitle: 'Erase everything & re-register PIN',
                          cardBg: cardBg,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          trailing: Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: textMuted),
                          onTap: _wipeAllData,
                        ),
                        const SizedBox(height: 6),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            const Spacer(),
            _buildFooter(textMuted),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildDrawerHeader() {
    return GestureDetector(
      onTap: _onHeaderTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // Subtle red tint once dev mode unlocked
            colors: _devModeUnlocked
                ? [AppTheme.primaryDark, const Color(0xFF1A4040)]
                : [AppTheme.primaryDark, AppTheme.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: _devModeUnlocked
              ? Border.all(color: AppTheme.error.withOpacity(0.5), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('I owe U',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                Text('Debt Tracker',
                    style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.7), fontSize: 12)),
              ],
            ),
            const Spacer(),
            // Show a tiny lock icon when dev mode is active
            if (_devModeUnlocked)
              Icon(Icons.developer_mode_rounded,
                  color: AppTheme.error.withOpacity(0.8), size: 18),
          ],
        ),
      ),
    );
  }

  // ── Dev toast ──────────────────────────────────────────────────────────────

  Widget _buildDevToast(Color textMuted) {
    final remaining = _tapsRequired - _tapCount;
    final isUnlocked = _devModeUnlocked;
    final show = isUnlocked || (_tapCount > 1 && remaining > 0);

    if (!show) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _toastFade,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUnlocked
              ? AppTheme.error.withOpacity(0.1)
              : AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUnlocked
                ? AppTheme.error.withOpacity(0.3)
                : AppTheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUnlocked
                  ? Icons.developer_mode_rounded
                  : Icons.touch_app_rounded,
              color: isUnlocked ? AppTheme.error : AppTheme.primaryLight,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              isUnlocked
                  ? 'Developer options unlocked!'
                  : '$remaining more tap${remaining == 1 ? '' : 's'} to unlock dev options',
              style: GoogleFonts.dmSans(
                color: isUnlocked ? AppTheme.error : AppTheme.primaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(Color textMuted) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text('I owe U • v1.0.0',
          style: GoogleFonts.dmSans(color: textMuted, fontSize: 12)),
    );
  }
}

// ── Reusable tile widgets ──────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final Color cardBg;
  final Color textPrimary;
  final Color textMuted;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.cardBg,
    required this.textPrimary,
    required this.textMuted,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.dmSans(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: GoogleFonts.dmSans(
                          color: textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ThemeToggleTile extends StatelessWidget {
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textMuted;
  final ValueChanged<bool> onToggle;

  const _ThemeToggleTile({
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textMuted,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Container(
              key: ValueKey(isDark),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.primaryLight : AppTheme.accent)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: isDark ? AppTheme.primaryLight : AppTheme.accent,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isDark ? 'Dark Mode' : 'Light Mode',
                    style: GoogleFonts.dmSans(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(isDark ? 'Switch to light theme' : 'Switch to dark theme',
                    style: GoogleFonts.dmSans(
                        color: textMuted, fontSize: 12)),
              ],
            ),
          ),
          Switch.adaptive(
            value: !isDark,
            onChanged: onToggle,
            activeColor: AppTheme.primary,
            activeTrackColor: AppTheme.primary.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

class _BiometricToggleTile extends StatelessWidget {
  final bool isEnabled;
  final bool isAvailable;
  final Color cardBg;
  final Color textPrimary;
  final Color textMuted;
  final ValueChanged<bool> onToggle;

  const _BiometricToggleTile({
    required this.isEnabled,
    required this.isAvailable,
    required this.cardBg,
    required this.textPrimary,
    required this.textMuted,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isAvailable
                      ? (isEnabled ? AppTheme.accent : AppTheme.textMuted)
                      : AppTheme.textMuted)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.fingerprint_rounded,
                color: isAvailable
                    ? (isEnabled ? AppTheme.accent : AppTheme.textMuted)
                    : AppTheme.textMuted,
                size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fingerprint Login',
                    style: GoogleFonts.dmSans(
                        color: isAvailable ? textPrimary : textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(
                  isAvailable
                      ? (isEnabled
                          ? 'Skip PIN with fingerprint'
                          : 'Enable fingerprint login')
                      : 'Not supported on this device',
                  style: GoogleFonts.dmSans(
                      color: textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isEnabled,
            onChanged: isAvailable ? onToggle : null,
            activeColor: AppTheme.accent,
            activeTrackColor: AppTheme.accent.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}
// ── Wipe confirmation dialog ───────────────────────────────────────────────────

/// Two-step confirmation dialog for the destructive "Wipe All Data" action.
///
/// Shows a stark warning with the app icon, a red border, and a second
/// confirmation checkbox so the user cannot accidentally confirm.
class _WipeConfirmDialog extends StatefulWidget {
  const _WipeConfirmDialog();

  @override
  State<_WipeConfirmDialog> createState() => _WipeConfirmDialogState();
}

class _WipeConfirmDialogState extends State<_WipeConfirmDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.error.withOpacity(0.6), width: 1.5),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_forever_rounded,
                color: AppTheme.error, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            'Wipe All Data',
            style: GoogleFonts.spaceGrotesk(
              color: AppTheme.error,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will permanently delete:',
            style: GoogleFonts.dmSans(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _BulletPoint('All debt records'),
          _BulletPoint('All payment history'),
          _BulletPoint('Your PIN & security question'),
          const SizedBox(height: 14),
          Text(
            'This action cannot be undone. You will be taken to the PIN registration screen immediately after.',
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 16),
          // Second confirmation checkbox
          GestureDetector(
            onTap: () => setState(() => _confirmed = !_confirmed),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _confirmed
                        ? AppTheme.error
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _confirmed
                          ? AppTheme.error
                          : AppTheme.textMuted,
                      width: 2,
                    ),
                  ),
                  child: _confirmed
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'I understand this cannot be undone',
                    style: GoogleFonts.dmSans(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel',
              style: GoogleFonts.dmSans(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600)),
        ),
        AnimatedOpacity(
          opacity: _confirmed ? 1.0 : 0.35,
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _confirmed
                ? () => Navigator.pop(context, true)
                : null,
            child: Text('Wipe Everything',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// A simple bullet-point row used inside [_WipeConfirmDialog].
class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: const BoxDecoration(
              color: AppTheme.error,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            text,
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}