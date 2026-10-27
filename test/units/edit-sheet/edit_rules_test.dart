import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/MAL/models/my_anime_list_status.dart';
import 'package:mywatchlist/services/api/MAL/models/my_manga_list_status.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';

import 'fixtures.dart';

final _now = DateTime(2026, 10, 27, 15);

void main() {
  group('pre-fill from MAL', () {
    test('a completed anime keeps every list field', () {
      final c =
          EditableContent.fromMalJson(completedAnimeJson(), isAnime: true);
      final e = c.entry!;
      expect(c.numEpisodes, 64);
      expect(e.status, 'completed');
      expect(e.score, 10);
      expect(e.progress, 64);
      expect(e.isRepeating, isFalse);
      expect(e.timesRepeated, 2);
      expect(e.repeatValue, 4);
      expect(e.priority, 2);
      expect(e.startDate, '2019-01-05');
      expect(e.finishDate, '2019-03');
      expect(e.tags, ['shounen', 'Tom &amp; Jerry']);
      expect(e.comments, 'Great<br />\nshow &quot;FMA&quot;');
    });

    test('manga chapters and volumes are read, not forced to 0', () {
      final c = EditableContent.fromMalJson(readingMangaJson(), isAnime: false);
      expect(c.entry!.progress, 112);
      expect(c.entry!.volumes, 12);
      expect(c.entry!.isRepeating, isTrue);
      expect(c.numChapters, 0);
      expect(c.numVolumes, 0);
    });

    test('no my_list_status means not on the list', () {
      final json = completedAnimeJson()..remove('my_list_status');
      expect(EditableContent.fromMalJson(json, isAnime: true).entry, isNull);
    });

    test('an update keeps a partial date it did not touch', () {
      final before =
          EditableContent.fromMalJson(completedAnimeJson(), isAnime: true)
              .entry!;
      final answer = MyAnimeListStatus.fromJson({
        'status': 'completed',
        'score': 9,
        'num_episodes_watched': 64,
        'start_date': '2019-01-05',
        'finish_date': '2019-03',
      });
      final after = ListEntry.fromAnimeStatus(answer, previous: before);
      expect(after.score, 9);
      expect(after.startDate, '2019-01-05');
      expect(after.finishDate, '2019-03');
    });

    test('a manga update maps chapters and volumes', () {
      final answer = MyMangaListStatus.fromJson({
        'status': 'reading',
        'num_chapters_read': 113,
        'num_volumes_read': 12,
      });
      final e = ListEntry.fromMangaStatus(answer, sentStart: '2026-10-27');
      expect(e.progress, 113);
      expect(e.volumes, 12);
      expect(e.startDate, '2026-10-27');
    });
  });

  group('auto dates', () {
    const anime = EditableContent(id: 1, isAnime: true, numEpisodes: 12);
    const planned = ListEntry(status: 'plan_to_watch');
    const started =
        ListEntry(status: 'watching', progress: 11, startDate: '2026-01-02');

    test('preference off: no date is ever set', () {
      final p = planStatusChange(
          content: anime,
          entry: planned,
          status: 'completed',
          autoDates: false,
          now: _now);
      expect(p.startDate, isNull);
      expect(p.finishDate, isNull);
      expect(p.progress, 12);
      final plan = planProgressChange(
          content: anime,
          entry: planned,
          progress: 12,
          autoDates: false,
          now: _now);
      expect(plan.patch!.startDate, isNull);
      expect(plan.patch!.finishDate, isNull);
    });

    test('watching fills an empty start date only', () {
      final empty = planStatusChange(
          content: anime,
          entry: planned,
          status: 'watching',
          autoDates: true,
          now: _now);
      expect(empty.startDate, '2026-10-27');
      final existing = planStatusChange(
          content: anime,
          entry: const ListEntry(status: 'on_hold', startDate: '2020-05-01'),
          status: 'watching',
          autoDates: true,
          now: _now);
      expect(existing.startDate, isNull);
    });

    test('completing keeps an existing finish date', () {
      final p = planStatusChange(
          content: anime,
          entry: const ListEntry(status: 'dropped', finishDate: '2021-02-03'),
          status: 'completed',
          autoDates: true,
          now: _now);
      expect(p.finishDate, isNull);
    });

    test('the last episode completes and sets the finish date', () {
      final plan = planProgressChange(
          content: anime,
          entry: started,
          progress: 12,
          autoDates: true,
          now: _now);
      expect(plan.patch!.status, 'completed');
      expect(plan.patch!.finishDate, '2026-10-27');
      expect(plan.patch!.startDate, isNull, reason: 'start date kept');
    });

    test('episode 0 to 1 fills the start date and starts watching', () {
      final plan = planProgressChange(
          content: anime,
          entry: planned,
          progress: 1,
          autoDates: true,
          now: _now);
      expect(plan.patch!.startDate, '2026-10-27');
      expect(plan.patch!.status, 'watching');
      expect(plan.patch!.finishDate, isNull);
    });

    test('progress over the total or below 0 is refused', () {
      expect(
          planProgressChange(
                  content: anime,
                  entry: started,
                  progress: 13,
                  autoDates: true,
                  now: _now)
              .error,
          ProgressError.overMaximum);
      expect(
          planProgressChange(
                  content: anime,
                  entry: started,
                  progress: -1,
                  autoDates: true,
                  now: _now)
              .error,
          ProgressError.negative);
    });

    test('unknown total: any progress is allowed and never completes', () {
      const airing = EditableContent(id: 2, isAnime: true);
      final plan = planProgressChange(
          content: airing,
          entry: started,
          progress: 500,
          autoDates: true,
          now: _now);
      expect(plan.patch!.status, isNull);
    });
  });

  group('add to list', () {
    const anime = EditableContent(id: 1, isAnime: true, numEpisodes: 12);
    const manga = EditableContent(id: 1, isAnime: false);

    test('uses the preferred status', () {
      expect(
          planAdd(
                  content: anime,
                  preferredStatus: 'on_hold',
                  autoDates: true,
                  now: _now)
              .status,
          'on_hold');
      final watching = planAdd(
          content: anime,
          preferredStatus: 'watching',
          autoDates: true,
          now: _now);
      expect(watching.status, 'watching');
      expect(watching.startDate, '2026-10-27');
    });

    test('maps an anime status to the manga one', () {
      expect(
          planAdd(
                  content: manga,
                  preferredStatus: 'watching',
                  autoDates: false,
                  now: _now)
              .status,
          'reading');
      expect(validStatus('nonsense', isAnime: false), 'plan_to_read');
    });
  });

  group('episode count of airing shows', () {
    test('known total wins', () {
      const c = EditableContent(id: 1, isAnime: true, numEpisodes: 24);
      expect(episodePickerCount(c, 3, _now), 24);
    });

    test('airing without total: weeks since the release start + 1', () {
      final c = EditableContent(
          id: 1,
          isAnime: true,
          airingStatus: 'currently_airing',
          releaseStart: '2026-10-06');
      expect(estimateAiredEpisodes(c, _now), 4);
      expect(episodePickerCount(c, 2, _now), 4);
      expect(episodePickerCount(c, 4, _now), 5);
    });

    test('season start when the release date is partial', () {
      const c = EditableContent(
          id: 1,
          isAnime: true,
          airingStatus: 'currently_airing',
          releaseStart: '2026-10',
          startSeason: 'fall',
          startSeasonYear: 2026);
      expect(estimateAiredEpisodes(c, _now), 4);
    });

    test('nothing known: watched + 10, or a free number', () {
      const c = EditableContent(id: 1, isAnime: true);
      expect(episodePickerCount(c, 5, _now), 15);
      expect(episodePickerCount(c, 0, _now), isNull);
    });
  });

  group('text', () {
    test('comments and tags are decoded', () {
      expect(decodeMalText('Great<br />\nshow &quot;FMA&quot; &#039;s'),
          'Great\nshow "FMA" \'s');
      expect(
          tagsToText(['shounen', 'Tom &amp; Jerry']), 'shounen, Tom & Jerry');
      expect(textToTags(' a, ,b ,c'), 'a,b,c');
    });

    test('partial dates open the picker on their month', () {
      expect(parseApiDate('2019-03'), DateTime(2019, 3, 1));
      expect(parseApiDate('2019'), DateTime(2019, 1, 1));
      expect(parseApiDate('2019-03-14'), DateTime(2019, 3, 14));
    });
  });
}
