import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';

/// Loads one Kitsu feed page by page for a list screen: the posts of a feed, newest first, with
/// the cursor kept between pages.
///
/// A feed holds posts, comments and reactions; the screens list posts only, since a comment or a
/// reaction carries no link to its post in the feed document. Items are deduplicated by post id
/// across pages. A failed first load keeps [error] set until [reload]; a failed next page keeps
/// the posts already shown and sets [loadMoreFailed] so the list can offer a retry.
class KitsuFeedController extends ChangeNotifier {
  KitsuFeedController(this._fetch);

  /// Fetches one page: the cursor is `null` for the first.
  final Future<KitsuFeedPage> Function(String? cursor) _fetch;

  final List<KitsuFeedPost> _posts = [];
  final Set<String> _seen = {};
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _loaded = false;
  Object? _error;
  bool _loadMoreFailed = false;
  bool _disposed = false;

  /// Bumped on [reload] so a page that answers late for an older load is ignored.
  int _generation = 0;

  List<KitsuFeedPost> get posts => List.unmodifiable(_posts);
  int get length => _posts.length;
  KitsuFeedPost operator [](int index) => _posts[index];
  bool get hasMore => _hasMore;
  bool get isLoading => _loading;

  /// True once a first page answered (even empty).
  bool get isLoaded => _loaded;
  Object? get error => _error;
  bool get loadMoreFailed => _loadMoreFailed;

  /// The first load is running and nothing is shown yet.
  bool get isFirstLoad => _loading && _posts.isEmpty;

  /// Starts again from the first page (pull to refresh, retry).
  Future<void> reload() {
    _generation++;
    _posts.clear();
    _seen.clear();
    _cursor = null;
    _hasMore = true;
    _loading = false;
    _loaded = false;
    _error = null;
    _loadMoreFailed = false;
    return loadMore();
  }

  /// Loads the next page; does nothing while loading or on the last page.
  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    _loading = true;
    _loadMoreFailed = false;
    _notify();
    try {
      final page = await _fetch(_cursor);
      if (generation != _generation) return;
      for (final item in page.items) {
        final post = item.post;
        if (post != null && _seen.add(post.id)) _posts.add(post);
      }
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
      _loaded = true;
      _error = null;
    } catch (e) {
      if (generation != _generation) return;
      if (_posts.isEmpty) {
        _error = e;
      } else {
        _loadMoreFailed = true;
      }
      _hasMore = _posts.isNotEmpty;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The feeds the community screens read, over one [KitsuGraphql] client.
class KitsuFeed {
  KitsuFeed({KitsuGraphql? client}) : _client = client ?? KitsuGraphql.instance;

  final KitsuGraphql _client;

  /// The official Kitsu News Network group: its feed is the Kitsu news.
  static const String newsGroupId = '596';

  /// Kitsu's site, for what the app does not show (a long reply thread).
  static const String siteUrl = 'https://kitsu.app';

  static String postUrl(String id) => '$siteUrl/posts/$id';

  /// Latest posts of the whole site.
  KitsuFeedController latest() => KitsuFeedController((c) => _client.globalFeed(cursor: c));

  /// News posts (group 596).
  KitsuFeedController news() => group(newsGroupId);

  /// Posts of one group.
  KitsuFeedController group(String groupId) =>
      KitsuFeedController((c) => _client.groupFeed(groupId, cursor: c));

  /// Posts about one title.
  KitsuFeedController media(KitsuMediaKind kind, String mediaId) =>
      KitsuFeedController((c) => _client.mediaFeed(kind, mediaId, cursor: c));

  /// The latest [limit] news posts, for a home row.
  Future<List<KitsuFeedPost>> newsPosts({int limit = 10}) async {
    final page = await _client.groupFeed(newsGroupId, limit: limit);
    return [
      for (final item in page.items)
        if (item.post != null) item.post!,
    ];
  }

  /// A page of the groups directory.
  Future<KitsuGroupPage> groups({int offset = 0, String sort = '-lastActivityAt', String? query}) =>
      _client.groups(offset: offset, sort: sort, query: query);

  /// A post with a page of its comments.
  Future<KitsuPostThread?> thread(String postId, [KitsuPageArgs page = const KitsuPageArgs()]) =>
      _client.post(postId, page);
}
