/*
 Copyright (c) OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   - Permitted for internal use within your own business or organization only.
   - Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../design_system/atoms/status_badge.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/date_time_ex.dart';
import '../../../util/dart/format.dart';
import '../../../util/dart/local_date.dart';

/// Compact job card for the redesigned grouped job list.
///
/// Shows a status dot, job summary (headline), customer name (subheadline),
/// scheduled date/time, and a [StatusBadge] for the job status.
class ListJobCard extends StatefulWidget {
  final Job job;

  const ListJobCard({required this.job, super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ListJobCardState createState() => _ListJobCardState();
}

class _ListJobCardState extends DeferredState<ListJobCard> {
  late Job job;
  late final JobActivity? nextActivity;
  late final Customer? customer;

  @override
  Future<void> asyncInitState() async {
    job = widget.job;
    nextActivity = await DaoJobActivity().getNextActivityByJob(job.id);
    customer = await DaoCustomer().getById(job.customerId);
  }

  @override
  void didUpdateWidget(ListJobCard old) {
    if (job != widget.job) {
      job = widget.job;
    }
    super.didUpdateWidget(old);
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
        this,
        builder: _buildCard,
      );

  Widget _buildCard(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HmbSpacing.lg,
        vertical: HmbSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status dot
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _statusDotColor(colors),
              ),
            ),
          ),
          const SizedBox(width: HmbSpacing.md),
          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: summary + badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.summary,
                        style: typography.headline.copyWith(
                          color: colors.label,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: HmbSpacing.sm),
                    StatusBadge(
                      label: job.status.displayName,
                      type: _badgeType(),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Customer name
                Text(
                  customer?.name ?? 'No Customer',
                  style: typography.subheadline.copyWith(
                    color: colors.secondaryLabel,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Scheduled date/time
                if (nextActivity != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _scheduledLabel(),
                    style: typography.footnote.copyWith(
                      color: _scheduledColor(colors),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the status dot color based on job status stage.
  Color _statusDotColor(HmbColors colors) {
    switch (job.status) {
      case JobStatus.inProgress:
      case JobStatus.scheduled:
        return colors.systemGreen;
      case JobStatus.prospecting:
        return colors.systemBlue;
      case JobStatus.quoting:
      case JobStatus.awaitingApproval:
      case JobStatus.awaitingPayment:
      case JobStatus.toBeScheduled:
        return colors.systemYellow;
      case JobStatus.completed:
      case JobStatus.toBeBilled:
      case JobStatus.rejected:
        return colors.systemGray;
      case JobStatus.onHold:
      case JobStatus.awaitingMaterials:
        return colors.systemOrange;
    }
  }

  /// Maps job status to a [StatusBadgeType].
  StatusBadgeType _badgeType() {
    switch (job.status.stage) {
      case JobStatusStage.progressing:
        return StatusBadgeType.success;
      case JobStatusStage.preStart:
        return StatusBadgeType.info;
      case JobStatusStage.onHold:
        return StatusBadgeType.warning;
      case JobStatusStage.finalised:
        return StatusBadgeType.neutral;
    }
  }

  String _scheduledLabel() {
    if (nextActivity == null) {
      return '';
    }
    final start = nextActivity!.start;
    if (start.toLocalDate() == LocalDate.today()) {
      return 'Today ${formatTime(start)}';
    }
    return formatDateTime(start);
  }

  Color _scheduledColor(HmbColors colors) {
    if (nextActivity == null) {
      return colors.tertiaryLabel;
    }
    final start = nextActivity!.start;
    if (start.isBefore(DateTime.now())) {
      return colors.systemRed;
    }
    if (start.toLocalDate() == LocalDate.today()) {
      return colors.systemOrange;
    }
    return colors.tertiaryLabel;
  }
}
