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

// lib/src/ui/nav/home_scaffold.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';

import '../../dao/dao_job.dart';
import '../../design_system/theme.dart';
import '../../util/flutter/app_title.dart';
import '../widgets/hmb_start_time_entry.dart';
import '../widgets/hmb_status_bar.dart';
import '../widgets/layout/layout.g.dart';
import 'hmb_global_search.dart';

/// A scaffold that wraps all screens and adds:
///  - a CupertinoTabBar-style bottom navigation with 5 tabs
///  - iOS-style large title that collapses on scroll
///  - global search bar
///  - the HMB status bar
class HomeScaffold extends StatelessWidget {
  final Widget initialScreen;

  const HomeScaffold({required this.initialScreen, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.tint,
        foregroundColor: Colors.white,
        // Home button replaces the old drawer
        leading: IconButton(
          icon: const Icon(CupertinoIcons.home),
          onPressed: () => GoRouter.of(context).go('/home'),
        ),
        title: JuneBuilder(
          HMBTitle.new,
          builder: (title) => FutureBuilderEx(
            future: DaoJob().getLastActiveJob(),
            builder: (context, activeJob) =>
                Text(formatAppTitle(title.title, activeJob: activeJob)),
          ),
        ),
      ),
      body: HMBColumn(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show active time entry bar when appropriate
          JuneBuilder<ActiveTimeEntryState>(
            ActiveTimeEntryState.new,
            builder: (_) {
              final state = June.getState<ActiveTimeEntryState>(
                ActiveTimeEntryState.new,
              );
              if (state.activeTimeEntry != null) {
                return HMBStatusBar(
                  activeTimeEntry: state.activeTimeEntry,
                  task: state.task,
                  onTimeEntryEnded: state.clearActiveTimeEntry,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Flexible(child: initialScreen),
        ],
      ),
    );
  }
}

/// Root tabbed navigation shell with CupertinoTabBar.
///
/// Provides 5 tabs: Jobs, Customers, Dashboard (center), Invoices, Settings.
/// Each tab maintains its own navigation state via GoRouter.
class TabbedHomeScaffold extends StatefulWidget {
  const TabbedHomeScaffold({super.key});

  @override
  State<TabbedHomeScaffold> createState() => _TabbedHomeScaffoldState();
}

class _TabbedHomeScaffoldState extends State<TabbedHomeScaffold> {
  var _currentIndex = 2; // Dashboard is center tab (index 2)
  var _showSearch = false;

  static const _tabRoutes = [
    '/home/jobs',
    '/home/customers',
    '/home',
    '/home/accounting/invoices',
    '/home/settings',
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      return; // already on this tab
    }
    setState(() {
      _currentIndex = index;
      _showSearch = false;
    });
    GoRouter.of(context).go(_tabRoutes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Active time entry bar
          JuneBuilder<ActiveTimeEntryState>(
            ActiveTimeEntryState.new,
            builder: (_) {
              final state = June.getState<ActiveTimeEntryState>(
                ActiveTimeEntryState.new,
              );
              if (state.activeTimeEntry != null) {
                return HMBStatusBar(
                  activeTimeEntry: state.activeTimeEntry,
                  task: state.task,
                  onTimeEntryEnded: state.clearActiveTimeEntry,
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Global search (toggled)
          if (_showSearch)
            Material(
              color: colors.secondarySystemBackground,
              child: const HMBGlobalSearch(),
            ),

          // Page content with large title
          Expanded(
            child: _LargeTitleWrapper(
              title: _tabTitle(_currentIndex),
              onSearchToggle: () =>
                  setState(() => _showSearch = !_showSearch),
              colors: colors,
              typography: typography,
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildTabBar(context, colors),
    );
  }

  // The actual content is rendered by GoRouter via the route tree.
  // GoRouter handles rendering the correct page.
  Widget _buildTabContent() => const SizedBox.expand();

  String _tabTitle(int index) => switch (index) {
        0 => 'Jobs',
        1 => 'Customers',
        2 => 'Dashboard',
        3 => 'Invoices',
        4 => 'Settings',
        _ => 'HMB',
      };

  Widget _buildTabBar(BuildContext context, HmbColors colors) =>
      CupertinoTabBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        activeColor: colors.tint,
        inactiveColor: colors.systemGray,
        backgroundColor: colors.secondarySystemBackground.withAlpha(230),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.briefcase),
            activeIcon: Icon(CupertinoIcons.briefcase_fill),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            activeIcon: Icon(CupertinoIcons.person_2_fill),
            label: 'Customers',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_grid_2x2),
            activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.doc_text),
            activeIcon: Icon(CupertinoIcons.doc_text_fill),
            label: 'Invoices',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear),
            activeIcon: Icon(CupertinoIcons.gear_solid),
            label: 'Settings',
          ),
        ],
      );
}

/// Wraps a child widget with an iOS-style large title that collapses
/// to an inline title on scroll using SliverAppBar + FlexibleSpaceBar.
class _LargeTitleWrapper extends StatelessWidget {
  final String title;
  final VoidCallback onSearchToggle;
  final HmbColors colors;
  final HmbTypography typography;
  final Widget child;

  const _LargeTitleWrapper({
    required this.title,
    required this.onSearchToggle,
    required this.colors,
    required this.typography,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 96,
            pinned: true,
            backgroundColor: colors.systemBackground,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            title: Text(
              title,
              style: typography.headline.copyWith(
                color: colors.label,
                fontSize: 17,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  CupertinoIcons.search,
                  color: colors.tint,
                ),
                onPressed: onSearchToggle,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    bottom: 8,
                  ),
                  child: Text(
                    title,
                    style: typography.largeTitle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.label,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            child: child,
          ),
        ],
      );
}

/// Standalone large-title scaffold for list screens.
///
/// Provides the iOS-style large title collapse behavior without
/// the tabbed navigation. Use this when wrapping list screens
/// that should have the collapsing title but are accessed via
/// the tab bar routes.
class LargeTitleScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const LargeTitleScaffold({
    required this.title,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 96,
          pinned: true,
          backgroundColor: colors.systemBackground,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Text(
            title,
            style: typography.headline.copyWith(
              color: colors.label,
              fontSize: 17,
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  bottom: 8,
                ),
                child: Text(
                  title,
                  style: typography.largeTitle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.label,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      body: child,
    );
  }
}
