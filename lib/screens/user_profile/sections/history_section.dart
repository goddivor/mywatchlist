import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_history.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// Recent list activity of a user (what they watched or read, and when), grouped by day with
/// an All / Anime / Manga filter.
class HistorySection extends StatefulWidget {
  final String username;

  const HistorySection({super.key, required this.username});

  @override
  State<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<HistorySection> with AutomaticKeepAliveClientMixin {
  late Future<List<ProfileHistoryEntry>> _future;
  String? _category;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ProfileHistoryEntry>> _load() async {
    // Anime and manga are independent pages; one failing must not hide the other.
    Future<List<ProfileHistoryEntry>?> one(String type) async {
      try {
        final envelope = await MwlApi.i.getUserHistory(widget.username, type: type);
        if (envelope == null) return null;
        return parseHistoryEnvelope(envelope, category: type);
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([one('anime'), one('manga')]);
    if (results.every((r) => r == null)) throw StateError('History unavailable');
    return [...?results[0], ...?results[1]];
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final key = 'history_${widget.username}';
    return FutureBuilder<List<ProfileHistoryEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ProfileTabScroll(storageKey: key, slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: ProfileLoading(label: s.Prof_Loading),
            ),
          ]);
        }
        if (snapshot.hasError) {
          return ProfileTabScroll(storageKey: key, slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: ProfileErrorView(error: snapshot.error!, onRetry: _retry),
            ),
          ]);
        }
        final all = snapshot.data!;
        if (all.isEmpty) {
          return ProfileTabScroll(storageKey: key, slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: ProfileMessage(icon: Icons.history, title: s.Prof_History_Empty),
            ),
          ]);
        }
        final rows = _rows(all.where((e) => _category == null || e.category == _category));
        return ProfileTabScroll(storageKey: key, slivers: [
          SliverToBoxAdapter(child: _filters(context)),
          if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ProfileMessage(icon: Icons.history, title: s.Prof_History_Empty),
            )
          else
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) => rows[i].build(context),
            ),
        ]);
      },
    );
  }

  Widget _filters(BuildContext context) {
    final s = S.of(context);
    final options = <(String?, String)>[
      (null, s.Prof_History_All),
      ('anime', s.Prof_Anime),
      ('manga', s.Prof_Manga),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        children: [
          for (final (value, label) in options)
            ChoiceChip(
              label: Text(label),
              selected: _category == value,
              onSelected: (_) => setState(() => _category = value),
            ),
        ],
      ),
    );
  }

  /// Day headers and entries as one flat list: "Today", then "Yesterday", then the other days
  /// in the order MAL gave them.
  List<_HistoryRow> _rows(Iterable<ProfileHistoryEntry> entries) {
    final groups = <String, List<ProfileHistoryEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(e.dayLabel, () => []).add(e);
    }
    final keys = [
      if (groups.containsKey('Today')) 'Today',
      if (groups.containsKey('Yesterday')) 'Yesterday',
      ...groups.keys.where((k) => k != 'Today' && k != 'Yesterday'),
    ];
    final s = S.current;
    return [
      for (final key in keys) ...[
        _HistoryRow.header(
          key == 'Today'
              ? s.Prof_Today
              : key == 'Yesterday'
                  ? s.Prof_Yesterday
                  : key,
          groups[key]!.length,
        ),
        for (final e in groups[key]!) _HistoryRow.entry(e),
      ],
    ];
  }
}

class _HistoryRow {
  final String? title;
  final int count;
  final ProfileHistoryEntry? entry;

  const _HistoryRow.header(this.title, this.count) : entry = null;
  const _HistoryRow.entry(ProfileHistoryEntry this.entry)
      : title = null,
        count = 0;

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;
    if (e == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Row(
          children: [
            Expanded(child: Text(title!, style: theme.textTheme.titleSmall)),
            Text(
              S.of(context).Prof_History_Items(count),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return ListTile(
      dense: true,
      leading: Icon(
        e.category == 'manga' ? Icons.menu_book_outlined : Icons.play_circle_outline,
        color: theme.colorScheme.primary,
      ),
      title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: e.progress.isEmpty ? null : Text(e.progress),
      trailing: e.clock.isEmpty
          ? null
          : Text(e.clock, style: theme.textTheme.labelSmall),
      onTap: () => AppRoutes.openContent(context, id: e.id, category: e.category),
    );
  }
}
