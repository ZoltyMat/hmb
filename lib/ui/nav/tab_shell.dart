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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';

import '../../design_system/theme.dart';
import '../widgets/hmb_start_time_entry.dart';
import '../widgets/hmb_status_bar.dart';
import 'hmb_global_search.dart';

/// Tab labels in display order.
const _tabLabels = ['Jobs', 'Customers', 'Dashboard', 'Invoices', 'Settings'];

/// Root navigation shell with a CupertinoTabBar (5 tabs) and iOS-style
/// large title that collapses to inline on scroll.
///
/// The [StatefulNavigationShell] manages per-branch navigation state so
/// each tab remembers its position in the navigation stack.
class TabShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const TabShell({required this.navigationShell, super.key});

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  var _showSearch = false;

  void _onTabTapped(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    if (_showSearch) {
      setState(() => _showSearch = false);
    }
  }

  String get _currentTitle =>
      _tabLabels[widget.navigationShell.currentIndex];

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Active time entry status bar
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

          // Global search overlay
          if (_showSearch)
            Material(
              color: colors.secondarySystemBackground,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: const HMBGlobalSearch(),
              ),
            ),

          // Page content wrapped in collapsing large title
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight: 96,
                  pinned: true,
                  backgroundColor: colors.systemBackground,
                  surfaceTintColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  // Inline title (17pt) shown when collapsed
                  title: Text(
                    _currentTitle,
                    style: typography.headline.copyWith(
                      color: colors.label,
                      fontSize: 17,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _showSearch
                            ? CupertinoIcons.xmark_circle_fill
                            : CupertinoIcons.search,
                        color: colors.tint,
                      ),
                      onPressed: () =>
                          setState(() => _showSearch = !_showSearch),
                    ),
                  ],
                  // Large title (34pt) shown when expanded
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
                          _currentTitle,
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
              body: widget.navigationShell,
            ),
          ),
        ],
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onTabTapped,
        activeColor: colors.tint,
        inactiveColor: colors.systemGray,
        backgroundColor:
            colors.secondarySystemBackground.withAlpha(230),
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
      ),
    );
  }
}
