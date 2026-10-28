import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/services/notifications/notification_models.dart' show AiringCandidate;
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart' show ListPage;

/// Kitsu's word for a [ListEntryStatus] (`current`, `planned`, `completed`, `on_hold`, `dropped`).
String kitsuStatusOf(ListEntryStatus status) => switch (status) {
      ListEntryStatus.current => 'current',
      ListEntryStatus.completed => 'completed',
      ListEntryStatus.onHold => 'on_hold',
      ListEntryStatus.dropped => 'dropped',
      ListEntryStatus.planned => 'planned',
    };

ListEntryStatus? listStatusOfKitsu(Object? value) => switch (value) {
      'current' => ListEntryStatus.current,
      'completed' => ListEntryStatus.completed,
      'on_hold' => ListEntryStatus.onHold,
      'dropped' => ListEntryStatus.dropped,
      'planned' => ListEntryStatus.planned,
      _ => null,
    };

/// A page of the library plus the Kitsu library-entry id of each media on it.
class KitsuLibraryPage {
  final ListPage page;

  /// Library-entry id by media id.
  final Map<int, String> entryIds;

  const KitsuLibraryPage(this.page, this.entryIds);
}

/// The signed-in user's Kitsu library (`/library-entries`), read and written through
/// `sendAuthenticated`.
class KitsuLibrary {
  KitsuLibrary({KitsuHttp? http, String? Function()? owner})
      : _http = http,
        _owner = owner ?? (() => UserKitsuV2.instance.username);

  static KitsuLibrary instance = KitsuLibrary();

  final KitsuHttp? _http;
  final String? Function() _owner;
  KitsuHttp get http => _http ?? KitsuHttp.instance;

  String? _userId;
  String? _userIdOwner;

  /// Largest page asked at once (Kitsu accepts more, but each entry carries its media).
  static const int maxPage = 200;

  /// Kitsu id of the signed-in user.
  Future<String> userId() async {
    final owner = _owner();
    final cached = _userId;
    if (cached != null && _userIdOwner == owner) return cached;
    final json = await http.getJson('/users',
        query: {'filter[self]': 'true', 'fields[users]': 'name'}, auth: true);
    final data = KitsuDocument.from(json).data;
    if (data.isEmpty) throw const KitsuSessionExpired();
    _userIdOwner = owner;
    return _userId = '${data.first['id']}';
  }

  /// Base parameters of a library request of [isAnime] entries.
  Map<String, String> _params(String userId, bool isAnime, ListEntryStatus? status) {
    final kind = isAnime ? 'anime' : 'manga';
    return {
      'filter[userId]': userId,
      'filter[kind]': kind,
      if (status != null) 'filter[status]': kitsuStatusOf(status),
      'include': '$kind,$kind.mappings',
      'fields[$kind]': KitsuCatalog.fields(isAnime),
      'fields[mappings]': 'externalSite,externalId',
    };
  }

  /// One page of the list. [sort] is a Kitsu sort (`-progressedAt`), null = Kitsu's order.
  Future<KitsuLibraryPage> page({
    required bool isAnime,
    required ListEntryStatus? status,
    required int offset,
    required int limit,
    String? sort,
  }) async {
    final id = await userId();
    final json = await http.getJson('/library-entries',
        query: {
          ..._params(id, isAnime, status),
          if (sort != null) 'sort': sort,
          'page[limit]': '${limit.clamp(1, maxPage)}',
          'page[offset]': '$offset',
        },
        auth: true);
    return parsePage(json, isAnime: isAnime, titleLang: Preferences.general.preferredTitle.name);
  }

  /// Entries per status (one cheap request each: only the count is read).
  Future<Map<ListEntryStatus, int>> statusCounts({
    required bool isAnime,
    String? userId,
    bool auth = true,
  }) async {
    final id = userId ?? await this.userId();
    final counts = await Future.wait([
      for (final s in ListEntryStatus.values)
        http
            .getJson('/library-entries',
                query: {
                  'filter[userId]': id,
                  'filter[kind]': isAnime ? 'anime' : 'manga',
                  'filter[status]': kitsuStatusOf(s),
                  'page[limit]': '1',
                  'fields[libraryEntries]': 'status',
                },
                auth: auth)
            .then((json) => ((json['meta'] as Map?)?['count'] as num?)?.toInt() ?? 0),
    ]);
    return {
      for (var i = 0; i < ListEntryStatus.values.length; i++) ListEntryStatus.values[i]: counts[i],
    };
  }

