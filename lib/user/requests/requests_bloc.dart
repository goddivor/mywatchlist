import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/mal_scrapper.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';

abstract class RequestsEvent extends Equatable {
  final bool forceUpdate;
  final int cacheDurationHours;
  const RequestsEvent({this.forceUpdate = false, this.cacheDurationHours = 2});

  @override
  List<Object?> get props => [forceUpdate, cacheDurationHours];
}

class LoadNewsEvent extends RequestsEvent {
  const LoadNewsEvent({super.forceUpdate, super.cacheDurationHours = 8});
}

class LoadFeaturesEvent extends RequestsEvent {
  const LoadFeaturesEvent({super.forceUpdate, super.cacheDurationHours = 8});
}

/// Loads the anime or manga cards of a home row ([SectionType.isContentRow]): the current season,
/// the suggestions or a MAL ranking, [limit] items (the largest item count among the enabled
/// sections of that kind).
class LoadHomeRowEvent extends RequestsEvent {
  final SectionType type;
  final int limit;

  const LoadHomeRowEvent(
    this.type, {
    this.limit = 15,
    super.forceUpdate,
    super.cacheDurationHours,
  });

  @override
  List<Object?> get props => [type, limit, ...super.props];
}

class RequestsState extends Equatable {
  final List<Map<String, String>> news;
  final List<Map<String, String>> features;
  final bool isNewsLoaded;
  final bool isFeaturesLoaded;
  final bool isNewsFailed;
  final bool isFeaturesFailed;

  /// The cards of each loaded home row.
  final Map<SectionType, List<Anime>> rows;

  /// The rows whose last load failed with nothing cached.
  final Set<SectionType> failedRows;

  const RequestsState({
    this.news = const [],
    this.features = const [],
    this.isNewsLoaded = false,
    this.isFeaturesLoaded = false,
    this.isNewsFailed = false,
    this.isFeaturesFailed = false,
    this.rows = const {},
    this.failedRows = const {},
  });

  bool isRowLoaded(SectionType type) => rows.containsKey(type);
  bool isRowFailed(SectionType type) => failedRows.contains(type);
  List<Anime> row(SectionType type) => rows[type] ?? const [];

  RequestsState copyWith({
    List<Map<String, String>>? news,
    List<Map<String, String>>? features,
    bool? isNewsLoaded,
    bool? isFeaturesLoaded,
    bool? isNewsFailed,
    bool? isFeaturesFailed,
    Map<SectionType, List<Anime>>? rows,
    Set<SectionType>? failedRows,
  }) {
    return RequestsState(
      news: news ?? this.news,
      features: features ?? this.features,
      isNewsLoaded: isNewsLoaded ?? this.isNewsLoaded,
      isFeaturesLoaded: isFeaturesLoaded ?? this.isFeaturesLoaded,
      isNewsFailed: isNewsFailed ?? this.isNewsFailed,
      isFeaturesFailed: isFeaturesFailed ?? this.isFeaturesFailed,
      rows: rows ?? this.rows,
      failedRows: failedRows ?? this.failedRows,
    );
  }

  /// This state with [items] as the cards of [type].
  RequestsState withRow(SectionType type, List<Anime> items) => copyWith(
        rows: {...rows, type: items},
        failedRows: {...failedRows}..remove(type),
      );

  /// This state with [type] marked failed (its previous cards, if any, stay shown).
  RequestsState withRowFailed(SectionType type) =>
      copyWith(failedRows: {...failedRows, type});

  @override
  List<Object?> get props => [
        news,
        features,
        isNewsLoaded,
        isFeaturesLoaded,
        isNewsFailed,
        isFeaturesFailed,
        rows,
        failedRows,
      ];
}

/// The shared requests of the MAL home page: news, featured articles and the content rows.
class RequestsBloc extends Bloc<RequestsEvent, RequestsState> {
  final MalScraper malScraper;
  final JikanApi jikanApi;
  final MalApi malApi;
  final CacheManager _cache = CacheManager.instance;

  // Fallback expiry: 7 days in seconds (for offline mode)
  static const int _fallbackExpiry = 7 * 24 * 3600;

  /// The item count each row holds (or is fetching): a row is fetched again only when a section
  /// asks for more, or on a forced refresh.
  final Map<SectionType, int> _rowLimits = {};

  /// Rows being fetched, with the item count asked.
  final Map<SectionType, int> _inFlight = {};

  bool _newsInFlight = false;
  bool _featuresInFlight = false;

  RequestsBloc({
    required this.malScraper,
    required this.jikanApi,
    required this.malApi,
  }) : super(const RequestsState()) {
    on<LoadNewsEvent>(_onLoadNews);
    on<LoadFeaturesEvent>(_onLoadFeatures);
    on<LoadHomeRowEvent>(_onLoadHomeRow);
  }

  /// The cache key of a row: the item count is part of it, so a longer row is never served from
  /// the cache of a shorter one.
  @visibleForTesting
  static String rowCacheKey(SectionType type, int limit) {
    final anime = type.animeRanking;
    final manga = type.mangaRanking;
    final base = switch (type) {
      SectionType.seasonNow => 'seasonNow',
      SectionType.suggested => 'suggested',
      SectionType.upcoming => 'upcoming',
      _ when anime != null => 'topAnime-${rankingMap[anime]}',
      _ when manga != null => 'topManga-${mangaRankingMap[manga]}',
      _ => type.name,
    };
    return '$base@$limit';
  }

