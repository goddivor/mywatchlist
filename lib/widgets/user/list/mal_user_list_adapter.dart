import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart' show AccountType, TitleLang;
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/services/api/MAL/models/my_anime_list_status.dart'
    as anime_status;
import 'package:mywatchlist/services/api/MAL/models/my_manga_list_status.dart'
    as manga_status;
import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart' show ListStats;
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/contenteditwidget.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';

/// Thrown when MyAnimeList answers a list request with an error status.
class MalListError implements Exception {
  final int statusCode;
  const MalListError(this.statusCode);

  @override
  String toString() => 'MalListError($statusCode)';
}

/// Manga entry counts of a MyAnimeList user, or null when unknown.
typedef MangaStatsSource = Future<ListStats?> Function(String username);

/// The manga numbers of a profile: MAL's own profile page raced with Jikan by
/// [UserProfileRepository] (cached one hour), so they come without Jikan.
Future<ListStats?> profileMangaStats(String username) async {
  final data = await UserProfileRepository.instance.load(username);
  return data.manga.isEmpty ? null : data.manga;
}

/// The MyAnimeList lists of the signed-in user (`GET users/@me/animelist|mangalist`), or of
/// another user when [username] is given (`users/<name>/…`, read with the client id when no
/// MAL account is signed in).
class MalUserListAdapter extends UserListAdapter {
  MalUserListAdapter({
    this.username,
    Future<http.Response> Function(String url)? get,
    Future<http.Response> Function(Uri url)? jikanGet,
    MangaStatsSource? mangaStats,
    ListEntryService? entryService,
    String? Function()? owner,
    DateTime Function()? clock,
  })  : _get = get ?? MalApi.authorizedGet,
        _jikanGet = jikanGet ?? JikanClient.instance.get,
        // An injected Jikan getter alone tests the Jikan path: no profile source then.
        _mangaStats = mangaStats ?? (jikanGet == null ? profileMangaStats : null),
        _entryService = entryService ?? const MalListEntryService(),
        _owner = owner ?? (() => username ?? UserMalV2.instance.username),
        _clock = clock ?? DateTime.now;

  /// Another user's name; null = the signed-in user.
  final String? username;
  final Future<http.Response> Function(String url) _get;
  final Future<http.Response> Function(Uri url) _jikanGet;
  final MangaStatsSource? _mangaStats;
  final ListEntryService _entryService;
  final String? Function() _owner;
  final DateTime Function() _clock;

  bool get isSelf => username == null;

  /// Node fields asked for each entry (everything the cards, sorts and filters use).
  static const String nodeFields = 'id,title,main_picture,alternative_titles,mean,'
      'num_list_users,num_scoring_users,popularity,status,media_type,genres,'
      'start_date,end_date';
  static const String animeFields = '$nodeFields,num_episodes,broadcast,'
      'list_status{status,score,num_episodes_watched,is_rewatching,updated_at,'
      'priority,start_date,finish_date,tags}';
  static const String mangaFields = '$nodeFields,num_chapters,num_volumes,'
      'list_status{status,score,num_chapters_read,num_volumes_read,is_rereading,'
      'updated_at,priority,start_date,finish_date,tags}';

  @override
  AccountType get tracker => AccountType.myanimelist;

  @override
  String? get owner => _owner();

  /// MAL serves at most 1000 entries per list request.
  @override
  int get maxPageSize => 1000;

  @override
  List<ListSortOption> sortOptions(String category) =>
      standardSortOptions(isAnime: category == 'anime');

  @override
  String? apiSort(String category, String sortKey, SortDirection direction) {
    final prefix = category == 'anime' ? 'anime' : 'manga';
    return switch ((sortKey, direction)) {
      (ListSortKeys.updated, SortDirection.descending) => 'list_updated_at',
      (ListSortKeys.score, SortDirection.descending) => 'list_score',
      // MAL sorts titles by their main (romaji) title only.
      (ListSortKeys.title, SortDirection.ascending)
          when Preferences.general.preferredTitle == TitleLang.ro =>
        '${prefix}_title',
      (ListSortKeys.releaseStart, SortDirection.descending) => '${prefix}_start_date',
      _ => null,
    };
  }

