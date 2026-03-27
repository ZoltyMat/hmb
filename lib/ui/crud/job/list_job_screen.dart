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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../dao/dao_job.dart';
import '../../../dao/dao_job_activity.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../entity/job.dart';
import '../../../entity/job_activity.dart';
import '../../../entity/job_status_stage.dart';
import '../../../services/job_service.dart';
import '../../../util/dart/date_time_ex.dart';
import '../../../util/dart/local_date.dart';
import '../../widgets/icons/hmb_copy_icon.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/select.g.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../../widgets/widgets.g.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'copy_job.dart';
import 'edit_job_screen.dart';
import 'job_creator.dart';
import 'list_job_card.dart';

/// Section header label for date-grouped job lists.
enum _DateSection {
  today('Today'),
  thisWeek('This Week'),
  later('Later'),
  completed('Completed');

  const _DateSection(this.label);
  final String label;
}

class JobListScreen extends StatefulWidget {
  static const pageTitle = 'Jobs';

  const JobListScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _JobListScreenState createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  static const _kStorageOrderKey = 'job_list_filter_order';
  static const _kStorageShowOldKey = 'job_list_filter_show_old';
  static const _kStorageBillingTypesKey = 'job_list_filter_billing_types';

  var _showOldJobs = false;
  JobOrder _order = JobOrder.active;
  var _selectedBillingTypes = <BillingType>{
    BillingType.timeAndMaterial,
    BillingType.fixedPrice,
  };
  final _storage = const FlutterSecureStorage();

  List<Widget> _buildActionItems(Job job) => [
    HMBCopyIcon(
      hint: 'Copy job & move tasks',
      onPressed: () => _onCopyAndMovePressed(job),
    ),
  ];

  final _entityListKey = GlobalKey<EntityListScreenState<Job>>();

  @override
  void initState() {
    super.initState();
    unawaited(_restoreFilters());
  }

  Future<void> _restoreFilters() async {
    final savedOrder = await _storage.read(key: _kStorageOrderKey);
    final savedShowOld = await _storage.read(key: _kStorageShowOldKey);
    final savedBilling = await _storage.read(key: _kStorageBillingTypesKey);

    if (!mounted) {
      return;
    }

    setState(() {
      if (savedOrder != null) {
        _order = JobOrder.values.firstWhere(
          (value) => value.name == savedOrder,
          orElse: () => JobOrder.active,
        );
      }
      _showOldJobs = savedShowOld == 'true';

      if (savedBilling != null && savedBilling.trim().isNotEmpty) {
        final names = savedBilling.split(',').toSet();
        final restored = BillingType.values
            .where((type) => names.contains(type.name))
            .toSet();
        if (restored.isNotEmpty) {
          _selectedBillingTypes = restored;
        }
      }
    });

    await _entityListKey.currentState?.refresh();
  }

  Future<void> _persistFilters() async {
    await _storage.write(key: _kStorageOrderKey, value: _order.name);
    await _storage.write(
      key: _kStorageShowOldKey,
      value: _showOldJobs ? 'true' : 'false',
    );
    await _storage.write(
      key: _kStorageBillingTypesKey,
      value: _selectedBillingTypes.map((type) => type.name).join(','),
    );
  }

