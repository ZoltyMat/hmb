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

import '../../../util/dart/parse/parse.dart';
import '../../dialog/source_context.dart';
import '../icons/hmb_phone_icon.dart';
import 'hmb_text_field.dart';

class HMBPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String? value)? validator;
  final SourceContext sourceContext;

  const HMBPhoneField({
    required this.labelText,
    required this.controller,
    required this.sourceContext,
    this.validator,
    super.key,
  });

  /// Matches digits, spaces, +, -, parentheses, and periods only.
  static final _phoneCharPattern = RegExp(r'^[0-9\s+\-().]*$');

  @override
  Widget build(BuildContext context) => HMBTextField(
    controller: controller,
    keyboardType: TextInputType.phone,
    maxLength: 20,
    labelText: labelText,
    suffixIcon: HMBPhoneIcon(controller.text, sourceContext: sourceContext),
    validator: (value) {
      if (value != null && value.isNotEmpty) {
        if (!_phoneCharPattern.hasMatch(value)) {
          return 'Phone may only contain digits, spaces, +, -, and ()';
        }
        // Require at least 3 digits for a meaningful phone number
        final digitCount = value.replaceAll(RegExp('[^0-9]'), '').length;
        if (digitCount < 3) {
          return 'Please enter a valid phone number';
        }
      }
      return validator?.call(value);
    },
    onPaste: parsePhone,
  );
}
