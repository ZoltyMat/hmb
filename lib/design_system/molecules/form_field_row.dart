import 'package:flutter/cupertino.dart';

/// A form row for use inside a `GroupedListSection`.
///
/// Displays a [label] on the left and a [child] widget (e.g. TextField,
/// Switch, Dropdown) on the right. Enforces a 44pt minimum touch target
/// height per Apple HIG.
///
/// ```dart
/// FormFieldRow(
///   label: 'Name',
///   child: CupertinoTextField(
///     placeholder: 'Enter name',
///   ),
/// )
/// ```
class FormFieldRow extends StatelessWidget {
  const FormFieldRow({
    required this.label,
    required this.child,
    this.isRequired = false,
    super.key,
  });

  /// The label displayed on the left side of the row.
  final String label;

  /// The input widget displayed on the right side.
  final Widget child;

  /// When true, appends a red asterisk to the label.
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;

    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.black;

    const requiredColor = CupertinoColors.systemRed;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Label
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: labelColor,
                      letterSpacing: -0.41,
                    ),
                  ),
                  if (isRequired)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: requiredColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Input widget — takes remaining space
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
