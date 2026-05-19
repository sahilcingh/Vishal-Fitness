import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE0E0E0),
      highlightColor:
          isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF5F5F5),
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

// Dark-tinted variant for cards with dark backgrounds (streak card, pass card)
class ShimmerBoxDark extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBoxDark({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2D2D2D),
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
