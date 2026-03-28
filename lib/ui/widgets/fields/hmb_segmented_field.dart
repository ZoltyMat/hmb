import 'package:flutter/cupertino.dart';

import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/spacing.dart';

/// A segmented control field for selecting from 2-4 options.
///
/// Wraps [CupertinoSegmentedControl] with a label and consistent styling.
///
/// ```dart
/// HMBSegmentedField<BillingType>(
///   label: 'Billing Type',
///   options: BillingType.values,
///   selected: _billingType,
///   labelBuilder: (v) => v.display,
///   onChanged: (v) => setState(() => _billingType = v),
/// )
/// ```
class HMBSegmentedField<T extends Object> extends StatelessWidget {
  final String label;
  final List<T> options;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  const HMBSegmentedField({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);

    final children = <T, Widget>{
      for (final option in options)
        option: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.sm,
            vertical: HmbSpacing.xs,
          ),
          child: Text(
            labelBuilder(option),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HmbSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: colors.secondaryLabel,
            ),
          ),
          const SizedBox(height: HmbSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: CupertinoSegmentedControl<T>(
              children: children,
              groupValue: selected,
              onValueChanged: onChanged,
              borderColor: colors.tint,
              selectedColor: colors.tint,
              unselectedColor: colors.secondarySystemBackground,
              pressedColor: colors.tint.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}
