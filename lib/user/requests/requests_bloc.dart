// Evénements BLoC
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/mal_scrapper.dart';

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

class LoadSeasonNowEvent extends RequestsEvent {
  const LoadSeasonNowEvent({super.forceUpdate, super.cacheDurationHours});
}

class LoadUpcomingAnimeEvent extends RequestsEvent {
  const LoadUpcomingAnimeEvent({super.forceUpdate, super.cacheDurationHours});
}

class LoadTopAnimeFavoriteEvent extends RequestsEvent {
  const LoadTopAnimeFavoriteEvent({super.forceUpdate, super.cacheDurationHours});
}

class LoadTopAnimeByPopularityEvent extends RequestsEvent {
  const LoadTopAnimeByPopularityEvent(
      {super.forceUpdate, super.cacheDurationHours});
}

class LoadTopAnimeByScoreEvent extends RequestsEvent {
  const LoadTopAnimeByScoreEvent({super.forceUpdate, super.cacheDurationHours});
}

class LoadSuggestedAnimeEvent extends RequestsEvent {
  const LoadSuggestedAnimeEvent({super.forceUpdate, super.cacheDurationHours});
}

class LoadTopAnimeAiringEvent extends RequestsEvent {
  const LoadTopAnimeAiringEvent({super.forceUpdate, super.cacheDurationHours});
}

class LoadTopAnimeTVEvent extends RequestsEvent {
  const LoadTopAnimeTVEvent({super.forceUpdate, super.cacheDurationHours});
}

class LoadTopAnimeMovieEvent extends RequestsEvent {
  const LoadTopAnimeMovieEvent({super.forceUpdate, super.cacheDurationHours});
}

class LoadTopAnimeSpecialEvent extends RequestsEvent {
  const LoadTopAnimeSpecialEvent({super.forceUpdate, super.cacheDurationHours});
}

class LoadTopMangaEvent extends RequestsEvent {
  const LoadTopMangaEvent({super.forceUpdate, super.cacheDurationHours});
}

class LoadTopMangaByPopularityEvent extends RequestsEvent {
  const LoadTopMangaByPopularityEvent(
      {super.forceUpdate, super.cacheDurationHours});
}

class LoadFeaturesEvent extends RequestsEvent {
  const LoadFeaturesEvent({super.forceUpdate, super.cacheDurationHours = 8});
}

// États BLoC
class RequestsState extends Equatable {
  final List<Map<String, String>> news;
  final List<Anime> seasonNow;
  final List<Anime> upcomingAnime;
  final List<Anime> topAnimeFavorite;
  final List<Anime> topAnimeByPopularity;
  final List<Anime> topAnimeByScore;
  final List<Anime> suggestedAnime;
  final List<Anime> topAnimeAiring;
  final List<Anime> topAnimeTV;
  final List<Anime> topAnimeMovie;
  final List<Anime> topAnimeSpecial;
  final List<Anime> topManga;
  final List<Anime> topMangaByPopularity;
  final List<Map<String, String>> features;

  final bool isNewsLoaded;
  final bool isSeasonNowLoaded;
  final bool isUpcomingAnimeLoaded;
  final bool isTopAnimeFavoriteLoaded;
  final bool isTopAnimeByPopularityLoaded;
  final bool isTopAnimeByScoreLoaded;
  final bool isSuggestedAnimeLoaded;
  final bool isTopAnimeAiringLoaded;
  final bool isTopAnimeTVLoaded;
  final bool isTopAnimeMovieLoaded;
  final bool isTopAnimeSpecialLoaded;
  final bool isTopMangaLoaded;
  final bool isTopMangaByPopularityLoaded;
  final bool isFeaturesLoaded;

