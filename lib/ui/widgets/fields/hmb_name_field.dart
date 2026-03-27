/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../layout/layout.g.dart';

/// Capitalises the first letter of each word in the text field.
class HMBNameField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final String? Function(String? value)? validator;
  final bool autofocus;
  final bool required;
  final bool leadingSpace;
  final TextInputType keyboardType;
  final void Function(String?)? onChanged;
  final int? maxLength;

  const HMBNameField({
    required this.controller,
    required this.labelText,
    this.keyboardType = TextInputType.text,
    this.required = false,
    this.validator,
    this.focusNode,
    this.onChanged,
    super.key,
    this.autofocus = false,
    this.leadingSpace = true,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) => HMBColumn(
    leadingSpace: leadingSpace,
    children: [
      TextFormField(
        onChanged: onChanged?.call,
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: keyboardType,
        maxLength: maxLength,
        textCapitalization: TextCapitalization.words,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          errorStyle: const TextStyle(
            color: Color(0xFFFF3B30), // systemRed
            fontSize: 13,
          ),
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'Please enter a $labelText';
          }
          if (maxLength != null &&
              value != null &&
              value.length > maxLength!) {
            return '$labelText must be at most $maxLength characters';
          }
          return validator?.call(value);
        },
      ),
    ],
  );
}
