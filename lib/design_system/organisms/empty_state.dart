import 'package:flutter/cupertino.dart';

/// A centered placeholder for screens with no content.
///
/// Shows an [icon], [title], [subtitle], and an optional [ctaLabel]/[onCta]
/// action button. Designed to be placed inside an expanded or scrollable area.
///
/// ```dart
/// EmptyState(
///   icon: CupertinoIcons.briefcase,
///   title: 'No Jobs Yet',
///   subtitle: 'Create your first job to get started.',
///   ctaLabel: 'Create Job',
///   onCta: () => Navigator.pushNamed(context, '/job/new'),
/// )
/// ```
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
    super.key,
  });

  /// Large icon displayed above the title.
  final IconData icon;

  /// Primary message (e.g. "No Jobs Yet").
  final String title;

  /// Secondary explanatory text.
  final String subtitle;

  /// Label for the optional call-to-action button.
  final String? ctaLabel;

  /// Callback when the CTA button is tapped.
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;

    final iconColor = isDark
        ? const Color(0xFF636366) // tertiaryLabel dark
        : const Color(0xFFC7C7CC); // tertiaryLabel light

    final titleColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.black;

    final subtitleColor = isDark
        ? const Color(0xFF8E8E93) // secondaryLabel dark
        : const Color(0xFF6C6C70); // secondaryLabel light

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: iconColor,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: titleColor,
                letterSpacing: 0.38,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: subtitleColor,
                letterSpacing: -0.24,
              ),
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: onCta,
                child: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
