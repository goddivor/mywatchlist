import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:mywatchlist/widgets/user/list/cards/custom_entry_card.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_controller.dart';

/// Gaps of the My List grid, DailyAL's: its grid rows put each card in an
/// equal share of the width with a padding on both sides (5 for the
/// comfortable card, 6 for the compact and cover-only cards) and end on a
/// 7 dp bottom padding, the compact and cover-only cards adding 4 on top.
/// So the gap between columns is twice the side padding, the screen edge
/// keeps one side padding, and the gap between rows is 7 (11 when compact).
/// List displays keep their own spacing and never read these.
typedef ListGridGaps = ({double column, double row, double edge});

ListGridGaps listGridGaps(DisplaySubType subType) => switch (subType) {
      DisplaySubType.compact || DisplaySubType.cover_only_grid => (column: 12, row: 11, edge: 6),
      _ => (column: 10, row: 7, edge: 5),
    };

/// Padding around the grid: DailyAL's edge on both sides, [top] above.
EdgeInsets listGridPadding(DisplaySubType subType, {double top = 0}) {
  final edge = listGridGaps(subType).edge;
  return EdgeInsets.fromLTRB(edge, top, edge, 0);
}

/// Fixed-extent grid delegate: every cell is [ListDisplay.gridHeight] tall,
/// with DailyAL's gaps between columns and rows.
SliverGridDelegateWithFixedCrossAxisCount listGridDelegate(ListDisplay display) {
  final gaps = listGridGaps(display.subType);
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: display.gridColumns,
    mainAxisExtent: display.gridHeight,
    crossAxisSpacing: gaps.column,
    mainAxisSpacing: gaps.row,
  );
}

/// The scrollable body of one status tab: lazy slivers, pull to refresh,
/// next page near the end, and loading / empty / error states.
class UserListTab extends StatefulWidget {
  final UserListTabController controller;
  final UserListAdapter adapter;
  final ListDisplay display;

  /// Layout of [DisplaySubType.custom], null falls back to comfortable rows.
  final ContentCardProps? cardProfile;
  final EntryActions actions;
  final EntryCardStyle style;

  /// Clears the filter and the search (empty state button), null hides it.
  final VoidCallback? onClearFilters;

  const UserListTab({
    super.key,
    required this.controller,
    required this.adapter,
    required this.display,
    required this.cardProfile,
    required this.actions,
    required this.style,
    this.onClearFilters,
  });

  @override
  State<UserListTab> createState() => _UserListTabState();
}

