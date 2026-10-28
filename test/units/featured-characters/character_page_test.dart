import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/character_page.dart';

import '../../helpers/no_network.dart';

/// Real MyAnimeList pages saved with a desktop user agent (read-only curl).
String _fixture(String name) =>
    File('test/units/featured-characters/fixtures/$name').readAsStringSync();

Map<String, dynamic> _first(Object? list) =>
    ((list as List).first as Map).cast<String, dynamic>();

String? _image(Object? node) =>
    (((node as Map)['images'] as Map)['jpg'] as Map)['image_url'] as String?;

/// Jikan as seen from the owner's network: every request fails.
JikanClient _deadJikan() => JikanClient(
      client: MockClient(
          (_) async => throw http.ClientException('Connection timed out')),
      minInterval: Duration.zero,
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('MAL character page parser', () {
    late Map<String, dynamic> data;

    setUpAll(() => data = parseMalCharacterPage(_fixture('character_417.html')));

    test('reads the profile header', () {
      expect(data['name'], 'Lelouch Lamperouge');
      expect(data['name_kanji'], 'ルルーシュ・ランペルージ');
      expect(data['favorites'], 181705);
      expect(_image(data),
          'https://cdn.myanimelist.net/images/characters/8/406163.jpg');
    });

    test('reads the about text with its line breaks, without the ads', () {
      final about = data['about'] as String;
      expect(about, startsWith('Age: 17 (first season), 18 (second season)\n'));
      expect(about, contains('\nBlood Type: A\n'));
      expect(about, endsWith('Anime and Manga Universe Wiki)'));
      expect(about, isNot(contains('Voice Actors')));
      expect(about, isNot(contains('<')));
    });

    test('reads the animeography and the mangaography at full size', () {
      final anime = _first(data['anime']);
      expect(anime['role'], 'Main');
      expect(anime['anime']['mal_id'], 1575);
      expect(anime['anime']['title'], 'Code Geass: Hangyaku no Lelouch');
      expect(_image(anime['anime']),
          'https://cdn.myanimelist.net/images/anime/1032/135088.jpg');
      final manga = _first(data['manga']);
      expect(manga['manga']['mal_id'], 1528);
      expect(manga['role'], 'Main');
      expect((data['anime'] as List).length, greaterThan(10));
    });

    test('reads every voice actor with the language', () {
      final voices = data['voices'] as List;
      expect(voices.length, greaterThan(10));
      final first = _first(voices);
      expect(first['language'], 'English');
      expect(first['person']['mal_id'], 10);
      expect(first['person']['name'], 'Bosch, Johnny Yong');
      expect(
          voices.any((v) => (v as Map)['language'] == 'Japanese'), isTrue);
    });
  });

  group('MAL person page parser', () {
    late Map<String, dynamic> data;

    setUpAll(() => data = parseMalPersonPage(_fixture('people_118.html')));

    test('reads the profile header and the biography', () {
      expect(data['name'], 'Hiroshi Kamiya');
      expect(data['given_name'], '浩史');
      expect(data['family_name'], '神谷');
      expect(data['favorites'], 108693);
      expect(_image(data),
          'https://cdn.myanimelist.net/images/voiceactors/1/66163.jpg');
      expect(data['about'],
          startsWith('Birthplace: Matsudo, Chiba Prefecture, Japan\n'));
    });

    test('reads the voice roles with the character favorites', () {
      final voices = data['voices'] as List;
      expect(voices.length, 513);
      final first = _first(voices);
      expect(first['role'], 'Main');
      expect(first['favorites'], 0);
      expect(first['character']['mal_id'], 284634);
      expect(first['character']['name'], 'Dao, Ran');
      expect(first['anime']['mal_id'], 62951);
      expect(_image(first['character']),
          'https://cdn.myanimelist.net/images/characters/6/625953.jpg');
      expect((voices[1] as Map)['favorites'], 59);
    });

    test('reads the staff positions; no published manga', () {
      final anime = data['anime'] as List;
      expect(anime.length, 33);
      expect(_first(anime)['position'], 'Theme Song Performance');
      expect(_first(anime)['anime']['mal_id'], 59406);
      expect(data['manga'], isEmpty);
    });

    test('reads the published manga of a mangaka', () {
      final miura = parseMalPersonPage(_fixture('people_1868.html'));
      final manga = _first(miura['manga']);
      expect(manga['manga']['mal_id'], 2);
      expect(manga['manga']['title'], 'Berserk');
      expect(manga['position'], 'Story & Art');
    });

    test('a page without a profile is refused', () async {
      MalCharacterPage.parseInline = true;
      MalCharacterPage.fetch = (_) async => '<html><body>Not found</body></html>';
      addTearDown(MalCharacterPage.reset);
      await expectLater(MalCharacterPage.load(1, isCharacter: true),
          throwsA(isA<FormatException>()));
    });

    test('asks for the desktop page', () {
      expect(MalCharacterPage.headers['User-Agent'], isNot(contains('Android')));
      expect(MalCharacterPage.url(118, isCharacter: false).toString(),
          'https://myanimelist.net/people/118');
    });
  });

  group('Character screen with Jikan unreachable', () {
    late JikanClient original;
    final asked = <Uri>[];

    setUpAll(() async {
      forbidNetwork();
      dotenv.testLoad(fileInput: 'MAL_CLIENT_ID=cid');
      await S.load(const Locale('en'));
    });

    setUp(() {
      original = JikanClient.instance;
      JikanClient.instance = _deadJikan();
      asked.clear();
      MalCharacterPage.parseInline = true;
      MalCharacterPage.fetch = (url) async {
        asked.add(url);
        return _fixture(url.path.startsWith('/character/')
            ? 'character_417.html'
            : 'people_118.html');
      };
    });

    tearDown(() {
      JikanClient.instance = original;
      JikanFallbacks.reset();
      MalCharacterPage.reset();
    });

    testWidgets('a character loads from MyAnimeList\'s page', (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: CharacterScreen(id: 417)));
      await _settle(tester);
      expect(asked.single.toString(), 'https://myanimelist.net/character/417');
      expect(find.text(S.current.Fch_Load_Failed), findsNothing);
      expect(find.text('Lelouch Lamperouge'), findsWidgets);
      await tester.tap(find.text(S.current.Fch_Details));
      await _settle(tester);
      expect(find.textContaining(S.current.Fch_Animeography, findRichText: true), findsOneWidget);
    });

    testWidgets('a person loads from MyAnimeList\'s page', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: CharacterScreen(id: 118, category: 'person')));
      await _settle(tester);
      expect(asked.single.toString(), 'https://myanimelist.net/people/118');
      expect(find.text('Hiroshi Kamiya'), findsWidgets);
      await tester.tap(find.text(S.current.Fch_Details));
      await _settle(tester);
      expect(find.textContaining(S.current.Fch_Voice_Roles, findRichText: true), findsOneWidget);
    });

    testWidgets('both sources down: the error and Retry', (tester) async {
      MalCharacterPage.fetch = (url) async => throw http.ClientException('down');
      await tester.pumpWidget(
          const MaterialApp(home: CharacterScreen(id: 417)));
      await _settle(tester);
      expect(find.text(S.current.Fch_Load_Failed), findsOneWidget);
    });
  });
}
