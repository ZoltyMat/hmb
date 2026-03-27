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
import 'package:june/june.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/flutter/flutter_util.g.dart';
import '../../widgets/hmb_start_time_entry.dart';
import '../../widgets/layout/layout.g.dart';
import '../job/edit_job_card.dart';

class ListTaskCard extends StatefulWidget {
  final Job job;
  final Task task;
  final bool summary;

  const ListTaskCard({
    required this.job,
    required this.task,
    required this.summary,
    super.key,
  });

  @override
  State<ListTaskCard> createState() => _ListTaskCardState();
}

class _ListTaskCardState extends State<ListTaskCard> {
  late Task activeTask;

  // Loaded async data for full-detail mode
  TaskAccruedValue? _accruedValue;
  String? _assignmentSummary;
  bool _fullDetailsLoaded = false;

  // Loaded async data for summary mode
  Duration? _totalDuration;
  int? _photoCount;
  String? _summaryAssignment;
  bool _summaryLoaded = false;

  @override
  void didUpdateWidget(covariant ListTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task != widget.task || oldWidget.summary != widget.summary) {
      activeTask = widget.task;
      _loadData();
    }
  }

  @override
  void initState() {
    super.initState();
    activeTask = widget.task;
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.summary) {
      await _loadSummaryData();
    } else {
      await _loadFullDetailsData();
    }
  }

  Future<void> _loadFullDetailsData() async {
    final accrued = await DaoTask().getAccruedValueForTask(
      job: widget.job,
      task: activeTask,
      includeBilled: true,
    );
    final assignment = await _getAssignmentSummary(activeTask.id);

    if (!mounted) return;
    setState(() {
      _accruedValue = accrued;
      _assignmentSummary = assignment;
      _fullDetailsLoaded = true;
    });
  }

  Future<void> _loadSummaryData() async {
    final timeEntries = await DaoTimeEntry().getByTask(activeTask.id);
    final photoCount = await _getPhotoCount(activeTask.id);
    final assignment = await _getAssignmentSummary(activeTask.id);

    if (!mounted) return;
    setState(() {
      _totalDuration = timeEntries.fold<Duration>(
        Duration.zero,
        (a, b) => a + b.duration,
      );
      _photoCount = photoCount;
      _summaryAssignment = assignment;
      _summaryLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.summary) {
      return _buildTaskSummary(activeTask);
    } else {
      return _buildFullTaskDetails();
    }
  }

  Widget _buildFullTaskDetails() {
    if (!_fullDetailsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return HMBColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(activeTask.status.name),
        if (_accruedValue != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Earned (Hrs|\$): '
              '${_accruedValue!.earnedLabourHours.format('0.00')}h'
              ' | ${_accruedValue!.earnedMaterialCharges}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (_assignmentSummary != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _assignmentSummary!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        HMBStartTimeEntry(
          key: ValueKey(activeTask),
          task: activeTask,
          onTimerChanged: () => setState(() {}),
          onStart: (job, task) {
            June.getState(SelectJobStatus.new).jobStatus = job.status;
            activeTask = task;
            _loadFullDetailsData();
          },
        ),
      ],
    );
  }

  Widget _buildTaskSummary(Task task) {
    if (!_summaryLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return HMBColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(task.status.name),
        Text(formatDuration(_totalDuration ?? Duration.zero)),
        Text('Photos: ${_photoCount ?? 0}'),
        if (_summaryAssignment != null)
          Text(
            _summaryAssignment!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        HMBStartTimeEntry(
          task: task,
          onStart: (job, task) {
            June.getState(SelectJobStatus.new).jobStatus = job.status;
            activeTask = task;
            _loadSummaryData();
          },
        ),
      ],
    );
  }

  Future<int> _getPhotoCount(int taskId) async =>
      (await DaoPhoto().getByParent(taskId, ParentType.task)).length;

  Future<String?> _getAssignmentSummary(int taskId) async {
    final supplierNames = await DaoWorkAssignmentTask()
        .getSupplierNamesByTaskId(taskId);
    if (supplierNames.isEmpty) {
      return null;
    }
    return 'Assigned to: ${supplierNames.join(', ')}';
  }
}
