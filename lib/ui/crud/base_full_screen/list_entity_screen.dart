/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart' hide StatefulBuilder;
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.dart';
import '../../../design_system/molecules/skeleton_list_tile.dart';
import '../../../entity/entity.g.dart';
import '../../../util/flutter/app_title.dart';
import '../../../util/flutter/flutter_util.g.dart';
import '../../dialog/hmb_comfirm_delete_dialog.dart';
import '../../nav/route.dart';
import '../../widgets/icons/hmb_delete_icon.dart';
import '../../widgets/icons/hmb_edit_icon.dart';
import '../../widgets/icons/hmb_filter_icon.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/hmb_filter_line.dart';
import '../../widgets/widgets.g.dart';

typedef BuildActionItems<T> = List<Widget> Function(T entity);

/// A generic list screen with optional search/add and advanced filters.
class EntityListScreen<T extends Entity<T>> extends StatefulWidget {
  final String entityNamePlural;
  final String entityNameSingular;

  final FutureOr<Widget> Function(T entity) listCardTitle;
  final Widget Function(T entity) listCard;
  final Future<T?> Function()? onAdd;
  final Future<bool> Function(T entity)? onDelete;
  final Widget Function(T? entity) onEdit;
  final Future<Color> Function(T entity)? background;
  final double cardHeight;

  /// Widgets to place in the cards action menu
  /// which also contains the delete button.
  final BuildActionItems<T>? buildActionItems;

  final bool canAdd;
  final bool Function(T entity)? canEdit;
  final bool Function(T entity)? canDelete;

  late final Future<List<T>> Function(String? filter) _fetchList;
  final Dao<T> dao;
  final FilterSheetBuilder? filterSheetBuilder;
  final VoidCallback? onFilterReset;
  final VoidCallback? onFilterSheetClosed;
  final BoolCallback? isFilterActive;

  /// Number of items to display per page. Set to 0 to disable pagination.
  final int pageSize;

  /// show the back arrow at the top of the screen.
  /// Used when the EntityList is shown from mini-dashboard
  /// to make back navigation clear.
  final bool showBackButton;
  final Widget? emptyBody;

  EntityListScreen({
    required this.entityNamePlural,
    required this.entityNameSingular,
    required this.listCardTitle,
    required this.dao,
    required this.onEdit,
    required this.listCard,
    super.key,

    /// Only implement onAdd if you need to override the default
    /// behavour (such as showing your own UI)
    /// when adding a new entity - normally an entity is created
    /// and then [onEdit] is called.
    this.onAdd,
    this.canAdd = true,
    this.canEdit,
    this.canDelete,

    /// Only implement onDelete if you need to override the default
    /// behavour (such as showing your own UI)
    /// when deleting an entity.
    /// If you override this method then you are responsible for
    /// deleting the entity.
    /// Return true if the delete occurred
    this.onDelete,
    this.cardHeight = 300,
    this.background,
    Future<List<T>> Function(String? filter)? fetchList,

    /// If non-null, enables advanced filtering via this sheet.
    this.filterSheetBuilder,
    this.onFilterSheetClosed,

    /// Called when the user clears all filters.
    this.onFilterReset,
    this.isFilterActive,
    this.showBackButton = false,
    this.buildActionItems,
    this.emptyBody,
    this.pageSize = 50,
  }) {
    _fetchList = fetchList ?? (_) => dao.getAll();
  }

  @override
  EntityListScreenState<T> createState() => EntityListScreenState<T>();
}

