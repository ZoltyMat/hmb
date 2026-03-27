import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// An Apple-inspired stat card for dashboards.
///
/// Displays an icon, label, large value, and optional subtitle
/// over a subtle tinted background. Supports dark mode via [HmbColors].
///
/// ```dart
/// StatCard(
///   icon: Icons.work,
///   iconColor: colors.systemBlue,
///   label: 'Jobs Today',
///   value: '5',
///   onTap: () => context.go('/home/jobs'),
/// )
/// ```
class StatCard extends StatelessWidget {
  const StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
    super.key,
  });

  /// Leading icon displayed in a tinted circle.
  final IconData icon;

  /// The accent color for the icon and its background tint.
  final Color iconColor;

  /// Short label above the value (e.g. "Jobs Today").
  final String label;

  /// The large prominent value (e.g. "12" or "\$4,200").
  final String value;

  /// Optional secondary text below the value.
  final String? subtitle;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(HmbSpacing.lg),
        decoration: BoxDecoration(
          color: colors.secondaryGroupedBackground,
          borderRadius: HmbRadius.large,
          border: Border.all(color: colors.separator, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon in tinted circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                borderRadius: HmbRadius.small,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: HmbSpacing.sm),
            // Label
            Text(
              label,
              style: typography.footnote.copyWith(
                color: colors.secondaryLabel,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: HmbSpacing.xs),
            // Value
            Text(
              value,
              style: typography.title1.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.label,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: typography.caption1.copyWith(
                  color: colors.tertiaryLabel,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
