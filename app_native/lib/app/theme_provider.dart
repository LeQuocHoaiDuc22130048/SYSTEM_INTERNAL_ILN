import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeStorageKey = 'app_theme_mode';
  final FlutterSecureStorage _storage;

  ThemeMode _themeMode = ThemeMode.light;

  ThemeProvider({FlutterSecureStorage storage = const FlutterSecureStorage()})
      : _storage = storage {
    _loadThemeFromStorage();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> _loadThemeFromStorage() async {
    try {
      final savedTheme = await _storage.read(key: _themeStorageKey);
      if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
        notifyListeners();
      } else if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
        notifyListeners();
      }
    } catch (_) {
      // Ignore if storage read fails
    }
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
    try {
      await _storage.write(
        key: _themeStorageKey,
        value: _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {
      // Ignore write error
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      await _storage.write(
        key: _themeStorageKey,
        value: mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {
      // Ignore write error
    }
  }
}