  Future<void> _setFiltersAndRefresh(
    void Function() update,
    void Function() onChange,
  ) async {
    setState(update);
    await _persistFilters();
    onChange();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Surface(
      elevation: SurfaceElevation.e0,
      child: HMBColumn(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: EntityListScreen<Job>(
              entityNameSingular: 'Job',
              entityNamePlural: JobListScreen.pageTitle,
              key: _entityListKey,
              dao: DaoJob(),
              onEdit: (job) => JobEditScreen(job: job),
              fetchList: _fetchJobs,
              listCardTitle: _buildSectionAwareTitle,
              onAdd: () => JobCreator.show(context),
              cardHeight: size.width < 456 ? 130 : 110,
              filterSheetBuilder: _buildFilterSheet,
              isFilterActive: () =>
                  _showOldJobs ||
                  _order != JobOrder.active ||
                  _selectedBillingTypes.length != BillingType.values.length,
              onFilterReset: () {
                _showOldJobs = false;
                _order = JobOrder.active;
                _selectedBillingTypes = {
                  BillingType.timeAndMaterial,
                  BillingType.fixedPrice,
                };
                unawaited(_persistFilters());
              },
              background: (job) async =>
                  SurfaceElevation.e6.color,
              listCard: (job) =>
                  ListJobCard(job: job, key: ValueKey(job.hashCode)),
              buildActionItems: _buildActionItems,
              canEdit: (job) => !job.isStock,
              canDelete: (job) => !job.isStock,
            ),
          ),
        ],
      ),
    );
  }

  /// Cache of next-activity per job, populated during fetch.
  final Map<int, JobActivity?> _activityCache = {};

  /// The ordered section list built after each fetch, used by the title
  /// builder to inject section headers.
  List<_SectionedJob> _sectionedJobs = [];

  Future<List<Job>> _fetchJobs(String? filter) async {
    final jobs = await DaoJob().getByFilter(filter, order: _order);
    final selected = <Job>[];
    for (final job in jobs) {
      if (!_selectedBillingTypes.contains(job.billingType)) {
        continue;
      }
      final stage = job.status.stage;
      if (_showOldJobs) {
        if (stage == JobStatusStage.onHold ||
            stage == JobStatusStage.finalised) {
          selected.add(job);
        }
      } else {
        if (stage == JobStatusStage.preStart ||
            stage == JobStatusStage.progressing) {
          selected.add(job);
        }
      }
    }

    // Pre-fetch next activities for date grouping.
    _activityCache.clear();
    for (final job in selected) {
      _activityCache[job.id] =
          await DaoJobActivity().getNextActivityByJob(job.id);
    }

    // Build section list.
    _sectionedJobs = _buildSections(selected);

    return selected;
  }

  /// Assigns each job to a date section based on its next activity.
  List<_SectionedJob> _buildSections(List<Job> jobs) {
    final today = LocalDate.today();
    final endOfWeek = today.addDays(7 - today.weekday); // Sunday

    final sections = <_SectionedJob>[];
    for (final job in jobs) {
      final section = _classifyJob(job, today, endOfWeek);
      sections.add(_SectionedJob(job: job, section: section));
    }
    return sections;
  }

  _DateSection _classifyJob(Job job, LocalDate today, LocalDate endOfWeek) {
    // Completed/finalised always go to Completed section.
    if (job.status.stage == JobStatusStage.finalised) {
      return _DateSection.completed;
    }

    final activity = _activityCache[job.id];
    if (activity == null) {
      // No scheduled activity -- put in Later.
      return _DateSection.later;
    }

    final actDate = activity.start.toLocalDate();
    if (actDate == today || actDate.isBefore(today)) {
      return _DateSection.today;
    }
    if (actDate.isBeforeOrEqual(endOfWeek)) {
      return _DateSection.thisWeek;
    }
    return _DateSection.later;
  }

  /// Builds the card title. Injects a section header before the first job
  /// in each section.
  Widget _buildSectionAwareTitle(Job job) {
    final idx = _sectionedJobs.indexWhere((s) => s.job.id == job.id);
    if (idx == -1) {
      return HMBCardTitle(job.summary);
    }
    final current = _sectionedJobs[idx];
    final isFirst =
        idx == 0 || _sectionedJobs[idx - 1].section != current.section;

    if (!isFirst) {
      // No section header -- return an empty widget so the card body
      // (ListJobCard) handles all rendering.
      return const SizedBox.shrink();
    }

    return _DateSectionHeader(label: current.section.label);
  }

  Widget _buildFilterSheet(void Function() onChange) => HMBColumn(
    children: [
      HMBDroplist<JobOrder>(
        title: 'Sort Order',
        selectedItem: () async => _order,
        items: (_) async => JobOrder.values,
        format: (order) => order.description,
        onChanged: (order) async {
          if (order == null) {
            return;
          }
          await _setFiltersAndRefresh(() => _order = order, onChange);
        },
      ),
      SwitchListTile(
        title: const Text('Show only Old Jobs'),
        value: _showOldJobs,
        onChanged: (val) async {
          await _setFiltersAndRefresh(() => _showOldJobs = val, onChange);
        },
      ).help(
        'Show only Old Jobs',
        'Only show Jobs that are on hold or have been finalised.',
      ),
      const HMBSpacer(height: true),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Billing Types',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      ...BillingType.values.map(
        (type) => CheckboxListTile(
          value: _selectedBillingTypes.contains(type),
          title: Text(type.display),
          onChanged: (selected) async {
            if (selected == null) {
              return;
            }
            await _setFiltersAndRefresh(() {
              if (selected) {
                _selectedBillingTypes.add(type);
                return;
              }
              if (_selectedBillingTypes.length == 1 &&
                  _selectedBillingTypes.contains(type)) {
                return;
              }
              _selectedBillingTypes.remove(type);
            }, onChange);
          },
        ),
      ),
    ],
  );

  Future<void> _onCopyAndMovePressed(Job job) async {
    final result = await selectTasksToMoveAndDescribeJob(
      context: context,
      job: job,
    );
    if (result == null) {
      return;
    }

    try {
      final newJob = await JobService().copyJobAndMoveTasks(
        job: job,
        tasksToMove: result.selectedTasks,
        summary: result.summary,
      );

      HMBToast.info(
        '''Created Job #${newJob.id} and moved ${result.selectedTasks.length} task(s).''',
      );

      await _entityListKey.currentState!.refresh();
    } catch (e) {
      HMBToast.error(e.toString());
    }
  }
}

/// Internal model pairing a job with its date section.
class _SectionedJob {
  final Job job;
  final _DateSection section;

  const _SectionedJob({required this.job, required this.section});
}

/// A sticky-style section header for date groups.
class _DateSectionHeader extends StatelessWidget {
  final String label;

  const _DateSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: HmbSpacing.lg,
        right: HmbSpacing.lg,
        top: HmbSpacing.lg,
        bottom: HmbSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: typography.footnote.copyWith(
          color: colors.secondaryLabel,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
