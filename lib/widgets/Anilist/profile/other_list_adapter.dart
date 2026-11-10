import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart' show AnilistScoreFormat;
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistTitle;
import 'package:mywatchlist/widgets/Anilist/list/anilist_list_look.dart'
    show anilistPercentText, anilistUserScoreText;
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';

/// The signed-in viewer's own entry of a title, read next to another user's list to compare.
@immutable
class AnilistMine {
  /// AniList `MediaListStatus`.
  final String status;

  /// 0-10 with decimals, 0 when unscored.
  final double score;
  final int progress;
  const AnilistMine(this.status, this.score, this.progress);
}

/// Another user's AniList list, read only. The whole category comes in one request (in
/// chunks) and is kept for the page's life; titles follow the signed-in account's title
/// language. `compare` adds a second, lighter read of the viewer's own entries of the same
/// titles (`Media.mediaListEntry`).
class AnilistOtherListSource {
  AnilistOtherListSource({
    required this.username,
    AnilistGraphql? client,
    AnilistProfileService? profiles,
    bool? signedIn,
  })  : _client = client,
        _profiles = profiles,
        _signedIn = signedIn;

  final String username;
  final AnilistGraphql? _client;
  final AnilistProfileService? _profiles;
  final bool? _signedIn;

  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;
  AnilistProfileService get _profile => _profiles ?? AnilistProfileService.instance;
  bool get signedIn =>
      _signedIn ?? UserAnilistV2.instance.status == AuthStatus.AUTHENTICATED;

  static const int _perChunk = 500;

  static const String _entryFields = '''
    id status progress progressVolumes repeat priority private notes hiddenFromStatusLists
    updatedAt createdAt
    scoreRaw: score(format: POINT_100)
    score(format: POINT_10_DECIMAL)
    customLists(asArray: true) advancedScores
    startedAt { year month day }
    completedAt { year month day }
    media { ${AnilistMedia.fields} volumes synonyms duration season source
      startDate { year month day } endDate { year month day } }
  ''';

  final Map<String, Future<List<ListEntryView>>> _lists = {};
  final Map<String, AnilistScoreFormat> _formats = {};
  final Map<String, Map<int, int>> _rawScores = {};
  final Map<String, Future<Map<int, AnilistMine>>> _mine = {};

  /// The score format that user chose for [category] (`mediaListOptions.scoreFormat`), once the
  /// list is loaded; AniList's default (POINT_10) before.
  AnilistScoreFormat scoreFormatOf(String category) =>
      _formats[category] ?? AnilistScoreFormat.point10;

  /// The exact 0-100 score of the title [mediaId] on that user's list (0 = unscored), null when
  /// unknown.
  int? rawScoreOf(String category, int mediaId) => _rawScores[category]?[mediaId];

  /// Every entry of [category] (`anime` | `manga`) the user shows.
  Future<List<ListEntryView>> all(String category, {bool force = false}) {
    if (force) _lists.remove(category);
    final future = _lists[category] ??= _load(category);
    // A failed read is not kept: the next ask tries again.
    future.catchError((Object _) {
      _lists.remove(category);
      return const <ListEntryView>[];
    });
    return future;
  }

  Future<List<ListEntryView>> _load(String category) async {
    final titleLang = await _profile.accountTitleLang();
    final byMedia = <int, ListEntryView>{};
    final raws = <int, int>{};
    var chunk = 1;
    while (true) {
      final data = await _gql.query('''
        query (\$name: String, \$type: MediaType, \$chunk: Int, \$perChunk: Int) {
          MediaListCollection(userName: \$name, type: \$type, chunk: \$chunk,
              perChunk: \$perChunk, forceSingleCompletedList: true) {
            hasNextChunk
            ${chunk == 1 ? 'user { mediaListOptions { scoreFormat } }' : ''}
            lists { entries { $_entryFields } }
          }
        }
      ''', variables: {
        'name': username,
        'type': category == 'manga' ? 'MANGA' : 'ANIME',
        'chunk': chunk,
        'perChunk': _perChunk,
      }, auth: signedIn);
      final collection = data['MediaListCollection'];
      if (collection is! Map) break;
      final user = collection['user'];
      final options = user is Map ? user['mediaListOptions'] : null;
      if (options is Map) _formats[category] = AnilistScoreFormat.parse(options['scoreFormat']);
      for (final list in (collection['lists'] as List? ?? const [])) {
        if (list is! Map || list['entries'] is! List) continue;
        for (final row in parseAnilistRows(list['entries'] as List,
            category: category, titleLang: titleLang)) {
          byMedia[row.view.id] = row.view;
          raws[row.view.id] = row.detail.scoreRaw;
        }
      }
      if (collection['hasNextChunk'] != true || chunk >= 40) break;
      chunk++;
    }
    _rawScores[category] = raws;
    return List.unmodifiable(byMedia.values);
  }

  /// The viewer's own entries for the titles of [username]'s [category] list, by AniList media
  /// id (empty when signed out).
  Future<Map<int, AnilistMine>> mine(String category) {
    if (!signedIn) return Future.value(const {});
    final future = _mine[category] ??= _loadMine(category);
    future.catchError((Object _) {
      _mine.remove(category);
      return const <int, AnilistMine>{};
    });
    return future;
  }

