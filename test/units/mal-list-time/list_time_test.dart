import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/mal_user_list_adapter.dart';

Map<String, dynamic> _anime(int id, String status, int watched,
        {int episodes = 12, int seconds = 1440}) =>
    {
      'node': {
        'id': id,
        'title': 'T$id',
        'num_episodes': episodes,
        'average_episode_duration': seconds,
        'start_season': {'year': 2024, 'season': 'spring'},
        'rating': 'pg_13',
        'source': 'manga',
        'studios': [
          {'id': 1, 'name': 'Bones'},
        ],
      },
      'list_status': {
        'status': status,
        'num_episodes_watched': watched,
        'num_times_rewatched': 2,
      },
    };

ListEntryView _view(String status, int watched, {int episodes = 12, int seconds = 1440}) =>
    parseMalListPage({
      'data': [_anime(1, status, watched, episodes: episodes, seconds: seconds)],
    }, category: 'anime', titleLang: 'en')
        .entries
        .single;

void main() {
  setUpAll(() async => S.load(const Locale('en')));

  test('the list asks the fields time and filters need', () {
    expect(MalUserListAdapter.animeFields, contains('average_episode_duration'));
    expect(MalUserListAdapter.animeFields, contains('start_season,rating,source,studios'));
    expect(MalUserListAdapter.animeFields, contains('num_times_rewatched'));
    expect(MalUserListAdapter.mangaFields, contains('authors{first_name,last_name}'));
    expect(MalUserListAdapter.mangaFields, contains('num_times_reread'));
    expect(MalUserListAdapter.mangaFields, isNot(contains('studios')));
  });

  test('the extra node fields are parsed', () {
    final e = _view('watching', 5);
    expect(e.episodeSeconds, 1440);
    expect(e.startSeason, 'spring');
    expect(e.startSeasonYear, 2024);
    expect(e.ageRating, 'pg_13');
    expect(e.source, 'manga');
    expect(e.studios, ['Bones']);
    expect(e.timesRewatched, 2);

    final m = parseMalListPage({
      'data': [
        {
          'node': {
            'id': 9,
            'title': 'M',
            'authors': [
              {'node': {'id': 1, 'first_name': 'Eiichiro', 'last_name': 'Oda'}, 'role': 'Story'},
              {'node': {'id': 2, 'first_name': '', 'last_name': 'Solo'}, 'role': 'Art'},
            ],
          },
          'list_status': {'status': 'reading', 'num_times_reread': 1},
        },
      ],
    }, category: 'manga', titleLang: 'en').entries.single;
    expect(m.authors, ['Eiichiro Oda', 'Solo']);
    expect(m.timesRewatched, 1);
    expect(m.episodeSeconds, 0);
    expect(m.timeLeft, isNull);
  });

  test('time left is the remaining episodes at the average length', () {
    expect(_view('watching', 2).timeLeft, const Duration(minutes: 24 * 10));
    expect(_view('plan_to_watch', 0).timeLeft, const Duration(minutes: 24 * 12));
    expect(_view('on_hold', 12).timeLeft, Duration.zero);
    expect(_view('completed', 12).timeLeft, isNull);
    expect(_view('dropped', 3).timeLeft, isNull);
    expect(_view('watching', 2, seconds: 0).timeLeft, isNull);
    expect(_view('watching', 2, episodes: 0).timeLeft, isNull);
    expect(_view('completed', 12).timeWatched, const Duration(minutes: 24 * 12));
  });

  test('a tab sums its entries: left for to-watch tabs, watched for the others', () {
    final entries = [_view('watching', 2), _view('plan_to_watch', 0)];
    final left = ListTimeSummary.of(entries, ListEntryStatus.planned)!;
    expect(left.kind, ListTimeKind.left);
    expect(left.total, const Duration(minutes: 24 * 22));
    expect(left.label(), 'Time left: 8 h 48 min');

    final done = ListTimeSummary.of([_view('completed', 12)], ListEntryStatus.completed)!;
    expect(done.kind, ListTimeKind.watched);
    expect(done.label(), 'Time watched: 4 h 48 min');

    expect(ListTimeSummary.of([_view('watching', 2, seconds: 0)], ListEntryStatus.current), isNull);
  });

  test('durations show their two largest units; a partial total ends with +', () {
    expect(formatListDuration(const Duration(days: 41, hours: 3, minutes: 9)), '41 d 3 h');
    expect(formatListDuration(const Duration(hours: 5, minutes: 20)), '5 h 20 min');
    expect(formatListDuration(const Duration(seconds: 10)), '1 min');
    final partial = ListTimeSummary.of([_view('planned'.replaceAll('planned', 'plan_to_watch'), 0)],
        ListEntryStatus.planned, partial: true)!;
    expect(partial.label(), 'Time left: 4 h 48 min+');
  });

  test('a saved edit updates the rewatch count', () {
    final view = _view('completed', 12);
    final saved = MalUserListAdapter.applyEntry(
        view, const ListEntry(status: 'completed', progress: 12, timesRepeated: 3), DateTime(2026));
    expect(saved.timesRewatched, 3);
    expect(saved.episodeSeconds, 1440, reason: 'node fields survive an edit');
    expect(saved.studios, ['Bones']);
  });
}