  /// Sends [attributes] to library entry [entryId].
  Future<void> update(String entryId, Map<String, Object?> attributes) async {
    await http.patchJson('/library-entries/$entryId', {
      'data': {'id': entryId, 'type': 'libraryEntries', 'attributes': attributes},
    });
  }

  /// The library-entry id of media [mediaId], null when it is not on the list.
  Future<String?> entryIdOf(int mediaId, {required bool isAnime}) async {
    final id = await userId();
    final json = await http.getJson('/library-entries',
        query: {
          'filter[userId]': id,
          'filter[${isAnime ? 'animeId' : 'mangaId'}]': '$mediaId',
          'fields[libraryEntries]': 'status',
          'page[limit]': '1',
        },
        auth: true);
    final data = KitsuDocument.from(json).data;
    return data.isEmpty ? null : '${data.first['id']}';
  }

  /// The user's airing (or soon airing) anime of the Watching and Plan to watch lists with
  /// their MyAnimeList id, for the airing notifications. Entries Kitsu maps to no MAL id are
  /// left out (the schedule is keyed by MAL id).
  Future<List<AiringCandidate>> airingCandidates() async {
    final out = <AiringCandidate>[];
    for (final status in [ListEntryStatus.current, ListEntryStatus.planned]) {
      var offset = 0;
      // Three pages of 200 per list is far more than anyone watches at once.
      for (var i = 0; i < 3; i++) {
        final result = await page(isAnime: true, status: status, offset: offset, limit: maxPage);
        for (final e in result.page.entries) {
          final mal = e.malId;
          if (mal == null || e.releaseState == ReleaseState.finished) continue;
          out.add(AiringCandidate(
            malId: mal,
            title: e.title,
            status: status == ListEntryStatus.current ? 'watching' : 'plan_to_watch',
            imageUrl: e.imageUrl,
            numEpisodes: e.total,
            airingStatus: switch (e.releaseState) {
              ReleaseState.releasing => 'currently_airing',
              ReleaseState.notYetReleased => 'not_yet_aired',
              _ => null,
            },
          ));
        }
        if (!result.page.hasMore) break;
        offset += result.page.entries.length;
      }
    }
    return out;
  }

  /// Parses a `/library-entries` answer that included the media and their mappings.
  @visibleForTesting
  static KitsuLibraryPage parsePage(Map<String, dynamic> json,
      {required bool isAnime, required String titleLang}) {
    final doc = KitsuDocument.from(json);
    final relation = isAnime ? 'anime' : 'manga';
    final entries = <ListEntryView>[];
    final ids = <int, String>{};
    for (final r in doc.data) {
      final mediaRes = doc.related(r, relation);
      if (mediaRes == null) continue;
      final media = KitsuMedia.fromResource(mediaRes, doc, titleLang: titleLang, isAnime: isAnime);
      if (media.id == 0) continue;
      entries.add(entryView(media, kitsuAttrs(r)));
      ids[media.id] = '${r['id']}';
    }
    return KitsuLibraryPage(ListPage(entries, hasMore: doc.hasNext), ids);
  }

  /// The card model of [media] with the library attributes [a] of its entry.
  @visibleForTesting
  static ListEntryView entryView(KitsuMedia media, Map<String, dynamic> a) {
    String? date(Object? v) =>
        v is String && v.length >= 10 ? v.substring(0, 10) : null;
    final rating = a['ratingTwenty'];
    return ListEntryView(
      id: media.id,
      malId: media.malId,
      category: media.category,
      title: media.title,
      otherTitles: media.otherTitles,
      imageUrl: media.posterUrl,
      largeImageUrl: media.largePosterUrl,
      mediaType: media.malMediaType,
      releaseState: media.releaseState,
      meanScore: media.meanScore,
      members: media.userCount,
      popularity: media.popularityRank,
      total: media.total,
      totalVolumes: media.totalVolumes,
      releaseStart: media.startDate,
      releaseEnd: media.endDate,
      status: listStatusOfKitsu(a['status']),
      score: rating is num ? scoreOfTwenty(rating.toInt()) : 0,
      progress: (a['progress'] as num?)?.toInt() ?? 0,
      repeating: a['reconsuming'] == true,
      updatedAt: DateTime.tryParse('${a['progressedAt'] ?? a['updatedAt'] ?? ''}'),
      listStartDate: date(a['startedAt']),
      listFinishDate: date(a['finishedAt']),
    );
  }

  /// Kitsu's 2-20 rating on the 0-10 scale of the cards (half points round up).
  static int scoreOfTwenty(int twenty) => twenty <= 0 ? 0 : ((twenty + 1) ~/ 2).clamp(1, 10);
}
