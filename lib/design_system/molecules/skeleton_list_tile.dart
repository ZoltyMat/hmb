import 'package:flutter/material.dart';

import '../atoms/skeleton_loader.dart';
import '../tokens/spacing.dart';

/// A skeleton placeholder that mimics a list tile with an avatar and two
/// text lines.
///
/// Use while list data is loading to convey the shape of incoming content,
/// reducing perceived latency compared to a blank screen or spinner.
///
/// ```dart
/// ListView.builder(
///   itemCount: 8,
///   itemBuilder: (_, __) => const SkeletonListTile(),
/// )
/// ```
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({
    this.hasAvatar = true,
    this.height = 72,
    super.key,
  });

  /// Whether to show a circular avatar placeholder on the leading edge.
  final bool hasAvatar;

  /// Total height of the tile.
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HmbSpacing.lg,
        vertical: HmbSpacing.sm,
      ),
      child: Row(
        children: [
          if (hasAvatar) ...[
            const SkeletonLoader(
              width: 40,
              height: 40,
              borderRadius: 20,
            ),
            const SizedBox(width: HmbSpacing.md),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: _randomWidth(context, 0.6, 0.85),
                  height: 14,
                ),
                const SizedBox(height: HmbSpacing.sm),
                SkeletonLoader(
                  width: _randomWidth(context, 0.3, 0.55),
                  height: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  /// Returns a width between [minFraction] and [maxFraction] of the
  /// available screen width, using a deterministic midpoint to avoid
  /// layout jitter on rebuilds.
  double _randomWidth(
    BuildContext context,
    double minFraction,
    double maxFraction,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final midFraction = (minFraction + maxFraction) / 2;
    return screenWidth * midFraction;
  }
}
