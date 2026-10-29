import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_media_page.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media_detail.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_media_row.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_rows.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_cards.dart' show KitsuWatchedTick;
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/no_network.dart';
import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    forbidNetwork();
    await initializeDateFormatting();
  });

  Future<void> pump(WidgetTester tester, Widget page, {String locale = 'en', bool settle = true}) async {
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
    if (settle) await tester.pumpAndSettle();
  }

  /// A signed-in Kitsu with Frieren at episode 5 of 28, rated 15/20; "writes" are recorded only.
  FakeKitsu site({Map<String, dynamic>? entry}) {
    late FakeKitsu fake;
    fake = FakeKitsu(graphql: {
      'MediaDetail': (_) => animeFixture(),
      'MyEntry': (_) => {
            'data': {
              'findAnimeById': {'id': '46474', 'myLibraryEntry': entry}
            }
          },
      'mutation Update': (r) {
        final input = fake.inputs('mutation Update').last;
        return {
          'data': {
            'libraryEntry': {
              'update': {
                'errors': [],
                'libraryEntry': entryJson(
                  progress: input['progress'] as int? ?? 5,
                  status: input['status'] as String? ?? 'CURRENT',
                  rating: 15,
                ),
              }
            }
          }
        };
      },
      'mutation Add': (_) => {
            'data': {
              'libraryEntry': {
                'create': {'errors': [], 'libraryEntry': entryJson(status: 'PLANNED', progress: 0)}
              }
            }
          },
    }, rest: {
      '/users': (_) => userDoc(),
      '/favorites': (_) => {'data': []},
    });
    return fake;
  }

  KitsuMediaPage page(FakeKitsu fake, {bool signedIn = true}) => KitsuMediaPage(
        kind: KitsuMediaKind.anime,
        slug: 'sousou-no-frieren',
        service: fake.detail(),
        library: fake.my,
        signedIn: signedIn,
      );

  group('title page, signed in', () {
    testWidgets('shows the library box in Kitsu words with the account rating and +1', (tester) async {
      final fake = site(entry: entryJson(rating: 15, reaction: 'Peak fiction'));
      await pump(tester, page(fake));
      expect(find.text('Currently watching'), findsOneWidget);
      expect(find.text('Ep 5 / 28'), findsOneWidget);
      expect(find.text('7.5'), findsOneWidget, reason: 'Advanced while the account system is unknown');
      expect(find.text('Peak fiction'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.byTooltip('Add to favourites'), findsOneWidget);
      expect(find.byType(KitsuWatchedTick), findsNWidgets(5), reason: 'episodes 1 to 5 of the strip');
      expect(fake.inputs('mutation'), isEmpty, reason: 'nothing is written without a tap');
    });

    testWidgets('+1 writes the next episode and moves the ticks', (tester) async {
      final fake = site(entry: entryJson());
      await pump(tester, page(fake));
      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();
      expect(fake.inputs('mutation Update').single, {'id': '900', 'progress': 6});
      expect(find.text('Ep 6 / 28'), findsOneWidget);
      expect(find.byType(KitsuWatchedTick), findsNWidgets(6));
    });

    testWidgets('a title outside the library offers Add with the five statuses', (tester) async {
      final fake = site(entry: null);
      await pump(tester, page(fake));
      await tester.tap(find.text('Add to library'));
      await tester.pumpAndSettle();
      expect(find.text('Want to watch'), findsOneWidget);
      expect(find.text('On hold'), findsOneWidget);
      await tester.tap(find.text('Want to watch'));
      await tester.pumpAndSettle();
      expect(fake.inputs('mutation Add').single['status'], 'PLANNED');
      expect(find.text('Want to watch'), findsOneWidget, reason: 'the box now shows the new status');
    });

    testWidgets('an episode opens its sheet with the discussion and "watched up to here"', (tester) async {
      final fake = site(entry: entryJson(progress: 1));
      await pump(tester, page(fake));
      await tester.tap(find.text('Episode 3'));
      await tester.pumpAndSettle();
      expect(find.text('Discussion'), findsOneWidget);
      await tester.tap(find.text('Watched up to here'));
      await tester.pumpAndSettle();
      expect(fake.inputs('mutation Update').single, {'id': '900', 'progress': 3});
    });

    testWidgets('signed out: no box, no heart, no token sent', (tester) async {
      final fake = site(entry: entryJson());
      await pump(tester, page(fake, signedIn: false));
      expect(find.text('Add to library'), findsNothing);
      expect(find.text('+1'), findsNothing);
      expect(find.byTooltip('Add to favourites'), findsNothing);
      expect(fake.requests.every((r) => !r.headers.containsKey('Authorization')), isTrue);
    });

    testWidgets('French: the box is translated', (tester) async {
      final fake = site(entry: entryJson());
      await pump(tester, page(fake), locale: 'fr_FR');
      expect(find.text('Ép. 5 / 28'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
    });
  });

  group('home', () {
    Map<String, dynamic> quick({int progress = 5, int total = 28}) => {
          'data': {
            'currentProfile': {
              'library': {
                'current': {
                  'nodes': [
                    entryJson(progress: progress, nextNumber: progress + 1, media: {
                      '__typename': 'Anime',
                      'id': '46474',
                      'slug': 'sousou-no-frieren',
                      'titles': {'canonical': 'Sousou no Frieren'},
                      'episodeCount': total,
                    }),
                  ]
                }
              }
            }
          }
        };

    testWidgets('Quick update marks the next episode on tap only', (tester) async {
      final fake = FakeKitsu(graphql: {
        'QuickUpdate': (_) => quick(),
        'mutation Update': (_) => {
              'data': {
                'libraryEntry': {
                  'update': {'errors': [], 'libraryEntry': entryJson(progress: 6, nextNumber: 7)}
                }
              }
            },
      });
      await pump(tester, Scaffold(body: KitsuQuickUpdateRow(service: fake.my)));
      expect(find.text('Continue watching'), findsOneWidget);
      expect(find.text('Sousou no Frieren'), findsOneWidget);
      expect(find.text('Episode 6'), findsOneWidget);
      expect(fake.inputs('mutation'), isEmpty);
      await tester.tap(find.text('Episode 6'));
      await tester.pumpAndSettle();
      expect(fake.inputs('mutation Update').single, {'id': '900', 'progress': 6});
      expect(find.text('Episode 7'), findsOneWidget);
    });

    testWidgets('the last episode completes and asks for the rating', (tester) async {
      final fake = FakeKitsu(graphql: {
        'QuickUpdate': (_) => quick(progress: 27),
        'mutation Update': (_) => {
              'data': {
                'libraryEntry': {
                  'update': {'errors': [], 'libraryEntry': entryJson(progress: 28, status: 'COMPLETED')}
                }
              }
            },
      });
      await pump(tester, Scaffold(body: KitsuQuickUpdateRow(service: fake.my)));
      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();
      expect(fake.inputs('mutation Update').single, {'id': '900', 'progress': 28, 'status': 'COMPLETED'});
      expect(find.text('Completed! Rate it'), findsOneWidget);
    });

    testWidgets('Quick update draws nothing when the library cannot be read', (tester) async {
      final fake = FakeKitsu(graphql: {'QuickUpdate': (_) => null});
      await pump(tester, Scaffold(body: KitsuQuickUpdateRow(service: fake.my)));
      expect(find.text('Continue watching'), findsNothing);
    });

    testWidgets('the latest reactions row opens nothing by itself and shows the votes', (tester) async {
      HomeSectionCache.clear();
      final reactions = FakeKitsu(rest: {
        '/media-reactions': (_) => {
              'data': [
                {
                  'id': 'r1',
                  'type': 'mediaReactions',
                  'attributes': {'reaction': 'Peak fiction', 'upVotesCount': 12},
                  'relationships': {
                    'user': {
                      'data': {'type': 'users', 'id': 'u1'}
                    },
                    'anime': {
                      'data': {'type': 'anime', 'id': '1'}
                    },
                  },
                }
              ],
              'included': [
                {'id': 'u1', 'type': 'users', 'attributes': {'name': 'Tamaya'}},
                {'id': '1', 'type': 'anime', 'attributes': {'canonicalTitle': 'Frieren'}},
              ],
            },
      });
      await pump(tester,
          Scaffold(body: KitsuReactionsRow(title: 'Latest reactions', load: () => reactions.catalog.recentReactions())));
      expect(find.text('Peak fiction'), findsOneWidget);
      expect(find.text('Tamaya'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('home tiles show Kitsu\'s percentage, never a score out of 10', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: SizedBox(
            height: 400,
            child: KitsuMediaRow.cards(
              items: const [KitsuMedia(id: 1, isAnime: true, title: 'Frieren', meanScore: 8.9)],
              cardWidth: 120,
            ),
          ),
        ),
      );
      expect(find.text('89%'), findsOneWidget);
      expect(find.text('8.9'), findsNothing);
    });
  });

  testWidgets('a profile title opens the native Kitsu page', (tester) async {
    final detail = KitsuMediaDetailService.instance;
    addTearDown(() => KitsuMediaDetailService.instance = detail);
    final fake = FakeKitsu(graphql: {'MediaDetail': (_) => animeFixture()});
    KitsuMediaDetailService.instance = fake.detail();
    await pump(
      tester,
      const Scaffold(
        body: KitsuMediaLine(
          media: KitsuMediaRef(
              kind: KitsuMediaKind.anime, id: '46474', slug: 'sousou-no-frieren', titles: KitsuTitles(canonical: 'Frieren')),
        ),
      ),
    );
    await tester.tap(find.text('Frieren'));
    await tester.pumpAndSettle();
    expect(find.byType(KitsuMediaPage), findsOneWidget);
  });
}
