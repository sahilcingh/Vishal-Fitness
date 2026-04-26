import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_styles.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.lightPrimary,
      fontFamily: AppStyles.bodyFont.fontFamily,

      colorScheme: const ColorScheme.light(
        background: AppColors.lightBackground,
        surface: AppColors.lightCard,
        primary: AppColors.lightPrimary,
        onPrimary: AppColors.lightPrimaryForeground,
        secondary: AppColors.lightMuted,
        onSurface: AppColors.lightForeground,
        error: Colors.redAccent,
      ),

      textTheme: TextTheme(
        displayLarge: AppStyles.displayFont.copyWith(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: AppColors.lightForeground,
        ),
        displayMedium: AppStyles.displayFont.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.lightForeground,
        ),
        titleLarge: AppStyles.displayFont.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.lightForeground,
        ),
        bodyLarge: AppStyles.bodyFont.copyWith(
          fontSize: 16,
          color: AppColors.lightForeground,
        ),
        bodyMedium: AppStyles.bodyFont.copyWith(
          fontSize: 14,
          color: AppColors.lightMutedForeground,
        ),
      ),

      // FIX applied here: Changed CardTheme to CardThemeData
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: AppColors.lightPrimaryForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyles.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          elevation: 0,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.darkPrimary,
      fontFamily: AppStyles.bodyFont.fontFamily,

      colorScheme: const ColorScheme.dark(
        background: AppColors.darkBackground,
        surface: AppColors.darkCard,
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkBackground,
        secondary: AppColors.darkMuted,
        onSurface: AppColors.darkForeground,
        error: Colors.redAccent,
      ),

      textTheme: TextTheme(
        displayLarge: AppStyles.displayFont.copyWith(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: AppColors.darkForeground,
        ),
        displayMedium: AppStyles.displayFont.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.darkForeground,
        ),
        titleLarge: AppStyles.displayFont.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.darkForeground,
        ),
        bodyLarge: AppStyles.bodyFont.copyWith(
          fontSize: 16,
          color: AppColors.darkForeground,
        ),
        bodyMedium: AppStyles.bodyFont.copyWith(
          fontSize: 14,
          color: AppColors.darkForeground.withOpacity(0.7),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyles.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          elevation: 0,
        ),
      ),
    );
  }
}
