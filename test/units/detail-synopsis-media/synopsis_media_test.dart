import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/MAL/content/media_platforms.dart';
import 'package:mywatchlist/widgets/common/translator.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUp(() async {
    Translator.clearCache();
    Translator.translate = (text, {required from, required to}) async => '[$to] $text';
    ScheduleLinks.reset();
    await S.load(const Locale('fr', 'FR'));
  });

  tearDown(() async {
    await S.load(const Locale('en'));
    Intl.defaultLocale = 'en';
  });

  test('targetLanguage maps the app locale', () async {
    Intl.defaultLocale = 'fr_FR';
    expect(Translator.targetLanguage, 'fr');
    Intl.defaultLocale = 'ko_KR';
    expect(Translator.targetLanguage, 'ko');
    Intl.defaultLocale = 'en';
    expect(Translator.needsTranslation(), isFalse);
  });

  testWidgets('button translates then restores the original', (tester) async {
    Intl.defaultLocale = 'fr_FR';
    await pumpInApp(
      tester,
      TranslatorWidget(content: 'Hello', builder: (_, t) => Text(t)),
    );
    expect(find.text('Hello'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    expect(find.text('[fr] Hello'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('autoTranslate translates at once', (tester) async {
    Intl.defaultLocale = 'fr_FR';
    await pumpInApp(
      tester,
      TranslatorWidget(
          content: 'Hello', autoTranslate: true, builder: (_, t) => Text(t)),
    );
    await tester.pumpAndSettle();
    expect(find.text('[fr] Hello'), findsOneWidget);
  });

  testWidgets('a failure keeps the original and reports', (tester) async {
    Intl.defaultLocale = 'fr_FR';
    Translator.translate = (text, {required from, required to}) async =>
        throw Exception('offline');
    Object? reported;
    await pumpInApp(
      tester,
      TranslatorWidget(
        content: 'Hello',
        autoTranslate: true,
        onError: (e) => reported = e,
        builder: (_, t) => Text(t),
      ),
    );
    await tester.pumpAndSettle();
    expect(reported, isNotNull);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('no button when the app is in English', (tester) async {
    Intl.defaultLocale = 'en';
    await pumpInApp(
      tester,
      TranslatorWidget(content: 'Hello', builder: (_, t) => Text(t)),
    );
    expect(find.byIcon(Icons.translate), findsNothing);
  });

  test('RelatedLinks.fromLiveChart reads the known kinds', () {
    final links = RelatedLinks.fromLiveChart({
      'mal': 'https://myanimelist.net/anime/1',
      'anilist': 'https://anilist.co/anime/1',
      'anime-planet': 'https://anime-planet.com/x',
      'twitter': 'https://x.com/a',
    });
    expect(links?.anilist, 'https://anilist.co/anime/1');
    expect(links?.animePlanet, 'https://anime-planet.com/x');
    expect(links?.kitsu, isNull);
    expect(RelatedLinks.fromLiveChart({'twitter': 'x'}), isNull);
  });

  test('ScheduleLinks finds a MAL id once per season', () async {
    var calls = 0;
    ScheduleLinks.source = () async {
      calls++;
      return [
        const LiveChartEpisode(
          timestamp: 1,
          episode: 1,
          malId: 42,
          relatedLinks: {'kitsu': 'https://kitsu.app/anime/42'},
        ),
      ];
    };
    expect((await ScheduleLinks.forMalId(42))?.kitsu, 'https://kitsu.app/anime/42');
    expect(await ScheduleLinks.forMalId(7), isNull);
    expect(calls, 1);
  });
}
