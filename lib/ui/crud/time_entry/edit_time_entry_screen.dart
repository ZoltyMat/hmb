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

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../../dao/dao_time_entry.dart';
import '../../../entity/task.dart';
import '../../../entity/time_entry.dart';
import '../../dialog/long_duration_dialog.dart';
import '../../widgets/fields/hmb_date_field.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/layout.g.dart' show HMBColumn;
import '../base_nested/edit_nested_screen.dart';

class TimeEntryEditScreen extends StatefulWidget {
  final Task task;
  final TimeEntry? timeEntry;

  const TimeEntryEditScreen({required this.task, super.key, this.timeEntry});

  @override
  // ignore: library_private_types_in_public_api
  _TimeEntryEditScreenState createState() => _TimeEntryEditScreenState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TimeEntry?>('timeEntry', timeEntry));
  }
}

class _TimeEntryEditScreenState extends State<TimeEntryEditScreen>
    implements NestedEntityState<TimeEntry> {
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  late TextEditingController _noteController;
  late FocusNode _noteFocusNode;
  var _hasUserEditedEndDate = false;

  @override
  TimeEntry? currentEntity;

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.timeEntry;
    final now = DateTime.now();
    _startDateTime = currentEntity?.startTime ?? now;
    _endDateTime = currentEntity?.endTime ?? now;
    _noteController = TextEditingController(text: currentEntity?.note ?? '');

    _noteFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NestedEntityEditScreen<TimeEntry, Task>(
    entityName: 'Time Entry',
    dao: DaoTimeEntry(),
    onInsert: (timeEntry, transaction) =>
        DaoTimeEntry().insert(timeEntry!, transaction),
    entityState: this,
    crossValidator: () async {
      if (_endDateTime.isBefore(_startDateTime)) {
        HMBToast.error('End must be after the start');
        return false;
      }

      final duration = _endDateTime.difference(_startDateTime);
      if (duration.inHours > TimeEntry.longDurationHours) {
        final confirm = await showLongDurationDialog(context, duration);
        if (!confirm) {
          return false;
        }
      }

      return true;
    },
    editor: (timeEntry) => HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HMBDateField(
          label: 'Start Time',
          mode: CupertinoDatePickerMode.dateAndTime,
          initialValue: _startDateTime,
          required: true,
          onChanged: (date) {
            setState(() {
              _startDateTime = date;
              if (!_hasUserEditedEndDate && currentEntity == null) {
                _endDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  _endDateTime.hour,
                  _endDateTime.minute,
                );
              }
            });
          },
        ),
        HMBDateField(
          label: 'End Time',
          mode: CupertinoDatePickerMode.dateAndTime,
          initialValue: _endDateTime,
          required: true,
          onChanged: (date) {
            _hasUserEditedEndDate = true;
            setState(() => _endDateTime = date);
          },
          validator: (date) {
            if (date != null && !date.isAfter(_startDateTime)) {
              return 'End time must be after start time';
            }
            return null;
          },
        ),
        HMBTextField(
          controller: _noteController,
          focusNode: _noteFocusNode,
          labelText: 'Note',
        ),
      ],
    ),
  );

  @override
  Future<TimeEntry> forUpdate(TimeEntry timeEntry) async => timeEntry.copyWith(
    taskId: widget.task.id,
    startTime: _startDateTime,
    endTime: _endDateTime,
    note: _noteController.text,
  );

  @override
  Future<TimeEntry> forInsert() async => TimeEntry.forInsert(
    taskId: widget.task.id,
    startTime: _startDateTime,
    endTime: _endDateTime,
    note: _noteController.text,
  );

  @override
  void refresh() {
    setState(() {});
  }

  @override
  Future<void> postSave(Transaction transaction, Operation operation) async {}
}
