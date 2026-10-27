import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType, TitleLang;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_error.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/MAL/detail/header/detail_title.dart';
import 'package:mywatchlist/screens/MAL/detail/section_frame.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';

import '../../helpers/pump_app.dart';

DetailData _data({
  String category = 'anime',
  MalAnime? content,
  Map<String, dynamic>? html,
  Anime? node,
}) =>
    DetailData(
      id: 1,
      category: category,
      content: content,
      html: html,
      node: node,
      state: content == null ? DetailLoadState.loading : DetailLoadState.loaded,
    );

MalAnime _content({AlternativeTitles? alt}) => MalAnime(
      id: 1,
      title: 'Shingeki no Kyojin',
      synopsis: 'Walls.',
      alternativeTitles: alt,
    );

List<TabType> _types(List<DetailSection> sections) =>
    sections.map((s) => s.type).toList();

void main() {
  setUpAll(() async => S.load(const Locale('en')));
  setUp(Preferences.reset);

  group('DetailSections', () {
    test('every section type has a builder', () {
      expect(DetailSections.registry.keys.toSet(), TabType.values.toSet());
    });

    test('nothing is shown before the details arrive', () {
      expect(DetailSections.build(_data()), isEmpty);
    });

    test('follows the default anime order and skips sections without data', () {
      final sections = DetailSections.build(_data(content: _content()));
      expect(_types(sections), [
        TabType.Synopsis,
        TabType.Reviews,
        TabType.Forums,
        TabType.Pictures,
        TabType.News,
        TabType.Featured_Articles,
        TabType.User_Updates,
        TabType.ScoreStats,
        TabType.More_Info,
      ]);
      expect(sections.every((s) => s.isTab), isTrue);
    });

    test('uses the saved order and drops hidden sections', () {
      final prefs = const ContentPreferences().copyWith(animeTabs: const [
        DetailTabPreference(TabType.More_Info),
        DetailTabPreference(TabType.Synopsis),
        DetailTabPreference(TabType.Reviews, visible: false),
      ]);
      final data = _data(content: _content());
      final order = DetailSections.order(data, prefs);
      expect(order.take(2), [TabType.More_Info, TabType.Synopsis]);
      expect(order, isNot(contains(TabType.Reviews)));
      expect(_types(DetailSections.build(data, order: order)).take(2),
          [TabType.More_Info, TabType.Synopsis]);
    });

    test('a manga page uses the manga order, without staff', () {
      final types = _types(
          DetailSections.build(_data(category: 'manga', content: _content())));
      expect(types.first, TabType.Synopsis);
      expect(types, isNot(contains(TabType.Staff)));
      expect(types, isNot(contains(TabType.Media)));
      expect(types.indexOf(TabType.Pictures),
          lessThan(types.indexOf(TabType.Forums)));
    });

    test('scraped streaming links bring the Media section', () {
      final data = _data(content: _content(), html: {
        'streamingPlatforms': [
          {'name': 'Crunchyroll', 'url': 'https://crunchyroll.com/x'},
          {'name': '', 'url': 'https://ignored'},
        ],
      });
      expect(data.links.single.name, 'Crunchyroll');
      expect(data.isStreamingBlank, isFalse);
      expect(_types(DetailSections.build(data)), contains(TabType.Media));
    });

    test('section titles are translated', () {
      expect(detailTabLabel(TabType.Interest_Stacks), S.current.Interest_Stacks);
      expect(detailTabLabel(TabType.ScoreStats), S.current.Score_Stats);
    });
  });

  group('resolveDetailTitle', () {
    final node = Anime(id: 1, title: 'Node', imageUrl: '', score: 0, members: 0);

    test('romaji is the main title, the card title while loading', () {
      expect(resolveDetailTitle(_data(node: node), TitleLang.ro), 'Node');
      expect(resolveDetailTitle(_data(content: _content()), TitleLang.ro),
          'Shingeki no Kyojin');
    });

    test('English and Japanese fall back when MAL has none', () {
      final data = _data(
          content: _content(alt: AlternativeTitles(en: 'Attack on Titan', ja: '')));
      expect(resolveDetailTitle(data, TitleLang.en), 'Attack on Titan');
      expect(resolveDetailTitle(data, TitleLang.ja), 'Shingeki no Kyojin');
    });

    test('the page starts on the preferred title of the preferences', () {
      expect(Preferences.general.preferredTitle, TitleLang.ro);
    });
  });

  group('widgets', () {
    testWidgets('error view explains and retries', (tester) async {
      var retries = 0;
      await pumpInApp(tester, DetailErrorView(onRetry: () => retries++));
      expect(find.text(S.current.Detail_Load_Error), findsOneWidget);
      expect(find.text(S.current.Detail_Load_Error_Hint), findsOneWidget);
      await tester.tap(find.text(S.current.Detail_Retry));
      expect(retries, 1);
    });

    testWidgets('error view names a dead MAL session', (tester) async {
      await pumpInApp(tester,
          DetailErrorView(error: const MalSessionExpired(), onRetry: () {}));
      expect(find.text(S.current.Detail_Session_Expired), findsOneWidget);
    });

    testWidgets('section frame: no title first, title and view all after',
        (tester) async {
      var opened = 0;
      final section = DetailSection(
        TabType.Forums,
        const Text('body'),
        onViewAll: (_) => opened++,
      );
      await pumpInApp(
          tester, DetailSectionFrame(section: section, isFirst: true));
      expect(find.text(S.current.Forums), findsNothing);

      await pumpInApp(
          tester, DetailSectionFrame(section: section, isFirst: false));
      expect(find.text(S.current.Forums), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_forward));
      expect(opened, 1);
    });
  });
}
