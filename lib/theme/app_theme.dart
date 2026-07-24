import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
export 'app_icons.dart';

class AppColors {
  // Primary brand palette — deep navy + electric teal
  static const Color navyDeep = Color(0xFF0A0E21);
  static const Color navyMid = Color(0xFF111827);
  static const Color navyCard = Color(0xFF1C2438);
  static const Color navyBorder = Color(0xFF2A3454);

  static const Color tealPrimary = Color(0xFF00D4AA);
  static const Color tealLight = Color(0xFF4DFFD6);
  static const Color tealDark = Color(0xFF00A882);
  static const Color mintAccent = Color(0xFFB8FFF0);

  static const Color purpleAccent = Color(0xFF7C6FCD);
  static const Color roseAccent = Color(0xFFFF6B9D);

  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF475569);

  static const Color success = Color(0xFF22D3EE);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFFF6B6B);
  static const Color income = Color(0xFF4ADE80);
  static const Color expense = Color(0xFFFF6B6B);

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, Color(0xFF0D1B2A), Color(0xFF0A1628)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C2438), Color(0xFF16202E)],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealPrimary, Color(0xFF00B894), Color(0xFF0099D6)],
  );

  static const LinearGradient balanceCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D4AA), Color(0xFF0099D6), Color(0xFF7C6FCD)],
  );

  static const LinearGradient aiCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C6FCD), Color(0xFF5B63B7)],
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.navyDeep,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.tealPrimary,
        secondary: AppColors.purpleAccent,
        surface: AppColors.navyCard,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
            displayMedium: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            headlineLarge: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            headlineMedium: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            bodyLarge: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
            bodyMedium: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
            labelLarge: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.navyCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.navyBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.navyBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.tealPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 15),
        labelStyle: GoogleFonts.outfit(
          color: AppColors.textSecondary,
          fontSize: 15,
        ),
        errorStyle: GoogleFonts.outfit(color: AppColors.error, fontSize: 12),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
      ),
    );
  }
}
