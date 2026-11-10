import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';
import 'package:mywatchlist/widgets/calendar/calendar_cubit.dart';
import 'package:mywatchlist/widgets/calendar/calendar_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

Anime _anime(int id, {int? episodes, String? status}) => Anime(
      id: id,
      title: 'MAL title $id',
      imageUrl: 'https://img/$id.jpg',
      score: 0,
      members: 0,
      numEpisodes: episodes,
      myListStatus: status == null
          ? null
          : MyListStatus(
              status: status,
              score: 0,
              numEpisodesWatched: 0,
              isRewatching: false,
              updatedAt: '',
            ),
    );

void main() {
  final now = DateTime.utc(2026, 10, 27, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  AiringSchedule schedule(List<LiveChartEpisode> episodes) =>
      AiringSchedule(fetcher: ({required fromCache}) async => episodes);

  LiveChartEpisode lc(int id, DateTime at, int ep) =>
      LiveChartEpisode(timestamp: at.millisecondsSinceEpoch ~/ 1000, episode: ep, malId: id);

  test('joins the schedule with the season and the list status', () async {
    final cubit = CalendarCubit(
      timezone: TimezonePref.utc,
      listKnown: true,
      clock: () => now,
      cache: ListStatusCache(),
      schedule: schedule([
        lc(1, DateTime.utc(2026, 10, 27, 15), 5),
        lc(2, DateTime.utc(2026, 10, 27, 16), 3),
      ]),
      seasonLoader: () async => {1: _anime(1, episodes: 12, status: 'watching')},
    );
    await cubit.load();
    final entries = cubit.state.entries;
    expect(cubit.state.status, CalendarStatus.ready);
    expect(entries[0].title, 'MAL title 1');
    expect(entries[0].numEpisodes, 12);
    expect(entries[0].listStatus, 'watching');
    expect(entries[0].isHighlighted, isTrue);
    expect(entries[1].title, '#2'); // not in the season list: no LiveChart title either
    expect(entries[1].imageUrl, '');
    expect(cubit.state.days[0].entries, hasLength(2));

    cubit.setFilter(CalendarFilter.watching);
    expect(cubit.state.days[0].entries.map((e) => e.malId), [1]);
    await cubit.close();
  });

  test('still shows the schedule when the season list fails', () async {
    final cubit = CalendarCubit(
      timezone: TimezonePref.utc,
      listKnown: true,
      clock: () => now,
      cache: ListStatusCache(),
      schedule: schedule([lc(7, DateTime.utc(2026, 10, 28, 15), 1)]),
      seasonLoader: () async => throw Exception('MAL down'),
    );
    await cubit.load();
    expect(cubit.state.status, CalendarStatus.ready);
    expect(cubit.state.weekCount, 1);
    await cubit.close();
  });

  test('fails when the schedule never loaded', () async {
    final cubit = CalendarCubit(
      timezone: TimezonePref.utc,
      listKnown: false,
      clock: () => now,
      cache: ListStatusCache(),
      schedule: AiringSchedule(fetcher: ({required fromCache}) async => throw Exception('offline')),
      seasonLoader: () async => {},
    );
    await cubit.load();
    expect(cubit.state.status, CalendarStatus.failure);
    await cubit.close();
  });

  test('changing the zone regroups the week; losing the list drops the filter', () async {
    final cubit = CalendarCubit(
      timezone: TimezonePref.utc,
      listKnown: true,
      clock: () => now,
      cache: ListStatusCache(),
      schedule: schedule([lc(1, DateTime.utc(2026, 10, 27, 20), 5)]),
      seasonLoader: () async => {},
    );
    await cubit.load();
    expect(cubit.state.days[0].entries, hasLength(1));
    cubit.setTimezone(TimezonePref.jst);
    expect(cubit.state.days[0].entries, isEmpty);
    expect(cubit.state.days[1].entries, hasLength(1));
    cubit.setFilter(CalendarFilter.watching);
    cubit.setListKnown(false);
    expect(cubit.state.filter, isNull);
    await cubit.close();
  });
}
