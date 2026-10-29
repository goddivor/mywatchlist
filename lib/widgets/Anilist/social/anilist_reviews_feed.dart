import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_review_composer.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_review_tile.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumMessage, ForumSkeleton;

/// Opens the AniList reviews: of title [mediaId] (with "Write a review"), by user
/// [userId], or the latest of everyone. [title] names the page (the title or the user).
Future<void> openAnilistReviews(
  BuildContext context, {
  int? mediaId,
  int? userId,
  String? title,
}) =>
    AppRoutes.push<void>(
      context,
      Scaffold(
        appBar: AppBar(title: Text(title ?? S.current.Reviews)),
        body: AnilistReviewsFeed(mediaId: mediaId, userId: userId, mediaTitle: title),
      ),
    );

/// AniList reviews page by page, sorted (newest, most helpful, highest or lowest score) and,
/// for everyone's reviews, narrowed to anime or manga.
class AnilistReviewsFeed extends StatefulWidget {
  const AnilistReviewsFeed({
    super.key,
    this.mediaId,
    this.userId,
    this.mediaTitle,
    this.service,
  });

  final int? mediaId;
  final int? userId;

  /// The title's name, for the composer.
  final String? mediaTitle;
  final AnilistSocialService? service;

  @override
  State<AnilistReviewsFeed> createState() => _AnilistReviewsFeedState();
}

class _AnilistReviewsFeedState extends State<AnilistReviewsFeed> {
  final List<AnilistReview> _items = [];
  AnilistReviewSort _sort = AnilistReviewSort.newest;

  /// `ANIME`, `MANGA` or null (both).
  String? _type;
  int _page = 0;
  int _generation = 0;
  bool _loading = false;
  bool _hasNext = true;
  Object? _error;

  AnilistSocialService get _service => widget.service ?? AnilistSocialService.instance;

  @override
  void initState() {
    super.initState();
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

  void _change(VoidCallback change) {
    setState(() {
      change();
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
      final page = await _service.reviews(
        mediaId: widget.mediaId,
        userId: widget.userId,
        mediaType: _type,
        sort: _sort,
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      final known = {for (final r in _items) r.id};
      setState(() {
        _page++;
        _items.addAll(page.items.where((r) => !known.contains(r.id)));
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

  Future<void> _write() async {
    final mediaId = widget.mediaId;
    if (mediaId == null) return;
    final saved = await openAnilistReviewComposer(context,
        mediaId: mediaId, mediaTitle: widget.mediaTitle, service: _service);
    if (saved != null && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String sortLabel(AnilistReviewSort sort) => switch (sort) {
          AnilistReviewSort.newest => s.Als_Sort_Newest,
          AnilistReviewSort.helpful => s.Als_Sort_Helpful,
          AnilistReviewSort.highestScore => s.Als_Sort_Highest,
          AnilistReviewSort.lowestScore => s.Als_Sort_Lowest,
          AnilistReviewSort.updated => s.Als_Sort_Updated,
        };
    final sorts = [
      AnilistReviewSort.newest,
      AnilistReviewSort.helpful,
      AnilistReviewSort.highestScore,
      AnilistReviewSort.lowestScore,
    ];
    final filters = SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          if (widget.mediaId == null) ...[
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: '', label: Text(s.All)),
                ButtonSegment(value: 'ANIME', label: Text(s.Anime_Caps)),
                ButtonSegment(value: 'MANGA', label: Text(s.Manga_Caps)),
              ],
              selected: {_type ?? ''},
              onSelectionChanged: (v) => _change(() => _type = v.first.isEmpty ? null : v.first),
            ),
            const SizedBox(width: 12),
          ],
          for (final sort in sorts)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(sortLabel(sort)),
                selected: _sort == sort,
                onSelected: (_) => _change(() => _sort = sort),
              ),
            ),
        ],
      ),
    );

    final Widget body;
    if (_items.isEmpty) {
      if (_loading) {
        body = const ForumSkeleton(count: 6, rowHeight: 96);
      } else if (_error != null) {
        body = ForumMessage(
            icon: Icons.cloud_off_outlined, title: anilistErrorText(_error!), onRetry: _load);
      } else {
        body = RefreshIndicator(
          onRefresh: _refresh,
          child: ForumMessage(icon: Icons.rate_review_outlined, title: s.Als_Reviews_Empty),
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
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: _items.length + 1,
            itemBuilder: (context, i) {
              if (i == _items.length) {
                return AnilistPageFooter(loading: _loading, failed: _error != null, onRetry: _load);
              }
              final r = _items[i];
              return AnilistReviewTile(
                key: ValueKey(r.id),
                review: r,
                showMedia: widget.mediaId == null,
                onChanged: (updated) => setState(() => _items[i] = updated),
              );
            },
          ),
        ),
      );
    }

    return Stack(
      children: [
        Column(children: [filters, Expanded(child: body)]),
        if (widget.mediaId != null && _service.signedIn)
          PositionedDirectional(
            end: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: null,
              onPressed: _write,
              icon: const Icon(Icons.rate_review_outlined),
              label: Text(s.Als_Write_Review),
            ),
          ),
      ],
    );
  }
}