  const RequestsState({
    this.news = const [],
    this.seasonNow = const [],
    this.upcomingAnime = const [],
    this.topAnimeFavorite = const [],
    this.topAnimeByPopularity = const [],
    this.topAnimeByScore = const [],
    this.suggestedAnime = const [],
    this.topAnimeAiring = const [],
    this.topAnimeTV = const [],
    this.topAnimeMovie = const [],
    this.topAnimeSpecial = const [],
    this.topManga = const [],
    this.topMangaByPopularity = const [],
    this.features = const [],
    this.isNewsLoaded = false,
    this.isSeasonNowLoaded = false,
    this.isUpcomingAnimeLoaded = false,
    this.isTopAnimeFavoriteLoaded = false,
    this.isTopAnimeByPopularityLoaded = false,
    this.isTopAnimeByScoreLoaded = false,
    this.isSuggestedAnimeLoaded = false,
    this.isTopAnimeAiringLoaded = false,
    this.isTopAnimeTVLoaded = false,
    this.isTopAnimeMovieLoaded = false,
    this.isTopAnimeSpecialLoaded = false,
    this.isTopMangaLoaded = false,
    this.isTopMangaByPopularityLoaded = false,
    this.isFeaturesLoaded = false,
  });

  RequestsState copyWith({
    List<Map<String, String>>? news,
    List<Anime>? seasonNow,
    List<Anime>? upcomingAnime,
    List<Anime>? topAnimeFavorite,
    List<Anime>? topAnimeByPopularity,
    List<Anime>? topAnimeByScore,
    List<Anime>? suggestedAnime,
    List<Anime>? topAnimeAiring,
    List<Anime>? topAnimeTV,
    List<Anime>? topAnimeMovie,
    List<Anime>? topAnimeSpecial,
    List<Anime>? topManga,
    List<Anime>? topMangaByPopularity,
    List<Map<String, String>>? features,
    bool? isNewsLoaded,
    bool? isSeasonNowLoaded,
    bool? isUpcomingAnimeLoaded,
    bool? isTopAnimeFavoriteLoaded,
    bool? isTopAnimeByPopularityLoaded,
    bool? isTopAnimeByScoreLoaded,
    bool? isSuggestedAnimeLoaded,
    bool? isTopAnimeAiringLoaded,
    bool? isTopAnimeTVLoaded,
    bool? isTopAnimeMovieLoaded,
    bool? isTopAnimeSpecialLoaded,
    bool? isTopMangaLoaded,
    bool? isTopMangaByPopularityLoaded,
    bool? isFeaturesLoaded,
  }) {
    return RequestsState(
      news: news ?? this.news,
      seasonNow: seasonNow ?? this.seasonNow,
      upcomingAnime: upcomingAnime ?? this.upcomingAnime,
      topAnimeFavorite: topAnimeFavorite ?? this.topAnimeFavorite,
      topAnimeByPopularity: topAnimeByPopularity ?? this.topAnimeByPopularity,
      topAnimeByScore: topAnimeByScore ?? this.topAnimeByScore,
      suggestedAnime: suggestedAnime ?? this.suggestedAnime,
      topAnimeAiring: topAnimeAiring ?? this.topAnimeAiring,
      topAnimeTV: topAnimeTV ?? this.topAnimeTV,
      topAnimeMovie: topAnimeMovie ?? this.topAnimeMovie,
      topAnimeSpecial: topAnimeSpecial ?? this.topAnimeSpecial,
      topManga: topManga ?? this.topManga,
      topMangaByPopularity: topMangaByPopularity ?? this.topMangaByPopularity,
      features: features ?? this.features,
      isNewsLoaded: isNewsLoaded ?? this.isNewsLoaded,
      isSeasonNowLoaded: isSeasonNowLoaded ?? this.isSeasonNowLoaded,
      isUpcomingAnimeLoaded:
          isUpcomingAnimeLoaded ?? this.isUpcomingAnimeLoaded,
      isTopAnimeFavoriteLoaded:
          isTopAnimeFavoriteLoaded ?? this.isTopAnimeFavoriteLoaded,
      isTopAnimeByPopularityLoaded:
          isTopAnimeByPopularityLoaded ?? this.isTopAnimeByPopularityLoaded,
      isTopAnimeByScoreLoaded:
          isTopAnimeByScoreLoaded ?? this.isTopAnimeByScoreLoaded,
      isSuggestedAnimeLoaded:
          isSuggestedAnimeLoaded ?? this.isSuggestedAnimeLoaded,
      isTopAnimeAiringLoaded:
          isTopAnimeAiringLoaded ?? this.isTopAnimeAiringLoaded,
      isTopAnimeTVLoaded: isTopAnimeTVLoaded ?? this.isTopAnimeTVLoaded,
      isTopAnimeMovieLoaded:
          isTopAnimeMovieLoaded ?? this.isTopAnimeMovieLoaded,
      isTopAnimeSpecialLoaded:
          isTopAnimeSpecialLoaded ?? this.isTopAnimeSpecialLoaded,
      isTopMangaLoaded: isTopMangaLoaded ?? this.isTopMangaLoaded,
      isTopMangaByPopularityLoaded:
          isTopMangaByPopularityLoaded ?? this.isTopMangaByPopularityLoaded,
      isFeaturesLoaded: isFeaturesLoaded ?? this.isFeaturesLoaded,
    );
  }

