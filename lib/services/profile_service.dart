import 'package:shared_preferences/shared_preferences.dart';

/// The single profile name shared by both roles.
///
/// The same person can be a lender and a borrower in this app. Rather than
/// asking twice, one stored name is used wherever an identity must be
/// displayed:
///  - lending  → "Lent by <name>" on the QR payload,
///  - borrowing → "Lent by <name>" vs. your own name on the received copy.
///
/// OOP principles:
/// - Single Responsibility : one name in, one name out — nothing else.
/// - Open/Closed            : a new identity field (e.g. avatar) can be
///   added here without touching every screen that already asks this class.
class ProfileService {
  static const _nameKey = 'profile_name';

  final Future<SharedPreferences> _prefs;

  const ProfileService(this._prefs);

  /// Stored name, trimmed; empty when the user has never set one.
  Future<String> getName() async {
    final prefs = await _prefs;
    return (prefs.getString(_nameKey) ?? '').trim();
  }

  Future<void> setName(String name) async {
    final prefs = await _prefs;
    await prefs.setString(_nameKey, name.trim());
  }

  Future<bool> hasName() async => (await getName()).isNotEmpty;
}