  /// The MAL request behind [type].
  static Future<List<Anime>> _fetchRow(SectionType type, int limit) {
    if (type == SectionType.seasonNow) {
      return MalApi.getAnimeSeasonal(
          MalApi.getSeasonType(), MalApi.getCurrentSeasonYear(),
          sortType: SortType.AnimeNumListUsers, limit: limit);
    }
    if (type == SectionType.suggested) {
      return MalApi.getContentSuggestions(limit: limit);
    }
    final anime = type.animeRanking;
    if (anime != null) return MalApi.getContentRanking(anime, limit: limit);
    final manga = type.mangaRanking;
    if (manga != null) {
      return MalApi.getContentRanking(manga, limit: limit, category: 'manga');
    }
    throw ArgumentError.value(type, 'type', 'not a content row');
  }

  Future<void> _onLoadHomeRow(
      LoadHomeRowEvent event, Emitter<RequestsState> emit) async {
    final type = event.type;
    if (!type.isContentRow) return;
    final limit = event.limit.clamp(1, kHomeRowMaxItems);

    final inFlight = _inFlight[type];
    if (!event.forceUpdate && inFlight != null && inFlight >= limit) return;
    if (!event.forceUpdate &&
        state.isRowLoaded(type) &&
        (_rowLimits[type] ?? 0) >= limit) {
      return;
    }

    final cacheKey = rowCacheKey(type, limit);
    _inFlight[type] = limit;
    // A request for more items started meanwhile: its result wins.
    bool superseded() => (_inFlight[type] ?? 0) > limit;
    void show(List<Anime> items) {
      if (superseded()) return;
      _rowLimits[type] = limit;
      emit(state.withRow(type, items));
    }

    try {
      if (!event.forceUpdate) {
        final cached = await _cache.getCachedAnimeList(
            cacheKey, event.cacheDurationHours * 3600);
        if (cached != null) {
          debugPrint('📦 Cache hit: $cacheKey');
          show(cached);
          return;
        }
      }

      try {
        debugPrint('🌐 API call: $cacheKey');
        final items = await _fetchRow(type, limit);
        show(items);
        await _cache.cacheAnimeList(cacheKey, items);
      } catch (e) {
        debugPrint('❌ Error loading $cacheKey: $e');
        final fallback =
            await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
        if (fallback != null) {
          debugPrint('📦 Offline fallback: $cacheKey');
          show(fallback);
        } else if (!superseded()) {
          emit(state.withRowFailed(type));
        }
      }
    } finally {
      if (_inFlight[type] == limit) _inFlight.remove(type);
    }
  }

  Future<List<Map<String, String>>> getNewsorFeaturedList() async {
    Map<String, dynamic>? data = await malScraper.getAnimeNews();
    return _articles(data);
  }

  Future<List<Map<String, String>>> getFeaturedList() async {
    Map<String, dynamic>? data = await malScraper.getAnimeFeatured();
    return _articles(data);
  }

  static List<Map<String, String>> _articles(Map<String, dynamic>? data) {
    if (data == null) return [];
    final List<dynamic> list = data['newsorfeatured'] ?? [];
    return list
        .map((item) => (item as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, value.toString()),
            ))
        .toList()
        .cast<Map<String, String>>();
  }

  Future<void> _onLoadFeatures(
      LoadFeaturesEvent event, Emitter<RequestsState> emit) async {
    if (_featuresInFlight) return;
    if (!event.forceUpdate && state.isFeaturesLoaded) return;
    const cacheKey = 'features';
    _featuresInFlight = true;
    try {
      if (!event.forceUpdate) {
        final cached = await _cache.getCachedNewsList(
            cacheKey, event.cacheDurationHours * 3600);
        if (cached != null) {
          debugPrint('📦 Cache hit: $cacheKey');
          emit(state.copyWith(
              features: cached, isFeaturesLoaded: true, isFeaturesFailed: false));
          return;
        }
      }
      try {
        debugPrint('🌐 API call: $cacheKey');
        final features = await getFeaturedList();
        emit(state.copyWith(
            features: features, isFeaturesLoaded: true, isFeaturesFailed: false));
        await _cache.cacheNewsList(cacheKey, features);
      } catch (e) {
        final fallback =
            await _cache.getCachedNewsList(cacheKey, _fallbackExpiry);
        if (fallback != null) {
          debugPrint('📦 Offline fallback: $cacheKey');
          emit(state.copyWith(
              features: fallback, isFeaturesLoaded: true, isFeaturesFailed: false));
        } else {
          emit(state.copyWith(isFeaturesFailed: true));
        }
      }
    } finally {
      _featuresInFlight = false;
    }
  }

  Future<void> _onLoadNews(
      LoadNewsEvent event, Emitter<RequestsState> emit) async {
    if (_newsInFlight) return;
    if (!event.forceUpdate && state.isNewsLoaded) return;
    const cacheKey = 'news';
    _newsInFlight = true;
    try {
      if (!event.forceUpdate) {
        final cached = await _cache.getCachedNewsList(
            cacheKey, event.cacheDurationHours * 3600);
        if (cached != null) {
          debugPrint('📦 Cache hit: $cacheKey');
          emit(state.copyWith(news: cached, isNewsLoaded: true, isNewsFailed: false));
          return;
        }
      }
      try {
        debugPrint('🌐 API call: $cacheKey');
        final news = await getNewsorFeaturedList();
        emit(state.copyWith(news: news, isNewsLoaded: true, isNewsFailed: false));
        await _cache.cacheNewsList(cacheKey, news);
      } catch (e) {
        final fallback =
            await _cache.getCachedNewsList(cacheKey, _fallbackExpiry);
        if (fallback != null) {
          debugPrint('📦 Offline fallback: $cacheKey');
          emit(state.copyWith(news: fallback, isNewsLoaded: true, isNewsFailed: false));
        } else {
          emit(state.copyWith(isNewsFailed: true));
        }
      }
    } finally {
      _newsInFlight = false;
    }
  }
}
