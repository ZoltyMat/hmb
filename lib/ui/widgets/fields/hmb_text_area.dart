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

class HMBTextArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final int maxLines;
  final bool leadingSpace;
  final void Function(String?)? onChanged;
  final int? maxLength;

  const HMBTextArea({
    required this.controller,
    required this.labelText,
    this.onChanged,
    this.maxLines = 6,
    this.focusNode,
    this.leadingSpace = true,
    this.maxLength,
    super.key,
  });

  @override
  Widget build(BuildContext context) => HMBColumn(
    leadingSpace: leadingSpace,
    children: [
      TextFormField(
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        controller: controller,
        focusNode: focusNode,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: onChanged?.call,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          errorStyle: const TextStyle(
            color: Color(0xFFFF3B30), // systemRed
            fontSize: 13,
          ),
        ),
        validator: maxLength == null
            ? null
            : (value) {
                if (value != null && value.length > maxLength!) {
                  return '$labelText must be at most $maxLength characters';
                }
                return null;
              },
      ),
    ],
  );
}
