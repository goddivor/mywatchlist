import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_forum.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/MAL/content/scorestatisticswidget.dart';
import 'package:mywatchlist/widgets/MAL/content/show_forum.dart';
import 'package:mywatchlist/widgets/MAL/content/show_reviews.dart';
import 'package:mywatchlist/widgets/MAL/content/userupdate_widget.dart';
import 'package:mywatchlist/widgets/MAL/home/animecharacterwidget.dart';

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

/// Jikan as seen from the owner's network: every request fails.
JikanClient _deadJikan() => JikanClient(
      client: MockClient((_) async => throw http.ClientException('Connection timed out')),
      minInterval: Duration.zero,
    );

JikanClient _jikanAnswering(Map<String, dynamic> body) => JikanClient(
      client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
      minInterval: Duration.zero,
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late JikanClient original;

  setUpAll(() async {
    forbidNetwork();
    dotenv.testLoad(fileInput: 'MAL_CLIENT_ID=cid');
    await S.load(const Locale('en'));
  });

  setUp(() => original = JikanClient.instance);

  tearDown(() {
    JikanClient.instance = original;
    JikanFallbacks.reset();
  });

  group('Score stats', () {
    testWidgets('Jikan down: MAL figures, a note and Retry, no grey bars', (tester) async {
      JikanClient.instance = _deadJikan();
      final mal = MalAnime.fromJson({
        'id': 1,
        'title': 'Shuiro no Kamen',
        'mean': 6.42,
        'num_scoring_users': 1234,
        'rank': 5000,
      });
      await pumpInApp(
        tester,
        SingleChildScrollView(child: ScoreStatisticsWidget(id: 1, category: 'anime', horizPadding: 0, mal: mal)),
      );
      await _settle(tester);
      expect(find.text('6.42'), findsOneWidget);
      expect(find.text(S.current.Res_Mean_Score), findsOneWidget);
      expect(find.text(S.current.Res_Score_Unavailable), findsOneWidget);
      expect(find.text(S.current.Res_Retry), findsOneWidget);
      expect(find.byType(ScoreBars), findsNothing);
    });

    testWidgets('no votes: an empty state instead of bars', (tester) async {
      JikanClient.instance = _jikanAnswering({
        'data': {
          'scores': [
            for (var s = 1; s <= 10; s++) {'score': s, 'votes': 0, 'percentage': 0},
          ],
        },
      });
      await pumpInApp(tester, ScoreStatisticsWidget(id: 2, category: 'anime', horizPadding: 0));
      await _settle(tester);
      expect(find.text(S.current.Res_Score_Empty), findsOneWidget);
      expect(find.byType(ScoreBars), findsNothing);
    });

    testWidgets('with votes: ten bars and the total', (tester) async {
      JikanClient.instance = _jikanAnswering({
        'data': {
          'scores': [
            for (var s = 1; s <= 10; s++) {'score': s, 'votes': s * 10, 'percentage': s * 1.8},
          ],
        },
      });
      await pumpInApp(tester, SizedBox(width: 400, child: ScoreStatisticsWidget(id: 3, category: 'anime', horizPadding: 0)));
      await _settle(tester);
      expect(find.byType(ScoreBars), findsOneWidget);
      expect(find.text(S.current.Res_Score_Total_Votes('550')), findsOneWidget);
    });
  });

  testWidgets('User updates: Jikan down ends in an error with Retry', (tester) async {
    JikanClient.instance = _deadJikan();
    await pumpInApp(tester, UserUpdatesPage(id: 1, category: 'anime', horizPadding: 0));
    await _settle(tester);
    expect(find.text(S.current.Social_Updates_Failed), findsOneWidget);
    expect(find.text(S.current.Res_Retry), findsOneWidget);
  });

  group('Forums', () {
    testWidgets('Jikan down: topics from MyAnimeList', (tester) async {
      JikanClient.instance = _deadJikan();
      JikanFallbacks.forum = (id, category) async => [
            AnimeForum(malId: 5, title: 'Episode 1 discussion', authorUsername: 'mod', comments: 3),
          ];
      await pumpInApp(tester, const ShowAnimeForum(animeId: 1));
      await _settle(tester);
      expect(find.text('Episode 1 discussion'), findsOneWidget);
    });

    testWidgets('every source down: a translated error with Retry', (tester) async {
      JikanClient.instance = _deadJikan();
      JikanFallbacks.forum = (id, category) async => throw StateError('down');
      await pumpInApp(tester, const ShowAnimeForum(animeId: 1));
      await _settle(tester);
      expect(find.text(S.current.Res_Forum_Failed), findsOneWidget);
      expect(find.text(S.current.Res_Retry), findsOneWidget);
    });
  });

  testWidgets('Reviews: Jikan down, reviews from the mwl-api', (tester) async {
    JikanClient.instance = _deadJikan();
    JikanFallbacks.reviews = (id, category, page) async => page == 1
        ? [AnimeReview(malId: 1, review: 'Fallback review text', score: 7, user: User(username: 'bob'))]
        : <AnimeReview>[];
    await pumpInApp(tester, const SizedBox(height: 500, child: SingleChildScrollView(child: ShowAnimeReviews(animeId: 1))));
    await _settle(tester);
    expect(find.text('Fallback review text'), findsOneWidget);
  });

  group('Round avatars', () {
    testWidgets('no shadow, no elevation, a circle clip', (tester) async {
      await pumpInApp(tester, RoundAvatar(url: 'https://cdn.myanimelist.net/images/questionmark_23.gif', onTap: () {}));
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget, reason: "MAL's question mark becomes the themed placeholder");
      for (final box in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.boxShadow, anyOf(isNull, isEmpty));
          expect(decoration.shape, BoxShape.circle);
        }
      }
      for (final material in tester.widgetList<Material>(find.descendant(
        of: find.byType(RoundAvatar),
        matching: find.byType(Material),
      ))) {
        expect(material.elevation, 0);
      }
    });

    testWidgets('staff rows use round avatars', (tester) async {
      final staff = [
        CharacterNode(
          image: 'https://cdn.myanimelist.net/images/questionmark_23.gif',
          name: Link(name: 'Director Name', url: 'https://myanimelist.net/people/1/x'),
          role: 'Director',
        ),
      ];
      await pumpInApp(tester, SizedBox(width: 400, child: AnimeCharacterWidget(staffList: staff, horizPadding: 0)));
      expect(find.text('Director Name'), findsOneWidget);
      expect(find.byType(RoundAvatar), findsOneWidget);
    });
  });
}
