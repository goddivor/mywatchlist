import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';
import 'package:mywatchlist/widgets/calendar/calendar_logic.dart';
import 'package:mywatchlist/widgets/calendar/calendar_models.dart';

/// Loads the anime of the current MAL season by id (cover, episodes, list status).
typedef SeasonLoader = Future<Map<int, Anime>> Function();

Future<Map<int, Anime>> _defaultSeasonLoader() async {
  final result = await MalApi.getAnimeSeasonalResult(
    MalApi.getSeasonType(),
    MalApi.getCurrentSeasonYear(),
    limit: 500,
    fields: const ['my_list_status', 'num_episodes'],
  );
  return {for (final a in result.data) a.id: a};
}

enum CalendarStatus { loading, ready, failure }

class CalendarState extends Equatable {
  final CalendarStatus status;

  /// Every episode joined with its anime, unfiltered.
  final List<CalendarEntry> entries;

  /// The filter value (`all`, `watching`, `plan_to_watch`,
  /// `watching_or_planned`, `in_list`, `not_in_list`); null behaves as `all`.
  final String? filter;
  final TimezonePref timezone;

  /// False when the active account is not MAL: the list status is unknown, the
  /// status chips are hidden and nothing is highlighted.
  final bool listKnown;

  /// The seven days starting today, filtered; today also lists the episodes
  /// that already aired (see [withPreviousEpisodes]).
  final List<CalendarDay> days;

  const CalendarState({
    this.status = CalendarStatus.loading,
    this.entries = const [],
    this.filter,
    this.timezone = TimezonePref.local,
    this.listKnown = true,
    this.days = const [],
  });

  /// Episodes of the whole week that pass the filter.
  int get weekCount => days.fold(0, (sum, d) => sum + d.entries.length);

  CalendarState copyWith({
    CalendarStatus? status,
    List<CalendarEntry>? entries,
    Object? filter = _keep,
    TimezonePref? timezone,
    bool? listKnown,
    List<CalendarDay>? days,
  }) =>
      CalendarState(
        status: status ?? this.status,
        entries: entries ?? this.entries,
        filter: identical(filter, _keep) ? this.filter : filter as String?,
        timezone: timezone ?? this.timezone,
        listKnown: listKnown ?? this.listKnown,
        days: days ?? this.days,
      );

  @override
  List<Object?> get props => [status, entries, filter, timezone, listKnown, days];
}

const Object _keep = Object();

/// State of the calendar screen: loads LiveChart's schedule (through
/// [AiringSchedule]) and the MAL season, joins them and groups the week by day.
class CalendarCubit extends Cubit<CalendarState> {
  CalendarCubit({
    required TimezonePref timezone,
    required bool listKnown,
    String? initialFilter,
    AiringSchedule? schedule,
    SeasonLoader? seasonLoader,
    ListStatusCache? cache,
    DateTime Function()? clock,
  })  : _schedule = schedule ?? AiringSchedule.instance,
        _season = seasonLoader ?? _defaultSeasonLoader,
        _cache = cache ?? ListStatusCache.instance,
        _clock = clock ?? DateTime.now,
        super(CalendarState(timezone: timezone, listKnown: listKnown, filter: listKnown ? initialFilter : null));

  final AiringSchedule _schedule;
  final SeasonLoader _season;
  final ListStatusCache _cache;
  final DateTime Function() _clock;
  int _generation = 0;

  /// Loads the schedule; [refresh] bypasses the caches. Keeps showing the
  /// previous week while reloading.
  Future<void> load({bool refresh = false}) async {
    final generation = ++_generation;
    if (state.entries.isEmpty) emit(state.copyWith(status: CalendarStatus.loading));
    final results = await Future.wait<Object?>([
      _schedule.ensureLoaded(refresh: refresh),
      _season().then<Map<int, Anime>?>((m) => m).catchError((Object e) {
        debugPrint('Calendar: season list unavailable ($e)');
        return null;
      }),
      _cache.ensureLoaded(),
    ]);
    if (isClosed || generation != _generation) return;
    final season = results[1] as Map<int, Anime>? ?? const {};
    if (!_schedule.isLoaded) {
      emit(state.copyWith(status: CalendarStatus.failure));
      return;
    }
    final entries = joinEntries(
      _schedule.episodes,
      season,
      statusOf: (id) => _cache.statusOf(id),
    );
    _emitWith(entries: entries, status: CalendarStatus.ready);
  }

  /// Joins airing episodes with the season list. An episode of an anime absent
  /// from the season (a long runner) keeps LiveChart's title and has no cover.
  @visibleForTesting
  static List<CalendarEntry> joinEntries(
    List<AiringEpisode> episodes,
    Map<int, Anime> season, {
    required String? Function(int malId) statusOf,
  }) {
    return [
      for (final e in episodes)
        CalendarEntry(
          malId: e.malId,
          title: season[e.malId]?.title ?? e.title ?? '#${e.malId}',
          imageUrl: season[e.malId]?.imageUrl ?? '',
          episode: e.episode,
          airingAt: e.airingAt,
          numEpisodes: _positive(season[e.malId]?.numEpisodes),
          listStatus: season[e.malId]?.myListStatus?.status ?? statusOf(e.malId),
          relatedLinks: e.relatedLinks,
        ),
    ];
  }

  static int? _positive(int? n) => n == null || n <= 0 ? null : n;

  void setFilter(String? filter) => _emitWith(filter: filter);

  void setTimezone(TimezonePref timezone) {
    if (timezone != state.timezone) _emitWith(timezone: timezone);
  }

  void setListKnown(bool known) {
    if (known != state.listKnown) _emitWith(listKnown: known, filter: known ? state.filter : null);
  }

  /// Rebuilds the week when midnight has passed in the chosen zone.
  void tick() {
    if (state.days.isEmpty) return;
    final today = inTimezone(_clock(), state.timezone);
    final first = state.days.first.date;
    if (today.year != first.year || today.month != first.month || today.day != first.day) {
      _emitWith();
    }
  }

  void _emitWith({
    List<CalendarEntry>? entries,
    CalendarStatus? status,
    Object? filter = _keep,
    TimezonePref? timezone,
    bool? listKnown,
  }) {
    final next = state.copyWith(
      entries: entries,
      status: status,
      filter: filter,
      timezone: timezone,
      listKnown: listKnown,
    );
    final now = _clock();
    emit(next.copyWith(
      days: buildWeek(
        withPreviousEpisodes(next.entries, now: now),
        now: now,
        pref: next.timezone,
        filter: next.filter,
        listKnown: next.listKnown,
      ),
    ));
  }
}
