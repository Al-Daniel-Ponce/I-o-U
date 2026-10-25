import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import 'borrower_dashboard_screen.dart';
import 'dashboard_screen.dart';
import 'role_selection_screen.dart';

/// Single destination for "the user just authenticated".
///
/// Resolves the remembered [UserRole] once and shows the matching
/// dashboard — or the role picker when no role has been chosen yet
/// (first run, after a wipe, or after Switch Role).
///
/// OOP principle: Single Responsibility — every entry point that used to
/// hard-code `DashboardScreen` (PIN login, biometric success, end of
/// first-run setup) delegates here, so the post-auth routing rule exists
/// in exactly one place. Flip [_alwaysAskForRole] to require the picker
/// on every unlock instead of only when a role is missing.
class AfterAuthGate extends StatelessWidget {
  const AfterAuthGate({super.key});

  /// When `true`, the role picker is shown on every unlock and the saved
  /// role is only used to pre-highlight a card.
  static const bool _alwaysAskForRole = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserRole?>(
      future: ServiceLocator.instance.roleService.getSavedRole(),
      builder: (context, snapshot) {
        // Still reading the preference — keep the app's spinner styling
        // instead of flashing a blank route. `hasData` cannot be used here:
        // a null role is a valid result and would never set it.
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ResolvingRole();
        }

        // A read failure degrades to "no role chosen" → the picker.
        final role = snapshot.hasError ? null : snapshot.data;
        if (_alwaysAskForRole || role == null) {
          return const RoleSelectionScreen();
        }
        if (role == UserRole.lender) return const DashboardScreen();
        return const BorrowerDashboardScreen();
      },
    );
  }
}

/// Brief themed placeholder shown while [AfterAuthGate] reads the saved role.
class _ResolvingRole extends StatelessWidget {
  const _ResolvingRole();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.background : AppTheme.lBackground,
      body: const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }
}
