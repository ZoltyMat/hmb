/*
 Copyright (C) OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   - Permitted for internal use within your own business or organization only.
   - Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// Extracted editor card — redesigned with GroupedListSection (Phase 4C.2)
import 'dart:async';
import 'dart:io';

import 'package:calendar_view/calendar_view.dart';
import 'package:deferred_state/deferred_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../dao/dao.g.dart';
import '../../../design_system/molecules/grouped_list_section.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../entity/entity.g.dart';
import '../../../entity/flutter_extensions/job_activity_status_ex.dart';
import '../../../util/dart/date_time_ex.dart';
import '../../../util/dart/format.dart';
import '../../../util/dart/local_date.dart';
import '../../../util/flutter/app_title.dart';
import '../../../util/flutter/platform_ex.dart';
import '../../dialog/hmb_file_picker_linux.dart';
import '../../scheduling/schedule_page.dart';
import '../../widgets/fields/hmb_segmented_field.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_chip.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/icons/circle.dart';
import '../../widgets/icons/help_button.dart';
import '../../widgets/icons/hmb_edit_icon.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/media/photo_gallery.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/select/hmb_select_contact.dart';
import '../../widgets/select/hmb_select_customer.dart';
import '../../widgets/select/hmb_select_site.dart';
import '../../widgets/text/hmb_expanding_text_block.dart';
import 'fsm_status_picker.dart';
import 'list_job_screen.dart';

class EditJobCard extends StatefulWidget {
  final Job? job;
  final Customer? customer;

  // Controllers
  final TextEditingController summaryController;
  final TextEditingController descriptionController;
  final TextEditingController notesController;
  final TextEditingController assumptionController;
  final TextEditingController hourlyRateController;
  final TextEditingController bookingFeeController;

  // Focus nodes
  final FocusNode summaryFocusNode;
  final FocusNode descriptionFocusNode;
  final FocusNode notesFocusNode;
  final FocusNode assumptionFocusNode;
  final FocusNode hourlyRateFocusNode;
  final FocusNode bookingFeeFocusNode;

  // Billing type state is owned by parent (so saves still work there).
  final BillingType selectedBillingType;
  final ValueChanged<BillingType> onBillingTypeChanged;

  const EditJobCard({
    required this.job,
    required this.customer,
    required this.summaryController,
    required this.descriptionController,
    required this.notesController,
    required this.assumptionController,
    required this.hourlyRateController,
    required this.bookingFeeController,
    required this.summaryFocusNode,
    required this.descriptionFocusNode,
    required this.notesFocusNode,
    required this.assumptionFocusNode,
    required this.hourlyRateFocusNode,
    required this.bookingFeeFocusNode,
    required this.selectedBillingType,
    required this.onBillingTypeChanged,
    super.key,
  });

  @override
  State<EditJobCard> createState() => _EditJobCardState();
}

class _EditJobCardState extends DeferredState<EditJobCard> {
  // Version counters to force TextAreaEditors to refresh
  var _descriptionVersion = 0;
  var _notesVersion = 0;
  var _assumptionVersion = 0;

  Job? job;

  // Pre-loaded data (replaces FutureBuilderEx for attachments, parties summary)
  String _partiesSummary = '';
  List<JobAttachment> _attachments = [];

  // Collapsible section state
  bool _detailsExpanded = true;
  bool _billingExpanded = false;
  bool _scheduleExpanded = false;
  bool _notesExpanded = false;
  bool _attachmentsExpanded = false;
  bool _photosExpanded = false;

  @override
  void initState() {
    super.initState();
    job = widget.job;

    // Auto-expand billing and schedule when editing an existing job.
    if (widget.job != null) {
      _scheduleExpanded = true;
      _billingExpanded = true;
    }
  }

  @override
  Future<void> asyncInitState() async {
    if (widget.job != null) {
      await DaoJob().markLastActive(widget.job!.id);
    }
    await _refreshPreloadedData();
  }

  /// Load parties summary and attachments in a single async call.
  Future<void> _refreshPreloadedData() async {
    final results = await Future.wait([
      _buildPartiesSummary(),
      if (job != null) DaoJobAttachment().getByJob(job!.id),
    ]);

    if (!mounted) return;
    setState(() {
      _partiesSummary = results[0] as String;
      if (job != null && results.length > 1) {
        _attachments = results[1] as List<JobAttachment>;
      }
    });
  }

  /// Refresh just the parties summary (called when selections change).
  Future<void> _refreshPartiesSummary() async {
    final summary = await _buildPartiesSummary();
    if (!mounted) return;
    setState(() => _partiesSummary = summary);
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: HmbSpacing.sm),
        _buildDetailsSection(),
        _buildPartiesSection(),
        _buildBillingSection(),
        if (job != null) _buildScheduleSection(),
        _buildNotesSection(),
        if (job != null) _buildAttachmentsSection(),
        if (job != null) _buildPhotosSection(),
        const SizedBox(height: HmbSpacing.xxl),
      ],
    ),
  );

  // ===========================================================================
  // DETAILS SECTION
  // ===========================================================================

  Widget _buildDetailsSection() => _CollapsibleGroupedSection(
    header: 'Details',
    expanded: _detailsExpanded,
    onToggle: () => setState(() => _detailsExpanded = !_detailsExpanded),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: _showSummary(),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: _chooseSite(),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: _chooseStatus(job),
      ),
    ],
  );

  Widget _showSummary() => HMBTextField(
    key: const Key('jobSummary'),
    focusNode: widget.summaryFocusNode,
    autofocus: isNotMobile,
    controller: widget.summaryController,
    labelText: 'Job Summary',
    textCapitalization: TextCapitalization.sentences,
    required: true,
    keyboardType: TextInputType.name,
  );

<<<<<<< HEAD
  Widget _chooseStatus(Job? job) => Row(
    children: [
      Text(
        'Status:',
        style: HmbTypography.of(context).headline.copyWith(
          color: HmbColors.of(context).label,
        ),
      ),
      const SizedBox(width: HmbSpacing.sm),
      JuneBuilder(
        SelectJobStatus.new,
        builder: (selectedJobStatus) => HMBChip(
          label:
              selectedJobStatus.jobStatus?.displayName ??
              JobStatus.startingStatus.displayName,
        ),
      ),
      const SizedBox(width: HmbSpacing.sm),
      HMBButton(
        enabled: job != null,
        label: 'Update',
        hint: 'Change job status',
        onPressed: () async {
          await showJobStatusDialog(context, job!);
          setState(() {});
        },
      ),
    ],
  );

  JuneBuilder<SelectedSite> _chooseSite() => JuneBuilder(
    () => SelectedSite()..siteId = job?.siteId,
    builder: (state) => HMBSelectSite(
      key: ValueKey(state.siteId),
      initialSite: state,
      customer: widget.customer,
      onSelected: (site) {
        June.getState(SelectedSite.new).siteId = site?.id;
      },
    ),
  );

  // ===========================================================================
  // PARTIES SECTION (collapsible ExpansionTile inside GroupedListSection)
  // ===========================================================================

  Widget _buildPartiesSection() => GroupedListSection(
    header: 'Parties',
    children: [
      ExpansionTile(
        title: Text(
          _partiesSummary,
          style: HmbTypography.of(context).subheadline.copyWith(
            color: HmbColors.of(context).secondaryLabel,
          ),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _chooseCustomer(),
          _chooseTenantContact(),
          _chooseContact(),
          _chooseBillingParty(),
          if (June.getState(SelectedBillingParty.new).billingParty ==
              BillingParty.referrer) ...[
            _chooseReferrerCustomer(),
            _chooseReferrerContact(),
          ],
          _chooseBillingContact(),
        ],
      ),
    ],
  );

  // ===========================================================================
  // BILLING SECTION
  // ===========================================================================

  Widget _buildBillingSection() => _CollapsibleGroupedSection(
    header: 'Billing',
    expanded: _billingExpanded,
    onToggle: () => setState(() => _billingExpanded = !_billingExpanded),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: _chooseBillingType(),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: _showHourlyRate(),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: _showBookingFee(),
      ),
    ],
  );

  Widget _chooseBillingType() =>
      HMBSegmentedField<BillingType>(
        label: 'Billing Type',
        options: BillingType.values,
        selected: widget.selectedBillingType,
        labelBuilder: (value) => value.display,
        onChanged: (billingType) {
          widget.onBillingTypeChanged(billingType);
          setState(() {});
        },
      );

  Widget _showHourlyRate() => HMBTextField(
    key: const Key('hourlyRate'),
    controller: widget.hourlyRateController,
    focusNode: widget.hourlyRateFocusNode,
    labelText: 'Hourly Rate',
    keyboardType: TextInputType.number,
  );

  Widget _showBookingFee() =>
      HMBTextField(
        key: const Key('bookingFee'),
        controller: widget.bookingFeeController,
        focusNode: widget.bookingFeeFocusNode,
        labelText: 'Booking Fee',
        keyboardType: TextInputType.number,
      ).help('Booking Fee', '''
A once off fee applied to this Job.

You can set a default booking fee from System | Billing screen''');

  // ===========================================================================
  // SCHEDULE SECTION
  // ===========================================================================

  Widget _buildScheduleSection() => _CollapsibleGroupedSection(
    header: 'Schedule',
    expanded: _scheduleExpanded,
    onToggle: () => setState(() => _scheduleExpanded = !_scheduleExpanded),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(child: _buildScheduleButton()),
            const SizedBox(width: HmbSpacing.sm),
            Expanded(child: _buildActivityButton()),
          ],
        ),
      ),
    ],
  );

  Widget _buildScheduleButton() => HMBButton(
    label: 'Schedule',
    hint: 'Schedule this Job',
    onPressed: () async {
      if ((await DaoSystem().get()).getOperatingHours().noOpenDays()) {
        HMBToast.error(
          'Before you Schedule a job, you must first set your '
          "opening hours from the 'System | Business' page.",
        );
        return;
      }
      final jobId = job!.id;
      final firstActivity = await _getFirstActivity(jobId);
      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => SchedulePage(
            defaultView: ScheduleView.week,
            initialActivityId: firstActivity?.id,
            defaultJob: jobId,
            dialogMode: true,
          ),
          fullscreenDialog: true,
        ),
      );

      setAppTitle(JobListScreen.pageTitle);
      June.getState(ActivityJobsState.new).setState();

      await _checkIfScheduled();
      setState(() {});
    },
  );

  Future<void> _checkIfScheduled() async {
    final tempJob = await DaoJob().getById(job?.id);
    if (tempJob!.status == JobStatus.scheduled) {
      June.getState(SelectJobStatus.new)
        ..jobStatus = JobStatus.scheduled
        ..setState();
    }
  }

  Future<JobActivity?> _getFirstActivity(int jobId) async {
    final now = DateTime.now();
    final dao = DaoJobActivity();
    final list = await dao.getByJob(jobId);
    for (final e in list) {
      if (e.start.isAfter(now)) {
        return e;
      }
    }
    return null;
  }

  Widget _buildActivityButton() => JuneBuilder(
    ActivityJobsState.new,
    builder: (context) => FutureBuilderEx<List<JobActivity>>(
      future: DaoJobActivity().getByJob(job!.id),
      builder: (context, activities) {
        final jobActivities = activities ?? [];
        final nextActivity = _nextActivity(jobActivities);
        final nextWhen = nextActivity == null
            ? ''
            : formatDateTimeAM(nextActivity.start);
        return ElevatedButton(
          onPressed: () async {
            final selected = await _showActivityDialog(jobActivities);
            if (!context.mounted || selected == null) {
              return;
            }

            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SchedulePage(
                  defaultView: ScheduleView.week,
                  initialActivityId: selected.id,
                  defaultJob: job?.id,
                  dialogMode: true,
                ),
                fullscreenDialog: true,
              ),
            );

            setAppTitle(JobListScreen.pageTitle);
            June.getState(ActivityJobsState.new).setState();
            await _checkIfScheduled();
          },
          child: HMBRow(
            children: [
              if (nextActivity != null)
                Circle(
                    color: nextActivity.status.color, child: const Text('')),
              Text(
                'Next: $nextWhen',
                style: TextStyle(
                  color: nextActivity != null && _isToday(nextActivity.start)
                      ? Colors.orangeAccent
                      : Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<JobActivity?> _showActivityDialog(List<JobActivity> activities) {
    final today = DateTime.now().withoutTime;
    return showDialog<JobActivity>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Open an Activity'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(_nextActivity(activities)),
            child: Text('Next Activity: ${_nextActivityWhen(activities)}'),
          ),
          for (final a in activities)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(a),
              child: HMBRow(
                children: [
                  Circle(color: a.status.color, child: const Text('')),
                  Text(
                    _activityDisplay(a),
                    style: TextStyle(
                      decoration: a.start.isBefore(today)
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _nextActivityWhen(List<JobActivity> activities) {
    final next = _nextActivity(activities);
    return next == null ? '' : formatDateTimeAM(next.start);
  }

  JobActivity? _nextActivity(List<JobActivity> list) {
    final today = LocalDate.today();
    for (final e in list) {
      final ld = e.start.toLocalDate();
      if (ld.isAfter(today) || ld == today) {
        return e;
      }
    }
    return null;
  }

  bool _isToday(DateTime dt) => dt.toLocalDate().isToday;

  String _activityDisplay(JobActivity e) => formatDateTimeAM(e.start);

  // ===========================================================================
  // NOTES SECTION (Description, Internal Notes, Assumptions)
  // ===========================================================================

  Widget _buildNotesSection() => _CollapsibleGroupedSection(
    header: 'Notes',
    expanded: _notesExpanded,
    onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
    children: [
      _buildDescription(),
      _buildNotes(),
      _buildAssumption(),
    ],
  );

  Widget _buildDescription() => _TextBlockRow(
    label: 'Description',
    text: widget.descriptionController.text,
    version: _descriptionVersion,
    onEdit: () async {
      final text = await _showTextAreaEditDialog(
        widget.descriptionController.text,
        'Description',
      );
      if (text != null) {
        widget.descriptionController.text = text;
      }
      setState(() => _descriptionVersion++);
    },
  );

  Widget _buildNotes() => _TextBlockRow(
    label: 'Internal Notes',
    text: widget.notesController.text,
    version: _notesVersion,
    onEdit: () async {
      final text = await _showTextAreaEditDialog(
        widget.notesController.text,
        'Notes',
      );
      if (text != null) {
        widget.notesController.text = text;
      }
      setState(() => _notesVersion++);
    },
  );

  Widget _buildAssumption() => _TextBlockRow(
    label: 'Assumptions',
    text: widget.assumptionController.text,
    version: _assumptionVersion,
    helpTitle: 'Assumptions',
    helpBody: 'Detail the assumptions your pricing is based on. '
        'Assumptions are shown on the Quote.',
    onEdit: () async {
      final text = await _showTextAreaEditDialog(
        widget.assumptionController.text,
        'Assumptions',
      );
      if (text != null) {
        widget.assumptionController.text = text;
      }
      setState(() => _assumptionVersion++);
    },
  );

  // ===========================================================================
  // ATTACHMENTS SECTION
  // ===========================================================================

  Widget _buildAttachmentsSection() {
    final colors = HmbColors.of(context);

    return _CollapsibleGroupedSection(
      header: 'Attachments',
      trailing: HMBButton.small(
        label: 'Add File',
        hint: 'Attach an existing file to this job.',
        onPressed: () async {
          await _pickAndAttachFile();
        },
      ),
      expanded: _attachmentsExpanded,
      onToggle: () =>
          setState(() => _attachmentsExpanded = !_attachmentsExpanded),
      children: [
        if (_attachments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HmbSpacing.lg,
              vertical: HmbSpacing.md,
            ),
            child: Text(
              'No attachments',
              style: HmbTypography.of(context).body.copyWith(
                color: colors.tertiaryLabel,
              ),
            ),
          )
        else
          ..._attachments.map(
            (attachment) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HmbSpacing.lg,
                vertical: HmbSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.attach_file,
                    size: 18,
                    color: colors.secondaryLabel,
                  ),
                  const SizedBox(width: HmbSpacing.sm),
                  Expanded(
                    child: Text(
                      attachment.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: HmbTypography.of(context).body.copyWith(
                        color: colors.label,
                      ),
                    ),
                  ),
                  HMBButton.small(
                    label: 'Open',
                    hint: 'Open this attachment in an external app.',
                    onPressed: () async {
                      await _openAttachment(attachment);
                    },
                  ),
                  HMBButton.small(
                    label: 'Remove',
                    hint: 'Remove this attachment from the job.',
                    onPressed: () async {
                      await DaoJobAttachment().delete(attachment.id);
                      _attachments =
                          await DaoJobAttachment().getByJob(job!.id);
                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickAndAttachFile() async {
    if (job == null) {
      return;
    }

    String? selectedFilePath;
    if (Platform.isLinux) {
      selectedFilePath = await HMBFilePickerDialog().show(context);
    } else {
      final result = await FilePicker.platform.pickFiles();
      selectedFilePath = result?.files.single.path;
    }

    if (selectedFilePath == null) {
      return;
    }

    final attachment = JobAttachment.forInsert(
      jobId: job!.id,
      filePath: selectedFilePath,
      displayName: p.basename(selectedFilePath),
    );

    await DaoJobAttachment().insert(attachment);
    if (mounted) {
      _attachments = await DaoJobAttachment().getByJob(job!.id);
      setState(() {});
    }
  }

  Future<void> _openAttachment(JobAttachment attachment) async {
    final uri = Uri.file(attachment.filePath);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      HMBToast.error('Unable to open attachment.');
    }
  }

  // ===========================================================================
  // PHOTOS SECTION
  // ===========================================================================

  Widget _buildPhotosSection() => _CollapsibleGroupedSection(
    header: 'Photos',
    expanded: _photosExpanded,
    onToggle: () => setState(() => _photosExpanded = !_photosExpanded),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: PhotoGallery.forJob(job: job!),
      ),
    ],
  );

  // ===========================================================================
  // PARTIES HELPERS (unchanged logic)
  // ===========================================================================

  Future<String> _buildPartiesSummary() async {
    final selectedCustomerId = June.getState(SelectedCustomer.new).customerId;
    final owner = await DaoCustomer().getById(
      selectedCustomerId ?? widget.customer?.id,
    );
    final referrer = await DaoCustomer().getById(
      June.getState(SelectedReferrerCustomer.new).customerId,
    );
    final tenant = await DaoContact().getById(
      June.getState(SelectedTenantContact.new).contactId,
    );

    final selected = <String>[];
    if (owner != null) {
      selected.add('Owner: ${owner.name}');
    }
    if (referrer != null) {
      selected.add('Referred By: ${referrer.name}');
    }
    if (tenant != null) {
      selected.add('Tenant: ${tenant.fullname}');
    }

    if (selected.isEmpty) {
      return 'No parties selected';
    }
    return selected.join(' | ');
  }

  Widget _chooseBillingContact() => JuneBuilder(
    SelectedBillingParty.new,
    builder: (billingPartyState) => FutureBuilderEx<Customer?>(
      future: billingPartyState.billingParty == BillingParty.referrer
          ? DaoCustomer().getById(
              June.getState(SelectedReferrerCustomer.new).customerId,
            )
          : Future.value(widget.customer),
      builder: (context, billingCustomer) => JuneBuilder(
        JobBillingContact.new,
        builder: (state) => HMBSelectContact(
          key: ValueKey('${state.contactId}-${billingCustomer?.id}'),
          title: 'Billing Contact',
          initialContact: state.contactId,
          customer: billingCustomer,
          onSelected: (contact) {
            June.getState(JobBillingContact.new).contactId = contact?.id;
          },
        ),
      ),
    ),
  );

  Widget _chooseContact() => FutureBuilderEx<List<Contact>>(
    future: _primaryContactChoices(),
    builder: (context, contacts) => JuneBuilder(
      SelectedContact.new,
      builder: (selectedContact) => HMBDroplist<Contact>(
        title: 'Primary Contact',
        selectedItem: () => DaoContact().getById(selectedContact.contactId),
        items: (filter) async {
          final value = filter?.trim().toLowerCase() ?? '';
          if (value.isEmpty) {
            return contacts ?? [];
          }
          return (contacts ?? []).where((contact) {
            final name = '${contact.firstName} ${contact.surname}'
                .toLowerCase();
            final email = contact.emailAddress.toLowerCase();
            return name.contains(value) || email.contains(value);
          }).toList();
        },
        format: _displayContact,
        required: false,
        onChanged: (contact) {
          June.getState(SelectedContact.new).contactId = contact?.id;
        },
      ),
    ),
  );

  Future<List<Contact>> _primaryContactChoices() async {
    final ids = <int>{};
    final contacts = <Contact>[];

    Future<void> addCustomerContacts(int? customerId) async {
      if (customerId == null) {
        return;
      }
      final list = await DaoContact().getByCustomer(customerId);
      for (final contact in list) {
        if (ids.add(contact.id)) {
          contacts.add(contact);
        }
      }
    }

    final selectedCustomerId = June.getState(SelectedCustomer.new).customerId;
    final customerId = selectedCustomerId ?? widget.customer?.id;
    await addCustomerContacts(customerId);
    await addCustomerContacts(
      June.getState(SelectedReferrerCustomer.new).customerId,
    );
    return contacts;
  }

  String _displayContact(Contact contact) {
    final fullName = '${contact.firstName} ${contact.surname}'.trim();
    if (contact.emailAddress.isEmpty) {
      return fullName;
    }
    return '$fullName (${contact.emailAddress})';
  }

  Widget _chooseCustomer() => HMBSelectCustomer(
    required: true,
    selectedCustomer: June.getState(SelectedCustomer.new),
    onSelected: (customer) {
      June.getState(SelectedCustomer.new).customerId = customer?.id;

      // Clear dependent selections
      June.getState(SelectedSite.new).siteId = null;
      June.getState(SelectedContact.new).contactId = null;
      June.getState(SelectedTenantContact.new).contactId = null;

      // Reset billing contact to the customer's default
      if (June.getState(SelectedBillingParty.new).billingParty ==
          BillingParty.customer) {
        June.getState(JobBillingContact.new).contactId =
            customer?.billingContactId;
      }

      // Pull the customer's rate into the text field
      widget.hourlyRateController.text =
          customer?.hourlyRate.amount.toString() ?? '';
      _refreshPartiesSummary();
    },
  );

  Widget _chooseReferrerCustomer() => HMBDroplist<Customer>(
    title: 'Referred By',
    selectedItem: () => DaoCustomer().getById(
      June.getState(SelectedReferrerCustomer.new).customerId,
    ),
    items: (filter) => DaoCustomer().getByFilter(filter),
    format: (customer) => customer.name,
    required: false,
    onChanged: (customer) {
      June.getState(SelectedReferrerCustomer.new).customerId = customer?.id;
      June.getState(SelectedReferrerContact.new).contactId = null;
      if (June.getState(SelectedBillingParty.new).billingParty ==
          BillingParty.referrer) {
        June.getState(JobBillingContact.new).contactId =
            customer?.billingContactId;
      }
      _refreshPartiesSummary();
    },
  );

  Widget _chooseReferrerContact() => FutureBuilderEx<Customer?>(
    future: DaoCustomer().getById(
      June.getState(SelectedReferrerCustomer.new).customerId,
    ),
    builder: (context, referrerCustomer) => HMBSelectContact(
      title: 'Referrer Contact',
      key: ValueKey(
        '${June.getState(SelectedReferrerContact.new).contactId}'
        '-${referrerCustomer?.id}',
      ),
      initialContact: June.getState(SelectedReferrerContact.new).contactId,
      customer: referrerCustomer,
      onSelected: (contact) {
        June.getState(SelectedReferrerContact.new).contactId = contact?.id;
      },
    ),
  );

  Widget _chooseTenantContact() => FutureBuilderEx<Customer?>(
    future: DaoCustomer().getById(
      June.getState(SelectedCustomer.new).customerId ?? widget.customer?.id,
    ),
    builder: (context, customer) => JuneBuilder(
      SelectedTenantContact.new,
      builder: (tenantState) => HMBSelectContact(
        title: 'Tenant',
        key: ValueKey('${tenantState.contactId}-${customer?.id}'),
        initialContact: tenantState.contactId,
        customer: customer,
        onSelected: (contact) {
          tenantState.contactId = contact?.id;
        },
      ),
    ),
  );

  Widget _chooseBillingParty() => HMBDroplist<BillingParty>(
    title: 'Bill To',
    selectedItem: () async =>
        June.getState(SelectedBillingParty.new).billingParty,
    items: (filter) async => BillingParty.values,
    format: (party) => party.display,
    onChanged: (value) async {
      final billingParty = value ?? BillingParty.customer;
      June.getState(SelectedBillingParty.new).billingParty = billingParty;

      final billingCustomer = billingParty == BillingParty.referrer
          ? await DaoCustomer().getById(
              June.getState(SelectedReferrerCustomer.new).customerId,
            )
          : widget.customer;
      June.getState(JobBillingContact.new).contactId =
          billingCustomer?.billingContactId;
      setState(() {});
    },
  );

  // ===========================================================================
  // TEXT AREA EDIT DIALOG
  // ===========================================================================

  Future<String?> _showTextAreaEditDialog(String text, String title) {
    final localController = TextEditingController(text: text);
    return showDialog<String?>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: HMBColumn(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 300,
                child: HMBTextArea(
                  labelText: title,
                  controller: localController,
                  focusNode: FocusNode(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  HMBButton(
                    label: 'Cancel',
                    hint: 'Close the dialog without saving any changes',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  HMBButton(
                    label: 'Save',
                    hint: 'Save any changes',
                    onPressed: () =>
                        Navigator.of(context).pop(localController.text),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

/// A collapsible wrapper around [GroupedListSection] with a tap-to-toggle
/// header chevron. Preserves the iOS Settings visual style while adding
/// expandable behaviour.
class _CollapsibleGroupedSection extends StatelessWidget {
  final String header;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  final Widget? trailing;

  const _CollapsibleGroupedSection({
    required this.header,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tappable header row
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 32,
              right: 32,
              top: 24,
              bottom: 6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    header.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: colors.secondaryLabel,
                      letterSpacing: -0.08,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colors.tertiaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Animated collapsible body
        AnimatedCrossFade(
          firstChild: GroupedListSection(children: children),
          secondChild: const SizedBox.shrink(),
          crossFadeState:
              expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}

/// A row showing a text block label with an edit icon, used inside the
/// Notes section for Description, Internal Notes, and Assumptions.
class _TextBlockRow extends StatelessWidget {
  final String label;
  final String text;
  final int version;
  final Future<void> Function() onEdit;
  final String? helpTitle;
  final String? helpBody;

  const _TextBlockRow({
    required this.label,
    required this.text,
    required this.version,
    required this.onEdit,
    this.helpTitle,
    this.helpBody,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    Widget labelWidget = Padding(
      padding: const EdgeInsets.only(
        left: HmbSpacing.lg,
        right: HmbSpacing.lg,
        top: HmbSpacing.md,
      ),
      child: Text(
        label,
        style: typography.headline.copyWith(color: colors.label),
      ),
    );

    if (helpTitle != null && helpBody != null) {
      labelWidget = Row(
        children: [
          labelWidget,
          const Spacer(),
          HelpButton.text(
            tooltip: helpTitle!,
            dialogTitle: helpTitle!,
            helpText: helpBody,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: labelWidget),
            Padding(
              padding: const EdgeInsets.only(
                right: HmbSpacing.sm,
                top: HmbSpacing.sm,
              ),
              child: HMBEditIcon(onPressed: onEdit, hint: 'Edit $label'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.lg,
            vertical: HmbSpacing.sm,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            child: HMBExpandingTextBlock(text, key: ValueKey(version)),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// JUNE STATE OBJECTS (unchanged -- kept at bottom of file)
// =============================================================================

/// State object to persist the selected billing contact ID across this screen.
class JobBillingContact extends JuneState {
  int? _contactId;

  int? get contactId => _contactId;

  set contactId(int? value) {
    _contactId = value;
    setState();
  }
}

/// State object to persist the selected contact ID across screens.
class SelectedContact extends JuneState {
  int? _contactId;

  SelectedContact();

  int? get contactId => _contactId;

  set contactId(int? value) {
    _contactId = value;
    setState();
  }
}

class SelectedReferrerCustomer extends JuneState {
  int? _customerId;

  int? get customerId => _customerId;

  set customerId(int? value) {
    _customerId = value;
    setState();
  }
}

class SelectedReferrerContact extends JuneState {
  int? _contactId;

  int? get contactId => _contactId;

  set contactId(int? value) {
    _contactId = value;
    setState();
  }
}

class SelectedTenantContact extends JuneState {
  int? _contactId;

  int? get contactId => _contactId;

  set contactId(int? value) {
    _contactId = value;
    setState();
  }
}

class SelectedBillingParty extends JuneState {
  BillingParty _billingParty = BillingParty.customer;

  BillingParty get billingParty => _billingParty;

  set billingParty(BillingParty value) {
    _billingParty = value;
    setState();
  }
}

class SelectJobStatus extends JuneState {
  JobStatus? _jobStatus = JobStatus.startingStatus;
  SelectJobStatus();

  JobStatus? get jobStatus => _jobStatus;

  set jobStatus(JobStatus? value) {
    _jobStatus = value;
    setState();
  }
}

/// Used to rebuild the activity button when
/// a job gets scheduled.
class ActivityJobsState extends JuneState {}
