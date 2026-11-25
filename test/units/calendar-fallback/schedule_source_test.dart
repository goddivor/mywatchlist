import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';
import 'package:mywatchlist/widgets/calendar/schedule_source.dart';

final _now = DateTime.utc(2026, 11, 25, 12);

Map<String, dynamic> _page(List<Map<String, dynamic>> rows, {bool next = false}) => {
      'Page': {
        'pageInfo': {'hasNextPage': next},
        'airingSchedules': rows,
      },
    };

Map<String, dynamic> _row(int malId, int episode, {bool adult = false, int? at}) => {
      'episode': episode,
      'airingAt': at ?? _now.millisecondsSinceEpoch ~/ 1000 + 3600,
      'media': {
        'idMal': malId,
        'isAdult': adult,
        'siteUrl': 'https://anilist.co/anime/$malId',
        'title': {'romaji': 'Title $malId'},
      },
    };

AiringScheduleSource _source({
  Future<List<LiveChartEpisode>> Function({required bool fromCache})? backend,
  AnilistQuery? anilist,
  bool adult = false,
}) =>
    AiringScheduleSource(
      backend: backend ?? ({required fromCache}) async => throw StateError('backend down'),
      anilist: anilist ?? (_, __) async => throw StateError('AniList down'),
      adultAllowed: () => adult,
      clock: () => _now,
    );

void main() {
  test('the backend schedule is used when it answers', () async {
    var asked = false;
    final source = _source(
      backend: ({required fromCache}) async =>
          [const LiveChartEpisode(timestamp: 10, episode: 3, malId: 1)],
      anilist: (_, __) async {
        asked = true;
        return _page([]);
      },
    );
    final episodes = await source.fetch();
    expect(episodes.single.episode, 3);
    expect(asked, isFalse);
  });

  test('AniList fills in when the backend fails, page after page, without adult titles', () async {
    final pages = <int>[];
    final source = _source(anilist: (query, variables) async {
      final page = variables['page'] as int;
      pages.add(page);
      expect(variables['from'], _now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000);
      expect(variables['to'], _now.add(const Duration(days: 8)).millisecondsSinceEpoch ~/ 1000);
      return page == 1
          ? _page([_row(52991, 11), _row(7, 2, adult: true)], next: true)
          : _page([_row(61967, 8), {'episode': 1, 'airingAt': 5, 'media': {'idMal': null}}]);
    });
    final episodes = await source.fetch();
    expect(pages, [1, 2]);
    expect(episodes.map((e) => e.malId), [52991, 61967]);
    expect(episodes.first.episode, 11);
    expect(episodes.first.title, 'Title 52991');
    expect(episodes.first.relatedLinks['anilist'], 'https://anilist.co/anime/52991');
  });

  test('an empty backend schedule also falls back to AniList', () async {
    final source = _source(
      backend: ({required fromCache}) async => const [],
      anilist: (_, __) async => _page([_row(1, 1)]),
    );
    expect((await source.fetch()).single.malId, 1);
  });

  test('both failing throws, so the calendar shows its failure state', () async {
    final source = _source();
    await expectLater(source.fetch(), throwsStateError);

    final schedule = AiringSchedule(fetcher: ({required fromCache}) => source.fetch(fromCache: fromCache));
    await schedule.ensureLoaded();
    expect(schedule.isLoaded, isFalse);
    expect(schedule.error, isNotNull);
  });
}
