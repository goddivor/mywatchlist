import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/screens/MAL/featured_screen.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// Loads one page of news of a title; replaceable in tests.
typedef NewsPageLoader = Future<AnimeNewsResponse> Function(int id, String category, int page);

/// News about a title (Jikan `news`), as a horizontal list of cards that loads
/// the next page near its end. Always ends in content, an empty state or an
/// error with Retry: Jikan down or slow (its client gives up after 12 s) never
/// leaves the skeleton on screen.
class ShowAnimeNews extends StatefulWidget {
  final int animeId;
  final String category;

  const ShowAnimeNews({super.key, required this.animeId, this.category = "anime"});

  /// The source of the news pages (tests replace it with a fake).
  static NewsPageLoader loader = _jikanNews;

  static Future<AnimeNewsResponse> _jikanNews(int id, String category, int page) =>
      JikanApi().getAnimeNews(id, page: page, category: category);

  /// Restores the Jikan source (tests).
  static void resetLoader() => loader = _jikanNews;

  @override
  State<ShowAnimeNews> createState() => _ShowAnimeNewsState();
}

enum _NewsState { loading, ready, failed }

class _ShowAnimeNewsState extends State<ShowAnimeNews> with AutomaticKeepAliveClientMixin {
  static const double _height = 280;
  static const double _cardWidth = 320;
  static const double _loadMoreDistance = 200;

  final List<AnimeNews> _news = [];
  final ScrollController _scroll = ScrollController();
  _NewsState _state = _NewsState.loading;
  int _page = 1;
  bool _hasNextPage = true;
  bool _loadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasNextPage || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreDistance) _loadMore();
  }

  Future<void> _loadFirstPage() async {
    _news.clear();
    _page = 1;
    _hasNextPage = true;
    if (_state != _NewsState.loading) setState(() => _state = _NewsState.loading);
    try {
      final response = await ShowAnimeNews.loader(widget.animeId, widget.category, _page);
      if (!mounted) return;
      setState(() {
        _news.addAll(response.data);
        _page++;
        _hasNextPage = (response.pagination.hasNextPage ?? false) && response.data.isNotEmpty;
        _state = _NewsState.ready;
      });
    } catch (e) {
      debugPrint('News of ${widget.category} ${widget.animeId} failed: $e');
      if (!mounted) return;
      setState(() => _state = _NewsState.failed);
    }
  }

  /// The next page; a failure keeps what is shown and stops asking.
  Future<void> _loadMore() async {
    // A flag, not setState: the trailing loading card is already in the list.
    _loadingMore = true;
    try {
      final response = await ShowAnimeNews.loader(widget.animeId, widget.category, _page);
      if (!mounted) return;
      setState(() {
        _news.addAll(response.data);
        _page++;
        _hasNextPage = (response.pagination.hasNextPage ?? false) && response.data.isNotEmpty;
      });
    } catch (e) {
      debugPrint('News page $_page of ${widget.animeId} failed: $e');
      if (mounted) setState(() => _hasNextPage = false);
    } finally {
      _loadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    switch (_state) {
      case _NewsState.loading:
        return SizedBox(
          height: _height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 3,
            itemBuilder: (_, __) => const _NewsLoadingCard(width: _cardWidth),
          ),
        );
      case _NewsState.failed:
        return SectionMessage.error(message: S.current.Dp_News_Failed, onRetry: _loadFirstPage);
      case _NewsState.ready:
        if (_news.isEmpty) {
          return SectionMessage(icon: Icons.newspaper_outlined, message: S.current.Dp_News_Empty);
        }
        return SizedBox(
          height: _height,
          child: ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemExtent: _cardWidth + 10,
            itemCount: _news.length + (_hasNextPage ? 1 : 0),
            itemBuilder: (context, index) => index < _news.length
                ? _NewsCard(news: _news[index], width: _cardWidth)
                : const _NewsLoadingCard(width: _cardWidth),
          ),
        );
    }
  }
}

class _NewsCard extends StatelessWidget {
  final AnimeNews news;
  final double width;

  const _NewsCard({required this.news, required this.width});

  String _date(BuildContext context) {
    final date = news.date == null ? null : DateTime.tryParse(news.date!);
    if (date == null) return '';
    try {
      return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date);
    } catch (_) {
      return date.toIso8601String().substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = _date(context);
    final comments = news.comments ?? 0;
    final id = news.malId;
    return Card(
      margin: const EdgeInsetsDirectional.only(end: 10, bottom: 4, top: 4),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: id == null
            ? null
            : () => gotoPage(
                  context: context,
                  newPage: FeaturedScreen(
                    id: id,
                    featureTitle: news.title,
                    imgUrl: news.images?.jpg?.imageUrl,
                    category: 'news',
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(
                url: news.images?.jpg?.imageUrl,
                width: 90,
                height: 240,
                borderRadius: BorderRadius.circular(12),
                placeholderColor: scheme.surfaceContainerHighest,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news.title ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        news.excerpt ?? '',
                        overflow: TextOverflow.fade,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            news.authorUsername ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (date.isNotEmpty)
                          Text(date, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                    if (comments > 0) ...[
                      const SizedBox(height: 4),
                      Semantics(
                        label: S.current.Dp_News_Comments(comments),
                        excludeSemantics: true,
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 13, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              NumberFormat.decimalPattern(Localizations.localeOf(context).toString())
                                  .format(comments),
                              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
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

class _NewsLoadingCard extends StatelessWidget {
  final double width;

  const _NewsLoadingCard({required this.width});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The shimmer paints over the shapes; any opaque theme colour works.
    Widget bar({double? height, double? width}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(4)),
        );
    return SizedBox(
      width: width,
      child: Card(
        margin: const EdgeInsetsDirectional.only(end: 10, bottom: 4, top: 4),
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ShimmerColor(
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 240,
                  width: 90,
                  decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(height: 16, width: double.infinity),
                      const SizedBox(height: 6),
                      bar(height: 16, width: 140),
                      const SizedBox(height: 12),
                      Expanded(child: bar()),
                      const SizedBox(height: 8),
                      bar(height: 12, width: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
