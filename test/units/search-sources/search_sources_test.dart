import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:mwl_commons/mwl_commons.dart' hide Constants, ContentType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/search/search_service.dart';
import 'package:mywatchlist/screens/search/search_sources.dart';
import 'package:mywatchlist/screens/studios/studios_pager.dart';
import 'package:mywatchlist/screens/studios/studios_screen.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';

import '../../helpers/no_network.dart';

String _fixture(String name) => File('test/units/search-sources/fixtures/$name').readAsStringSync();

MalSearchPageHtml _page(String name, String category) =>
    SearchParsers.parseSearchPage(html.parse(_fixture(name)), category);

CompanyPageHtml _companies(String name) => SearchParsers.parseCompanies(html.parse(_fixture(name)));

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  group('MalSearchQuery: app filters to MAL search page URLs', () {
    test('studio Arch is anime.php?p=1966 with every column', () {
      final url = MalSearchQuery.url(category: 'anime', filters: {'producer': 1966});
      expect(url.host, 'myanimelist.net');
      expect(url.path, '/anime.php');
      expect(url.queryParametersAll['p'], ['1966']);
      expect(url.queryParametersAll['cat'], ['anime']);
      expect(url.queryParametersAll['c[]'], ['a', 'b', 'c', 'd', 'e', 'f', 'g']);
      expect(url.queryParameters.containsKey('show'), isFalse);
    });

    test('every anime filter maps to its MAL parameter', () {
      final url = MalSearchQuery.url(
        category: 'anime',
        query: ' gundam ',
        filters: {
          'type': 'movie',
          'status': 'complete',
          'rating': 'r17',
          'score': 7,
          'letter': 'g',
          'start_date': '2001-04-07',
          'end_date': '2010-12',
          'genres_in': [1, 2],
          'genres_out': '4,22',
          'order_by': 'score',
          'sort': 'asc',
          'magazines': 83, // not an anime filter: ignored
        },
        page: 3,
      );
      final p = url.queryParametersAll;
      expect(p['q'], ['gundam']);
      expect(p['type'], ['3']);
      expect(p['status'], ['2']);
      expect(p['r'], ['4']);
      expect(p['score'], ['7']);
      expect(p['letter'], ['G']);
      expect([p['sy'], p['sm'], p['sd']], [['2001'], ['4'], ['7']]);
      expect([p['ey'], p['em'], p['ed']], [['2010'], ['12'], null]);
      expect(p['genre[]'], ['1', '2']);
      expect(p['genre_ex[]'], ['4', '22']);
      expect(p['o'], ['3']);
      expect(p['w'], ['2']);
      expect(p['show'], ['100']);
      expect(p.containsKey('mid'), isFalse);
    });

    test('rank and popularity invert the direction (1 is the best)', () {
      Map<String, List<String>> q(String order, String sort) =>
          MalSearchQuery.url(category: 'anime', filters: {'order_by': order, 'sort': sort}).queryParametersAll;
      expect(q('rank', 'asc')['o'], ['3']);
      expect(q('rank', 'asc')['w'], ['1']);
      expect(q('popularity', 'asc')['o'], ['7']);
      expect(q('popularity', 'asc')['w'], ['1']);
      expect(q('members', 'desc')['w'], ['1']);
    });

    test('manga uses manga.php, mid and its own codes', () {
      final p = MalSearchQuery.url(category: 'manga', filters: {
        'magazines': 83,
        'type': 'lightnovel',
        'status': 'hiatus',
        'producer': 1966, // anime only: ignored
        'rating': 'g', // anime only: ignored
        'order_by': 'chapters',
      }).queryParametersAll;
      expect(MalSearchQuery.url(category: 'manga').path, '/manga.php');
      expect(p['mid'], ['83']);
      expect(p['type'], ['2']);
      expect(p['status'], ['4']);
      expect(p['o'], ['6']);
      expect(p['w'], ['1']);
      expect(p.containsKey('p'), isFalse);
      expect(p.containsKey('r'), isFalse);
    });

    test('characters and people have their own pages', () {
      expect(MalSearchQuery.url(category: 'character', query: 'luffy').path, '/character.php');
      final people = MalSearchQuery.url(category: 'person', query: 'kana', page: 2);
      expect(people.path, '/people.php');
      expect(people.queryParameters['show'], '50');
    });

    test('one or two characters are too short for MAL', () {
      expect(MalSearchQuery.isTooShort('na'), isTrue);
      expect(MalSearchQuery.isTooShort(''), isFalse);
      expect(MalSearchQuery.isTooShort('nar'), isFalse);
    });
  });

  group('MAL search pages (saved pages)', () {
    test('studio Arch: 7 anime with every column', () {
      final page = _page('anime_search_arch.html', 'anime');
      expect(page.items, hasLength(7));
      expect(page.hasNext, isFalse);
      final first = page.items.first;
      expect(first.id, 56191);
      expect(first.title, 'I Like U');
      expect(first.image, 'https://cdn.myanimelist.net/images/anime/1234/137601.jpg');
      expect(first.type, 'Music');
      expect(first.episodes, 1);
      expect(first.score, 6.04);
      expect(first.synopsis, startsWith('Music video for the song'));
      expect(page.items.every((i) => i.members != null && i.members! > 0), isTrue);
      expect(page.items.map((i) => i.rated), ['PG-13', 'R', 'PG', 'PG-13', null, 'R', 'R']);
      final upcoming = page.items[4];
      expect(upcoming.score, isNull);
      expect(upcoming.episodes, isNull);
      expect(upcoming.startDate, '2027-01-05');
      expect(upcoming.endDate, isNull);
      expect(page.items[3].startDate, '2025-10-21');
    });

    test('a magazine: manga rows with chapters and volumes, and a next page', () {
      final page = _page('manga_search_magazine.html', 'manga');
      expect(page.items, hasLength(3));
      expect(page.hasNext, isTrue);
      expect(page.items.first.id, 28208);
      expect(page.items.first.title, '-SINS-');
      expect(page.items.first.image, startsWith('https://cdn.myanimelist.net/images/manga/'));
      expect(page.items.any((i) => i.volumes != null), isTrue);
    });

    test('"no titles matched" is an empty page, not a failure', () {
      final page = _page('anime_search_none.html', 'anime');
      expect(page.items, isEmpty);
      expect(page.tooShort, isFalse);
    });

    test('a text MAL refuses reads as too short', () {
      expect(_page('anime_search_short.html', 'anime').tooShort, isTrue);
    });

    test('a page that is not MAL (challenge) is a failure', () {
      expect(
        () => SearchParsers.parseSearchPage(html.parse('<html><body>Just a moment...</body></html>'), 'anime'),
        throwsFormatException,
      );
    });

    test('people and characters', () {
      final people = _page('people_search.html', 'person');
      expect(people.items.map((p) => p.id), [36521, 185, 75340]);
      expect(people.items[1].title, 'Hanazawa, Kana');
      expect(people.items[1].alternative, 'HanaKana, KanaHana');
      expect(people.items[1].image, 'https://cdn.myanimelist.net/images/voiceactors/3/69318.jpg');
      expect(people.items[0].image, isNull);
      expect(people.hasNext, isTrue);
      final chars = _page('character_search.html', 'character');
      expect(chars.items.first.id, 40);
      expect(chars.items.first.title, 'Monkey D., Luffy');
    });

    test('MAL dates become ISO dates', () {
      final now = DateTime(2026, 10, 28);
      expect(SearchParsers.malDate('01-05-25', now: now), '2025-01-05');
      expect(SearchParsers.malDate('04-??-98', now: now), '1998-04');
      expect(SearchParsers.malDate('??-??-29', now: now), '2029');
      expect(SearchParsers.malDate('-', now: now), isNull);
    });
  });

  group('company directory (saved pages)', () {
    test('listing: names, logos, anime counts, next page', () {
      final page = _companies('company_directory.html');
      expect(page.items, hasLength(3));
      expect(page.hasNext, isTrue);
      final kyoani = page.items.first;
      expect(kyoani.id, 2);
      expect(kyoani.name, 'Kyoto Animation');
      expect(kyoani.japaneseName, '京都アニメーション');
      expect(kyoani.logo, startsWith('https://cdn.myanimelist.net/s/common/company_logos/'));
      expect(kyoani.animeCount, 142);
      expect(kyoani.favorites, greaterThan(0));
    });

    test('last listing page has no next page', () {
      expect(_companies('company_directory_last.html').hasNext, isFalse);
    });

    test('search "arch": Arch first with its logo, missing logos are null', () {
      final page = _companies('company_search_arch.html');
      expect(page.items.map((c) => c.name).first, 'Arch');
      expect(page.items.first.id, 1966);
      expect(page.items.first.logo, contains('company_logos'));
      expect(page.items.firstWhere((c) => c.id == 3100).logo, isNull);
      expect(page.hasNext, isFalse);
    });

    test('search pages link the next one', () {
      final page = _companies('company_search.html');
      expect(page.items, isNotEmpty);
      expect(page.hasNext, isTrue);
    });

    test('JSON round trip', () {
      final page = _companies('company_directory.html');
      final back = CompanyPageHtml.fromJson(page.toJson());
      expect(back.items.first.name, 'Kyoto Animation');
      expect(back.hasNext, isTrue);
    });
  });

  test('producer page keeps names with digits and reads the count (owner scraper)', () {
    final list = HtmlParsers.parseProducer(html.parse(_fixture('anime_producer_page.html')));
    final all = list.categories.expand((c) => c.genres).toList();
    final eightBit = all.firstWhere((g) => g.id == 441);
    expect(eightBit.name, '8bit');
    expect(eightBit.count, 78);
    expect(all.firstWhere((g) => g.id == 2264).name, '5 Inc.');
  });

  group('firstUseful', () {
    SourceAnswer answer(MediaSource source, int n) =>
        SourceAnswer(source, [for (var i = 0; i < n; i++) Anime(id: i + 1, title: '$i', imageUrl: '', score: 0, members: 0)], hasMore: false);

    test('the first answer with rows wins', () async {
      final slow = Completer<SourceAnswer>();
      final result = await firstUseful([slow.future, Future.value(answer(MediaSource.malPage, 2))]);
      expect(result.source, MediaSource.malPage);
    });

    test('an empty answer waits for the others', () async {
      final result = await firstUseful([
        Future.value(answer(MediaSource.jikan, 0)),
        Future.delayed(const Duration(milliseconds: 10), () => answer(MediaSource.malPage, 3)),
      ]);
      expect(result.source, MediaSource.malPage);
    });

    test('a failed source does not hide the other', () async {
      final result = await firstUseful([
        Future<SourceAnswer>.error(TimeoutException('jikan')),
        Future.delayed(const Duration(milliseconds: 10), () => answer(MediaSource.malPage, 1)),
      ]);
      expect(result.items, hasLength(1));
    });

    test('everything failed: the fallback error is thrown', () async {
      await expectLater(
        firstUseful([Future<SourceAnswer>.error(StateError('a')), Future<SourceAnswer>.error(const FormatException('b'))]),
        throwsFormatException,
      );
    });

    test('all empty: empty', () async {
      final result = await firstUseful([Future.value(answer(MediaSource.jikan, 0)), Future.value(answer(MediaSource.malPage, 0))]);
      expect(result.items, isEmpty);
    });
  });

  group('SearchService without Jikan', () {
    final calls = <(String, String, Map<String, Object?>, int)>[];
    MalSearchPageHtml? next;

    setUp(() {
      calls.clear();
      next = null;
      SearchService.jikanAllowed = () => false;
      SearchService.malSearchPage = ({required String category, String query = '', Map<String, Object?> filters = const {}, int page = 1}) async {
        calls.add((category, query, filters, page));
        return next;
      };
    });
    tearDown(SearchService.reset);

    test('studio filter: results from the MAL page, next page from the same source', () async {
      next = _page('anime_search_arch.html', 'anime');
      next = MalSearchPageHtml(items: next!.items, hasNext: true);
      const service = SearchService();
      final request = SearchRequest(
        category: SearchCategory.anime,
        query: '',
        filters: SearchFilters.empty.set(FilterKey.producer, 1966).set(FilterKey.producerLabel, 'Arch'),
      );
      final page = await service.search(request);
      expect(page.source, MediaSource.malPage);
      expect(page.media, hasLength(7));
      expect(page.media.first.imageUrl, 'https://cdn.myanimelist.net/images/anime/1234/137601.jpg');
      expect(page.hasMore, isTrue);
      expect(calls.single.$3, {FilterKey.producer: 1966});
      next = const MalSearchPageHtml(items: [MalSearchItemHtml(id: 99, category: 'anime', title: 'Next')]);
      await service.loadMore(page, request);
      expect(calls.last.$4, 2);
      expect(page.media.last.id, 99);
      expect(page.hasMore, isFalse);
    });

    test('a failed MAL page throws (the screen then tells offline from source failed)', () async {
      next = null;
      const service = SearchService();
      await expectLater(
        service.search(SearchRequest(
          category: SearchCategory.anime,
          query: '',
          filters: SearchFilters.empty.set(FilterKey.genresIn, [1]),
        )),
        throwsA(isA<StateError>()),
      );
    });

    test('characters use the MAL page too', () async {
      next = _page('character_search.html', 'character');
      final page = await const SearchService().search(const SearchRequest(category: SearchCategory.character, query: 'luffy'));
      expect(page.media.first.title, 'Monkey D., Luffy');
      expect(calls.single.$1, 'character');
    });

    test('a short text without Jikan fails as too short, without asking MAL', () async {
      await expectLater(
        const SearchService().search(SearchRequest(
          category: SearchCategory.anime,
          query: 'na',
          filters: SearchFilters.empty.set(FilterKey.type, 'tv'),
        )),
        throwsA(isA<SearchFailure>().having((f) => f.kind, 'kind', SearchFailureKind.tooShort)),
      );
      expect(calls, isEmpty);
    });
  });

  group('failure kinds', () {
    tearDown(SearchFailures.reset);

    test('offline when the network check says so, else source failed', () async {
      SearchFailures.isOffline = () async => true;
      expect(await SearchFailures.classify(StateError('x')), SearchFailureKind.offline);
      SearchFailures.isOffline = () async => false;
      expect(await SearchFailures.classify(TimeoutException('x')), SearchFailureKind.source);
      expect(await SearchFailures.classify(const SearchFailure(SearchFailureKind.tooShort)), SearchFailureKind.tooShort);
    });
  });

  group('MwlApi search page client', () {
    test('query of the route', () {
      final params = MwlApi.searchContentParams(
        category: 'anime',
        query: ' x ',
        filters: {'producer': 1966, 'genres_in': [1, 2], 'genres_out': <int>[], 'producer_label': 'Arch'},
      );
      expect(params, {'category': 'anime', 'q': 'x', 'page': 1, 'producer': '1966', 'genres_in': '1,2'});
    });

    test('no answer in time is null, never a hang', () async {
      final result = await MwlApi.fetchSearchPage(
        () => Completer<dynamic>().future,
        timeout: const Duration(milliseconds: 20),
      );
      expect(result, isNull);
    });
  });

  group('StudiosPager', () {
    test('pages, next page, failure and retry', () async {
      final asked = <(String, int)>[];
      var fail = false;
      final pager = StudiosPager(
        onChanged: () {},
        fetch: (q, p) async {
          asked.add((q, p));
          if (fail) return null;
          return CompanyPageHtml(items: [CompanyHtml(id: p, name: 'S$p')], hasNext: p < 2);
        },
      );
      await pager.start(' arch ');
      expect(pager.stage, StudiosStage.loaded);
      expect(pager.query, 'arch');
      expect(pager.hasMore, isTrue);
      fail = true;
      await pager.loadMore();
      expect(pager.loadMoreFailed, isTrue);
      fail = false;
      await pager.retry();
      expect(pager.items.map((c) => c.id), [1, 2]);
      expect(pager.hasMore, isFalse);
      expect(asked, [('arch', 1), ('arch', 2), ('arch', 2)]);
    });
  });

  test('StudiosPager: the whole directory goes on with the other producers, A to Z', () async {
    final pager = StudiosPager(
      onChanged: () {},
      fetch: (q, p) async => CompanyPageHtml(items: [CompanyHtml(id: 1, name: 'Studio Pierrot', logo: 'x')]),
      fetchOthers: () async => {1: 'Studio Pierrot', 3: 'Gonzo', 1966: 'Arch'},
    );
    await pager.start('');
    expect(pager.hasMore, isTrue);
    await pager.loadMore();
    expect(pager.items.map((c) => c.name), ['Studio Pierrot', 'Arch', 'Gonzo']);
    expect(pager.items.last.logo, isNull);
    expect(pager.hasMore, isFalse);
  });

  group('StudiosScreen', () {
    tearDown(() {
      StudiosPager.reset();
      SearchFailures.reset();
    });

    testWidgets('lists studios and opens the studio search on tap', (tester) async {
      final directory = _companies('company_directory.html');
      StudiosPager.defaultFetch = (q, p) async => directory;
      final pushed = <Route<dynamic>>[];
      await tester.pumpWidget(MaterialApp(
        home: const StudiosScreen(),
        navigatorObservers: [_Observer(pushed.add)],
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('Kyoto Animation'), findsOneWidget);
      expect(find.textContaining('142 anime'), findsOneWidget);
      pushed.clear();
      await tester.tap(find.text('Kyoto Animation'));
      // The route is checked without building the search screen (it would search).
      final route = pushed.single as MaterialPageRoute<dynamic>;
      final screen = route.builder(tester.element(find.byType(StudiosScreen))) as GeneralSearchScreen;
      expect(screen.filters?.integer(FilterKey.producer), 2);
      expect(screen.category, SearchCategory.anime);
    });

    testWidgets('a failure says whether the network or MyAnimeList failed', (tester) async {
      StudiosPager.defaultFetch = (q, p) async => null;
      SearchFailures.isOffline = () async => true;
      await tester.pumpWidget(const MaterialApp(home: StudiosScreen()));
      await tester.pump();
      await tester.pump();
      expect(find.text('No internet connection'), findsOneWidget);
      SearchFailures.isOffline = () async => false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('MyAnimeList didn’t answer'), findsOneWidget);
    });

    testWidgets('no studio found', (tester) async {
      StudiosPager.defaultFetch = (q, p) async => const CompanyPageHtml();
      await tester.pumpWidget(const MaterialApp(home: StudiosScreen(initialQuery: 'zzzz')));
      await tester.pump();
      await tester.pump();
      expect(find.text('No studio found'), findsOneWidget);
    });
  });
}

class _Observer extends NavigatorObserver {
  _Observer(this.onPush);
  final void Function(Route<dynamic>) onPush;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => onPush(route);
}
