import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../dao/dao.g.dart';
import '../../../design_system/atoms/status_badge.dart';
import '../../../design_system/molecules/skeleton_list_tile.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/radius.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../entity/contact.dart';
import '../../../entity/customer.dart';
import '../../../entity/job.dart';
import '../../nav/route.dart';
import '../../widgets/widgets.g.dart';
import 'customer_creator.dart';
import 'customer_profile_screen.dart';

/// Redesigned customer list with alphabetical section headers,
/// prominent search, contact info tiles, and swipe-to-call.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends DeferredState<CustomerListScreen>
    with RouteAware {
  List<Customer> _allCustomers = [];
  var _isLoading = true;
  String? _filter;
  final _scrollController = ScrollController();

  @override
  Future<void> asyncInitState() async {
    await _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver
        ..unsubscribe(this)
        ..subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    unawaited(_refresh());
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final list = await DaoCustomer().getByFilter(_filter);
    if (mounted) {
      setState(() {
        _allCustomers = list;
        _isLoading = false;
      });
    }
  }

  /// Group customers by first letter of name, sorted alphabetically.
  Map<String, List<Customer>> _groupedCustomers() {
    final sorted = List<Customer>.from(_allCustomers)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final groups = <String, List<Customer>>{};
    for (final customer in sorted) {
      final letter = customer.name.isNotEmpty
          ? customer.name[0].toUpperCase()
          : '#';
      final key = RegExp('[A-Z]').hasMatch(letter) ? letter : '#';
      groups.putIfAbsent(key, () => []).add(customer);
    }
    return groups;
  }

  Future<void> _onAdd() async {
    final newCustomer = await CustomerCreator.show(context);
    if (newCustomer != null) {
      await _refresh();
    }
  }

  Future<void> _onTapCustomer(Customer customer) async {
    final latest = await DaoCustomer().getById(customer.id);
    if (!mounted || latest == null) {
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerProfileScreen(customer: latest),
      ),
    );
    // Refresh in case edits were made from the profile screen.
    await _refresh();
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
        toolbarHeight: 80,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.screenHorizontal,
          ),
          child: Row(
            children: [
              Expanded(
                child: HMBSearch(
                  label: 'Search Customers',
                  onSearch: (filter) async {
                    _filter = filter?.trim().toLowerCase();
                    await _refresh();
                  },
                ),
              ),
              const SizedBox(width: HmbSpacing.sm),
              HMBButtonAdd(
                onAdd: _onAdd,
                enabled: true,
                hint: 'Add Customer',
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(colors, typography),
    );
  }

  Widget _buildBody(HmbColors colors, HmbTypography typography) {
    if (_isLoading) {
      return ListView.builder(
        itemCount: 8,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) => const SkeletonListTile(),
      );
    }

    if (_allCustomers.isEmpty) {
      return Center(
        child: Text(
          'No customers found.',
          style: typography.body.copyWith(color: colors.secondaryLabel),
        ),
      );
    }

    final grouped = _groupedCustomers();
    final sections = grouped.keys.toList()..sort();

    // Build a flat list with section headers interleaved.
    final items = <_ListItem>[];
    for (final section in sections) {
      items.add(_ListItem.header(section));
      for (final customer in grouped[section]!) {
        items.add(_ListItem.customer(customer));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) {
          return _SectionHeader(letter: item.headerLetter!, colors: colors);
        }
        return _CustomerTile(
          customer: item.customer!,
          colors: colors,
          typography: typography,
          onTap: () => _onTapCustomer(item.customer!),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Internal models
// ---------------------------------------------------------------------------

class _ListItem {
  final String? headerLetter;
  final Customer? customer;

  _ListItem.header(this.headerLetter) : customer = null;
  _ListItem.customer(this.customer) : headerLetter = null;

  bool get isHeader => headerLetter != null;
}

// ---------------------------------------------------------------------------
// Alphabetical section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String letter;
  final HmbColors colors;

  const _SectionHeader({required this.letter, required this.colors});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
          left: HmbSpacing.screenHorizontal + HmbSpacing.xs,
          top: HmbSpacing.lg,
          bottom: HmbSpacing.xs,
        ),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.secondaryLabel,
            letterSpacing: -0.08,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Customer tile with swipe-to-call
// ---------------------------------------------------------------------------

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final HmbColors colors;
  final HmbTypography typography;
  final VoidCallback onTap;

  const _CustomerTile({
    required this.customer,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => FutureBuilderEx<_CustomerTileData>(
        waitingBuilder: (context) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.screenHorizontal,
            vertical: HmbSpacing.xs,
          ),
          child: Container(
            height: 76,
            decoration: BoxDecoration(
              color: colors.secondaryGroupedBackground,
              borderRadius: HmbRadius.grouped,
            ),
          ),
        ),
        future: _loadData(),
        builder: (context, data) {
          if (data == null) {
            return const SizedBox.shrink();
          }

          final phoneNo = data.contact?.bestPhone;
          final hasPhone = phoneNo != null && phoneNo.isNotEmpty;

          var tile = _buildTileContent(data);

          // Wrap in Dismissible for swipe-to-call if phone is available.
          if (hasPhone) {
            tile = Dismissible(
              key: ValueKey('call-${customer.id}'),
              direction: DismissDirection.startToEnd,
              confirmDismiss: (_) async {
                final uri = Uri(scheme: 'tel', path: phoneNo);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
                return false; // Don't actually dismiss the tile
              },
              background: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: HmbSpacing.screenHorizontal,
                  vertical: HmbSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.systemGreen,
                  borderRadius: HmbRadius.grouped,
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: HmbSpacing.lg),
                child: const Icon(Icons.phone, color: Colors.white, size: 24),
              ),
              child: tile,
            );
          }

          return tile;
        },
      );

  Future<_CustomerTileData> _loadData() async {
    final contact = await DaoContact().getPrimaryForCustomer(customer.id);
    final jobs = await DaoJob().getByCustomer(customer);
    return _CustomerTileData(contact: contact, jobs: jobs);
  }

  Widget _buildTileContent(_CustomerTileData data) {
    final contact = data.contact;
    final jobCount = data.jobs.length;
    final phone = contact?.bestPhone;
    final email = contact?.emailAddress;
    final hasPhone = phone != null && phone.isNotEmpty;
    final hasEmail = email != null && email.isNotEmpty;

    // Build subtitle: phone, email
    final subtitleParts = <String>[];
    if (hasPhone) {
      subtitleParts.add(phone);
    }
    if (hasEmail) {
      subtitleParts.add(email);
    }
    final subtitle = subtitleParts.join('  |  ');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HmbSpacing.screenHorizontal,
        vertical: HmbSpacing.xs,
      ),
      child: Material(
        color: colors.secondaryGroupedBackground,
        borderRadius: HmbRadius.grouped,
        child: InkWell(
          borderRadius: HmbRadius.grouped,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HmbSpacing.lg,
              vertical: HmbSpacing.md,
            ),
            child: Row(
              children: [
                // Avatar circle with initials
                _AvatarCircle(
                  name: customer.name,
                  colors: colors,
                  typography: typography,
                ),
                const SizedBox(width: HmbSpacing.md),
                // Name + contact info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        customer.name,
                        style: typography.headline.copyWith(
                          color: colors.label,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: typography.subheadline.copyWith(
                            color: colors.secondaryLabel,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Job count badge
                if (jobCount > 0) ...[
                  const SizedBox(width: HmbSpacing.sm),
                  StatusBadge(
                    label: '$jobCount job${jobCount == 1 ? '' : 's'}',
                    type: StatusBadgeType.info,
                  ),
                ],
                const SizedBox(width: HmbSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  color: colors.tertiaryLabel,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerTileData {
  final Contact? contact;
  final List<Job> jobs;
  const _CustomerTileData({required this.contact, required this.jobs});
}

// ---------------------------------------------------------------------------
// Avatar circle
// ---------------------------------------------------------------------------

class _AvatarCircle extends StatelessWidget {
  final String name;
  final HmbColors colors;
  final HmbTypography typography;

  const _AvatarCircle({
    required this.name,
    required this.colors,
    required this.typography,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.tint.withAlpha(30),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          _initials,
          style: typography.callout.copyWith(
            color: colors.tint,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
