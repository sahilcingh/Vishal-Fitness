import 'package:flutter/material.dart';

class AppColors {
  // --- Vibrant Accent Palette ---
  static const Color brand = Color(0xFF1FC56B); // Electric lime-green
  static const Color energy = Color(0xFFFF7A29); // Fiery orange
  static const Color pulse = Color(0xFFB14CF0); // Neon violet
  static const Color aqua = Color(0xFF26B6E8); // Cyan
  static const Color sun = Color(0xFFFFD633); // Yellow

  // --- Light Mode Tokens (Approximated from HSL 0 0% X%) ---
  static const Color lightBackground = Color(0xFFFAFAFA); // 98%
  static const Color lightForeground = Color(0xFF0F0F0F); // 6%
  static const Color lightCard = Color(0xFFFFFFFF); // 100%
  static const Color lightPrimary = Color(0xFF0F0F0F); // 6%
  static const Color lightPrimaryForeground = Color(0xFFFAFAFA); // 98%
  static const Color lightMuted = Color(0xFFF2F2F2); // 95%
  static const Color lightMutedForeground = Color(0xFF6B6B6B); // 42%
  static const Color lightBorder = Color(0xFFE6E6E6); // 90%

  // --- Dark Mode Tokens ---
  static const Color darkBackground = Color(0xFF0D0D0D); // 5%
  static const Color darkForeground = Color(0xFFF5F5F5); // 96%
  static const Color darkCard = Color(0xFF141414); // 8%
  static const Color darkPrimary = Color(0xFFF5F5F5); // 96%
  static const Color darkMuted = Color(0xFF1F1F1F); // 12%
  static const Color darkBorder = Color(0xFF292929); // 16%

  // --- Gradients ---
  static const LinearGradient gradientBrand = LinearGradient(
    colors: [brand, aqua],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientEnergy = LinearGradient(
    colors: [energy, pulse],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientSunrise = LinearGradient(
    colors: [sun, energy, pulse],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientCool = LinearGradient(
    colors: [aqua, pulse],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientInk = LinearGradient(
    colors: [Color(0xFF141414), Color(0xFF242424)], // 8% to 14%
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

extension AppThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => isDark ? AppColors.darkBackground : AppColors.lightBackground;
  Color get fg => isDark ? AppColors.darkForeground : AppColors.lightForeground;
  Color get card => isDark ? AppColors.darkCard : AppColors.lightCard;
  Color get primaryColor => isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
  Color get primaryFg => isDark ? AppColors.darkBackground : AppColors.lightPrimaryForeground;
  Color get muted => isDark ? AppColors.darkMuted : AppColors.lightMuted;
  Color get mutedFg => isDark ? AppColors.darkForeground.withOpacity(0.7) : AppColors.lightMutedForeground;
  Color get border => isDark ? AppColors.darkBorder : AppColors.lightBorder;
}
