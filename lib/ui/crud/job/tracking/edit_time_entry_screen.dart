import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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

import 'package:sqflite_common/sqlite_api.dart';

import '../../../../dao/dao.g.dart';
import '../../../../entity/entity.g.dart';
import '../../../dialog/long_duration_dialog.dart';
import '../../../widgets/fields/fields.g.dart';
import '../../../widgets/hmb_toast.dart';
import '../../../widgets/layout/hmb_column.dart';
import '../../../widgets/select/select.g.dart';
import '../../base_nested/edit_nested_screen.dart';

class TimeEntryEditScreen extends StatefulWidget {
  final Job job;
  final TimeEntry? timeEntry;

  const TimeEntryEditScreen({required this.job, this.timeEntry, super.key});

  @override
  _TimeEntryEditScreenState createState() => _TimeEntryEditScreenState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TimeEntry?>('timeEntry', timeEntry));
  }
}

class _TimeEntryEditScreenState extends DeferredState<TimeEntryEditScreen>
    implements NestedEntityState<TimeEntry> {
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  late TextEditingController _noteController;
  late FocusNode _noteFocusNode;
  var _hasUserEditedEndDate = false;

  @override
  TimeEntry? currentEntity;
  Task? _selectedTask;

  final _selectedSupplier = SelectedSupplier();

  @override
  Future<void> asyncInitState() async {
    if (widget.timeEntry != null) {
      _selectedTask = await DaoTask().getById(widget.timeEntry!.taskId);
      _selectedSupplier.selected = (await DaoSupplier().getById(
        widget.timeEntry!.supplierId,
      ))?.id;
    }
  }

  @override
  void initState() {
    super.initState();
    currentEntity ??= widget.timeEntry;

    final now = DateTime.now();
    _startDateTime = currentEntity?.startTime ?? now;
    _endDateTime = currentEntity?.endTime ??
        now.add(const Duration(minutes: 15));
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
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => NestedEntityEditScreen<TimeEntry, Job>(
      entityName: 'Time Entry',
      dao: DaoTimeEntry(),
      onInsert: (e, tx) => DaoTimeEntry().insert(e!, tx),
      entityState: this,
      crossValidator: () async {
        if (_endDateTime.isBefore(_startDateTime)) {
          HMBToast.error('End must be after the Start');
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
          HMBDroplist<Task>(
            title: 'Select Task',
            selectedItem: () async => _selectedTask,
            items: (filter) => DaoTask().getTasksByJob(widget.job.id),
            format: (task) => task.name,
            onChanged: (task) => setState(() => _selectedTask = task),
          ),

          HMBSelectSupplier(selectedSupplier: _selectedSupplier),

          HMBDateField(
            label: 'Start',
            mode: CupertinoDatePickerMode.dateAndTime,
            initialValue: _startDateTime,
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
            label: 'End',
            mode: CupertinoDatePickerMode.dateAndTime,
            initialValue: _endDateTime,
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
    ),
  );

  @override
  Future<TimeEntry> forUpdate(TimeEntry timeEntry) async => timeEntry.copyWith(
    taskId: _selectedTask!.id,
    supplierId: _selectedSupplier.selected,
    startTime: _startDateTime,
    endTime: _endDateTime,
    note: _noteController.text,
  );

  @override
  Future<TimeEntry> forInsert() async => TimeEntry.forInsert(
    taskId: _selectedTask!.id,
    supplierId: _selectedSupplier.selected,
    startTime: _startDateTime,
    endTime: _endDateTime,
    note: _noteController.text,
  );

  @override
  void refresh() => setState(() {});

  @override
  Future<void> postSave(Transaction transaction, Operation operation) async {}
}
