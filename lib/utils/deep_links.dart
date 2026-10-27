import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/enums.dart' show SeasonType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/main.dart' show appNavigatorKey;
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/MAL/featured_screen.dart';
import 'package:mywatchlist/screens/forum/club_screen.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/screens/forum/forum_topics_screen.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_screen.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_topics_data.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/constants/constants.dart' show showToast;

/// Opens myanimelist.net links inside the app.
///
/// [DeepLinks.start] (called once from `main`) does two things:
/// - registers [WebLauncher.internalLinkHandler], so a tap on a MyAnimeList link anywhere in the
///   app (synopsis, forum post, review...) opens its screen directly, without the "leave the
///   app?" dialog;
/// - listens to links the system hands to the app (`https://myanimelist.net/...` through the
///   Android intent filters) and routes them the same way.
///
/// [screenForLink] is the pure mapping from a parsed link to a screen.
abstract final class DeepLinks {
  static StreamSubscription<Uri>? _sub;
  static Uri? _lastHandled;
  static DateTime? _lastHandledAt;

  /// Registers the in-app handler and starts listening to system links. Safe to call twice.
  static Future<void> start({AppLinks? appLinks}) async {
    register();
    if (_sub != null) return;
    final links = appLinks ?? AppLinks();
    _sub = links.uriLinkStream.listen(_onSystemLink, onError: (Object e) => debugPrint('Deep link error: $e'));
    try {
      final initial = await links.getInitialLink();
      if (initial != null) unawaited(_onSystemLink(initial));
    } catch (e) {
      debugPrint('Initial deep link unavailable: $e');
    }
  }

  /// Only registers [WebLauncher.internalLinkHandler].
  static void register() => WebLauncher.internalLinkHandler = _handle;

  /// Stops listening (tests).
  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _lastHandled = null;
    _lastHandledAt = null;
    if (WebLauncher.internalLinkHandler == _handle) WebLauncher.internalLinkHandler = null;
  }

  static Future<bool> _handle(BuildContext context, MalLink link) async {
    final screen = screenForLink(link);
    if (screen == null) return false;
    await AppRoutes.push<void>(context, screen);
    return true;
  }

  /// A link from the system. The initial link can arrive twice (stream and `getInitialLink`),
  /// so the same uri within 3 seconds is handled once. Links of the OAuth scheme are `main`'s.
  static Future<void> _onSystemLink(Uri uri) async {
    if (uri.scheme != 'https' && uri.scheme != 'http') return;
    final link = parseMalLink(uri);
    if (link == null) return;
    final now = DateTime.now();
    if (_lastHandled == uri && _lastHandledAt != null && now.difference(_lastHandledAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastHandled = uri;
    _lastHandledAt = now;
    final screen = screenForLink(link);
    final context = await _navigatorContext();
    if (context == null) return;
    if (screen == null) {
      showToast('${S.current.Couldn_Launch} $uri');
      return;
    }
    await AppRoutes.push<void>(context, screen);
  }

  /// On a cold start the navigator can be a few frames away: wait for it, at most 10 seconds.
  static Future<BuildContext?> _navigatorContext() async {
    for (var i = 0; i < 34; i++) {
      final context = appNavigatorKey.currentContext;
      if (context != null && context.mounted) return context;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return null;
  }

  /// The screen of a MyAnimeList [link], or null when the app has none for it (the caller then
  /// falls back to the browser).
  ///
  /// | Link | Screen |
  /// | --- | --- |
  /// | `/anime/<id>[/slug]`, `/manga/<id>[/slug]` | content detail |
  /// | `/character/<id>`, `/people/<id>` | character / person |
  /// | `/profile/<name>` | MyAnimeList profile |
  /// | `/forum/?topicid=` / `?board=` / `?subboard=` | topic posts / board / sub-board |
  /// | `/clubs.php?cid=` | club |
  /// | `/featured/<id>`, `/news/<id>` | article |
  /// | `/anime/genre/<id>`, `/manga/genre/<id>`, `/anime/producer/<id>`, `/manga/magazine/<id>`, `/anime/season/<year>/<season>`, `/anime.php?q=`, `/manga.php?q=` | search entry points |
  static Widget? screenForLink(MalLink link) {
    final seg = link.segments;
    final second = seg.length > 1 ? seg[1].toLowerCase() : '';
    switch (link.kind) {
      case 'anime':
      case 'manga':
        return _animeManga(link, second);
      case 'character':
      case 'people':
        final id = link.id;
        if (id == null || id <= 0) return null;
        return CharacterScreen(id: id, category: link.kind);
      case 'profile':
        final name = seg.length > 1 ? seg[1].trim() : '';
        if (name.isEmpty) return null;
        // Profile links are MyAnimeList usernames whatever tracker is signed in.
        return UserProfileScreen(username: name);
      case 'forum':
        return _forum(link);
      case 'clubs.php':
        final id = int.tryParse(link.query['cid'] ?? '');
        if (id == null || id <= 0) return null;
        return ClubScreen(clubHtml: ClubHtml(id: id));
      case 'featured':
      case 'news':
        final id = link.id;
        if (id == null || id <= 0) return null;
        return FeaturedScreen(id: id, category: link.kind);
      case 'anime.php':
      case 'manga.php':
        final query = link.query['q']?.trim() ?? '';
        if (query.isEmpty) return null;
        return GeneralSearchScreen.byQuery(
          query,
          category: link.kind == 'manga.php' ? SearchCategory.manga : SearchCategory.anime,
        );
    }
    return null;
  }

  static Widget? _animeManga(MalLink link, String second) {
    final manga = link.kind == 'manga';
    final category = manga ? SearchCategory.manga : SearchCategory.anime;
    final id = link.segments.length > 2 ? int.tryParse(link.segments[2]) : null;
    switch (second) {
      case 'genre':
        return id == null ? null : GeneralSearchScreen.byGenre(ids: [id], category: category);
      case 'producer':
        return manga || id == null ? null : GeneralSearchScreen.byStudio(id: id, name: _name(link));
      case 'magazine':
        return !manga || id == null ? null : GeneralSearchScreen.byMagazine(id: id, name: _name(link));
      case 'season':
        if (manga) return null;
        final year = int.tryParse(link.segments.length > 2 ? link.segments[2] : '');
        final season = _season(link.segments.length > 3 ? link.segments[3] : '');
        if (year == null || season == null) return null;
        return GeneralSearchScreen.bySeason(season, year);
    }
    final contentId = int.tryParse(link.segments.length > 1 ? link.segments[1] : '');
    if (contentId == null || contentId <= 0) return null;
    return ContentDetailedScreen(node: null, id: contentId, category: link.kind);
  }

  static String? _name(MalLink link) {
    if (link.segments.length < 4) return null;
    final name = link.segments[3].replaceAll('_', ' ').trim();
    return name.isEmpty ? null : name;
  }

  static SeasonType? _season(String value) {
    for (final season in SeasonType.values) {
      if (season.name.toLowerCase() == value.toLowerCase()) return season;
    }
    return null;
  }

  static Widget? _forum(MalLink link) {
    final topic = int.tryParse(link.query['topicid'] ?? '');
    if (topic != null && topic > 0) return ForumPostsScreen(topic: ForumTopicsData(id: topic));
    final board = int.tryParse(link.query['board'] ?? '');
    if (board != null && board > 0) return ForumTopicsScreen(boardId: board);
    final sub = int.tryParse(link.query['subboard'] ?? '');
    if (sub != null && sub > 0) return ForumTopicsScreen(subBoardId: sub);
    return null;
  }
}
