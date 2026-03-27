import 'package:flutter/material.dart';

import '../atoms/skeleton_loader.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';

/// A skeleton card placeholder with shimmer lines inside a rounded rectangle.
///
/// Mimics the shape of a content card while data is loading. Shows 2-3
/// shimmer text lines inside a card-shaped container.
///
/// ```dart
/// SkeletonCard(height: 120)
/// ```
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    this.height = 120,
    this.lineCount = 3,
    super.key,
  });

  /// Total height of the card.
  final double height;

  /// Number of shimmer text lines to show inside the card.
  final int lineCount;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);

    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: HmbSpacing.sm),
      padding: const EdgeInsets.all(HmbSpacing.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: HmbRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(lineCount, (index) {
          // First line is wider (title), subsequent lines are shorter.
          final fraction = index == 0 ? 0.7 : 0.4 + (index * 0.05);
          final screenWidth = MediaQuery.sizeOf(context).width;
          return SkeletonLoader(
            width: screenWidth * fraction.clamp(0.3, 0.85),
            height: index == 0 ? 14 : 12,
          );
        }),
      ),
    );
  }
}
