import 'dart:async';

import 'package:flutter/material.dart';

/// A reusable shimmer placeholder widget for skeleton loading states.
///
/// Renders a rounded rectangle with an animated shimmer gradient that
/// sweeps left-to-right, indicating content is loading.
///
/// ```dart
/// SkeletonLoader(width: 120, height: 16)
/// SkeletonLoader(width: 40, height: 40, borderRadius: HmbRadius.fullValue)
/// ```
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    required this.width,
    required this.height,
    this.borderRadius = 4,
    super.key,
  });

  /// Width of the placeholder. Use `double.infinity` for full-width.
  final double width;

  /// Height of the placeholder.
  final double height;

  /// Corner radius of the placeholder rectangle.
  final double borderRadius;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final baseColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE0E0E0);
    final shimmerColor =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF0F0F0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerPosition = _controller.value * 2 - 0.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [baseColor, shimmerColor, baseColor],
              stops: [
                (shimmerPosition - 0.3).clamp(0.0, 1.0),
                shimmerPosition.clamp(0.0, 1.0),
                (shimmerPosition + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
