import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mwl_commons/mwl_commons.dart'
    show ContentCharacterHtml, ContentCharactersHtml, VoiceActorHtml;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/characters_staff_screen.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_statistics.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/MAL/content/adaptation_widget.dart';
import 'package:mywatchlist/widgets/MAL/content/scorestatisticswidget.dart';
import 'package:mywatchlist/widgets/MAL/home/animecharacterwidget.dart';

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

AdaptNode _node(String title, String relation, String url) =>
    AdaptNode(image: '', relation: relation, animeTitle: Link(name: title, url: url));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    forbidNetwork();
    dotenv.testLoad(fileInput: 'MAL_CLIENT_ID=cid');
    await S.load(const Locale('en'));
  });

  group('Score stats (U12)', () {
    testWidgets('bars from MyAnimeList print no source caption', (tester) async {
      await pumpInApp(
        tester,
        SizedBox(
          width: 400,
          child: ScoreBars(
            scores: [for (var s = 1; s <= 10; s++) ScoreStatistics(score: s, votes: 10)],
            horizPadding: 0,
            fromMyAnimeList: true,
          ),
        ),
      );
      expect(find.text(S.current.Res_Source_Mal), findsNothing);
      expect(find.text(S.current.Res_Score_Total_Votes('100')), findsOneWidget);
    });
  });

  group('Adaptations (U14, DailyAL tile)', () {
    test('media type comes from the relation, else from the entry kind', () {
      expect(
          adaptationKindLabel(
              _node('A', 'Adaptation (Light Novel)', 'https://myanimelist.net/manga/1/A')),
          S.current.UserList_Media_Light_Novel);
      expect(
          adaptationKindLabel(
              _node('B', 'Adaptation (One-shot)', 'https://myanimelist.net/manga/2/B')),
          S.current.UserList_Media_One_Shot);
      expect(adaptationKindLabel(_node('C', 'Adaptation', 'https://myanimelist.net/manga/3/C')),
          S.current.UserList_Media_Manga);
      expect(adaptationKindLabel(_node('D', 'Adaptation', 'https://myanimelist.net/anime/4/D')),
          S.current.Anime_Caps);
      expect(adaptationId('https://myanimelist.net/manga/123/Name'), 123);
      expect(adaptationCategory('https://myanimelist.net/manga/123/Name'), 'manga');
    });

    testWidgets('280 x 130 cards: cover, relation badge, title, media type and chevron', (tester) async {
      await pumpInApp(
        tester,
        SizedBox(
          width: 400,
          child: AdaptationsWidget(nodes: [
            _node('Sousou no Frieren', 'Adaptation (Manga)',
                'https://myanimelist.net/manga/126287/Sousou_no_Frieren'),
          ]),
        ),
      );
      await tester.pump();
      expect(find.text('Sousou no Frieren'), findsOneWidget);
      expect(find.text(S.current.UserList_Media_Manga), findsOneWidget);
      expect(find.text('Adaptation'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(tester.getSize(find.byType(AdaptationTile)), const Size(280, 130));
    });
  });

  group('Characters & staff page', () {
    late JikanClient original;
    setUp(() => original = JikanClient.instance);
    tearDown(() {
      JikanClient.instance = original;
      JikanFallbacks.reset();
    });

    testWidgets('every character portrait is 60 x 80, one or several voice actors', (tester) async {
      JikanClient.instance = JikanClient(
        client: MockClient((_) async => throw http.ClientException('down')),
        minInterval: Duration.zero,
      );
      JikanFallbacks.characters = (id, category) async => const ContentCharactersHtml(characters: [
            ContentCharacterHtml(
              id: 1,
              name: 'Frieren',
              role: 'Main',
              favorites: 10,
              voiceActors: [VoiceActorHtml(id: 11, name: 'Tanezaki, Atsumi', language: 'Japanese')],
            ),
            ContentCharacterHtml(
              id: 2,
              name: 'Flamme',
              role: 'Supporting',
              favorites: 5,
              voiceActors: [
                VoiceActorHtml(id: 21, name: 'Tanaka, Atsuko', language: 'Japanese'),
                VoiceActorHtml(id: 22, name: 'Someone', language: 'English'),
              ],
            ),
          ]);
      await tester
          .pumpWidget(const MaterialApp(home: CharactersStaffScreen(id: 1, category: 'anime')));
      await _settle(tester);

      Finder portrait(String name) =>
          find.byWidgetPredicate((w) => w is CastPicture && w.semanticLabel == name);
      expect(tester.getSize(portrait('Frieren')), const Size(60, 80));
      expect(tester.getSize(portrait('Flamme')), const Size(60, 80));
      // Same column: both names start at the same x.
      expect(tester.getTopLeft(find.text('Frieren')).dx, tester.getTopLeft(find.text('Flamme')).dx);

      // Several voice actors: hidden until the row is tapped.
      expect(find.text('Someone'), findsNothing);
      await tester.tap(find.text(S.current.Res_Voice_Actors_Count(2)));
      await _settle(tester);
      expect(find.text('Someone'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
