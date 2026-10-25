import 'package:flutter/material.dart';

/// The two perspectives a user can adopt in the app.
///
/// OOP principles:
/// - Enumeration — a closed set of two fixed values, no other type of
///   "role" can exist, so invalid states are unrepresentable.
/// - Information Expert — serialization (`storageValue` / `fromStorage`)
///   lives with the data it describes instead of leaking into services.
enum UserRole {
  lender(
    label: 'Lender',
    tagline: 'I lent money — track who owes me',
    icon: Icons.handshake_rounded,
  ),
  borrower(
    label: 'Borrower',
    tagline: 'I borrowed money — track what I owe',
    icon: Icons.request_quote_rounded,
  );

  const UserRole({
    required this.label,
    required this.tagline,
    required this.icon,
  });

  /// Human-readable name shown on the picker card and mode badges.
  final String label;

  /// One-line explanation shown under [label].
  final String tagline;

  /// Leading glyph on the picker card.
  final IconData icon;

  /// Value written to persistent storage.
  ///
  /// Kept explicit rather than relying on `name` so a future enum
  /// rename cannot silently invalidate stored data.
  String get storageValue => name;

  /// Reads a persisted value back into a role.
  ///
  /// Returns `null` for anything unknown or absent — an unreadable
  /// stored role degrades to "no role chosen" (the picker) rather
  /// than throwing or guessing.
  static UserRole? fromStorage(String? raw) {
    switch (raw) {
      case 'lender':
        return UserRole.lender;
      case 'borrower':
        return UserRole.borrower;
      default:
        return null;
    }
  }
}
