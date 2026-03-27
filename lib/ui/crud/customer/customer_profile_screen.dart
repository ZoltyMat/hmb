import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../dao/dao.g.dart';
import '../../../design_system/atoms/status_badge.dart';
import '../../../design_system/molecules/grouped_list_section.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/radius.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../entity/entity.g.dart';
import 'edit_customer_screen.dart';

/// A read-only customer profile screen with hero header, quick actions,
/// and grouped sections for contact info, job history, invoices, and notes.
class CustomerProfileScreen extends StatefulWidget {
  final Customer customer;

  const CustomerProfileScreen({required this.customer, super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState
    extends DeferredState<CustomerProfileScreen> {
  late Customer _customer;
  Contact? _primaryContact;
  Site? _primarySite;
  List<Job> _jobs = [];
  List<Invoice> _invoices = [];

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  @override
  Future<void> asyncInitState() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    final contact = await DaoContact().getPrimaryForCustomer(_customer.id);
    final site = await DaoSite().getPrimaryForCustomer(_customer.id);
    final jobs = await DaoJob().getByCustomer(_customer);

    // Collect all invoices across all jobs.
    final invoices = <Invoice>[];
    for (final job in jobs) {
      final jobInvoices = await DaoInvoice().getByJobId(job.id);
      invoices.addAll(jobInvoices);
    }

    if (mounted) {
      setState(() {
        _primaryContact = contact;
        _primarySite = site;
        _jobs = jobs;
        _invoices = invoices;
      });
    }
  }

  Future<void> _navigateToEdit() async {
    final latest = await DaoCustomer().getById(_customer.id);
    if (!mounted) {
      return;
    }
    final updated = await Navigator.push<Customer?>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerEditScreen(customer: latest),
      ),
    );
    if (updated != null) {
      _customer = updated;
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return Scaffold(
      backgroundColor: colors.groupedBackground,
      appBar: AppBar(
        backgroundColor: colors.groupedBackground,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: colors.tint),
            onPressed: _navigateToEdit,
            tooltip: 'Edit Customer',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _HeroHeader(
              customer: _customer,
              contact: _primaryContact,
              colors: colors,
              typography: typography,
            ),
            const SizedBox(height: HmbSpacing.lg),
            _ContactInfoSection(
              contact: _primaryContact,
              site: _primarySite,
              colors: colors,
              typography: typography,
            ),
            _JobHistorySection(
              jobs: _jobs,
              colors: colors,
              typography: typography,
            ),
            _InvoicesSection(
              invoices: _invoices,
              colors: colors,
              typography: typography,
            ),
            _NotesSection(
              description: _customer.description,
              colors: colors,
              typography: typography,
            ),
            const SizedBox(height: HmbSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero header with avatar, name, and quick action buttons
// ---------------------------------------------------------------------------

class _HeroHeader extends StatelessWidget {
  final Customer customer;
  final Contact? contact;
  final HmbColors colors;
  final HmbTypography typography;

  const _HeroHeader({
    required this.customer,
    required this.contact,
    required this.colors,
    required this.typography,
  });

  String get _initials {
    final parts = customer.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final phone = contact?.bestPhone;
    final email = contact?.emailAddress;
    final hasPhone = phone != null && phone.isNotEmpty;
    final hasEmail = email != null && email.isNotEmpty;

    return Column(
      children: [
        // Avatar
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.tint.withAlpha(30),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            _initials,
            style: typography.title1.copyWith(
              color: colors.tint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: HmbSpacing.md),
        // Name
        Text(
          customer.name,
          style: typography.title1.copyWith(
            color: colors.label,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        // Customer type
        const SizedBox(height: HmbSpacing.xs),
        Text(
          customer.customerType.display,
          style: typography.subheadline.copyWith(color: colors.secondaryLabel),
        ),
        const SizedBox(height: HmbSpacing.lg),
        // Quick action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasPhone)
              _QuickActionButton(
                icon: Icons.phone,
                label: 'Call',
                color: colors.systemGreen,
                onTap: () => _launch('tel:$phone'),
              ),
            if (hasPhone) const SizedBox(width: HmbSpacing.xl),
            if (hasPhone)
              _QuickActionButton(
                icon: Icons.message,
                label: 'Text',
                color: colors.systemBlue,
                onTap: () => _launch('sms:$phone'),
              ),
            if (hasPhone && hasEmail) const SizedBox(width: HmbSpacing.xl),
            if (hasEmail)
              _QuickActionButton(
                icon: Icons.email,
                label: 'Email',
                color: colors.systemOrange,
                onTap: () => _launch('mailto:$email'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _launch(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typography = HmbTypography.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: HmbRadius.medium,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: HmbSpacing.xs),
          Text(
            label,
            style: typography.caption1.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact Info section
// ---------------------------------------------------------------------------

class _ContactInfoSection extends StatelessWidget {
  final Contact? contact;
  final Site? site;
  final HmbColors colors;
  final HmbTypography typography;

  const _ContactInfoSection({
    required this.contact,
    required this.site,
    required this.colors,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (contact != null) {
      final phone = contact!.bestPhone;
      if (phone.isNotEmpty) {
        rows.add(_InfoRow(
          icon: Icons.phone,
          label: 'Phone',
          value: phone,
          colors: colors,
          typography: typography,
        ));
      }
      if (contact!.emailAddress.isNotEmpty) {
        rows.add(_InfoRow(
          icon: Icons.email,
          label: 'Email',
          value: contact!.emailAddress,
          colors: colors,
          typography: typography,
        ));
      }
    }

    if (site != null) {
      final address = _formatAddress(site!);
      if (address.isNotEmpty) {
        rows.add(_InfoRow(
          icon: Icons.location_on,
          label: 'Address',
          value: address,
          colors: colors,
          typography: typography,
        ));
      }
    }

    if (rows.isEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.md,
        ),
        child: Text(
          'No contact information',
          style: typography.body.copyWith(color: colors.tertiaryLabel),
        ),
      ));
    }

    return GroupedListSection(
      header: 'Contact Info',
      children: rows,
    );
  }

  String _formatAddress(Site site) {
    final parts = <String>[
      if (site.addressLine1.isNotEmpty) site.addressLine1,
      if (site.addressLine2.isNotEmpty) site.addressLine2,
      if (site.suburb.isNotEmpty) site.suburb,
      if (site.state.isNotEmpty) '${site.state} ${site.postcode}'.trim(),
    ];
    return parts.join(', ');
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final HmbColors colors;
  final HmbTypography typography;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.lg,
            vertical: HmbSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.secondaryLabel),
              const SizedBox(width: HmbSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: typography.caption1.copyWith(
                        color: colors.secondaryLabel,
                      ),
                    ),
                    Text(
                      value,
                      style: typography.body.copyWith(color: colors.label),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Job History section
// ---------------------------------------------------------------------------

class _JobHistorySection extends StatelessWidget {
  final List<Job> jobs;
  final HmbColors colors;
  final HmbTypography typography;

  const _JobHistorySection({
    required this.jobs,
    required this.colors,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return GroupedListSection(
        header: 'Job History',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HmbSpacing.lg,
              vertical: HmbSpacing.md,
            ),
            child: Text(
              'No jobs yet',
              style: typography.body.copyWith(color: colors.tertiaryLabel),
            ),
          ),
        ],
      );
    }

    // Show most recent jobs first, limit to 10.
    final recentJobs = List<Job>.from(jobs)
      ..sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
    final display = recentJobs.take(10).toList();

    return GroupedListSection(
      header: 'Job History',
      footer: jobs.length > 10
          ? '${jobs.length} jobs total (showing 10 most recent)'
          : null,
      children: display.map((job) => _JobRow(
        job: job,
        colors: colors,
        typography: typography,
      )).toList(),
    );
  }
}

class _JobRow extends StatelessWidget {
  final Job job;
  final HmbColors colors;
  final HmbTypography typography;

  const _JobRow({
    required this.job,
    required this.colors,
    required this.typography,
  });

  StatusBadgeType _badgeType(JobStatus status) {
    switch (status) {
      case JobStatus.completed:
        return StatusBadgeType.success;
      case JobStatus.inProgress:
      case JobStatus.scheduled:
        return StatusBadgeType.info;
      case JobStatus.onHold:
      case JobStatus.awaitingMaterials:
      case JobStatus.awaitingPayment:
      case JobStatus.awaitingApproval:
        return StatusBadgeType.warning;
      case JobStatus.rejected:
        return StatusBadgeType.error;
      case JobStatus.prospecting:
      case JobStatus.quoting:
      case JobStatus.toBeScheduled:
      case JobStatus.toBeBilled:
        return StatusBadgeType.neutral;
    }
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.lg,
            vertical: HmbSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      job.summary,
                      style: typography.body.copyWith(color: colors.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.billingType.display,
                      style: typography.caption1.copyWith(
                        color: colors.tertiaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HmbSpacing.sm),
              StatusBadge(
                label: job.status.displayName,
                type: _badgeType(job.status),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Invoices section
// ---------------------------------------------------------------------------

class _InvoicesSection extends StatelessWidget {
  final List<Invoice> invoices;
  final HmbColors colors;
  final HmbTypography typography;

  const _InvoicesSection({
    required this.invoices,
    required this.colors,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) {
    final paid = invoices.where((i) => i.paid).length;
    final outstanding = invoices.length - paid;
    final totalPaid = invoices
        .where((i) => i.paid)
        .fold(BigInt.zero,
            (sum, i) => sum + i.totalAmount.minorUnits);
    final totalOutstanding = invoices
        .where((i) => !i.paid)
        .fold(BigInt.zero,
            (sum, i) => sum + i.totalAmount.minorUnits);

    return GroupedListSection(
      header: 'Invoices',
      children: [
        _InvoiceSummaryRow(
          label: 'Outstanding',
          count: outstanding,
          amount: _formatMinor(totalOutstanding),
          badgeType: outstanding > 0
              ? StatusBadgeType.warning
              : StatusBadgeType.neutral,
          colors: colors,
          typography: typography,
        ),
        _InvoiceSummaryRow(
          label: 'Paid',
          count: paid,
          amount: _formatMinor(totalPaid),
          badgeType: StatusBadgeType.success,
          colors: colors,
          typography: typography,
        ),
      ],
    );
  }

  String _formatMinor(BigInt minorUnits) {
    final dollars = minorUnits ~/ BigInt.from(100);
    final cents = (minorUnits % BigInt.from(100)).abs();
    final centsStr = '$cents'.padLeft(2, '0');
    return '\$$dollars.$centsStr';
  }
}

class _InvoiceSummaryRow extends StatelessWidget {
  final String label;
  final int count;
  final String amount;
  final StatusBadgeType badgeType;
  final HmbColors colors;
  final HmbTypography typography;

  const _InvoiceSummaryRow({
    required this.label,
    required this.count,
    required this.amount,
    required this.badgeType,
    required this.colors,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.lg,
            vertical: HmbSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$label ($count)',
                  style: typography.body.copyWith(color: colors.label),
                ),
              ),
              StatusBadge(label: amount, type: badgeType),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Notes section
// ---------------------------------------------------------------------------

class _NotesSection extends StatelessWidget {
  final String? description;
  final HmbColors colors;
  final HmbTypography typography;

  const _NotesSection({
    required this.description,
    required this.colors,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) {
    final text = (description ?? '').trim();
    return GroupedListSection(
      header: 'Notes',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.lg,
            vertical: HmbSpacing.md,
          ),
          child: Text(
            text.isEmpty ? 'No notes' : text,
            style: typography.body.copyWith(
              color: text.isEmpty ? colors.tertiaryLabel : colors.label,
            ),
          ),
        ),
      ],
    );
  }
}
