import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_media_page.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/no_network.dart';
import 'fakes.dart';

Map<String, dynamic> _anime({bool trailer = false}) {
  final json = withoutPictures(fixtureJson('media_anime')) as Map<String, dynamic>;
  final data = json['data'] as Map<String, dynamic>;
  final root = data['findAnimeBySlug'] as Map<String, dynamic>;
  if (!trailer) root['youtubeTrailerVideoId'] = null;
  // The saved title has no cast: give it a character, a voice actor and a staff member.
  root['characters'] = {
    'totalCount': 1,
    'pageInfo': {'hasNextPage': false, 'endCursor': null},
    'nodes': [
      {
        'role': 'MAIN',
        'character': {'id': '1', 'slug': 'frieren', 'names': {'canonical': 'Frieren'}},
        'voices': {
          'nodes': [
            {'person': {'id': '9', 'name': 'Atsumi Tanezaki'}}
          ]
        },
      }
    ],
  };
  root['staff'] = {
    'totalCount': 1,
    'pageInfo': {'hasNextPage': false, 'endCursor': null},
    'nodes': [
      {'role': 'Director', 'person': {'id': '5', 'slug': 'keiichiro-saito', 'name': 'Keiichiro Saito'}}
    ],
  };
  root['quotes'] = {
    'nodes': [
      {
        'id': 'q1',
        'lines': {
          'nodes': [
            {'content': 'Magic is about imagination.', 'character': {'names': {'canonical': 'Frieren'}}}
          ]
        },
      }
    ],
  };
  return json;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    forbidNetwork();
    await initializeDateFormatting();
  });

  FakeKitsu site({Map<String, Object?>? graphql, bool ratings = true}) => FakeKitsu(
        graphql: graphql ?? {'findAnimeBySlug': _anime()},
        rest: ratings ? {'/anime/46474': fixtureJson('rating_frequencies')} : const {},
      );

  Future<void> pump(WidgetTester tester, Widget page, {String locale = 'en'}) async {
    SharedPreferences.setMockInitialValues({});
    await LanguageBloc.apply(locale);
    final prefs = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
    addTearDown(prefs.close);
    tester.view.physicalSize = const Size(900, 9000);
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

  KitsuMediaPage anime(FakeKitsu fake) =>
      KitsuMediaPage(kind: KitsuMediaKind.anime, slug: 'sousou-no-frieren', title: 'Frieren', service: fake.service());

  testWidgets('shows the header, every section Kitsu has data for, and no other tracker', (tester) async {
    final fake = site();
    await pump(tester, anime(fake));

    expect(find.text('Sousou no Frieren'), findsWidgets);
    expect(find.text('#2 Highest rated'), findsOneWidget);
    expect(find.text('89%'), findsOneWidget);
    expect(find.text('#788 Most popular'), findsOneWidget);
    expect(find.text('21,409 users'), findsOneWidget);
    expect(find.text('TV (28 eps)'), findsOneWidget);
    expect(find.text('Finished'), findsWidgets);
    expect(find.text('Synopsis'), findsOneWidget);
    expect(find.text('Fantasy'), findsOneWidget);
    expect(find.text('Ratings'), findsOneWidget);
    expect(find.textContaining(' ratings'), findsOneWidget);
    expect(find.text('Where to watch'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Subs en · Dubs ja · US'), findsNWidgets(2));
    expect(find.text('Trailer'), findsNothing, reason: 'no trailer id on this record');
    expect(find.text('Episodes'), findsWidgets);
    expect(find.text('Episode 1'), findsOneWidget);
    expect(find.text("The Journey's End"), findsOneWidget);
    expect(find.text('Franchise'), findsOneWidget);
    expect(find.text('Sequel'), findsOneWidget);
    expect(find.text('Reactions'), findsOneWidget);
    expect(find.text('Tamaya'), findsOneWidget);
    expect(find.text('At episode 2'), findsWidgets);
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Characters'), findsOneWidget);
    expect(find.text('Frieren'), findsWidgets);
    expect(find.text('Main'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Director'), findsOneWidget);
    expect(find.text('Quotes'), findsOneWidget);
    expect(find.text('Information'), findsOneWidget);
    expect(find.text('Producers'), findsOneWidget);
    expect(find.text('TOHO animation, Shogakukan'), findsOneWidget);
    expect(find.text('Also on'), findsOneWidget);
    expect(find.text('MyAnimeList'), findsOneWidget);
    expect(find.text('AniList'), findsOneWidget);
    expect(fake.requests.every((r) => r.url.host == 'kitsu.io'), isTrue);
    expect(fake.requests.every((r) => !r.headers.containsKey('Authorization')), isTrue);
  });

  testWidgets('without a rating histogram the page stays whole', (tester) async {
    await pump(tester, anime(site(ratings: false)));
    expect(find.text('Ratings'), findsNothing);
    expect(find.text('Synopsis'), findsOneWidget);
    expect(find.text('Episodes'), findsWidgets);
  });

  testWidgets('a related title opens its own Kitsu page, by id', (tester) async {
    final next = _anime();
    final root = (next['data'] as Map)['findAnimeBySlug'] as Map<String, dynamic>;
    root['id'] = '49240';
    root['slug'] = 'sousou-no-frieren-season-2';
    root['titles'] = {'canonical': 'Sousou no Frieren 2nd Season'};
    final fake = site(graphql: {
      'findAnimeBySlug': _anime(),
      'findAnimeById': {'data': {'findAnimeById': root}},
    });
    await pump(tester, anime(fake));
    await tester.tap(find.text('Sousou no Frieren 2nd Season'));
    await tester.pumpAndSettle();
    expect(find.byType(KitsuMediaPage, skipOffstage: false), findsNWidgets(2));
    expect(find.text('Sousou no Frieren 2nd Season'), findsWidgets);
    expect(fake.requests.any((r) => r.body.contains('"key":"49240"')), isTrue);
  });

  testWidgets('a streaming link and an external id open in the browser', (tester) async {
    final opened = <Uri>[];
    final before = WebLauncher.opener;
    WebLauncher.opener = (uri, {barColor, onBarColor, external = false}) async {
      opened.add(uri);
      return true;
    };
    addTearDown(() => WebLauncher.opener = before);
    await pump(tester, anime(site()));
    await tester.tap(find.text('Netflix'));
    await tester.pump();
    await tester.tap(find.text('AniList'));
    await tester.pump();
    expect(opened.map((u) => u.toString()), [
      'https://www.netflix.com/title/81726714',
      'https://anilist.co/anime/154587',
    ]);
  });

  testWidgets('a manga shows chapters and no episodes', (tester) async {
    final json = withoutPictures(fixtureJson('media_manga'));
    final fake = site(graphql: {'findMangaBySlug': json}, ratings: false);
    await pump(tester, KitsuMediaPage(kind: KitsuMediaKind.manga, slug: 'sousou-no-frieren', service: fake.service()));
    expect(find.text('Chapters'), findsWidgets);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Episodes'), findsNothing);
    expect(find.text('Published'), findsWidgets);
    expect(find.text('Publishing'), findsWidgets);
  });

  testWidgets('the episode list opens filled and pages on', (tester) async {
    final fake = site(graphql: {
      'findAnimeBySlug': _anime(),
      'findAnimeById': fixtureJson('media_episodes'),
    });
    await pump(tester, anime(fake));
    await tester.tap(find.byTooltip('View all').first);
    // The list keeps a spinner while more pages exist: it never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Episode 1'), findsOneWidget);
    expect(fake.requests.any((r) => r.body.contains('"after":"MTI"')), isTrue,
        reason: 'the list asks for the page after the 12 the title page holds');
  });

  testWidgets('an unknown title ends in a message', (tester) async {
    final fake = site(graphql: {'findAnimeBySlug': {'data': {'findAnimeBySlug': null}}});
    await pump(tester, anime(fake));
    expect(find.text('Kitsu doesn’t know this title'), findsOneWidget);
  });

  testWidgets('an unreachable Kitsu ends in an error with Retry', (tester) async {
    await pump(tester, anime(FakeKitsu(failAll: true)));
    expect(find.text('Couldn’t load this title from Kitsu'), findsOneWidget);
    expect(find.text(S.current.Res_Retry), findsOneWidget);
  });

  testWidgets('French: sections and values are translated', (tester) async {
    await pump(tester, anime(site()), locale: 'fr_FR');
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Où regarder'), findsOneWidget);
    expect(find.text('Épisode 1'), findsOneWidget);
    expect(find.text('Suite'), findsOneWidget);
    expect(find.text('Franchise'), findsOneWidget);
    expect(find.text('Réactions'), findsOneWidget);
    expect(find.text('Personnages'), findsOneWidget);
    expect(find.text('Informations'), findsOneWidget);
    expect(find.text('Producteurs'), findsOneWidget);
    expect(find.text('Terminé'), findsWidgets);
    expect(find.text('Ratings'), findsNothing);
    expect(find.text('Sequel'), findsNothing);
  });
}
