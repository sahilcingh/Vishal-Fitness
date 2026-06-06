import 'package:flutter/material.dart';

class AppStyles {
  // --- Layout & Shape ---
  static const double radiusLg = 20.0;
  static const double radiusMd = 14.0;
  static const double radiusSm = 8.0;
  static const double containerPadding = 20.0;

  // --- Typography Getters ---
  // Fonts are bundled locally in assets/fonts/ — no CDN dependency.
  static TextStyle get displayFont =>
      const TextStyle(fontFamily: 'SpaceGrotesk', letterSpacing: -0.32);

  static TextStyle get bodyFont => const TextStyle(
        fontFamily: 'Inter',
        fontFeatures: [
          FontFeature('cv11'),
          FontFeature('ss01'),
          FontFeature('ss03'),
        ],
      );

  // --- Specific Text Treatments ---
  static TextStyle get eyebrow => bodyFont.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.2,
      );

  static TextStyle get numTabular =>
      bodyFont.copyWith(fontFeatures: [const FontFeature.tabularFigures()]);
}
