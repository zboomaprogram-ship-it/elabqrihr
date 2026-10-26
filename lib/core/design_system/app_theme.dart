import 'package:flutter/material.dart';

class AppTheme {
  // --- Attend (العبقري HR) Approved Palette ---
  static const Color primaryColor = Color(0xFF0272F2);
  static const Color primary = primaryColor;
  static const Color primaryLight = Color(0xFF60A5FA);

  static const Color secondaryColor = Color(0xFFAAD5FF);
  static const Color secondary = secondaryColor;

  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color background = backgroundColor;

  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color surface01 = Colors.white;
  static const Color surface02 = Color(0xFFF1F5F9);
  static const Color surface03 = Color(0xFFE2E8F0);
  static const Color borderColor = surface03;

  static const Color textPrimary = Color(0xFF17162E);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textLight = Colors.white;
  static const Color darkInk = textPrimary;
  static const Color steel = textSecondary;

  static const Color successColor = Color(0xFF10B981);
  static const Color mint = successColor;
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color coral = errorColor;
  static const Color dangerDeep = Color(0xFFB91C1C);

  static const Color electricViolet = Color(0xFF6366F1);
  static const Color pendingColor = warningColor;

  // Asset paths
  static const String logoAsset = 'assets/images/logo.png';
  static const String splashAsset = 'assets/images/splash.png';

  // --- Gradients & Shadows ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0272F2), Color(0xFF0153B2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [errorColor, dangerDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient permissionGradient = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 10,
    offset: Offset(0, 2),
  );

  // --- Attend Light Theme ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: Colors.white,
      fontFamily: 'Cairo',
      textTheme: ThemeData.light().textTheme.apply(
            fontFamily: 'Cairo',
            bodyColor: textPrimary,
            displayColor: textPrimary,
          ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (BuildContext context) => const Icon(
          Icons.arrow_back,
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: secondaryColor,
        onPrimaryContainer: primaryColor,
        secondary: secondaryColor,
        onSecondary: textPrimary,
        surface: Colors.white,
        onSurface: textPrimary,
        surfaceContainerHighest: surface02,
        onSurfaceVariant: textSecondary,
        outline: surface03,
        outlineVariant: surface02,
        error: errorColor,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        selectedLabelStyle:
            TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(44, 48),
          side: const BorderSide(color: primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface02,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surface03),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surface03),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: surface03, width: 1),
        ),
      ),
    );
  }
}
