// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/theme_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pin_screen.dart';
import 'services/service_locator.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize notification service
  final notificationService = ServiceLocator.instance.notificationService;
  await notificationService.initialize();
  await notificationService.requestPermission();

  // Set up notification action handler
  final debtService = ServiceLocator.instance.debtService;
  notificationService.onAction = (action, debtId) async {
    if (action == 'paid') {
      // Mark as paid
      final debt = await debtService.getDebtById(debtId);
      if (debt != null && !debt.isPaid) {
        await debtService.recordPayment(
          debt: debt,
          amount: debt.remainingBalance,
          note: 'Paid via notification',
        );
      }
    } else if (action == 'later' || action == 'reminder') {
      // Reschedule for next interval
      await debtService.rescheduleNextReminder(debtId);
    }
  };

  // Auto-reschedule next reminder whenever a notification fires,
  // regardless of which action the user takes.
  notificationService.onReschedule = (debtId) async {
    await debtService.rescheduleNextReminder(debtId);
  };

  // Persist the next reminder date to the DB after scheduling.
  notificationService.onPersistNextDate = (debtId, nextDate) async {
    await debtService.persistNextReminderDate(debtId, nextDate);
  };

  // Reschedule all active reminders on app start
  final activeDebts = await debtService.getDebtsWithActiveReminders();
  await notificationService.rescheduleAllActive(activeDebts);

  // Load persisted theme preference before first frame.
  await ThemeController.instance.init();

  runApp(const IOUApp());
}

class IOUApp extends StatefulWidget {
  const IOUApp({super.key});

  @override
  State<IOUApp> createState() => _IOUAppState();
}

class _IOUAppState extends State<IOUApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Reschedule reminders when app comes back to foreground
      final debtService = ServiceLocator.instance.debtService;
      final notificationService = ServiceLocator.instance.notificationService;
      final activeDebts = await debtService.getDebtsWithActiveReminders();
      await notificationService.rescheduleAllActive(activeDebts);
    }
  }

  void _onThemeChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I owe U',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeController.instance.themeMode,
      home: const _SplashRouter(),
    );
  }
}

// ── Splash ─────────────────────────────────────────────────────────────────────

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<double>(begin: 30.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1800));

    final authService = ServiceLocator.instance.authService;
    final biometricService = ServiceLocator.instance.biometricService;

    final pinSet = await authService.isPinSet();

    if (!mounted) return;

    // If PIN is set, try biometric auth before showing PIN screen
    if (pinSet) {
      final biometricsEnabled = await authService.isBiometricsEnabled();
      final hasFingerprint = await biometricService.isFingerprintAvailable();

      if (biometricsEnabled && hasFingerprint) {
        final authenticated = await biometricService.authenticate(
          reason: 'Authenticate to access your debts',
        );

        if (authenticated && mounted) {
          // Biometric success — go straight to dashboard
          Navigator.of(context).pushReplacement(PageRouteBuilder(
            pageBuilder: (_, __, ___) => const DashboardScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ));
          return;
        }
        // Biometric failed/declined — fall through to PIN screen
      }
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => PinScreen(isSetup: !pinSet),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDark;
    final bg = isDark ? AppTheme.background : AppTheme.lBackground;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lTextPrimary;
    final textSecondary =
        isDark ? AppTheme.textSecondary : AppTheme.lTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _fade.value,
            child: Transform.translate(
              offset: Offset(0, _slide.value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 24),
                  Text('I owe U',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        color: textPrimary,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      )),
                  const SizedBox(height: 8),
                  Text('Debt Tracker System',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      )),
                  const SizedBox(height: 48),
                  CircularProgressIndicator(
                      color: AppTheme.primary.withOpacity(0.6),
                      strokeWidth: 2.5),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
