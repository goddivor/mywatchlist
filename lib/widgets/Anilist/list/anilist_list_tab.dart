import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_list_look.dart';
import 'package:mywatchlist/user/preferences/preferences.dart' show ContentCardProps;
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_format.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/common/score_reveal.dart';
import 'package:mywatchlist/widgets/user/list/cards/custom_entry_card.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart' show EntryGridCard;
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_controller.dart';
import 'package:mywatchlist/widgets/user/list/user_list_tab.dart' show listGridDelegate, listGridPadding;

/// What an AniList row needs besides the shared entry: AniList's own fields of the entry and
/// the account's score format.
typedef AnilistRowData = ({AnilistListEntry? detail, AnilistScoreFormat format});

/// Height of an AniList list row ([compact] = one-line rows), grown with the text size: the
/// three text lines of a row take more room under a larger [scaler].
double anilistRowExtent({required bool compact, TextScaler scaler = TextScaler.noScaling}) =>
    (compact ? 96 : 124) + (scaler.scale(14) - 14).clamp(0, 40) * 3;

/// The body of one AniList list section: AniList's own rows (cover, title and score in the
/// account's format, label rail, progress bar with +1), the shared grid and custom cards, pull
/// to refresh, the next page near the end, and loading / empty / error states.
class AnilistListTab extends StatefulWidget {
  final UserListTabController controller;
  final UserListAdapter adapter;
  final ListDisplay display;

  /// Layout of [DisplaySubType.custom], null falls back to the standard rows.
  final ContentCardProps? cardProfile;
  final EntryActions actions;
  final EntryCardStyle style;

  /// AniList's fields and the score format of one row.
  final AnilistRowData Function(ListEntryView entry) dataOf;

  /// Clears the filter and the search (empty state button), null hides it.
  final VoidCallback? onClearFilters;

  const AnilistListTab({
    super.key,
    required this.controller,
    required this.adapter,
    required this.display,
    required this.cardProfile,
    required this.actions,
    required this.style,
    required this.dataOf,
    this.onClearFilters,
  });

  @override
  State<AnilistListTab> createState() => _AnilistListTabState();
}