  Future<Map<int, AnilistMine>> _loadMine(String category) async {
    final out = <int, AnilistMine>{};
    var chunk = 1;
    while (true) {
      final data = await _gql.query('''
        query (\$name: String, \$type: MediaType, \$chunk: Int, \$perChunk: Int) {
          MediaListCollection(userName: \$name, type: \$type, chunk: \$chunk,
              perChunk: \$perChunk, forceSingleCompletedList: true) {
            hasNextChunk
            lists { entries { media { id
              mediaListEntry { status progress score(format: POINT_10_DECIMAL) } } } }
          }
        }
      ''', variables: {
        'name': username,
        'type': category == 'manga' ? 'MANGA' : 'ANIME',
        'chunk': chunk,
        'perChunk': _perChunk,
      }, auth: true);
      final collection = data['MediaListCollection'];
      if (collection is! Map) break;
      for (final list in (collection['lists'] as List? ?? const [])) {
        if (list is! Map) continue;
        for (final entry in (list['entries'] as List? ?? const [])) {
          final media = entry is Map ? entry['media'] : null;
          final mine = media is Map ? media['mediaListEntry'] : null;
          if (media is Map && media['id'] is num && mine is Map) {
            out[(media['id'] as num).toInt()] = AnilistMine(
              mine['status'] as String? ?? '',
              (mine['score'] as num?)?.toDouble() ?? 0,
              (mine['progress'] as num?)?.toInt() ?? 0,
            );
          }
        }
      }
      if (collection['hasNextChunk'] != true || chunk >= 40) break;
      chunk++;
    }
    return out;
  }
}

/// How the compare mode narrows the list.
enum AnilistCompareFilter { all, onMine, notOnMine }

/// [AnilistOtherListSource] for the shared list widgets, read only: a row opens the AniList
/// title, nothing edits the user's list, there is no quick +1.
class AnilistReadOnlyListAdapter extends UserListAdapter {
  AnilistReadOnlyListAdapter({
    required this.source,
    Future<void> Function(BuildContext context, {required String category, required int id})?
        opener,
  }) : _opener = opener ?? openAnilistTitle;

  final AnilistOtherListSource source;
  final Future<void> Function(BuildContext context, {required String category, required int id})
      _opener;

  /// Narrows [fetch] to titles on / not on the viewer's list (set by the page, which then
  /// reloads its tabs).
  AnilistCompareFilter compareFilter = AnilistCompareFilter.all;

  @override
  AccountType get tracker => AccountType.anilist;

  @override
  String? get owner => source.username;

  @override
  int get maxPageSize => 1000;

  @override
  List<ListSortOption> sortOptions(String category) =>
      standardSortOptions(isAnime: category == 'anime');

  @override
  String? apiSort(String category, String sortKey, SortDirection direction) => null;

  /// That user's score in the score format they chose (stars, a face, 0-100...), from the exact
  /// 0-100 value AniList keeps.
  @override
  ListScoreText? userScore(ListEntryView entry) => anilistUserScoreText(
      source.rawScoreOf(entry.category, entry.id) ?? entry.score * 10,
      source.scoreFormatOf(entry.category));

  /// AniList's community score as a percentage (`82%`).
  @override
  ListScoreText? meanScore(ListEntryView entry) => anilistPercentText(entry);

  @override
  Future<ListPage> fetch({
    required String category,
    required ListEntryStatus? status,
    required int offset,
    required int limit,
    String? apiSort,
  }) async {
    var all = await source.all(category);
    if (compareFilter != AnilistCompareFilter.all) {
      final mine = await source.mine(category);
      all = [
        for (final e in all)
          if (mine.containsKey(e.id) == (compareFilter == AnilistCompareFilter.onMine)) e,
      ];
    }
    final inStatus = status == null ? all : [for (final e in all) if (e.status == status) e];
    final from = offset.clamp(0, inStatus.length);
    final end = (offset + limit).clamp(0, inStatus.length);
    return ListPage(inStatus.sublist(from, end), hasMore: end < inStatus.length);
  }

  @override
  Future<Map<ListEntryStatus, int>?> statusCounts(String category) async {
    try {
      return AnilistListService.countStatuses(await source.all(category));
    } catch (_) {
      return null;
    }
  }

  @override
  void open(BuildContext context, ListEntryView entry) =>
      _opener(context, category: entry.category, id: entry.id);

  @override
  Future<ListEditResult> edit(BuildContext context, ListEntryView entry) async =>
      const ListEditUnchanged();

  @override
  bool isSessionExpired(Object error) => error is AnilistSessionExpired;

  @override
  Future<void> signInAgain(BuildContext context) =>
      AppRoutes.signInAgain(context, AccountType.anilist);
}

/// The cards of the compare mode: each title shows the viewer's own score (or status) as a
/// badge, or "Not on your list".
class AnilistCompareLook extends ListEntryLook {
  final Map<int, AnilistMine> mine;

  /// The look of the list the cards belong to: scores keep that user's format and the
  /// community percentage in compare mode.
  final ListEntryLook? base;

  const AnilistCompareLook(this.mine, {this.base});

  @override
  ListScoreText? userScore(ListEntryView entry) =>
      base?.userScore(entry) ?? super.userScore(entry);

  @override
  ListScoreText? meanScore(ListEntryView entry) =>
      base?.meanScore(entry) ?? super.meanScore(entry);

  @override
  List<ListCardBadge> cardBadges(ListEntryView entry) {
    final s = S.current;
    final own = mine[entry.id];
    if (own == null) {
      return [
        ListCardBadge(
            icon: Icons.person_off_outlined, label: '-', detail: s.Alpp_Not_On_Your_List),
      ];
    }
    final label = own.score > 0
        ? (own.score == own.score.roundToDouble()
            ? '${own.score.round()}'
            : own.score.toStringAsFixed(1))
        : '${own.progress}';
    return [
      ListCardBadge(
        icon: Icons.person_outline,
        label: label,
        detail: own.score > 0 ? s.Alpp_Your_Score(label) : s.Alpp_Your_Progress(own.progress),
      ),
    ];
  }
}
