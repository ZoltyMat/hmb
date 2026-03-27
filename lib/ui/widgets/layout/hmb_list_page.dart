import 'package:flutter/material.dart';

import '../../../util/flutter/hmb_theme.dart';
import '../text/hmb_text_themes.dart';
import '../widgets.g.dart';
import 'layout.g.dart';

class HMBListPage extends StatefulWidget {
  final String emptyMessage;
  final NullableIndexedWidgetBuilder itemBuilder;
  final int itemCount;

  final void Function()? onAdd;
  final void Function(String? filter)? onSearch;

  /// Called when the user scrolls near the bottom and more items are available.
  /// If null, no scroll-to-load-more behaviour is applied.
  final VoidCallback? onLoadMore;

  /// Whether there are more items available beyond [itemCount].
  final bool hasMore;

  const HMBListPage({
    required this.emptyMessage,
    required this.itemCount,
    required this.itemBuilder,
    this.onSearch,
    this.onAdd,
    this.onLoadMore,
    this.hasMore = false,
    super.key,
  });

  @override
  State<HMBListPage> createState() => _HMBListPageState();
}

class _HMBListPageState extends State<HMBListPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (widget.onLoadMore == null || !widget.hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      widget.onLoadMore!();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayCount =
        widget.itemCount + (widget.hasMore ? 1 : 0);
    final child = (widget.itemCount == 0)
        ? Center(child: Text(widget.emptyMessage))
        : ListView.builder(
            controller: _scrollController,
            itemCount: displayCount,
            itemBuilder: (context, index) {
              if (index >= widget.itemCount) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return widget.itemBuilder(context, index);
            },
          );
    return Surface(
      elevation: SurfaceElevation.e0,
      child: HMBColumn(
        children: [
          if (widget.onSearch != null)
            Container(
              margin: HMBTheme.marginInset,
              child: HMBSearchWithAdd(
                onSearch: widget.onSearch!,
                showAdd: widget.onAdd != null,
                onAdd: widget.onAdd ?? () {},
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class HMBListCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final void Function()? onTap;
  final List<Widget>? actions;

  const HMBListCard({
    required this.title,
    required this.children,
    this.actions,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Surface(
      margin: const EdgeInsets.only(
        top: HMBTheme.margin,
        // bottom: HMBTheme.margin,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: HMBColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [HMBTextHeadline2(title), ...children],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [...?actions],
          ),
        ],
      ),
    ),
  );
}
