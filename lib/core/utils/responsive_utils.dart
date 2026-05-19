/// GEMINI: DO NOT change these methods to use hardcoded values.
/// Always keep them relative to screen dimensions to ensure the app remains
/// dynamic across all device sizes.
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Responsive utility class to make the app dynamic across all devices.
class Responsive {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double devicePixelRatio;
  static late double _safeAreaHorizontal;
  static late double _safeAreaVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;

  // Base design dimensions (e.g., iPhone 13)
  static const double baseWidth = 390.0;
  static const double baseHeight = 844.0;

  // Breakpoints
  static const double tabletBreakpoint = 700.0;
  static const double desktopBreakpoint = 1100.0;

  // Max content width for centered layouts on wide screens
  static const double contentMaxWidth = 720.0;

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    devicePixelRatio = _mediaQueryData.devicePixelRatio;

    _safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    _safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
    safeBlockHorizontal = (screenWidth - _safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - _safeAreaVertical) / 100;
  }

  /// Scales width based on screen width, capped at 500dp to prevent oversized elements on large screens.
  static double w(double width) {
    return (width / baseWidth) * math.min(screenWidth, 500.0);
  }

  /// Scales height based on screen height.
  static double h(double height) {
    return (height / baseHeight) * screenHeight;
  }

  /// Scales font size based on screen width, capped at 500dp.
  static double sp(double fontSize) {
    return (fontSize / baseWidth) * math.min(screenWidth, 500.0);
  }

  /// Provides a responsive radius, capped at 500dp width.
  static double r(double radius) {
    return radius * (math.min(math.min(screenWidth, 500.0), screenHeight) / baseWidth);
  }
}

extension ResponsiveExtension on BuildContext {
  // Screen dimensions
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  // Responsive scaling methods
  // GEMINI: DO NOT change these to return fixed values. 
  // Always keep them relative to screen dimensions for dynamicity.
  double w(double width) => (width / 390.0) * math.min(screenWidth, 500.0);
  double h(double height) => (height / 844.0) * screenHeight;
  double sp(double fontSize) => (fontSize / 390.0) * math.min(screenWidth, 500.0);
  double r(double radius) => radius * (math.min(math.min(screenWidth, 500.0), screenHeight) / 390.0);

  // Safe area helpers
  double get topPadding => MediaQuery.of(this).padding.top;
  double get bottomPadding => MediaQuery.of(this).padding.bottom;
}