class _UserListTabState extends State<UserListTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.activate();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // The cards below word and draw their entries as this tracker does.
    return ListEntryLookScope(
      look: widget.adapter,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = widget.controller;
    final entries = c.entries;
    if (entries.isEmpty) {
      if (!c.isStarted || c.isLoading) return _Skeleton(display: widget.display);
      if (c.error != null) {
        return _MessageView(
          icon: widget.adapter.isSessionExpired(c.error!)
              ? Icons.lock_clock_outlined
              : Icons.cloud_off_rounded,
          title: widget.adapter.isSessionExpired(c.error!)
              ? S.current.UserList_Session_Expired
              : S.current.UserList_Load_Error,
          message: widget.adapter.isSessionExpired(c.error!)
              ? S.current.UserList_Session_Expired_Hint
              : S.current.UserList_Load_Error_Hint,
          action: widget.adapter.isSessionExpired(c.error!)
              ? (S.current.UserList_Sign_In_Again, () => widget.adapter.signInAgain(context))
              : (S.current.UserList_Retry, c.refresh),
          onRefresh: c.refresh,
        );
      }
      final filtered = !c.settings.filter.isEmpty || c.query.trim().isNotEmpty;
      if (filtered && c.hasMore) {
        // Whole list still loading for the filter.
        return _Skeleton(display: widget.display);
      }
      return _MessageView(
        icon: filtered ? Icons.filter_alt_off_outlined : Icons.inbox_outlined,
        title: filtered ? S.current.UserList_No_Match : S.current.UserList_Empty,
        message: filtered ? S.current.UserList_No_Match_Hint : S.current.UserList_Empty_Hint,
        action: filtered && widget.onClearFilters != null
            ? (S.current.UserList_Clear_Filters, widget.onClearFilters!)
            : null,
        onRefresh: c.refresh,
      );
    }
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    final display = widget.display;
    final Widget list;
    if (display.isGrid) {
      list = SliverPadding(
        padding: listGridPadding(display.subType, top: 4),
        sliver: SliverGrid.builder(
          gridDelegate: listGridDelegate(display),
          itemCount: entries.length,
          itemBuilder: (context, i) => EntryGridCard(
            key: ValueKey(entries[i].id),
            entry: entries[i],
            subType: display.subType,
            actions: widget.actions,
            style: widget.style,
            now: now,
          ),
        ),
      );
    } else {
      final profile = display.subType == DisplaySubType.custom ? widget.cardProfile : null;
      final subType = display.subType == DisplaySubType.custom && profile == null
          ? DisplaySubType.comfortable
          : display.subType;
      list = SliverFixedExtentList.builder(
        itemExtent: profile != null ? profile.height + 8 : listRowExtent(subType),
        itemCount: entries.length,
        itemBuilder: (context, i) => profile != null
            ? CustomEntryCard(
                key: ValueKey(entries[i].id),
                props: profile,
                entry: entries[i],
                actions: widget.actions,
                now: now,
                locale: locale,
              )
            : EntryListTile(
                key: ValueKey(entries[i].id),
                entry: entries[i],
                subType: subType,
                actions: widget.actions,
                style: widget.style,
                now: now,
                locale: locale,
              ),
      );
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: CustomScrollView(
        key: PageStorageKey('user-list-${c.category}-${c.status?.name ?? 'all'}'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 4)),
          list,
          SliverToBoxAdapter(child: _Footer(controller: c)),
        ],
      ),
    );
  }
}

/// End of the list: asks the next page when built (i.e. when it nears the
/// viewport), shows a spinner meanwhile and a retry button after an error.
class _Footer extends StatelessWidget {
  final UserListTabController controller;
  const _Footer({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: TextButton.icon(
            onPressed: c.loadMore,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(S.current.UserList_Load_More_Failed),
          ),
        ),
      );
    }
    if (c.hasMore) {
      if (c.isPaged && !c.isLoadingMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) => c.loadMore());
      }
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      );
    }
    return const SizedBox(height: 96);
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final (String, VoidCallback)? action;
  final Future<void> Function() onRefresh;

  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  if (action != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.tonal(onPressed: action!.$2, child: Text(action!.$1)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grey shapes of the current layout while the first page loads (one shared
/// shimmer ticker).
class _Skeleton extends StatelessWidget {
  final ListDisplay display;
  const _Skeleton({required this.display});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget box(double? w, double h, [double r = 6]) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(r)),
        );
    if (display.isGrid) {
      return ShimmerColor(
        GridView.builder(
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          padding: listGridPadding(display.subType, top: 8),
          gridDelegate: listGridDelegate(display),
          itemCount: display.gridColumns * 4,
          itemBuilder: (_, __) => box(null, display.gridHeight, 10),
        ),
      );
    }
    final compact = display.subType == DisplaySubType.compact;
    final extent = listRowExtent(display.subType == DisplaySubType.custom
        ? DisplaySubType.comfortable
        : display.subType);
    return ShimmerColor(
      ListView.builder(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        itemExtent: extent,
        itemCount: 10,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              box(compact ? 36 : extent * 0.66, compact ? 48 : extent - 16, 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    box(120, 12),
                    const SizedBox(height: 8),
                    box(double.infinity, 14),
                    if (!compact) ...[
                      const SizedBox(height: 8),
                      box(160, 12),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
