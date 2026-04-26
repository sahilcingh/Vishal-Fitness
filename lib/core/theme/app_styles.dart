import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppStyles {
  // --- Layout & Shape ---
  static const double radiusLg = 20.0;
  static const double radiusMd = 14.0;
  static const double radiusSm = 8.0;
  static const double containerPadding = 20.0;

  // --- Typography Getters ---
  static TextStyle get displayFont =>
      GoogleFonts.spaceGrotesk(letterSpacing: -0.02 * 16);

  // FIX applied here: Removed const from the list, used const FontFeature()
  static TextStyle get bodyFont => GoogleFonts.inter(
    fontFeatures: [
      const FontFeature('cv11'),
      const FontFeature('ss01'),
      const FontFeature('ss03'),
    ],
  );

  // --- Specific Text Treatments ---
  static TextStyle get eyebrow => bodyFont.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
  );

  // FIX applied here: Removed const from the list
  static TextStyle get numTabular =>
      bodyFont.copyWith(fontFeatures: [const FontFeature.tabularFigures()]);
}
