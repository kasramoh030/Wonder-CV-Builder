import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Font family names, matching the `fonts:` section of `pubspec.yaml`.
abstract final class AppFonts {
  static const String inter = 'Inter';
  static const String vazirmatn = 'Vazirmatn';
  static const String lato = 'Lato';
  static const String notoSans = 'Noto Sans';
  static const String openSans = 'Open Sans';

  /// Family used for Latin / Cyrillic scripts.
  static const String latin = inter;

  /// Family used for Perso-Arabic scripts.
  ///
  /// Vazirmatn is chosen over the generic fallback because it is designed for
  /// UI at small optical sizes, has a genuine SemiBold, and — critically for
  /// this app — ships the full Arabic presentation-forms range that the PDF
  /// shaper relies on.
  static const String persian = vazirmatn;

  /// Returns the UI family for [locale].
  static String forLocale(Locale locale) =>
      locale.languageCode == 'fa' ? persian : latin;
}

/// Builds the app [TextTheme].
///
/// The type scale is intentionally tighter and heavier than the Material
/// default: a CV tool is a *document* tool, and a slightly more editorial
/// scale makes the preview and the app feel like one product.
abstract final class AppTypography {
  /// Multiplier applied to every font size.
  ///
  /// Persian script has a taller x-height relative to Latin at the same
  /// nominal size, so Persian runs are nudged up to keep optical parity.
  static double opticalScaleFor(Locale locale) =>
      locale.languageCode == 'fa' ? 1.04 : 1.0;

  static TextTheme textTheme(Locale locale) {
    final String family = AppFonts.forLocale(locale);
    final double s = opticalScaleFor(locale);

    TextStyle t(
      double size,
      FontWeight weight, {
      double? height,
      double? spacing,
      Color? color,
    }) =>
        TextStyle(
          fontFamily: family,
          fontSize: size * s,
          fontWeight: weight,
          height: height ?? 1.35,
          letterSpacing: spacing ?? 0,
          color: color,
        );

    return TextTheme(
      displayLarge: t(48, FontWeight.w700, height: 1.12, spacing: -0.8),
      displayMedium: t(38, FontWeight.w700, height: 1.14, spacing: -0.6),
      displaySmall: t(32, FontWeight.w700, height: 1.16, spacing: -0.4),
      headlineLarge: t(28, FontWeight.w700, height: 1.2, spacing: -0.3),
      headlineMedium: t(24, FontWeight.w700, height: 1.22, spacing: -0.2),
      headlineSmall: t(21, FontWeight.w600, height: 1.26, spacing: -0.1),
      titleLarge: t(19, FontWeight.w600, height: 1.28),
      titleMedium: t(16, FontWeight.w600, height: 1.32),
      titleSmall: t(14, FontWeight.w600, height: 1.34, spacing: 0.1),
      bodyLarge: t(16, FontWeight.w400, height: 1.5),
      bodyMedium: t(14, FontWeight.w400, height: 1.48),
      bodySmall: t(12.5, FontWeight.w400, height: 1.45),
      labelLarge: t(14, FontWeight.w600, height: 1.2, spacing: 0.2),
      labelMedium: t(12.5, FontWeight.w600, height: 1.2, spacing: 0.3),
      labelSmall: t(11, FontWeight.w600, height: 1.2, spacing: 0.4),
    );
  }

  /// The text style used to render CV section headings inside the app chrome
  /// (not inside the PDF, which has its own engine).
  static TextStyle sectionHeading(Locale locale, {Color? color}) => TextStyle(
        fontFamily: AppFonts.forLocale(locale),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: locale.languageCode == 'fa' ? 0 : 1.1,
        color: color ?? AppColors.brandSeed,
      );
}