class EntityListScreenState<T extends Entity<T>>
    extends DeferredState<EntityListScreen<T>>
    with RouteAware {
  BuildActionItems<T>? buildActionItems;

  /// The full list of entities fetched from the data source.
  List<T> _allEntities = [];

  /// The visible subset displayed in the list (paginated).
  List<T> entityList = [];

  /// Whether the initial data fetch is still in progress.
  var _isInitialLoading = true;

  /// How many items are currently visible (pagination cursor).
  var _visibleCount = 0;

  /// Whether the next page is currently being appended.
  var _isLoadingMore = false;

  String? filterOption;
  late final TextEditingController filterController;
  final _scrollController = ScrollController();

  static List<Widget> _noItems<T>(T entity) => <Widget>[];

  bool get _paginationEnabled => widget.pageSize > 0;

  @override
  void initState() {
    super.initState();
    filterController = TextEditingController();

    buildActionItems = widget.buildActionItems ?? _noItems;

    _scrollController.addListener(_onScroll);

    setAppTitle(widget.entityNamePlural);
  }

  /// Load the next page of items when the user scrolls near the bottom.
  void _onScroll() {
    if (!_paginationEnabled || _isLoadingMore) {
      return;
    }
    if (_visibleCount >= _allEntities.length) {
      return; // all items already visible
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  void _loadNextPage() {
    if (_visibleCount >= _allEntities.length) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
    });

    final nextEnd =
        (_visibleCount + widget.pageSize).clamp(0, _allEntities.length);
    setState(() {
      _visibleCount = nextEnd;
      entityList = _allEntities.sublist(0, _visibleCount);
      _isLoadingMore = false;
    });
  }

  /// Apply pagination to the full entity list, resetting the visible window.
  void _applyPagination() {
    if (_paginationEnabled) {
      _visibleCount = widget.pageSize.clamp(0, _allEntities.length);
      entityList = _allEntities.sublist(0, _visibleCount);
    } else {
      _visibleCount = _allEntities.length;
      entityList = List.of(_allEntities);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver..unsubscribe(this)
      ..subscribe(this, route);
    }
  }

  @override
  Future<void> asyncInitState() async {
    await refresh();
  }

  Future<void> refresh() async {
    final list = await widget._fetchList(filterOption);
    if (mounted) {
      setState(() {
        _allEntities = list;
        _applyPagination();
        _isInitialLoading = false;
      });
    }
  }

  /// Insert or update a **single** entity in memory (partial refresh).
  void _partialRefresh(T updatedEntity) {
    final idx = _allEntities.indexWhere((e) => e.id == updatedEntity.id);
    setState(() {
      if (idx == -1) {
        _allEntities.insert(0, updatedEntity);
      } else {
        _allEntities[idx] = updatedEntity;
      }
      _applyPagination();
    });
  }

  /// Remove the entity from our in-memory list.
  void _removeFromList(T entity) {
    setState(() {
      _allEntities.removeWhere((e) => e.id == entity.id);
      // Adjust visible count down but keep current scroll position viable.
      _visibleCount = _visibleCount.clamp(0, _allEntities.length);
      entityList = _allEntities.sublist(0, _visibleCount);
    });
  }

  Future<void> _resetFilters() async {
    widget.onFilterReset?.call();
    filterOption = null;
    await refresh();
  }

  final _filterSheetKey = GlobalKey<_FilterSheetState>();

  @override
  Widget build(BuildContext context) {
    final Widget searchAdd;

    searchAdd = HMBSearchWithAdd(
      onSearch: (newValue) async {
        filterOption = newValue;
        await refresh();
      },
      showAdd: widget.canAdd,
      onAdd: () async {
        T? newEntity;
        if (widget.onAdd != null) {
          newEntity = await widget.onAdd!.call();
        } else if (context.mounted) {
          newEntity = await Navigator.push<T?>(
            context,
            MaterialPageRoute(builder: (context) => widget.onEdit(null)),
          );
        }
        if (newEntity != null) {
          _partialRefresh(newEntity);
        }
      },
    );

    Widget titleRow;
    if (widget.filterSheetBuilder != null) {
      titleRow = HMBFilterLine(
        lineBuilder: (_) => searchAdd,
        sheetBuilder: (context) => FilterSheet(
          sheetBuilder: widget.filterSheetBuilder!,
          onChange: () async {
            _filterSheetKey.currentState!.refresh();
            await refresh();
          },
          key: _filterSheetKey,
        ),

        onReset: _resetFilters,
        onSheetClosed: widget.onFilterSheetClosed,
        isActive: () => widget.isFilterActive?.call() ?? false,
      );
    } else {
      titleRow = searchAdd;
    }

    return Surface(
      elevation: SurfaceElevation.e0,
      padding: EdgeInsets.zero,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: SurfaceElevation.e0.color,
          toolbarHeight: 80,
          titleSpacing: 0,
          title: titleRow,
          automaticallyImplyLeading: widget.showBackButton,
        ),
        body: _buildList(),
      ),
    );
  }

  Widget _buildList() {
    // Show skeleton placeholders during initial data load.
    if (_isInitialLoading) {
      return _buildSkeletonList();
    }

    if (entityList.isEmpty) {
      if (widget.emptyBody != null) {
        return widget.emptyBody!;
      }
      if (widget.canAdd) {
        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Click'),
              HMBButtonAdd(
                small: true,
                enabled: false,
                hint: 'Not this one',
                onAdd: () async {},
              ),

              Text('to add ${widget.entityNamePlural}.'),
            ],
          ),
        );
      } else {
        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('No ${widget.entityNamePlural} found. Check the Filter '),
              HMBFilterIcon(
                enabled: false,
                small: true,
                hint:
                    '''Click the Filter Icon in the top right hand corner to view active filters''',
                onPressed: () async {},
              ),
            ],
          ),
        );
      }
    }

    final hasMore =
        _paginationEnabled && _visibleCount < _allEntities.length;
    final itemCount = entityList.length + (hasMore ? 1 : 0);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        key: const ValueKey('entity-list'),
        controller: _scrollController,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= entityList.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return SizedBox(
            height: widget.cardHeight,
            child: _buildCard(entityList[index]),
          );
        },
      ),
    );
  }

  /// Builds a list of 8 skeleton placeholder tiles to show while
  /// the initial data fetch is in progress.
  Widget _buildSkeletonList() => ListView.builder(
    key: const ValueKey('skeleton-list'),
    itemCount: 8,
    physics: const NeverScrollableScrollPhysics(),
    itemBuilder: (context, index) => const SkeletonListTile(),
  );

  Widget _buildEditButton(T entity, BuildContext context) => HMBEditIcon(
    onPressed: () => _edit(entity, context),
    hint: 'Edit this ${widget.entityNameSingular}',
  );

  Widget _buildDeleteButton(T entity) => HMBDeleteIcon(
    onPressed: () => _confirmDelete(entity),
    hint: 'Delete this ${widget.entityNameSingular}',
  );

  Widget _buildCard(T entity) => FutureBuilderEx<Color>(
    initialData: SurfaceElevation.e6.color,
    future:
        widget.background?.call(entity) ??
        Future.value(SurfaceElevation.e6.color),
    builder: (context, cardColor) =>
        // GestureDetector(
        //   onTap: () async {
        //     await _edit(entity, context);
        //   },
        //   child:
        Surface(
          elevation: SurfaceElevation.e6,
          margin: const EdgeInsets.only(bottom: 8),
          child: HMBColumn(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FutureBuilderEx(
                      future:
                          ((widget.listCardTitle is Future)
                                  ? widget.listCardTitle(entity)
                                  : Future.value(widget.listCardTitle(entity)))
                              as Future<Widget>,
                      builder: (context, title) => title!,
                    ),
                  ),
                  _actionMenu(entity),
                ],
              ),
              // Body (details)
              widget.listCard(entity),
            ],
          ),
          // ),
        ),
  );

  Future<void> _edit(T entity, BuildContext context) async {
    /// make certain we have the latest version of the entity
    /// becuase some action from the list card could have
    /// changed it.
    final currentEntity = await widget.dao.getById(entity.id);
    if (context.mounted) {
      // Navigate to the edit screen
      final updatedEntity = await Navigator.push<T?>(
        context,
        MaterialPageRoute(builder: (context) => widget.onEdit(currentEntity)),
      );
      // If user successfully saved or created a new entity
      if (updatedEntity != null) {
        _partialRefresh(updatedEntity);
      }
    }
  }

  Widget _actionMenu(T entity) => HMBRow(
    children: [
      ...widget.buildActionItems?.call(entity) ?? [],
      if (widget.canEdit?.call(entity) ?? true)
        _buildEditButton(entity, context),
      if (widget.canDelete?.call(entity) ?? true) _buildDeleteButton(entity),
    ],
  );

  Future<void> _confirmDelete(T entity) async {
    await showConfirmDeleteDialog(
      context: context,
      question:
          'Are you sure you want to delete this ${widget.entityNameSingular}?',
      nameSingular: widget.entityNameSingular,
      onConfirmed: () => _delete(entity),
    );
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    filterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    unawaited(refresh());
  }

  Future<void> _delete(T entity) async {
    var remove = false;
    try {
      if (widget.onDelete != null) {
        remove = await widget.onDelete!.call(entity);
      } else {
        await widget.dao.delete(entity.id);
        remove = true;
      }
      if (remove) {
        _removeFromList(entity);
      }
    }
    // ignore: avoid_catches_without_on_clauses
    catch (e) {
      HMBToast.error(e.toString());
    }
  }
}

typedef FilterSheetBuilder = Widget Function(void Function() onChange);

class FilterSheet extends StatefulWidget {
  final FilterSheetBuilder sheetBuilder;
  final void Function() onChange;

  const FilterSheet({
    required this.sheetBuilder,
    required this.onChange,
    super.key,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  final _stateBuilderKey = GlobalKey<StatefulBuilderState>();
  @override
  Widget build(BuildContext context) => StatefulBuilder(
    key: _stateBuilderKey,
    builder: (context, setState) => widget.sheetBuilder(widget.onChange),
  );

  /// cause the fitler sheet to rebuild.
  void refresh() {
    _stateBuilderKey.currentState!.setState(() {});
  }
}