  @override
  List<Object?> get props => [
        news,
        seasonNow,
        upcomingAnime,
        topAnimeFavorite,
        topAnimeByPopularity,
        topAnimeByScore,
        suggestedAnime,
        topAnimeAiring,
        topAnimeTV,
        topAnimeMovie,
        topAnimeSpecial,
        topManga,
        topMangaByPopularity,
        isNewsLoaded,
        isSeasonNowLoaded,
        isUpcomingAnimeLoaded,
        isTopAnimeFavoriteLoaded,
        isTopAnimeByPopularityLoaded,
        isTopAnimeByScoreLoaded,
        isSuggestedAnimeLoaded,
        isTopAnimeAiringLoaded,
        isTopAnimeTVLoaded,
        isTopAnimeMovieLoaded,
        isTopAnimeSpecialLoaded,
        isTopMangaLoaded,
        isTopMangaByPopularityLoaded,
        features,
        isFeaturesLoaded,
      ];
}

// Bloc de gestion des requêtes
class RequestsBloc extends Bloc<RequestsEvent, RequestsState> {
  final MalScraper malScraper;
  final JikanApi jikanApi;
  final MalApi malApi;
  final CacheManager _cache = CacheManager.instance;

  // Fallback expiry: 7 days in seconds (for offline mode)
  static const int _fallbackExpiry = 7 * 24 * 3600;

  RequestsBloc({
    required this.malScraper,
    required this.jikanApi,
    required this.malApi,
  }) : super(const RequestsState()) {
    on<LoadNewsEvent>(_onLoadNews);
    on<LoadSeasonNowEvent>(_onLoadSeasonNow);
    on<LoadUpcomingAnimeEvent>(_onLoadUpcomingAnime);
    on<LoadTopAnimeFavoriteEvent>(_onLoadTopAnimeFavorite);
    on<LoadTopAnimeByPopularityEvent>(_onLoadTopAnimeByPopularity);
    on<LoadTopAnimeByScoreEvent>(_onLoadTopAnimeByScore);
    on<LoadSuggestedAnimeEvent>(_onLoadSuggestedAnime);
    on<LoadTopAnimeAiringEvent>(_onLoadTopAnimeAiring);
    on<LoadTopAnimeTVEvent>(_onLoadTopAnimeTV);
    on<LoadTopAnimeMovieEvent>(_onLoadTopAnimeMovie);
    on<LoadTopAnimeSpecialEvent>(_onLoadTopAnimeSpecial);
    on<LoadTopMangaEvent>(_onLoadTopManga);
    on<LoadTopMangaByPopularityEvent>(_onLoadTopMangaByPopularity);
    on<LoadFeaturesEvent>(_onLoadFeatures);
  }

