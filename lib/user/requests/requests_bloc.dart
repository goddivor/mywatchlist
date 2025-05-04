// Evénements BLoC
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/mal_scrapper.dart';

abstract class RequestsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadNewsEvent extends RequestsEvent {}

class LoadSeasonNowEvent extends RequestsEvent {}

class LoadUpcomingAnimeEvent extends RequestsEvent {}

class LoadTopAnimeFavoriteEvent extends RequestsEvent {}

class LoadTopAnimeByPopularityEvent extends RequestsEvent {}

class LoadTopAnimeByScoreEvent extends RequestsEvent {}

class LoadSuggestedAnimeEvent extends RequestsEvent {}

// États BLoC
class RequestsState extends Equatable {
  final List<Map<String, String>> news;
  final List<Anime> seasonNow;
  final List<Anime> upcomingAnime;
  final List<Anime> topAnimeFavorite;
  final List<Anime> topAnimeByPopularity;
  final List<Anime> topAnimeByScore;
  final List<Anime> suggestedAnime;

  final bool isNewsLoaded;
  final bool isSeasonNowLoaded;
  final bool isUpcomingAnimeLoaded;
  final bool isTopAnimeFavoriteLoaded;
  final bool isTopAnimeByPopularityLoaded;
  final bool isTopAnimeByScoreLoaded;
  final bool isSuggestedAnimeLoaded;

  const RequestsState({
    this.news = const [],
    this.seasonNow = const [],
    this.upcomingAnime = const [],
    this.topAnimeFavorite = const [],
    this.topAnimeByPopularity = const [],
    this.topAnimeByScore = const [],
    this.suggestedAnime = const [],
    this.isNewsLoaded = false,
    this.isSeasonNowLoaded = false,
    this.isUpcomingAnimeLoaded = false,
    this.isTopAnimeFavoriteLoaded = false,
    this.isTopAnimeByPopularityLoaded = false,
    this.isTopAnimeByScoreLoaded = false,
    this.isSuggestedAnimeLoaded = false,
  });

  RequestsState copyWith({
    List<Map<String, String>>? news,
    List<Anime>? seasonNow,
    List<Anime>? upcomingAnime,
    List<Anime>? topAnimeFavorite,
    List<Anime>? topAnimeByPopularity,
    List<Anime>? topAnimeByScore,
    List<Anime>? suggestedAnime,
    bool? isNewsLoaded,
    bool? isSeasonNowLoaded,
    bool? isUpcomingAnimeLoaded,
    bool? isTopAnimeFavoriteLoaded,
    bool? isTopAnimeByPopularityLoaded,
    bool? isTopAnimeByScoreLoaded,
    bool? isSuggestedAnimeLoaded,
  }) {
    return RequestsState(
      news: news ?? this.news,
      seasonNow: seasonNow ?? this.seasonNow,
      upcomingAnime: upcomingAnime ?? this.upcomingAnime,
      topAnimeFavorite: topAnimeFavorite ?? this.topAnimeFavorite,
      topAnimeByPopularity: topAnimeByPopularity ?? this.topAnimeByPopularity,
      topAnimeByScore: topAnimeByScore ?? this.topAnimeByScore,
      suggestedAnime: suggestedAnime ?? this.suggestedAnime,
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
        isNewsLoaded,
        isSeasonNowLoaded,
        isUpcomingAnimeLoaded,
        isTopAnimeFavoriteLoaded,
        isTopAnimeByPopularityLoaded,
        isTopAnimeByScoreLoaded,
        isSuggestedAnimeLoaded,
      ];
}

// Bloc de gestion des requêtes
class RequestsBloc extends Bloc<RequestsEvent, RequestsState> {
  final MalScraper malScraper;
  final JikanApi jikanApi;
  final MalApi malApi;

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

  Future<void> _onLoadNews(
      LoadNewsEvent event, Emitter<RequestsState> emit) async {
    try {
      final news = await getNewsorFeaturedList();
      emit(state.copyWith(news: news, isNewsLoaded: true));
    } catch (e) {
      emit(state.copyWith(isNewsLoaded: false));
    }
  }

  Future<void> _onLoadSeasonNow(
      LoadSeasonNowEvent event, Emitter<RequestsState> emit) async {
    try {
      final seasonNow = await MalApi.getAnimeSeasonal(
          MalApi.getSeasonType(), MalApi.getCurrentSeasonYear(),sortType: SortType.AnimeScore,
          limit: 15);
      emit(state.copyWith(seasonNow: seasonNow, isSeasonNowLoaded: true));
    } catch (e) {
      emit(state.copyWith(isSeasonNowLoaded: false));
    }
  }

  Future<void> _onLoadUpcomingAnime(
      LoadUpcomingAnimeEvent event, Emitter<RequestsState> emit) async {
    try {
      final upcomingAnime =
          await MalApi.getContentRanking(RankingType.UPCOMING, limit: 15);
      emit(state.copyWith(
          upcomingAnime: upcomingAnime, isUpcomingAnimeLoaded: true));
    } catch (e) {
      emit(state.copyWith(isUpcomingAnimeLoaded: false));
    }
  }

  Future<void> _onLoadTopAnimeFavorite(
      LoadTopAnimeFavoriteEvent event, Emitter<RequestsState> emit) async {
    try {
      final topAnimeFavorite =
          await MalApi.getContentRanking(RankingType.FAVOURITE, limit: 15);
      emit(state.copyWith(
          topAnimeFavorite: topAnimeFavorite, isTopAnimeFavoriteLoaded: true));
    } catch (e) {
      emit(state.copyWith(isTopAnimeFavoriteLoaded: false));
    }
  }

  Future<void> _onLoadTopAnimeByPopularity(
      LoadTopAnimeByPopularityEvent event, Emitter<RequestsState> emit) async {
    try {
      final topAnimeByPopularity =
          await MalApi.getContentRanking(RankingType.BYPOPULARITY, limit: 15);
      emit(state.copyWith(
          topAnimeByPopularity: topAnimeByPopularity,
          isTopAnimeByPopularityLoaded: true));
    } catch (e) {
      emit(state.copyWith(isTopAnimeByPopularityLoaded: false));
    }
  }

  Future<void> _onLoadTopAnimeByScore(
      LoadTopAnimeByScoreEvent event, Emitter<RequestsState> emit) async {
    try {
      final topAnimeByScore =
          await MalApi.getContentRanking(RankingType.ALL, limit: 15);
      emit(state.copyWith(
          topAnimeByScore: topAnimeByScore, isTopAnimeByScoreLoaded: true));
    } catch (e) {
      emit(state.copyWith(isTopAnimeByScoreLoaded: false));
    }
  }

  Future<void> _onLoadSuggestedAnime(
      LoadSuggestedAnimeEvent event, Emitter<RequestsState> emit) async {
    try {
      final suggestedAnime = await MalApi.getContentSuggestions(limit: 15);
      emit(state.copyWith(
          suggestedAnime: suggestedAnime, isSuggestedAnimeLoaded: true));
    } catch (e) {
      emit(state.copyWith(isSuggestedAnimeLoaded: false));
    }
  }
}
