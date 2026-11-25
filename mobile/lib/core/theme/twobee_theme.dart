import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Neo-Tactile Eco-Emerald Brand Colors (Reference-Aligned)
class TwoBeeColors {
  static const splashBg = Color(0xFF0E1310);
  static const primary = Color(0xFF00C853); // Locked Eco Emerald
  static const primaryAccent = Color(0xFF00A844);
  static const primarySoft = Color(0xFF22C55E);
  static const primaryDark = Color(0xFF007A33); // Dark emerald for high contrast on light bg
  static const scaffoldBg = Color(0xFFF6F8F7);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const surfaceTonal = Color(0xFFEDF4F0);
  static const surfaceTonalAlt = Color(0xFFE2EFE7);
  static const obsidian = Color(0xFF0E1310); // Deep Forest Obsidian
  static const obsidianCard = Color(0xFF171F1B);
  static const textPrimary = Color(0xFF0A110D); // Deep forest black (WCAG AAA)
  static const textSecondary = Color(0xFF334155); // Slate 700 - sharp, high contrast
  static const textMuted = Color(0xFF64748B); // Slate 500 - clear caption
  static const textOnDark = Color(0xFFFFFFFF); // Crisp pure white on dark
  static const textOnDarkSecondary = Color(0xFFCBD5E1); // Slate 300 on dark
  static const borderSoft = Color(0xFFE2EBE5);
  static const borderHairline = Color(0x1F000000);
  static const warningBg = Color(0xFFFCF8E0);
  static const warningBorder = Color(0xFFFCE080);
  static const warningText = Color(0xFF9A5B00);
  static const errorBg = Color(0xFFFCD8D4);
  static const errorText = Color(0xFFE53935);
  static const accentGlow = Color(0x5900C853);
}

/// Squircle Radii Standards for Neo-Tactile UI
class TwoBeeRadii {
  static const double cardRadius = 26.0;
  static const double innerRadius = 18.0;
  static const double pillRadius = 999.0;

  static final BorderRadius card = BorderRadius.circular(cardRadius);
  static final BorderRadius inner = BorderRadius.circular(innerRadius);
  static final BorderRadius pill = BorderRadius.circular(pillRadius);
  static const BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(32));
  static const BorderRadius headerBottom = BorderRadius.vertical(bottom: Radius.circular(32));
}

/// Multi-stop Ambient Diffuse Shadows
class TwoBeeShadows {
  static const List<BoxShadow> softCard = [
    BoxShadow(
      color: Color(0x0E0A110D),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x060A110D),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> dockNav = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> emeraldGlow = [
    BoxShadow(
      color: TwoBeeColors.accentGlow,
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];
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
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: TwoBeeColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: TwoBeeColors.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: TwoBeeRadii.card,
          side: const BorderSide(color: TwoBeeColors.borderSoft, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TwoBeeColors.primary,
          foregroundColor: TwoBeeColors.textPrimary,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TwoBeeColors.textPrimary,
          minimumSize: const Size(64, 50),
          side: const BorderSide(color: TwoBeeColors.borderSoft, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TwoBeeColors.surfaceTonal,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: TwoBeeRadii.pill,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: TwoBeeRadii.pill,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TwoBeeRadii.pill,
          borderSide: const BorderSide(color: TwoBeeColors.primary, width: 1.8),
        ),
      ),
    );
  }
}

String bdt(dynamic amount) {
  if (amount == null) return '৳0';
  final num val = amount is num ? amount : (num.tryParse(amount.toString()) ?? 0);
  return '৳${val.toStringAsFixed(val % 1 == 0 ? 0 : 2)}';
}
