import 'package:flutter/material.dart';

class AppTheme {
  // Professional Color Palette
  static const Color darkBackground = Color(0xFF0B132B); // Deep navy
  static const Color cardBackground = Color(0xFF1C2541); // Slate gray
  static const Color primaryBlue = Color(0xFF3A506B);    // Authoritative blue
  static const Color accentTeal = Color(0xFF48CAE4);     // Professional bright highlight
  
  static const Color successGreen = Color(0xFF2Ecc71);
  static const Color warningOrange = Color(0xFFF39C12);
  static const Color dangerRed = Color(0xFFE74C3C);

  // Text Colors
  static const Color textHighContrast = Colors.white;
  static const Color textMediumContrast = Color(0xFFB0BEC5); // Blue-grey

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Outfit',
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: accentTeal,
        secondary: primaryBlue,
        surface: cardBackground,
        background: darkBackground,
        error: dangerRed,
      ),
      
      // Typography with larger base sizes for readability
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textHighContrast, letterSpacing: 1.2),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textHighContrast, letterSpacing: 1.0),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textHighContrast, letterSpacing: 0.5),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textHighContrast), // used for app bars, dialog titles
        bodyLarge: TextStyle(fontSize: 16, color: textHighContrast), // default body text
        bodyMedium: TextStyle(fontSize: 15, color: textMediumContrast), // secondary body text
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2), // button text
        labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.0), // small caps labels (e.g. badges, tiny stats)
      ),

      // Input Field Styling
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: const TextStyle(fontSize: 15, color: textMediumContrast),
        labelStyle: const TextStyle(fontSize: 15, color: textHighContrast),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: dangerRed, width: 2),
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentTeal,
          foregroundColor: darkBackground,
          elevation: 4,
          shadowColor: accentTeal.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentTeal,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),

      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textHighContrast),
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textHighContrast, letterSpacing: 1.5, fontFamily: 'Outfit'),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF070B19), // Even darker than background for contrast
        selectedItemColor: accentTeal,
        unselectedItemColor: textMediumContrast.withOpacity(0.5),
        selectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        elevation: 20,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
