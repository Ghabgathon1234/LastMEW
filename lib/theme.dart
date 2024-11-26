import 'package:flutter/material.dart';

class AppThemes {
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.white,
    scaffoldBackgroundColor: Colors.white,
    switchTheme: SwitchThemeData(
      //thumbColor: WidgetStatePropertyAll(Color(0xFF228BE6)),
      trackColor: WidgetStatePropertyAll(Colors.white)),
    appBarTheme: AppBarTheme(color: Color(0xFF007AFF)),
    hintColor:  Color(0xFF007AFF),
    cardColor: Colors.white,
    shadowColor: Colors.black,
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.grey),
      bodyMedium: TextStyle(color: Colors.black87),
      bodySmall: TextStyle(color: Colors.black54),
    ),
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    //primaryColor: Color(0xFF2C2C2C),
    scaffoldBackgroundColor: Colors.black,
    
    appBarTheme: AppBarTheme(color: Color(0xFF1E1E1E)),
    //cardColor: Color(0xFF1E1E1E),
    hintColor: Color(0xFF007AFF),
    shadowColor: Colors.grey,
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white),
    ),
  );


}