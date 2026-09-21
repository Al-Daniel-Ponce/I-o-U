import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/logger.dart';

/// Manages the app-wide theme mode (dark / light) and persists the choice.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();
  static const _prefKey = 'is_dark_mode';
  static const _logger = Logger('ThemeController');

  bool _isDark = true;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_prefKey) ?? true;
    } catch (e, stack) {
      _logger.error('Failed to load theme preference', e, stack);
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();
    await _persist();
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, _isDark);
    } catch (e, stack) {
      _logger.error('Failed to persist theme preference', e, stack);
    }
  }
}
