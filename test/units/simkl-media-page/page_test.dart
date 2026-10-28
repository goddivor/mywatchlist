import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Simkl/simkl_media_page.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/no_network.dart';
import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const base = 'https://simkl.com/anime/831411/kimetsu-no-yaiba';

  FakeSimklSite site({bool pages = true}) => FakeSimklSite(
        api: {
          '/anime/831411': () => withoutPictures(jsonDecode(fixture('simkl_anime_831411.json'))),
          '/anime/episodes/831411': () => withoutPictures(jsonDecode(fixture('simkl_episodes_831411.json'))),
          '/anime/77': () => <Object>[],
        },
        pages: pages
            ? {
                // Frieren's saved pages stand in for this title's.
                base: () => withoutImages(fixture('simkl_title_frieren.html')),
                '$base/comments/': () => withoutImages(fixture('simkl_comments_frieren.html')),
                '$base/memos/': () => withoutImages(fixture('simkl_memos_frieren.html')),
                '$base/reviews/': () => withoutImages(fixture('simkl_reviews_frieren.html')),
              }
            : const {},
      );

  setUpAll(() async {
    forbidNetwork();
    await initializeDateFormatting();
  });

  Future<void> pump(WidgetTester tester, Widget page, {String locale = 'en'}) async {
    SharedPreferences.setMockInitialValues({});
    await LanguageBloc.apply(locale);
    final prefs = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
    addTearDown(prefs.close);
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final parts = locale.split('_');
    await tester.pumpWidget(BlocProvider.value(
      value: prefs,
      child: MaterialApp(
        locale: Locale(parts.first, parts.length > 1 ? parts[1] : null),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: page,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the record, the scraped sections and the episodes', (tester) async {
    final s = site();
    await pump(tester, SimklMediaPage(simklId: 831411, title: 'Kimetsu', service: s.service()));

    expect(find.text('Kimetsu no Yaiba'), findsWidgets);
    expect(find.text('#14'), findsOneWidget);
    expect(find.text('8.7'), findsOneWidget);
    expect(find.text('Synopsis'), findsOneWidget);
    expect(find.text('Watchers'), findsOneWidget);
    expect(find.text('21,255 · 61.7%'), findsOneWidget);
    expect(find.text('245 reactions'), findsOneWidget);
    expect(find.text('6 reviews'), findsOneWidget);
    expect(find.text('Episodes'), findsOneWidget);
    expect(find.text('Episode 1'), findsOneWidget);
    expect(find.text('Cruelty'), findsOneWidget);
    expect(find.text('Related'), findsOneWidget);
    expect(find.text('Sequel'), findsOneWidget);
    expect(find.text('Recommendations'), findsOneWidget);
    expect(find.text('24% · 75 ♥'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('CapnBlaze'), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('RecycledDoom'), findsOneWidget);
    expect(find.text('Memos'), findsOneWidget);
    expect(find.text('Licensors'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Links'), findsOneWidget);
    expect(find.text('Trailers'), findsNothing, reason: 'trailers were removed from this record');
    expect(s.pageCalls.map((u) => u.toString()).toSet(), {base, '$base/comments/', '$base/memos/'});
    expect(s.apiCalls.every((u) => u.host == 'api.simkl.com'), isTrue);
  });

  testWidgets('a blocked simkl.com hides every scraped section, the record stays', (tester) async {
    await pump(tester, SimklMediaPage(simklId: 831411, service: site(pages: false).service()));
    expect(find.text('Kimetsu no Yaiba'), findsWidgets);
    expect(find.text('Synopsis'), findsOneWidget);
    expect(find.text('Episodes'), findsOneWidget);
    expect(find.text('Watchers'), findsNothing);
    expect(find.text('Reviews'), findsNothing);
    expect(find.text('Comments'), findsNothing);
    expect(find.text('Tags'), findsNothing);
  });

  testWidgets('unknown title and unreachable API end in a message', (tester) async {
    await pump(tester, SimklMediaPage(simklId: 77, service: site().service()));
    expect(find.text('Simkl has no title with this id'), findsOneWidget);

    await pump(tester, SimklMediaPage(simklId: 5, service: site().service()));
    expect(find.text("Couldn't load this title from Simkl"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('French: sections and numbers are translated', (tester) async {
    await pump(tester, SimklMediaPage(simklId: 831411, service: site().service()), locale: 'fr_FR');
    expect(find.text('Spectateurs'), findsOneWidget);
    expect(find.text('Épisode 1'), findsOneWidget);
    expect(find.text('Suite'), findsOneWidget);
    expect(find.text('Critiques'), findsOneWidget);
    expect(find.text('Commentaires'), findsOneWidget);
    expect(find.text('Licences'), findsOneWidget);
    expect(find.text('245 réactions'), findsOneWidget);
    expect(find.text('Watchers'), findsNothing);
    expect(find.text('Sequel'), findsNothing);
  });
}
