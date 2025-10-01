import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color.fromARGB(255, 3, 2, 76); // Deep Navy Blue
  static const Color secondaryColor = Color(0xFF111111);           // Deep Black
  static const Color accentColor = Colors.white;                   // White
  static const Color activeColor = Color(0xFFADFF2F);              // Green Yellow

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,

      // Main Colors
      scaffoldBackgroundColor: primaryColor,
      primaryColor: primaryColor,
      secondaryHeaderColor: secondaryColor,
      splashColor: activeColor,
      highlightColor: activeColor,

      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primaryColor,
        onPrimary: accentColor,
        secondary: secondaryColor,
        onSecondary: accentColor,
        background: primaryColor,
        onBackground: accentColor,
        surface: primaryColor,
        onSurface: accentColor,
        error: Colors.red,
        onError: Colors.white,
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        elevation: 0,
        iconTheme: IconThemeData(color: accentColor),
      ),

      // Icons
      iconTheme: const IconThemeData(
        color: accentColor,
      ),

      // Text
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: accentColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: accentColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: accentColor,
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: accentColor,
        ),
      ),

      // Text Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryColor,
        hintStyle: const TextStyle(color: Colors.white54),
        labelStyle: const TextStyle(color: accentColor),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: accentColor),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: activeColor, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: accentColor),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
