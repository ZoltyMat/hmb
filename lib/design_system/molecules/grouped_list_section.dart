import 'package:flutter/cupertino.dart';

/// An iOS Settings-style grouped list section with rounded corners.
///
/// Displays an optional uppercase [header] above the section, wraps [children]
/// in a rounded card with inset dividers between rows, and shows an optional
/// [footer] below.
///
/// ```dart
/// GroupedListSection(
///   header: 'General',
///   children: [
///     FormFieldRow(label: 'Name', child: CupertinoTextField()),
///     FormFieldRow(label: 'Email', child: CupertinoTextField()),
///   ],
/// )
/// ```
class GroupedListSection extends StatelessWidget {
  const GroupedListSection({
    required this.children,
    this.header,
    this.footer,
    super.key,
  });

  /// Uppercase section header displayed above the rounded card.
  final String? header;

  /// Explanatory text displayed below the rounded card in caption style.
  final String? footer;

  /// The row widgets rendered inside the section card.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF1C1C1E) // secondarySystemBackground dark
        : CupertinoColors.white;

    final dividerColor = isDark
        ? const Color(0xFF38383A) // separator dark
        : const Color(0xFFC6C6C8); // separator light

    final headerColor = isDark
        ? const Color(0xFF8E8E93) // secondaryLabel dark
        : const Color(0xFF6C6C70); // secondaryLabel light

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 6, top: 24),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: headerColor,
                  letterSpacing: -0.08,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(color: bgColor),
              child: Column(
                children: _buildRows(dividerColor),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 6, bottom: 8),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: headerColor,
                  letterSpacing: -0.08,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildRows(Color dividerColor) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        // Inset divider (not full-width) matching iOS style
        rows.add(
          Container(
            margin: const EdgeInsets.only(left: 16),
            height: 0.5,
            color: dividerColor,
          ),
        );
      }
    }
    return rows;
  }
}
