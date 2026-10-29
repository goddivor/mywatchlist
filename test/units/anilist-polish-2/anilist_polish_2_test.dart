import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_list_look.dart';
import 'package:mywatchlist/widgets/Anilist/profile/other_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

import '../../helpers/no_network.dart';

// Fakes only: the AniList answers are built here, nothing reaches AniList.

class _FakeProfile extends AnilistProfileService {
  _FakeProfile() : super(signedIn: false);
  @override
  Future<String> accountTitleLang() async => 'ro';
}

Map<String, dynamic> _entry(int id, int raw, {Map<String, dynamic>? next, String? status}) => {
      'id': id * 10,
      'status': 'CURRENT',
      'scoreRaw': raw,
      'score': raw / 10,
      'progress': 3,
      'media': {
        'id': id,
        'type': 'ANIME',
        'format': 'TV',
        'status': status ?? 'RELEASING',
        'episodes': 12,
        'duration': 24,
        'title': {'romaji': 'Title $id', 'userPreferred': 'Title $id'},
        if (next != null) 'nextAiringEpisode': next,
      },
    };

AnilistOtherListSource _source(String format, List<Map<String, dynamic>> entries,
    List<String> queries) {
  return AnilistOtherListSource(
    username: 'someone',
    signedIn: false,
    profiles: _FakeProfile(),
    client: AnilistGraphql(
      sender: (body, {required auth}) async {
        final d = jsonDecode(body) as Map<String, dynamic>;
        queries.add(d['query'] as String);
        return http.Response(
            jsonEncode({
              'data': {
                'MediaListCollection': {
                  'hasNextChunk': false,
                  'user': {
                    'mediaListOptions': {'scoreFormat': format}
                  },
                  'lists': [
                    {'entries': entries}
                  ],
                },
              },
            }),
            200);
      },
      mutationSender: (body, {required auth}) async => throw StateError('read only'),
    ),
  );
}

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  group('other users lists in their score format', () {
    test('asks for that user\'s score format and shows stars', () async {
      final queries = <String>[];
      final source = _source('POINT_5', [_entry(1, 85)], queries);
      final adapter = AnilistReadOnlyListAdapter(source: source);
      final rows = await source.all('anime');
      expect(queries.first, contains('mediaListOptions { scoreFormat }'));
      expect(source.scoreFormatOf('anime'), AnilistScoreFormat.point5);
      final score = adapter.userScore(rows.single)!;
      expect(score.icon, Icons.star_rounded);
      expect(score.text, '4');
    });

    test('POINT_10_DECIMAL keeps the exact value, the percent comes from the mean', () async {
      final source = _source('POINT_10_DECIMAL', [_entry(1, 73)], []);
      final adapter = AnilistReadOnlyListAdapter(source: source);
      final rows = await source.all('anime');
      expect(adapter.userScore(rows.single)!.text, '7.3');
      const rated = ListEntryView(id: 2, category: 'anime', title: 'T', meanScore: 8.2);
      expect(adapter.meanScore(rated)!.text, '82%');
    });

    test('the compare look keeps the format of the list', () async {
      final source = _source('POINT_100', [_entry(1, 73)], []);
      final adapter = AnilistReadOnlyListAdapter(source: source);
      final rows = await source.all('anime');
      final look = AnilistCompareLook(const {}, base: adapter);
      expect(look.userScore(rows.single)!.text, '73');
    });
  });

  group('exact next airing', () {
    final now = DateTime.utc(2026, 10, 29, 12);
    final airing = now.add(const Duration(days: 12));
    final next = {'episode': 7, 'airingAt': airing.millisecondsSinceEpoch ~/ 1000};

    test('the rows carry the next episode and its exact moment', () async {
      final source = _source('POINT_10', [_entry(1, 70, next: next)], []);
      final row = (await source.all('anime')).single;
      expect(row.nextEpisode, 7);
      expect(row.nextAiringAt, airing);
      final shown = anilistNextAiring(row, now)!;
      expect(shown.episode, 7);
      expect(shown.at, airing);
    });

    test('a passed moment falls back to the weekly slot', () async {
      final past = {'episode': 7, 'airingAt': now.millisecondsSinceEpoch ~/ 1000 - 60};
      final source = _source('POINT_10', [_entry(1, 70, next: past)], []);
      final row = (await source.all('anime')).single;
      expect(anilistNextAiring(row, now)!.at.isAfter(now), isTrue);
    });

    test('a finished title shows nothing', () async {
      final source = _source('POINT_10', [_entry(1, 70, status: 'FINISHED')], []);
      expect(anilistNextAiring((await source.all('anime')).single, now), isNull);
    });
  });
}
