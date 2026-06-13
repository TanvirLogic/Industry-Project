import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _keyDarkMode = 'dark_mode';

  ThemeMode _currentThemeMode = ThemeMode.light;
  ThemeMode get currentThemeMode => _currentThemeMode;

  bool get isDarkMode => _currentThemeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_keyDarkMode) ?? false;
    _currentThemeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _currentThemeMode =
        _currentThemeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, _currentThemeMode == ThemeMode.dark);
  }

  Future<void> changeTheme(ThemeMode mode) async {
    _currentThemeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, mode == ThemeMode.dark);
  }
}
