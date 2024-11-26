import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';


class ThemeNotifier extends ChangeNotifier{
  ThemeData _currentTheme;
  static const String _themeKey = 'theme';

  ThemeNotifier(this._currentTheme);
  ThemeData get currentTheme => _currentTheme;

  void switchTheme (ThemeData newTheme) async {
    _currentTheme = newTheme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_themeKey, newTheme == AppThemes.darkTheme);
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    bool isDarkTheme = prefs.getBool(_themeKey) ?? false;
    _currentTheme = isDarkTheme ? AppThemes.darkTheme : AppThemes.lightTheme;
    notifyListeners();
  }
}