import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TwoBeeColors {
  static const splashBg = Color(0xFF092113);
  static const primary = Color(0xFF006C04);
  static const primaryAccent = Color(0xFF199853);
  static const primarySoft = Color(0xFF8CF07C);
  static const scaffoldBg = Color(0xFFF5FBF7);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const surfaceTonal = Color(0xFFE8F7F0);
  static const surfaceTonalAlt = Color(0xFFE1F4D6);
  static const obsidian = Color(0xFF101C0C);
  static const textPrimary = Color(0xFF101C0C);
  static const textSecondary = Color(0xFF545C70);
  static const borderSoft = Color(0xFFD0ECDC);
  static const warningBg = Color(0xFFFCF8E0);
  static const warningBorder = Color(0xFFFCE080);
  static const warningText = Color(0xFF9A5B00);
  static const errorBg = Color(0xFFFCD8D4);
  static const errorText = Color(0xFFB71C1C);
}

class TwoBeeTheme {
  static ThemeData light() {
    final baseText = GoogleFonts.interTextTheme();
    final bengaliFallback = GoogleFonts.notoSansBengali().fontFamily;

    final textTheme = baseText.apply(
      bodyColor: TwoBeeColors.textPrimary,
      displayColor: TwoBeeColors.textPrimary,
      fontFamilyFallback: [?bengaliFallback, 'sans-serif'],
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: TwoBeeColors.scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TwoBeeColors.primary,
        primary: TwoBeeColors.primary,
        secondary: TwoBeeColors.primaryAccent,
        surface: TwoBeeColors.surfaceCard,
        error: TwoBeeColors.errorText,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: TwoBeeColors.surfaceCard,
        foregroundColor: TwoBeeColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: TwoBeeColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: TwoBeeColors.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: TwoBeeColors.borderSoft, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TwoBeeColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TwoBeeColors.primary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: TwoBeeColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TwoBeeColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TwoBeeColors.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TwoBeeColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TwoBeeColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

String bdt(num amount) => '৳${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';