  Future<List<Map<String, String>>> getNewsorFeaturedList() async {
    Map<String, dynamic>? data = await malScraper.getAnimeNews();
    if (data == null) return [];

    List<dynamic> newsorfeaturedList = data['newsorfeatured'] ?? [];
    List<Map<String, String>> formattedList = newsorfeaturedList
        .map((item) => (item as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, value.toString()),
            ))
        .toList()
        .cast<Map<String, String>>();

    return formattedList;
  }

  Future<List<Map<String, String>>> getFeaturedList() async {
    Map<String, dynamic>? data = await malScraper.getAnimeFeatured();
    if (data == null) return [];

    List<dynamic> featuredList = data['newsorfeatured'] ?? [];
    List<Map<String, String>> formattedList = featuredList
        .map((item) => (item as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, value.toString()),
            ))
        .toList()
        .cast<Map<String, String>>();

    return formattedList;
  }

  Future<void> _onLoadFeatures(
      LoadFeaturesEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'features';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedNewsList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(features: cached, isFeaturesLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final features = await getFeaturedList();
      emit(state.copyWith(features: features, isFeaturesLoaded: true));
      await _cache.cacheNewsList(cacheKey, features);
    } catch (e) {
      final fallback = await _cache.getCachedNewsList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(features: fallback, isFeaturesLoaded: true));
      } else {
        emit(state.copyWith(isFeaturesLoaded: false));
      }
    }
  }

  Future<void> _onLoadNews(
      LoadNewsEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'news';
    final expirySeconds = event.cacheDurationHours * 3600;

    // Try cache first
    if (!event.forceUpdate) {
      final cached = await _cache.getCachedNewsList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(news: cached, isNewsLoaded: true));
        return;
      }
    }

    // Fetch from API
    try {
      debugPrint('🌐 API call: $cacheKey');
      final news = await getNewsorFeaturedList();
      emit(state.copyWith(news: news, isNewsLoaded: true));
      await _cache.cacheNewsList(cacheKey, news);
    } catch (e) {
      // Offline fallback
      final fallback = await _cache.getCachedNewsList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(news: fallback, isNewsLoaded: true));
      } else {
        emit(state.copyWith(isNewsLoaded: false));
      }
    }
  }

  Future<void> _onLoadSeasonNow(
      LoadSeasonNowEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'seasonNow';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(seasonNow: cached, isSeasonNowLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final seasonNow = await MalApi.getAnimeSeasonal(
          MalApi.getSeasonType(), MalApi.getCurrentSeasonYear(),
          sortType: SortType.AnimeScore, limit: 15);
      emit(state.copyWith(seasonNow: seasonNow, isSeasonNowLoaded: true));
      await _cache.cacheAnimeList(cacheKey, seasonNow);
    } catch (e) {
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(seasonNow: fallback, isSeasonNowLoaded: true));
      } else {
        emit(state.copyWith(isSeasonNowLoaded: false));
      }
    }
  }

  Future<void> _onLoadUpcomingAnime(
      LoadUpcomingAnimeEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'upcoming';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(
            upcomingAnime: cached, isUpcomingAnimeLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final upcomingAnime =
          await MalApi.getContentRanking(RankingType.UPCOMING, limit: 15);
      emit(state.copyWith(
          upcomingAnime: upcomingAnime, isUpcomingAnimeLoaded: true));
      await _cache.cacheAnimeList(cacheKey, upcomingAnime);
    } catch (e) {
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(
            upcomingAnime: fallback, isUpcomingAnimeLoaded: true));
      } else {
        emit(state.copyWith(isUpcomingAnimeLoaded: false));
      }
    }
  }

  Future<void> _onLoadTopAnimeFavorite(
      LoadTopAnimeFavoriteEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'topAnime-FAVOURITE';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(
            topAnimeFavorite: cached, isTopAnimeFavoriteLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final topAnimeFavorite =
          await MalApi.getContentRanking(RankingType.FAVOURITE, limit: 15);
      emit(state.copyWith(
          topAnimeFavorite: topAnimeFavorite, isTopAnimeFavoriteLoaded: true));
      await _cache.cacheAnimeList(cacheKey, topAnimeFavorite);
    } catch (e) {
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(
            topAnimeFavorite: fallback, isTopAnimeFavoriteLoaded: true));
      } else {
        emit(state.copyWith(isTopAnimeFavoriteLoaded: false));
      }
    }
  }

  Future<void> _onLoadTopAnimeByPopularity(
      LoadTopAnimeByPopularityEvent event,
      Emitter<RequestsState> emit) async {
    const cacheKey = 'topAnime-BYPOPULARITY';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(
            topAnimeByPopularity: cached,
            isTopAnimeByPopularityLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final topAnimeByPopularity =
          await MalApi.getContentRanking(RankingType.BYPOPULARITY, limit: 15);
      emit(state.copyWith(
          topAnimeByPopularity: topAnimeByPopularity,
          isTopAnimeByPopularityLoaded: true));
      await _cache.cacheAnimeList(cacheKey, topAnimeByPopularity);
    } catch (e) {
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(
            topAnimeByPopularity: fallback,
            isTopAnimeByPopularityLoaded: true));
      } else {
        emit(state.copyWith(isTopAnimeByPopularityLoaded: false));
      }
    }
  }

  Future<void> _onLoadTopAnimeByScore(
      LoadTopAnimeByScoreEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'topAnime-ALL';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(
            topAnimeByScore: cached, isTopAnimeByScoreLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final topAnimeByScore =
          await MalApi.getContentRanking(RankingType.ALL, limit: 15);
      emit(state.copyWith(
          topAnimeByScore: topAnimeByScore, isTopAnimeByScoreLoaded: true));
      await _cache.cacheAnimeList(cacheKey, topAnimeByScore);
    } catch (e) {
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(
            topAnimeByScore: fallback, isTopAnimeByScoreLoaded: true));
      } else {
        emit(state.copyWith(isTopAnimeByScoreLoaded: false));
      }
    }
  }

  Future<void> _onLoadSuggestedAnime(
      LoadSuggestedAnimeEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'suggested';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(
            suggestedAnime: cached, isSuggestedAnimeLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final suggestedAnime = await MalApi.getContentSuggestions(limit: 15);
      emit(state.copyWith(
          suggestedAnime: suggestedAnime, isSuggestedAnimeLoaded: true));
      await _cache.cacheAnimeList(cacheKey, suggestedAnime);
    } catch (e) {
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(
            suggestedAnime: fallback, isSuggestedAnimeLoaded: true));
      } else {
        emit(state.copyWith(isSuggestedAnimeLoaded: false));
      }
    }
  }

  Future<void> _onLoadTopAnimeAiring(
      LoadTopAnimeAiringEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'topAnime-AIRING';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(
            topAnimeAiring: cached, isTopAnimeAiringLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final result =
          await MalApi.getContentRanking(RankingType.AIRING, limit: 15);
      emit(state.copyWith(
          topAnimeAiring: result, isTopAnimeAiringLoaded: true));
      await _cache.cacheAnimeList(cacheKey, result);
    } catch (e) {
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(
            topAnimeAiring: fallback, isTopAnimeAiringLoaded: true));
      } else {
        emit(state.copyWith(isTopAnimeAiringLoaded: false));
      }
    }
  }

  Future<void> _onLoadTopAnimeTV(
      LoadTopAnimeTVEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'topAnime-TV';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(topAnimeTV: cached, isTopAnimeTVLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final result =
          await MalApi.getContentRanking(RankingType.TV, limit: 15);
      emit(state.copyWith(topAnimeTV: result, isTopAnimeTVLoaded: true));
      await _cache.cacheAnimeList(cacheKey, result);
    } catch (e) {
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(topAnimeTV: fallback, isTopAnimeTVLoaded: true));
      } else {
        emit(state.copyWith(isTopAnimeTVLoaded: false));
      }
    }
  }

  Future<void> _onLoadTopAnimeMovie(
      LoadTopAnimeMovieEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'topAnime-MOVIE';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(
            topAnimeMovie: cached, isTopAnimeMovieLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final result =
          await MalApi.getContentRanking(RankingType.MOVIE, limit: 15);
      emit(state.copyWith(
          topAnimeMovie: result, isTopAnimeMovieLoaded: true));
      await _cache.cacheAnimeList(cacheKey, result);
    } catch (e) {
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(
            topAnimeMovie: fallback, isTopAnimeMovieLoaded: true));
      } else {
        emit(state.copyWith(isTopAnimeMovieLoaded: false));
      }
    }
  }

  Future<void> _onLoadTopAnimeSpecial(
      LoadTopAnimeSpecialEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'topAnime-SPECIAL';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(
            topAnimeSpecial: cached, isTopAnimeSpecialLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final result =
          await MalApi.getContentRanking(RankingType.SPECIAL, limit: 15);
      emit(state.copyWith(
          topAnimeSpecial: result, isTopAnimeSpecialLoaded: true));
      await _cache.cacheAnimeList(cacheKey, result);
    } catch (e) {
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(
            topAnimeSpecial: fallback, isTopAnimeSpecialLoaded: true));
      } else {
        emit(state.copyWith(isTopAnimeSpecialLoaded: false));
      }
    }
  }

  Future<void> _onLoadTopManga(
      LoadTopMangaEvent event, Emitter<RequestsState> emit) async {
    const cacheKey = 'topManga-ALL';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(topManga: cached, isTopMangaLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final result = await MalApi.getContentRanking(MangaRanking.all,
          limit: 15, category: "manga");
      emit(state.copyWith(topManga: result, isTopMangaLoaded: true));
      await _cache.cacheAnimeList(cacheKey, result);
    } catch (e, stack) {
      debugPrint('❌ Error loading $cacheKey: $e');
      debugPrint('$stack');
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(topManga: fallback, isTopMangaLoaded: true));
      } else {
        emit(state.copyWith(isTopMangaLoaded: false));
      }
    }
  }

  Future<void> _onLoadTopMangaByPopularity(
      LoadTopMangaByPopularityEvent event,
      Emitter<RequestsState> emit) async {
    const cacheKey = 'topManga-BYPOPULARITY';
    final expirySeconds = event.cacheDurationHours * 3600;

    if (!event.forceUpdate) {
      final cached = await _cache.getCachedAnimeList(cacheKey, expirySeconds);
      if (cached != null) {
        debugPrint('📦 Cache hit: $cacheKey');
        emit(state.copyWith(
            topMangaByPopularity: cached,
            isTopMangaByPopularityLoaded: true));
        return;
      }
    }

    try {
      debugPrint('🌐 API call: $cacheKey');
      final result = await MalApi.getContentRanking(MangaRanking.bypopularity,
          limit: 15, category: "manga");
      emit(state.copyWith(
          topMangaByPopularity: result,
          isTopMangaByPopularityLoaded: true));
      await _cache.cacheAnimeList(cacheKey, result);
    } catch (e, stack) {
      debugPrint('❌ Error loading $cacheKey: $e');
      debugPrint('$stack');
      final fallback =
          await _cache.getCachedAnimeList(cacheKey, _fallbackExpiry);
      if (fallback != null) {
        debugPrint('📦 Offline fallback: $cacheKey');
        emit(state.copyWith(
            topMangaByPopularity: fallback,
            isTopMangaByPopularityLoaded: true));
      } else {
        emit(state.copyWith(isTopMangaByPopularityLoaded: false));
      }
    }
  }
}
