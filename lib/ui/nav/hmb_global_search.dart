import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../dao/dao.g.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/tokens/spacing.dart';
import '../../design_system/tokens/typography.dart';
import '../../entity/contact.dart';
import '../../entity/customer.dart';
import '../../entity/invoice.dart';
import '../../entity/job.dart';
import '../crud/customer/customer_profile_screen.dart';
import '../crud/job/edit_job_screen.dart';

/// Grouped search result category.
enum _SearchCategory {
  jobs('Jobs', CupertinoIcons.briefcase),
  customers('Customers', CupertinoIcons.person_2),
  contacts('Contacts', CupertinoIcons.person_crop_circle),
  invoices('Invoices', CupertinoIcons.doc_text);

  const _SearchCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// A single search hit with enough info to display and navigate.
class _SearchResult {
  final _SearchCategory category;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SearchResult({
    required this.category,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
}

/// Pull-down global search that searches across jobs, customers, contacts,
/// and invoices. Results are grouped by entity type.
class HMBGlobalSearch extends StatefulWidget {
  const HMBGlobalSearch({super.key});

  @override
  State<HMBGlobalSearch> createState() => _HMBGlobalSearchState();
}

class _HMBGlobalSearchState extends State<HMBGlobalSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  var _results = <_SearchResult>[];
  var _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_performSearch(query.trim()));
    });
  }

  Future<void> _performSearch(String query) async {
    final lowerQuery = query.toLowerCase();
    final results = <_SearchResult>[];

    // Search jobs
    final jobs = await DaoJob().getActiveJobs(null);
    final allJobs = await DaoJob().getAll();
    final combinedJobs = <Job>{...jobs, ...allJobs};
    for (final job in combinedJobs) {
      if (job.summary.toLowerCase().contains(lowerQuery) ||
          job.description.toLowerCase().contains(lowerQuery)) {
        results.add(_SearchResult(
          category: _SearchCategory.jobs,
          title: job.summary,
          subtitle: job.status.displayName,
          onTap: () => unawaited(_navigateToJob(job)),
        ));
      }
    }

    // Search customers
    final customers = await DaoCustomer().getByFilter(null);
    for (final customer in customers) {
      if (customer.name.toLowerCase().contains(lowerQuery) ||
          (customer.description?.toLowerCase().contains(lowerQuery) ?? false)) {
        results.add(_SearchResult(
          category: _SearchCategory.customers,
          title: customer.name,
          subtitle: customer.customerType.display,
          onTap: () => unawaited(_navigateToCustomer(customer)),
        ));
      }
    }

    // Search contacts
    final contacts = await DaoContact().getAll();
    for (final contact in contacts) {
      final fullName =
          '${contact.firstName} ${contact.surname}'.toLowerCase();
      if (fullName.contains(lowerQuery) ||
          contact.emailAddress.toLowerCase().contains(lowerQuery) ||
          contact.mobileNumber.contains(lowerQuery)) {
        results.add(_SearchResult(
          category: _SearchCategory.contacts,
          title: '${contact.firstName} ${contact.surname}',
          subtitle: contact.emailAddress.isNotEmpty
              ? contact.emailAddress
              : contact.mobileNumber,
          onTap: () => unawaited(_navigateToContact(contact)),
        ));
      }
    }

    // Search invoices
    final invoices = await DaoInvoice().getAll();
    for (final invoice in invoices) {
      final invoiceNum = invoice.invoiceNum ?? '';
      final amountStr = invoice.totalAmount.toString();
      if (invoiceNum.toLowerCase().contains(lowerQuery) ||
          amountStr.contains(lowerQuery)) {
        results.add(_SearchResult(
          category: _SearchCategory.invoices,
          title: invoiceNum.isNotEmpty
              ? 'Invoice #$invoiceNum'
              : 'Invoice ${invoice.id}',
          subtitle: '${invoice.totalAmount}'
              ' - ${invoice.paid ? "Paid" : "Unpaid"}',
          onTap: () => unawaited(_navigateToInvoice(invoice)),
        ));
      }
    }

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _navigateToJob(Job job) async {
    _dismiss();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => JobEditScreen(job: job)),
    );
  }

  Future<void> _navigateToCustomer(Customer customer) async {
    _dismiss();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CustomerProfileScreen(customer: customer),
      ),
    );
  }

  Future<void> _navigateToContact(Contact contact) async {
    _dismiss();
    final customers = await DaoCustomer().getByFilter(null);
    for (final customer in customers) {
      final contacts =
          await DaoContact().getByCustomer(customer.id);
      if (contacts.any((c) => c.id == contact.id)) {
        if (mounted) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  CustomerProfileScreen(customer: customer),
            ),
          );
        }
        return;
      }
    }
  }

  Future<void> _navigateToInvoice(Invoice invoice) async {
    _dismiss();
    final job = await DaoJob().getById(invoice.jobId);
    if (job != null && mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => JobEditScreen(job: job),
        ),
      );
    }
  }

  void _dismiss() {
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _results = [];
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.screenHorizontal,
            vertical: HmbSpacing.sm,
          ),
          child: CupertinoSearchTextField(
            controller: _controller,
            focusNode: _focusNode,
            placeholder: 'Search jobs, customers, contacts...',
            onChanged: _onQueryChanged,
            onSuffixTap: _dismiss,
            style: typography.body.copyWith(color: colors.label),
          ),
        ),

        // Results
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(HmbSpacing.xl),
            child: CupertinoActivityIndicator(),
          ),

        if (!_isSearching && _results.isNotEmpty)
          Flexible(
            child: _SearchResultsList(
              results: _results,
              colors: colors,
              typography: typography,
            ),
          ),

        if (!_isSearching &&
            _results.isEmpty &&
            _controller.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(HmbSpacing.xl),
            child: Text(
              'No results found',
              style: typography.subheadline.copyWith(
                color: colors.tertiaryLabel,
              ),
            ),
          ),
      ],
    );
  }
}

/// Displays grouped search results by category.
class _SearchResultsList extends StatelessWidget {
  final List<_SearchResult> results;
  final HmbColors colors;
  final HmbTypography typography;

  const _SearchResultsList({
    required this.results,
    required this.colors,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) {
    // Group results by category
    final grouped = <_SearchCategory, List<_SearchResult>>{};
    for (final result in results) {
      grouped.putIfAbsent(result.category, () => []).add(result);
    }

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: [
        for (final category in _SearchCategory.values)
          if (grouped.containsKey(category)) ...[
            // Section header
            Padding(
              padding: const EdgeInsets.only(
                left: HmbSpacing.screenHorizontal,
                right: HmbSpacing.screenHorizontal,
                top: HmbSpacing.md,
                bottom: HmbSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    category.icon,
                    size: 16,
                    color: colors.secondaryLabel,
                  ),
                  const SizedBox(width: HmbSpacing.sm),
                  Text(
                    category.label,
                    style: typography.footnote.copyWith(
                      color: colors.secondaryLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Results in this category
            ...grouped[category]!.take(5).map(
                  (result) => _SearchResultTile(
                    result: result,
                    colors: colors,
                    typography: typography,
                  ),
                ),
          ],
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final _SearchResult result;
  final HmbColors colors;
  final HmbTypography typography;

  const _SearchResultTile({
    required this.result,
    required this.colors,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: result.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.screenHorizontal,
            vertical: HmbSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.separator,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: typography.body.copyWith(color: colors.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.subtitle != null)
                      Text(
                        result.subtitle!,
                        style: typography.caption1.copyWith(
                          color: colors.secondaryLabel,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: colors.tertiaryLabel,
              ),
            ],
          ),
        ),
      );
}