  /// URL of one list page.
  @visibleForTesting
  static String pageUrl({
    required String category,
    required ListEntryStatus? status,
    required int offset,
    required int limit,
    String? sort,
    String? username,
  }) {
    final isAnime = category == 'anime';
    final query = <String>[
      'fields=${isAnime ? animeFields : mangaFields}',
      'limit=$limit',
      'offset=$offset',
      if (status != null) 'status=${status.malValue(isAnime: isAnime)}',
      if (sort != null) 'sort=$sort',
      // Another user's adult entries stay in their list, as on the own list (counts match).
      if (username != null) 'nsfw=1',
    ];
    final who = username == null ? '@me' : Uri.encodeComponent(username);
    return '${MalApi.userBaseEndPoint}/$who/${isAnime ? 'animelist' : 'mangalist'}?${query.join('&')}';
  }

  @override
  Future<ListPage> fetch({
    required String category,
    required ListEntryStatus? status,
    required int offset,
    required int limit,
    String? apiSort,
  }) async {
    final url = pageUrl(
      category: category,
      status: status,
      offset: offset,
      limit: limit.clamp(1, maxPageSize),
      sort: apiSort,
      username: username,
    );
    final response = await _get(url);
    if (response.statusCode == 401 && MalApi.sessionExpired.value) {
      throw const MalSessionExpired();
    }
    if (response.statusCode != 200) throw MalListError(response.statusCode);
    final input = (response.body, category, Preferences.general.preferredTitle.name);
    // Big pages (300 entries ≈ 250 KB) are parsed off the UI isolate.
    return response.body.length > 32 * 1024
        ? compute(_parsePage, input)
        : _parsePage(input);
  }

  @override
  Future<Map<ListEntryStatus, int>?> statusCounts(String category) async {
    try {
      if (!isSelf) {
        // Another user: the numbers of their profile (official API has no statistics for them).
        final data = await UserProfileRepository.instance.load(username);
        return countsOf(category == 'anime' ? data.anime : data.manga);
      }
      if (category == 'anime') {
        final response =
            await _get('${MalApi.userBaseEndPoint}/@me?fields=anime_statistics');
        if (response.statusCode != 200) return null;
        final stats = (json.decode(response.body) as Map)['anime_statistics'];
        if (stats is! Map) return null;
        int at(String k) => (stats[k] as num?)?.toInt() ?? 0;
        return {
          ListEntryStatus.current: at('num_items_watching'),
          ListEntryStatus.completed: at('num_items_completed'),
          ListEntryStatus.onHold: at('num_items_on_hold'),
          ListEntryStatus.dropped: at('num_items_dropped'),
          ListEntryStatus.planned: at('num_items_plan_to_watch'),
        };
      }
      // MAL's API has no manga statistics: MAL's profile page (raced with Jikan), then Jikan.
      final name = owner;
      if (name == null || name.isEmpty) return null;
      final source = _mangaStats;
      if (source != null) {
        try {
          final stats = await source(name);
          if (stats != null) return countsOf(stats);
        } catch (e) {
          debugPrint('MalUserListAdapter.statusCounts (profile): $e');
        }
      }
      final response = await _jikanGet(Uri.parse(
          'https://api.jikan.moe/v4/users/${Uri.encodeComponent(name)}/statistics'));
      if (response.statusCode != 200) return null;
      final manga = ((json.decode(response.body) as Map)['data'] as Map?)?['manga'];
      if (manga is! Map) return null;
      int at(String k) => (manga[k] as num?)?.toInt() ?? 0;
      return {
        ListEntryStatus.current: at('reading'),
        ListEntryStatus.completed: at('completed'),
        ListEntryStatus.onHold: at('on_hold'),
        ListEntryStatus.dropped: at('dropped'),
        ListEntryStatus.planned: at('plan_to_read'),
      };
    } catch (e) {
      debugPrint('MalUserListAdapter.statusCounts: $e');
      return null;
    }
  }

