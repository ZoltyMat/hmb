/*
 Copyright (c) OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   * Permitted for internal use within your own business or organization only.
   * Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../../../dao/dao.g.dart';
import '../../../../design_system/molecules/grouped_list_section.dart';
import '../../../../design_system/molecules/stat_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../entity/entity.g.dart';
import '../../../../util/dart/format.dart';
import '../../../../util/dart/local_date.dart';
import '../../../../util/flutter/app_title.dart';
import '../../route.dart';
import '../dashboard.dart';

/// Apple-inspired dashboard with greeting hero, stat cards, today's schedule,
/// and activity feed.
class MainDashboardPage extends StatefulWidget {
  const MainDashboardPage({super.key});

  @override
  State<MainDashboardPage> createState() => _MainDashboardPageState();
}

class _MainDashboardPageState extends State<MainDashboardPage>
    with RouteAware {
  @override
  void initState() {
    super.initState();
    setAppTitle('Dashboard');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    setAppTitle('Dashboard');
    June.getState<DashboardReloaded>(DashboardReloaded.new).setState();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: HmbColors.of(context).groupedBackground,
        body: JuneBuilder(
          DashboardReloaded.new,
          builder: (_) => FutureBuilderEx<_DashboardData>(
            future: _loadDashboardData(),
            builder: (context, data) {
              if (data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _DashboardContent(data: data);
            },
          ),
        ),
      );

  Future<_DashboardData> _loadDashboardData() async {
    final system = await DaoSystem().get();
    final today = LocalDate.today();
    final todayActivities =
        await DaoJobActivity().getActivitiesForDate(today);
    final activeJobs = await DaoJob().getActiveJobs(null);
    final unpaidInvoices = await DaoInvoice().getByFilter(null);
    final recentJobs = await DaoJob().getByStatuses([
      JobStatus.completed,
      JobStatus.toBeBilled,
    ]);

    // Calculate stats
    var billableCount = 0;
    for (final job in activeJobs) {
      if (job.billingType != BillingType.nonBillable) {
        billableCount++;
      }
    }

    var overdueCount = 0;
    var revenueDue = Money.parse('0', isoCode: 'AUD');
    for (final inv in unpaidInvoices) {
      if (!inv.paid) {
        revenueDue += inv.totalAmount;
        if (inv.dueDate.isBefore(today)) {
          overdueCount++;
        }
      }
    }

    // Monthly revenue (paid this month)
    final allInvoices =
        await DaoInvoice().getByFilter(null, includePaid: true);
    var monthlyRevenue = Money.parse('0', isoCode: 'AUD');
    final monthStart = LocalDate(today.year, today.month);
    for (final inv in allInvoices) {
      if (inv.paid && inv.paidDate != null) {
        final paidDate = LocalDate.fromDateTime(inv.paidDate!);
        if (!paidDate.isBefore(monthStart) &&
            (paidDate.isBefore(today) || paidDate == today)) {
          monthlyRevenue += inv.totalAmount;
        }
      }
    }

    // Build activity feed from recent completed/billed jobs + paid invoices
    final activityItems = <_ActivityItem>[];

    for (final inv in allInvoices) {
      if (inv.paid && inv.paidDate != null) {
        final paidDate = inv.paidDate!;
        if (DateTime.now().difference(paidDate).inDays <= 30) {
          activityItems.add(_ActivityItem(
            icon: Icons.payments_outlined,
            title: 'Payment received',
            subtitle: inv.totalAmount.toString(),
            timestamp: paidDate,
            color: HmbColors.light.systemGreen,
          ));
        }
      }
    }

    for (final job in recentJobs.take(10)) {
      activityItems.add(_ActivityItem(
        icon: job.status == JobStatus.completed
            ? Icons.check_circle_outline
            : Icons.receipt_long_outlined,
        title: job.status == JobStatus.completed
            ? 'Job completed'
            : 'Ready to bill',
        subtitle: job.summary,
        timestamp: job.modifiedDate,
        color: job.status == JobStatus.completed
            ? HmbColors.light.systemBlue
            : HmbColors.light.systemOrange,
      ));
    }

    activityItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Resolve job summaries for today's activities
    final scheduleItems = <_ScheduleItem>[];
    for (final activity in todayActivities) {
      final job = await DaoJob().getById(activity.jobId);
      var customerName = '';
      if (job?.customerId != null) {
        final customer = await DaoCustomer().getById(job?.customerId);
        customerName = customer?.name ?? '';
      }
      scheduleItems.add(_ScheduleItem(
        start: activity.start,
        end: activity.end,
        jobSummary: job?.summary ?? 'Unknown Job',
        customerName: customerName,
        status: activity.status,
      ));
    }

    return _DashboardData(
      firstName: system.firstname,
      jobsToday: todayActivities.length,
      activeJobs: billableCount,
      revenueDue: revenueDue,
      overdueInvoices: overdueCount,
      monthlyRevenue: monthlyRevenue,
      scheduleItems: scheduleItems,
      activityItems: activityItems.take(8).toList(),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + HmbSpacing.lg,
        bottom: HmbSpacing.xxl,
      ),
      children: [
        // -- Greeting Hero --
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.screenHorizontal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(data.firstName),
                style: typography.largeTitle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.label,
                ),
              ),
              const SizedBox(height: HmbSpacing.xs),
              Text(
                _formattedDate(),
                style: typography.subheadline.copyWith(
                  color: colors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: HmbSpacing.xl),

        // -- Stat Cards (2x2 grid) --
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.screenHorizontal,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = HmbSpacing.md;
              final cardWidth = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      icon: Icons.calendar_today_rounded,
                      iconColor: colors.systemBlue,
                      label: 'Jobs Today',
                      value: '${data.jobsToday}',
                      subtitle: '${data.activeJobs} active total',
                      onTap: () => context.go('/home/today'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      icon: Icons.attach_money_rounded,
                      iconColor: colors.systemGreen,
                      label: 'Revenue Due',
                      value: _shortMoney(data.revenueDue),
                      subtitle: 'Outstanding invoices',
                      onTap: () => context.go('/home/accounting'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      icon: Icons.warning_amber_rounded,
                      iconColor: data.overdueInvoices > 0
                          ? colors.systemRed
                          : colors.systemGray,
                      label: 'Overdue',
                      value: '${data.overdueInvoices}',
                      subtitle: 'Invoices past due',
                      onTap: () => context.go('/home/accounting'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      icon: Icons.trending_up_rounded,
                      iconColor: colors.systemTeal,
                      label: 'This Month',
                      value: _shortMoney(data.monthlyRevenue),
                      subtitle: 'Revenue collected',
                      onTap: () => context.go('/home/accounting'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: HmbSpacing.xl),

        // -- Today's Schedule --
        if (data.scheduleItems.isNotEmpty)
          GroupedListSection(
            header: "Today's Schedule",
            children: data.scheduleItems
                .map((item) => _ScheduleTile(item: item))
                .toList(),
          ),

        if (data.scheduleItems.isEmpty)
          GroupedListSection(
            header: "Today's Schedule",
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HmbSpacing.lg,
                  vertical: HmbSpacing.xl,
                ),
                child: Center(
                  child: Text(
                    'No jobs scheduled for today',
                    style: typography.subheadline.copyWith(
                      color: colors.tertiaryLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: HmbSpacing.sm),

        // -- Activity Feed --
        if (data.activityItems.isNotEmpty)
          GroupedListSection(
            header: 'Recent Activity',
            children: data.activityItems
                .map((item) => _ActivityTile(item: item))
                .toList(),
          ),

        // -- Quick Actions (navigation to all original dashlets) --
        const SizedBox(height: HmbSpacing.sm),
        GroupedListSection(
          header: 'Quick Actions',
          children: [
            _QuickActionTile(
              icon: Icons.work_outline,
              label: 'Jobs',
              onTap: () => context.go('/home/jobs'),
            ),
            _QuickActionTile(
              icon: Icons.people_outline,
              label: 'Customers',
              onTap: () => context.go('/home/customers'),
            ),
            _QuickActionTile(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Accounting',
              onTap: () => context.go('/home/accounting'),
            ),
            _QuickActionTile(
              icon: Icons.checklist_rounded,
              label: 'To Do',
              onTap: () => context.go('/home/todo'),
            ),
            _QuickActionTile(
              icon: Icons.schedule_outlined,
              label: 'Schedule',
              onTap: () => context.go('/home/schedule'),
            ),
            _QuickActionTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => context.go('/home/settings'),
            ),
          ],
        ),
      ],
    );
  }

  String _greeting(String? firstName) {
    final hour = DateTime.now().hour;
    final name = Strings.isNotBlank(firstName) ? ', $firstName' : '';
    if (hour < 12) {
      return 'Good morning$name';
    } else if (hour < 17) {
      return 'Good afternoon$name';
    } else {
      return 'Good evening$name';
    }
  }

  String _formattedDate() {
    final now = DateTime.now();
    return formatDate(now, format: 'l, j F Y');
  }

  String _shortMoney(Money money) {
    // Fixed doesn't have toDouble(); parse from string representation
    final amount =
        double.tryParse(money.amount.toString()) ?? 0;
    if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '\$${amount.toStringAsFixed(0)}';
  }
}

// -- Schedule tile --

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({required this.item});

  final _ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    final statusColor = switch (item.status) {
      JobActivityStatus.confirmed => colors.systemGreen,
      JobActivityStatus.proposed => colors.systemBlue,
      JobActivityStatus.tentative => colors.systemOrange,
    };

    final timeStr =
        '${formatDate(item.start, format: 'g:ia')} - '
        '${formatDate(item.end, format: 'g:ia')}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HmbSpacing.lg,
        vertical: HmbSpacing.md,
      ),
      child: Row(
        children: [
          // Status indicator dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: HmbSpacing.md),
          // Time column
          SizedBox(
            width: 110,
            child: Text(
              timeStr,
              style: typography.caption1.copyWith(
                color: colors.secondaryLabel,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: HmbSpacing.sm),
          // Job info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.jobSummary,
                  style: typography.subheadline.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.label,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.customerName.isNotEmpty)
                  Text(
                    item.customerName,
                    style: typography.caption1.copyWith(
                      color: colors.tertiaryLabel,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- Activity feed tile --

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final _ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HmbSpacing.lg,
        vertical: HmbSpacing.md,
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: item.color),
          const SizedBox(width: HmbSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: typography.subheadline.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.label,
                  ),
                ),
                Text(
                  item.subtitle,
                  style: typography.caption1.copyWith(
                    color: colors.secondaryLabel,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: HmbSpacing.sm),
          Text(
            _relativeTime(item.timestamp),
            style: typography.caption2.copyWith(
              color: colors.tertiaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return formatDate(timestamp, format: 'j M');
    }
  }
}

// -- Quick action tile --

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.tint),
            const SizedBox(width: HmbSpacing.md),
            Expanded(
              child: Text(
                label,
                style: typography.body.copyWith(color: colors.label),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colors.tertiaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}

// -- Data models --

class _DashboardData {
  final String? firstName;
  final int jobsToday;
  final int activeJobs;
  final Money revenueDue;
  final int overdueInvoices;
  final Money monthlyRevenue;
  final List<_ScheduleItem> scheduleItems;
  final List<_ActivityItem> activityItems;

  const _DashboardData({
    required this.firstName,
    required this.jobsToday,
    required this.activeJobs,
    required this.revenueDue,
    required this.overdueInvoices,
    required this.monthlyRevenue,
    required this.scheduleItems,
    required this.activityItems,
  });
}

class _ScheduleItem {
  final DateTime start;
  final DateTime end;
  final String jobSummary;
  final String customerName;
  final JobActivityStatus status;

  const _ScheduleItem({
    required this.start,
    required this.end,
    required this.jobSummary,
    required this.customerName,
    required this.status,
  });
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final Color color;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.color,
  });
}
