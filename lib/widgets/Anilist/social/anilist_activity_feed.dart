import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_activity_tile.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_composer.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumMessage, ForumSkeleton;

/// The AniList activity feed: Following (signed in) or Global, narrowed to a kind, page by
/// page, with pull to refresh and a button to post a status.
///
/// With [userId] it is that user's activity (their profile's Activity tab), with [mediaId]
/// the activity about one title; neither has the Following / Global switch.
class AnilistActivityFeed extends StatefulWidget {
  const AnilistActivityFeed({
    super.key,
    this.userId,
    this.mediaId,
    this.showComposer = true,
    this.service,
  });

  final int? userId;
  final int? mediaId;

  /// Shows the "post a status" button (only for the signed-in user's feeds).
  final bool showComposer;
  final AnilistSocialService? service;

  @override
  State<AnilistActivityFeed> createState() => _AnilistActivityFeedState();
}

class _AnilistActivityFeedState extends State<AnilistActivityFeed> {
  final List<AnilistActivity> _items = [];
  late AnilistFeedScope _scope;
  AnilistFeedKind _kind = AnilistFeedKind.all;
  int _page = 0;
  int _generation = 0;
  bool _loading = false;
  bool _hasNext = true;
  Object? _error;
  int? _viewerId;

  AnilistSocialService get _service => widget.service ?? AnilistSocialService.instance;

  bool get _scoped => widget.userId != null || widget.mediaId != null;

  @override
  void initState() {
    super.initState();
    _scope = _service.signedIn && !_scoped ? AnilistFeedScope.following : AnilistFeedScope.global;
    _service.viewerId().then((id) {
      if (mounted && id != _viewerId) setState(() => _viewerId = id);
    });
    _load();
  }

  void _reset() {
    _generation++;
    _items.clear();
    _page = 0;
    _hasNext = true;
    _loading = false;
    _error = null;
  }

  void _setScope(AnilistFeedScope scope) {
    if (scope == _scope) return;
    setState(() {
      _scope = scope;
      if (scope == AnilistFeedScope.global && _kind == AnilistFeedKind.message) {
        _kind = AnilistFeedKind.all;
      }
      _reset();
    });
    _load();
  }

  void _setKind(AnilistFeedKind kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _reset();
    });
    _load();
  }

  Future<void> _refresh() async {
    setState(_reset);
    await _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasNext) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.activities(
        scope: _scope,
        kind: _kind,
        userId: widget.userId,
        mediaId: widget.mediaId,
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      final known = {for (final a in _items) a.id};
      setState(() {
        _page++;
        _items.addAll(page.items.where((a) => !known.contains(a.id)));
        _hasNext = page.hasNext && page.items.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _replace(AnilistActivity updated) {
    final i = _items.indexWhere((a) => a.id == updated.id);
    if (i >= 0) setState(() => _items[i] = updated);
  }

  void _remove(int id) => setState(() => _items.removeWhere((a) => a.id == id));

  Future<void> _compose() async {
    final s = S.of(context);
    await showAnilistComposer(
      context,
      title: s.Als_New_Status,
      service: _service,
      submit: (markdown) async {
        final posted = await _service.saveStatus(markdown);
        if (mounted) setState(() => _items.insert(0, posted));
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final signedIn = _service.signedIn;
    final ownFeed = widget.userId == null || (_viewerId != null && widget.userId == _viewerId);
    final kinds = [
      AnilistFeedKind.all,
      AnilistFeedKind.text,
      AnilistFeedKind.list,
      if (_scope == AnilistFeedScope.following || widget.userId != null) AnilistFeedKind.message,
    ];
    String kindLabel(AnilistFeedKind k) => switch (k) {
          AnilistFeedKind.all => s.All,
          AnilistFeedKind.text => s.Als_Kind_Status,
          AnilistFeedKind.list => s.Als_Kind_List,
          AnilistFeedKind.message => s.Als_Kind_Messages,
        };

    final filters = SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          if (!_scoped && signedIn) ...[
            SegmentedButton<AnilistFeedScope>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: AnilistFeedScope.following, label: Text(s.Als_Following)),
                ButtonSegment(value: AnilistFeedScope.global, label: Text(s.Als_Global)),
              ],
              selected: {_scope},
              onSelectionChanged: (v) => _setScope(v.first),
            ),
            const SizedBox(width: 12),
          ],
          for (final k in kinds)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(kindLabel(k)),
                selected: _kind == k,
                onSelected: (_) => _setKind(k),
              ),
            ),
        ],
      ),
    );

    final Widget body;
    if (_items.isEmpty) {
      if (_loading) {
        body = const ForumSkeleton(count: 6, round: true, rowHeight: 88);
      } else if (_error != null) {
        body = RefreshIndicator(
          onRefresh: _refresh,
          child: ForumMessage(
            icon: Icons.cloud_off_outlined,
            title: anilistErrorText(_error!),
            onRetry: _load,
          ),
        );
      } else {
        body = RefreshIndicator(
          onRefresh: _refresh,
          child: ForumMessage(icon: Icons.dynamic_feed_outlined, title: s.Als_Activity_Empty),
        );
      }
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 600) _load();
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: _items.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, i) {
              if (i == _items.length) {
                return AnilistPageFooter(loading: _loading, failed: _error != null, onRetry: _load);
              }
              final a = _items[i];
              return AnilistActivityTile(
                key: ValueKey(a.id),
                activity: a,
                viewerId: _viewerId,
                service: _service,
                onChanged: _replace,
                onDeleted: () => _remove(a.id),
              );
            },
          ),
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            filters,
            Expanded(child: body),
          ],
        ),
        if (widget.showComposer && signedIn && ownFeed && widget.mediaId == null)
          PositionedDirectional(
            end: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: null,
              tooltip: s.Als_New_Status,
              onPressed: _compose,
              child: const Icon(Icons.edit_outlined),
            ),
          ),
      ],
    );
  }
}