  /// Entry counts per status of a profile's [stats].
  static Map<ListEntryStatus, int> countsOf(ListStats stats) => {
        ListEntryStatus.current: stats.current,
        ListEntryStatus.completed: stats.completed,
        ListEntryStatus.onHold: stats.onHold,
        ListEntryStatus.dropped: stats.dropped,
        ListEntryStatus.planned: stats.planned,
      };

  @override
  void open(BuildContext context, ListEntryView entry) {
    AppRoutes.openContent(context, id: entry.id, category: entry.category);
  }

  @override
  Future<ListEditResult> edit(BuildContext context, ListEntryView entry) async {
    Object? last;
    var removed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: ContentEditWidget(
            id: entry.id,
            category: entry.category,
            service: _entryService,
            onListStatusChange: (status) {
              last = status;
              removed = false;
            },
            onDelete: () {
              removed = true;
              last = null;
            },
          ),
        ),
      ),
    );
    if (removed) return const ListEditRemoved();
    final status = last;
    if (status is anime_status.MyAnimeListStatus) {
      return ListEditUpdated(applyEntry(entry, ListEntry.fromAnimeStatus(status, previous: _entryOf(entry)), _clock()));
    }
    if (status is manga_status.MyMangaListStatus) {
      return ListEditUpdated(applyEntry(entry, ListEntry.fromMangaStatus(status, previous: _entryOf(entry)), _clock()));
    }
    return const ListEditUnchanged();
  }

  /// Another user's list is read only.
  @override
  bool canStep(ListEntryView entry) => isSelf && entry.status != null;

  @override
  Future<ListEntryView> step(ListEntryView entry, int delta) async {
    final previous = _entryOf(entry);
    final plan = planProgressChange(
      content: EditableContent(
        id: entry.id,
        isAnime: entry.isAnime,
        numEpisodes: entry.isAnime ? entry.total : 0,
        numChapters: entry.isAnime ? 0 : entry.total,
        numVolumes: entry.totalVolumes,
      ),
      entry: previous,
      progress: entry.progress + delta,
      autoDates: Preferences.general.autoAddStartEndDate,
      now: _clock(),
    );
    final patch = plan.patch;
    if (patch == null) throw ArgumentError(plan.error);
    final update = await _entryService.update(entry.id,
        isAnime: entry.isAnime, patch: patch, previous: previous);
    return applyEntry(entry, update.entry, _clock());
  }

  @override
  bool isSessionExpired(Object error) => error is MalSessionExpired;

  @override
  Future<void> signInAgain(BuildContext context) =>
      AppRoutes.signInAgain(context, AccountType.myanimelist);

  static ListEntry _entryOf(ListEntryView e) => ListEntry(
        status: e.status?.malValue(isAnime: e.isAnime) ?? '',
        score: e.score,
        progress: e.progress,
        volumes: e.progressVolumes,
        isRepeating: e.repeating,
        priority: e.priority,
        startDate: e.listStartDate,
        finishDate: e.listFinishDate,
        tags: e.tags,
      );

  /// [view] with the list fields of [entry] (saved just now, at [now]).
  @visibleForTesting
  static ListEntryView applyEntry(ListEntryView view, ListEntry entry, DateTime now) =>
      view.copyWith(
        status: ListEntryStatus.fromMal(entry.status),
        clearStatus: ListEntryStatus.fromMal(entry.status) == null,
        score: entry.score,
        progress: entry.progress,
        progressVolumes: view.isAnime ? 0 : entry.volumes,
        repeating: entry.isRepeating,
        priority: entry.priority,
        updatedAt: now,
        listStartDate: entry.startDate,
        listFinishDate: entry.finishDate,
        tags: entry.tags,
      );
}

/// Parses one `users/@me/<category>list` answer; top level so [compute] can run it.
ListPage _parsePage((String, String, String) input) {
  final (body, category, titleLang) = input;
  return parseMalListPage(json.decode(body) as Map<String, dynamic>,
      category: category, titleLang: titleLang);
}

