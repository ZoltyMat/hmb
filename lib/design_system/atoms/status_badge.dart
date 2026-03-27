import 'package:flutter/cupertino.dart';

/// The semantic type of a [StatusBadge], each mapping to a distinct color.
enum StatusBadgeType {
  success,
  warning,
  error,
  info,
  neutral,
}

/// A small colored pill badge for displaying status labels.
///
/// Renders a rounded pill with a colored background and contrasting text.
/// Designed to sit inline with titles or inside list rows.
///
/// ```dart
/// StatusBadge(label: 'Paid', type: StatusBadgeType.success)
/// ```
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.type,
    super.key,
  });

  /// The text displayed inside the pill.
  final String label;

  /// Determines the background and text color of the badge.
  final StatusBadgeType type;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final (bg, fg) = _colors(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  (Color bg, Color fg) _colors(bool isDark) {
    switch (type) {
      case StatusBadgeType.success:
        return isDark
            ? (const Color(0xFF1B3A2A), CupertinoColors.systemGreen)
            : (const Color(0xFFD4EDDA), const Color(0xFF155724));
      case StatusBadgeType.warning:
        return isDark
            ? (const Color(0xFF3A3520), CupertinoColors.systemYellow)
            : (const Color(0xFFFFF3CD), const Color(0xFF856404));
      case StatusBadgeType.error:
        return isDark
            ? (const Color(0xFF3A1B1B), CupertinoColors.systemRed)
            : (const Color(0xFFF8D7DA), const Color(0xFF721C24));
      case StatusBadgeType.info:
        return isDark
            ? (const Color(0xFF1B2A3A), CupertinoColors.systemBlue)
            : (const Color(0xFFD1ECF1), const Color(0xFF0C5460));
      case StatusBadgeType.neutral:
        return isDark
            ? (const Color(0xFF2C2C2E), const Color(0xFF8E8E93))
            : (const Color(0xFFE9ECEF), const Color(0xFF495057));
    }
  }
}
