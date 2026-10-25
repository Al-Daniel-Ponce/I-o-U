import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';

/// Persists which [UserRole] the user last selected.
///
/// OOP principle: Single Responsibility — role persistence only. PIN and
/// biometric preferences belong to [AuthService]; this class never touches
/// the database, so it stays usable before the SQLite layer is open.
class RoleService {
  const RoleService();

  static const _roleKey = 'selected_role';

  /// The last chosen role, or `null` when none has been chosen yet
  /// (first run, after a data wipe, or if storage is unavailable).
  Future<UserRole?> getSavedRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return UserRole.fromStorage(prefs.getString(_roleKey));
    } catch (_) {
      // SharedPreferences may not be available in tests; non-critical.
      return null;
    }
  }

  /// Remembers the user's choice so the next launch skips the picker.
  Future<void> saveRole(UserRole role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_roleKey, role.storageValue);
    } catch (_) {
      // SharedPreferences may not be available in tests; non-critical.
    }
  }

  /// Forgets the choice so the picker is shown again.
  ///
  /// Used by "Switch Role" and by wiping all data.
  Future<void> clearRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_roleKey);
    } catch (_) {
      // SharedPreferences may not be available in tests; non-critical.
    }
  }
}
