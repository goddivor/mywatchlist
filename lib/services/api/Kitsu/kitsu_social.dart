import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';

/// The social side of a Kitsu profile (activity, reactions, posts, followers, favourites, another
/// user's list, user search), read through [KitsuGraphql]. Public data, read-only: nothing here
/// writes to a Kitsu account.
class KitsuSocial {
  KitsuSocial({KitsuGraphql? graphql}) : _graphql = graphql;

  /// Replaced by tests.
  static KitsuSocial instance = KitsuSocial();

  final KitsuGraphql? _graphql;
  KitsuGraphql get _gql => _graphql ?? KitsuGraphql.instance;

  /// Favourite characters and people sit among the titles in one connection, so they are
  /// collected page by page; at most this many pages are read.
  static const int maxFavouritePages = 4;

  /// The header data of [slug]: site links, pinned post, counters. `null` when unknown.
  Future<KitsuProfileSummary?> summary(String slug) => _gql.profile(slug);

  Future<KitsuConnection<KitsuLibraryEvent>> activity(String slug, KitsuPageArgs page) =>
      _gql.profileActivity(slug, page);

  Future<KitsuConnection<KitsuReaction>> reactions(String slug, KitsuPageArgs page) =>
      _gql.profileReactions(slug, page);

  Future<KitsuConnection<KitsuPost>> posts(String slug, KitsuPageArgs page) =>
      _gql.profilePosts(slug, page);

  Future<KitsuConnection<KitsuAuthor>> followers(String slug, KitsuPageArgs page) =>
      _gql.profileFollowers(slug, page);

  Future<KitsuConnection<KitsuAuthor>> following(String slug, KitsuPageArgs page) =>
      _gql.profileFollowing(slug, page);

  Future<KitsuConnection<KitsuAuthor>> searchUsers(String username, KitsuPageArgs page) =>
      _gql.searchProfiles(username, page);

  /// A page of the public library of [slug]; [status] is one `LibraryEntryStatusEnum` value or
  /// `null` for every status.
  Future<KitsuConnection<KitsuLibraryItem>> library(
    String slug, {
    required KitsuMediaKind kind,
    String? status,
    required KitsuPageArgs page,
  }) =>
      _gql.profileLibrary(slug, kind: kind, statuses: status == null ? null : [status], page: page);

  /// The favourites of [slug] whose [KitsuFavourite.type] is [type] (`Character` or `Person`), in
  /// the user's order.
  Future<List<KitsuFavourite>> favourites(String slug, String type) async {
    final out = <KitsuFavourite>[];
    var page = const KitsuPageArgs(first: KitsuPageArgs.maxSize);
    for (var i = 0; i < maxFavouritePages; i++) {
      final connection = await _gql.profileFavourites(slug, page);
      out.addAll(connection.nodes.where((f) => f.type == type));
      final next = connection.nextPage(first: KitsuPageArgs.maxSize);
      if (next == null) break;
      page = next;
    }
    return out;
  }
}

/// A cursor-paged list that loads page after page. The UI listens and reads [items].
class KitsuPager<T> extends ChangeNotifier {
  KitsuPager(this._fetch, {this.pageSize = KitsuPageArgs.defaultSize});

  final Future<KitsuConnection<T>> Function(KitsuPageArgs page) _fetch;
  final int pageSize;

  final List<T> items = [];
  int? total;
  bool loading = false;
  bool loaded = false;
  Object? error;
  KitsuPageArgs? _next = const KitsuPageArgs();
  bool _disposed = false;
  int _generation = 0;

  bool get hasMore => _next != null;

  /// Loads the first page, or the next one; does nothing while a page is loading or at the end.
  Future<void> loadMore() async {
    final page = _next;
    if (loading || page == null) return;
    loading = true;
    error = null;
    notifyListeners();
    final generation = _generation;
    try {
      final connection = await _fetch(KitsuPageArgs(first: pageSize, after: page.after));
      if (_disposed || generation != _generation) return;
      items.addAll(connection.nodes);
      total = connection.totalCount ?? total;
      _next = connection.nextPage(first: pageSize);
      loaded = true;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  /// Starts again from the first page.
  Future<void> reload() {
    _generation++;
    items.clear();
    total = null;
    loaded = false;
    error = null;
    _next = const KitsuPageArgs();
    loading = false;
    return loadMore();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
