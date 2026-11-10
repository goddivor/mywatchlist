import 'package:flutter/foundation.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/services/api/mwl_api.dart';

/// One upcoming episode of an airing anime, as listed by LiveChart.me.
@immutable
class AiringEpisode {
  /// MyAnimeList id of the anime.
  final int malId;

  /// Number of the episode that airs at [airingAt].
  final int episode;

  /// Air time (UTC).
  final DateTime airingAt;

  /// LiveChart's title of the anime (can differ from MAL's).
  final String? title;

  /// Link kind (`mal`, `anilist`, `website`, `twitter`...) to URL.
  final Map<String, String> relatedLinks;

  const AiringEpisode({
    required this.malId,
    required this.episode,
    required this.airingAt,
    this.title,
    this.relatedLinks = const {},
  });

  factory AiringEpisode.fromLiveChart(LiveChartEpisode e) => AiringEpisode(
        malId: e.malId!,
        episode: e.episode,
        airingAt: e.airingAt,
        title: e.title,
        relatedLinks: e.relatedLinks,
      );
}

/// Loads a LiveChart page of episodes; `fromCache: false` forces a refresh.
typedef AiringScheduleFetcher = Future<List<LiveChartEpisode>> Function({required bool fromCache});

/// The real airing schedule of the current season (LiveChart, through the
/// backend's `schedules` route), shared by the calendar, the list cards and the
/// notifications.
///
/// Read it synchronously once loaded:
///
/// ```dart
/// await AiringSchedule.instance.ensureLoaded();
/// final next = AiringSchedule.instance.nextEpisode(malId); // episode + time, or null
/// ```
///
/// [nextEpisode] returns null while nothing is loaded or when the anime does
/// not air in the current season: callers then fall back to their own estimate.
/// Listen to the instance to rebuild when a refresh brings new times.
class AiringSchedule extends ChangeNotifier {
  AiringSchedule({AiringScheduleFetcher? fetcher, this.ttl = const Duration(minutes: 30)})
      : _fetch = fetcher ?? _defaultFetch;

  static AiringSchedule instance = AiringSchedule();

  final AiringScheduleFetcher _fetch;

  /// How long a loaded schedule is considered fresh.
  final Duration ttl;

  /// Next episode per MAL id, the earliest first.
  final Map<int, List<AiringEpisode>> _byMalId = {};
  List<AiringEpisode> _all = const [];
  DateTime? _loadedAt;
  Future<void>? _loading;
  Object? _error;

  static Future<List<LiveChartEpisode>> _defaultFetch({required bool fromCache}) =>
      MwlApi.i.getLiveChartSchedule(fromCache: fromCache);

  /// True once a schedule has been loaded at least once.
  bool get isLoaded => _loadedAt != null;

  /// The last load error (null after a success).
  Object? get error => _error;

  /// When the schedule was last loaded.
  DateTime? get loadedAt => _loadedAt;

  /// Every known upcoming episode, sorted by air time.
  List<AiringEpisode> get episodes => _all;

  bool _isStale(DateTime now) => _loadedAt == null || now.difference(_loadedAt!) > ttl;

  /// Loads the schedule when nothing is loaded yet, when it is older than [ttl]
  /// or when [refresh] is true. Concurrent calls share one request. Never
  /// throws: a failure is kept in [error] and the previous schedule stays.
  Future<void> ensureLoaded({bool refresh = false, DateTime? now}) {
    if (!refresh && !_isStale(now ?? DateTime.now())) return Future.value();
    return _loading ??= _load(fromCache: !refresh).whenComplete(() => _loading = null);
  }

  Future<void> _load({required bool fromCache}) async {
    try {
      final raw = await _fetch(fromCache: fromCache);
      replace(raw);
      _error = null;
    } catch (e) {
      _error = e;
    }
    notifyListeners();
  }

  /// Installs [raw] (episodes without a MAL id are ignored).
  @visibleForTesting
  void replace(List<LiveChartEpisode> raw, {DateTime? now}) {
    final parsed = raw
        .where((e) => e.malId != null && e.timestamp > 0)
        .map(AiringEpisode.fromLiveChart)
        .toList()
      ..sort((a, b) => a.airingAt.compareTo(b.airingAt));
    _all = List.unmodifiable(parsed);
    _byMalId
      ..clear()
      ..addEntries(_group(parsed));
    _loadedAt = now ?? DateTime.now();
  }

  static Iterable<MapEntry<int, List<AiringEpisode>>> _group(List<AiringEpisode> sorted) {
    final map = <int, List<AiringEpisode>>{};
    for (final e in sorted) {
      (map[e.malId] ??= []).add(e);
    }
    return map.entries;
  }

  /// The next episode of the anime with MAL id [malId] that has not aired yet
  /// at [now], or null when the schedule has none.
  AiringEpisode? nextEpisode(int? malId, {DateTime? now}) {
    if (malId == null) return null;
    final list = _byMalId[malId];
    if (list == null) return null;
    final at = (now ?? DateTime.now()).toUtc();
    for (final e in list) {
      if (e.airingAt.isAfter(at)) return e;
    }
    return null;
  }

  /// Forgets everything (tests, sign-out).
  @visibleForTesting
  void reset() {
    _byMalId.clear();
    _all = const [];
    _loadedAt = null;
    _error = null;
  }
}
