import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_feed_parts.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// The groups directory, most recently active first, with a search box.
class KitsuGroupsList extends StatefulWidget {
  final KitsuFeed feed;
  final void Function(KitsuGroup group) onOpenGroup;
  const KitsuGroupsList({super.key, required this.feed, required this.onOpenGroup});

  @override
  State<KitsuGroupsList> createState() => _KitsuGroupsListState();
}

class _KitsuGroupsListState extends State<KitsuGroupsList> with AutomaticKeepAliveClientMixin {
  final _groups = <KitsuGroup>[];
  final _seen = <String>{};
  final _search = TextEditingController();
  int? _next = 0;
  bool _loading = false;
  bool _loaded = false;
  bool _failed = false;
  String _query = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reset() {
    _generation++;
    _groups.clear();
    _seen.clear();
    _next = 0;
    _loading = false;
    _loaded = false;
    _failed = false;
    return _load();
  }

  Future<void> _load() async {
    final offset = _next;
    if (_loading || offset == null) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.feed.groups(offset: offset, query: _query);
      if (!mounted || generation != _generation) return;
      for (final g in page.groups) {
        if (_seen.add(g.id)) _groups.add(g);
      }
      _next = page.nextOffset;
      _loaded = true;
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _failed = true;
    }
    if (mounted && generation == _generation) setState(() => _loading = false);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 600) _load();
    return false;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final theme = Theme.of(context);
    final Widget body;
    if (_failed && _groups.isEmpty) {
      body = KitsuStateMessage(
        icon: Icons.cloud_off_outlined,
        title: s.Kc_Error_Title,
        actionLabel: s.Kc_Retry,
        onAction: _reset,
        top: true,
      );
    } else if (!_loaded) {
      body = const Align(
        alignment: Alignment.topCenter,
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      );
    } else if (_groups.isEmpty) {
      body = KitsuStateMessage(icon: Icons.groups_outlined, title: s.Kc_Empty, top: true);
    } else {
      body = RefreshIndicator(
        onRefresh: _reset,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _groups.length + 1,
            itemBuilder: (context, i) {
              if (i == _groups.length) {
                return KitsuListFooter(loading: _loading, failed: _failed, onRetry: _load);
              }
              final g = _groups[i];
              return ListTile(
                leading: AppImage(
                  url: g.avatarUrl,
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.circular(8),
                  placeholderColor: theme.colorScheme.surfaceContainerHighest,
                  errorWidget: (_) => Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.groups_outlined,
                        color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
                title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    s.Kc_Member_Count(g.membersCount),
                    if (g.tagline != null && g.tagline!.trim().isNotEmpty) g.tagline!.trim(),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => widget.onOpenGroup(g),
              );
            },
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: s.Kc_Group_Search,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onSubmitted: (value) {
              _query = value.trim();
              setState(() {});
              _reset();
            },
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