class _AnilistListTabState extends State<AnilistListTab> with AutomaticKeepAliveClientMixin {
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
    final display = widget.display;
    if (entries.isEmpty) {
      if (!c.isStarted || c.isLoading) return _Skeleton(display: display);
      final error = c.error;
      if (error != null) {
        final expired = widget.adapter.isSessionExpired(error);
        return _Message(
          icon: expired ? Icons.lock_clock_outlined : Icons.cloud_off_rounded,
          title: expired ? S.current.UserList_Session_Expired : S.current.UserList_Load_Error,
          action: expired
              ? (S.current.UserList_Sign_In_Again, () => widget.adapter.signInAgain(context))
              : (S.current.UserList_Retry, c.refresh),
          onRefresh: c.refresh,
        );
      }
      final filtered = !c.settings.filter.isEmpty || c.query.trim().isNotEmpty;
      if (filtered && c.hasMore) return _Skeleton(display: display);
      return _Message(
        icon: filtered ? Icons.filter_alt_off_outlined : Icons.inbox_outlined,
        title: filtered ? S.current.UserList_No_Match : S.current.UserList_Empty,
        action: filtered && widget.onClearFilters != null
            ? (S.current.UserList_Clear_Filters, widget.onClearFilters!)
            : null,
        onRefresh: c.refresh,
      );
    }
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
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
      final compact = display.subType == DisplaySubType.compact;
      final scaler = MediaQuery.textScalerOf(context);
      list = SliverFixedExtentList.builder(
        itemExtent: profile != null
            ? profile.height + 8
            : anilistRowExtent(compact: compact, scaler: scaler),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          if (profile != null) {
            return CustomEntryCard(
              key: ValueKey(e.id),
              props: profile,
              entry: e,
              actions: widget.actions,
              now: now,
              locale: locale,
            );
          }
          final data = widget.dataOf(e);
          return AnilistEntryRow(
            key: ValueKey(e.id),
            entry: e,
            detail: data.detail,
            format: data.format,
            compact: compact,
            actions: widget.actions,
            style: widget.style,
            now: now,
          );
        },
      );
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: CustomScrollView(
        key: PageStorageKey('al-list-${c.category}-${c.status?.name ?? 'all'}'),
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

/// One row of the AniList list, AniHyou's standard item: cover; title with the user's score
/// in the account's format; the label rail (format · next episode · behind · status); progress
/// bar, progress, community %, AniList's marks and the +1 buttons. [compact] keeps one line
/// of title and a smaller cover.
class AnilistEntryRow extends StatelessWidget {
  final ListEntryView entry;
  final AnilistListEntry? detail;
  final AnilistScoreFormat format;
  final bool compact;
  final EntryActions actions;
  final EntryCardStyle style;
  final DateTime now;

  const AnilistEntryRow({
    super.key,
    required this.entry,
    required this.detail,
    required this.format,
    required this.compact,
    required this.actions,
    required this.style,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(12);
    final coverW = compact ? 50.0 : 72.0;
    final coverH = compact ? 72.0 : 108.0;
    final raw = detail?.scoreRaw ?? entry.score * 10;
    final rail = anilistRailOf(context, entry, detail, now: now, showStatus: style.showStatus);
    final scoreStyle = theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700, color: scheme.onSurface);
    final title = Text(
      entry.title,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: (compact ? theme.textTheme.bodyMedium : theme.textTheme.titleSmall)
          ?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
    );
    final scored = raw > 0 && entry.status != null;
    final score = scored
        ? Semantics(
            label: anilistUserScoreText(raw, format)?.spoken,
            excludeSemantics: true,
            child: ScoreReveal(
              iconSize: 16,
              child: AnilistUserScore(raw: raw, format: format, style: scoreStyle),
            ),
          )
        : null;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            if (score != null) ...[const SizedBox(width: 8), score],
          ],
        ),
        const SizedBox(height: 3),
        if (rail.isNotEmpty) _Rail(labels: rail),
        const Spacer(),
        if (!compact) ...[
          EntryProgressBar(entry: entry, height: 4),
          const SizedBox(height: 2),
        ],
        Row(
          children: [
            Flexible(
              child: Text(
                progressText(entry),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            if (!compact && anilistPercentOf(entry) != null) ...[
              const SizedBox(width: 10),
              _Percent(percent: anilistPercentOf(entry)!),
            ],
            if (entry.timesRewatched > 0) ...[
              const SizedBox(width: 6),
              RewatchPill(entry: entry, short: true),
            ],
            const SizedBox(width: 6),
            EntryCardBadges(entry: entry, short: true),
            const Spacer(),
            // AniHyou's row: +1 only (and edit); -1 stays in the editor.
            EntryStepper(entry: entry, actions: actions, compact: true),
          ],
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        type: style.cardBackground ? MaterialType.canvas : MaterialType.transparency,
        color: style.cardBackground ? scheme.surfaceContainerLow : null,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => actions.onOpen(entry),
          onLongPress: actions.onEdit == null ? null : () => actions.onEdit!(entry),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: coverW,
                  child: Stack(
                    children: [
                      EntryCover(
                        entry: entry,
                        width: coverW,
                        height: coverH,
                        borderRadius: BorderRadius.circular(compact ? 6 : 8),
                      ),
                      PositionedDirectional(top: 3, end: 3, child: EntryDubBadge(entry: entry)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The label rail on one line: small tonal labels, cut at the row's end.
class _Rail extends StatelessWidget {
  final List<AnilistRailLabel> labels;
  const _Rail({required this.labels});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(fontSize: 11, height: 1.3);
    final spans = <InlineSpan>[];
    for (var i = 0; i < labels.length; i++) {
      final l = labels[i];
      if (i > 0) {
        spans.add(TextSpan(text: '  ·  ', style: TextStyle(color: scheme.outline)));
      }
      spans.add(TextSpan(
        text: l.text,
        style: TextStyle(
          color: l.role?.color ?? scheme.onSurfaceVariant,
          fontWeight: l.role == null ? FontWeight.w500 : FontWeight.w700,
        ),
      ));
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// `82%` with anilist.co's face, coloured on its scale (hidden by the "Hide score" setting).
class _Percent extends StatelessWidget {
  final int percent;
  const _Percent({required this.percent});

  @override
  Widget build(BuildContext context) {
    final role = anilistPercentRole(context, percent);
    final text = AnilistMediaFormat.percent(percent);
    return Semantics(
      label: S.current.Ald_Average_Score(text),
      excludeSemantics: true,
      child: ScoreReveal(
        iconSize: 14,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(anilistPercentIcon(percent), size: 15, color: role.color),
            const SizedBox(width: 3),
            Text(text,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: role.color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// End of the list: asks the next page when built, a spinner meanwhile, Retry after an error.
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

/// Empty or error state: icon, one line, optional action; pull to refresh still works.
class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final (String, VoidCallback)? action;
  final Future<void> Function() onRefresh;

  const _Message({
    required this.icon,
    required this.title,
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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                    if (action != null) ...[
                      const SizedBox(height: 16),
                      FilledButton.tonal(onPressed: action!.$2, child: Text(action!.$1)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grey placeholders while the section loads (no animation per row).
class _Skeleton extends StatelessWidget {
  final ListDisplay display;
  const _Skeleton({required this.display});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget box(double? w, double h, double r) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(r)),
        );
    if (display.isGrid) {
      return GridView.builder(
        padding: listGridPadding(display.subType, top: 8),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: listGridDelegate(display),
        itemCount: 12,
        itemBuilder: (_, __) => box(null, display.gridHeight, 10),
      );
    }
    final compact = display.subType == DisplaySubType.compact;
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemExtent: anilistRowExtent(compact: compact),
      itemCount: 10,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            box(compact ? 50 : 72, compact ? 70 : 104, 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(double.infinity, 12, 4),
                  const SizedBox(height: 8),
                  box(140, 10, 4),
                  if (!compact) ...[
                    const SizedBox(height: 18),
                    box(double.infinity, 4, 2),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
