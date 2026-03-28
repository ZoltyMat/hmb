import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/spacing.dart';

/// A reusable date picker field that shows a CupertinoDatePicker in a modal
/// bottom sheet when tapped.
///
/// Supports date-only, time-only, and date-and-time modes via [mode].
class HMBDateField extends StatefulWidget {
  final String label;
  final DateTime? initialValue;
  final ValueChanged<DateTime> onChanged;
  final String? Function(DateTime?)? validator;
  final CupertinoDatePickerMode mode;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final bool required;

  const HMBDateField({
    required this.label,
    required this.onChanged,
    this.initialValue,
    this.validator,
    this.mode = CupertinoDatePickerMode.dateAndTime,
    this.minimumDate,
    this.maximumDate,
    this.required = false,
    super.key,
  });

  @override
  State<HMBDateField> createState() => _HMBDateFieldState();
}

class _HMBDateFieldState extends State<HMBDateField> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialValue ?? DateTime.now();
  }

  @override
  void didUpdateWidget(covariant HMBDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != null &&
        widget.initialValue != oldWidget.initialValue) {
      _selectedDate = widget.initialValue!;
    }
  }

  String get _formattedValue {
    switch (widget.mode) {
      case CupertinoDatePickerMode.date:
        return DateFormat('EEE, d MMM yyyy').format(_selectedDate);
      case CupertinoDatePickerMode.time:
        return DateFormat('h:mm a').format(_selectedDate);
      case CupertinoDatePickerMode.dateAndTime:
      case CupertinoDatePickerMode.monthYear:
        return DateFormat('EEE, d MMM yyyy h:mm a').format(_selectedDate);
    }
  }

  Future<void> _showPicker() async {
    var tempDate = _selectedDate;
    final colors = HmbColors.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.secondarySystemBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              // Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: colors.systemRed),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: colors.tint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      setState(() => _selectedDate = tempDate);
                      widget.onChanged(tempDate);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              // Picker
              Expanded(
                child: CupertinoDatePicker(
                  mode: widget.mode,
                  initialDateTime: _selectedDate,
                  minimumDate: widget.minimumDate,
                  maximumDate: widget.maximumDate,
                  use24hFormat: false,
                  onDateTimeChanged: (date) => tempDate = date,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);

    return FormField<DateTime>(
      initialValue: widget.initialValue,
      validator: (_) => widget.validator?.call(_selectedDate),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: _showPicker,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: widget.label,
                border: const OutlineInputBorder(),
                suffixIcon: Icon(
                  CupertinoIcons.calendar,
                  color: colors.tint,
                ),
                errorText: field.errorText,
                errorStyle: TextStyle(
                  color: colors.systemRed,
                  fontSize: 13,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: HmbSpacing.xs),
                child: Text(
                  _formattedValue,
                  style: TextStyle(
                    color: colors.label,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