/// [ListPage] of a decoded MAL list answer; [titleLang] is a [TitleLang] name.
@visibleForTesting
ListPage parseMalListPage(Map<String, dynamic> json,
    {required String category, required String titleLang}) {
  final isAnime = category == 'anime';
  final data = json['data'];
  final entries = <ListEntryView>[];
  if (data is List) {
    for (final item in data) {
      if (item is! Map) continue;
      final node = item['node'];
      if (node is! Map || node['id'] is! num) continue;
      final ls = item['list_status'];
      entries.add(_entryFromMal(node, ls is Map ? ls : const {},
          isAnime: isAnime, titleLang: titleLang));
    }
  }
  final paging = json['paging'];
  final hasMore = paging is Map && paging['next'] is String && (paging['next'] as String).isNotEmpty;
  return ListPage(entries, hasMore: hasMore);
}

ListEntryView _entryFromMal(Map node, Map ls,
    {required bool isAnime, required String titleLang}) {
  int toInt(Object? v) => v is num ? v.toInt() : 0;
  int? toIntOrNull(Object? v) => v is num ? v.toInt() : null;
  String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

  final main = text(node['title']) ?? '';
  final alt = node['alternative_titles'];
  final en = alt is Map ? text(alt['en']) : null;
  final ja = alt is Map ? text(alt['ja']) : null;
  final synonyms = alt is Map && alt['synonyms'] is List
      ? (alt['synonyms'] as List).whereType<String>().where((s) => s.trim().isNotEmpty)
      : const <String>[];
  final title = switch (titleLang) {
    'en' => en ?? main,
    'ja' => ja ?? main,
    _ => main,
  };
  final picture = node['main_picture'];
  final genres = node['genres'] is List
      ? [
          for (final g in node['genres'] as List)
            if (g is Map && text(g['name']) != null) text(g['name'])!,
        ]
      : const <String>[];
  final broadcast = node['broadcast'];
  final tags = ls['tags'];
  return ListEntryView(
    id: toInt(node['id']),
    malId: toInt(node['id']),
    category: isAnime ? 'anime' : 'manga',
    title: title,
    otherTitles: [
      for (final t in [main, en, ja, ...synonyms])
        if (t != null && t != title) t,
    ],
    imageUrl: picture is Map ? text(picture['medium']) ?? text(picture['large']) : null,
    largeImageUrl: picture is Map ? text(picture['large']) ?? text(picture['medium']) : null,
    mediaType: text(node['media_type']),
    releaseState: ReleaseState.fromMal(text(node['status'])),
    meanScore: node['mean'] is num ? (node['mean'] as num).toDouble() : null,
    members: toIntOrNull(node['num_list_users']),
    scoringUsers: toIntOrNull(node['num_scoring_users']),
    popularity: toIntOrNull(node['popularity']),
    total: toInt(isAnime ? node['num_episodes'] : node['num_chapters']),
    totalVolumes: isAnime ? 0 : toInt(node['num_volumes']),
    genres: genres,
    releaseStart: text(node['start_date']),
    releaseEnd: text(node['end_date']),
    broadcast: broadcast is Map
        ? BroadcastSlot.fromMal(text(broadcast['day_of_the_week']), text(broadcast['start_time']))
        : null,
    status: ListEntryStatus.fromMal(text(ls['status'])),
    score: toInt(ls['score']),
    progress: toInt(isAnime ? ls['num_episodes_watched'] : ls['num_chapters_read']),
    progressVolumes: isAnime ? 0 : toInt(ls['num_volumes_read']),
    repeating: (isAnime ? ls['is_rewatching'] : ls['is_rereading']) == true,
    priority: toInt(ls['priority']),
    updatedAt: DateTime.tryParse(text(ls['updated_at']) ?? ''),
    listStartDate: text(ls['start_date']),
    listFinishDate: text(ls['finish_date']),
    tags: tags is List
        ? [for (final t in tags) if (t is String && t.trim().isNotEmpty) t]
        : const [],
  );
}
