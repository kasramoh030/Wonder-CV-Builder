import 'package:flutter/material.dart';

/// Brand colour tokens for CV Pro.
///
/// The palette is deliberately narrow: one strong brand hue, one calm
/// secondary, and a semantic ramp used by the analyzer to communicate
/// severity. Everything else is derived from the Material 3 [ColorScheme]
/// so the app keeps working under dynamic colour and in both brightnesses.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────
  /// Primary brand hue — deep indigo. Reads as trustworthy and editorial.
  static const Color brandSeed = Color(0xFF4F46E5);

  /// Secondary hue used for "online / cloud" affordances.
  static const Color brandAccent = Color(0xFF0EA5E9);

  /// Warm accent reserved for premium upsell surfaces.
  static const Color brandPremium = Color(0xFFF59E0B);

  // ── Semantic (analyzer severity) ─────────────────────────────────────────
  static const Color critical = Color(0xFFDC2626);
  static const Color high = Color(0xFFEA580C);
  static const Color medium = Color(0xFFD97706);
  static const Color low = Color(0xFF0D9488);

  // ── Score ramp ───────────────────────────────────────────────────────────
  static const Color scoreExcellent = Color(0xFF15803D);
  static const Color scoreGood = Color(0xFF65A30D);
  static const Color scoreFair = Color(0xFFD97706);
  static const Color scorePoor = Color(0xFFDC2626);

  // ── Network status ───────────────────────────────────────────────────────
  static const Color offline = Color(0xFF64748B);
  static const Color online = Color(0xFF0D9488);

  /// Maps a 0..100 quality score onto the score ramp.
  static Color forScore(num score) {
    if (score >= 85) return scoreExcellent;
    if (score >= 70) return scoreGood;
    if (score >= 50) return scoreFair;
    return scorePoor;
  }

  /// Light-theme surface stack. Kept explicit so the PDF preview chrome and
  /// the app chrome agree on what "paper" looks like.
  static const Color paper = Color(0xFFFFFFFF);
  static const Color canvasLight = Color(0xFFF6F7FB);
  static const Color canvasDark = Color(0xFF0E1116);
}
