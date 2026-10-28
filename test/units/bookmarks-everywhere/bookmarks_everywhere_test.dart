import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/bookmarks_screen.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_card.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_opener.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Locale locale) async {
  await tester.runAsync(() => S.load(locale));
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: const BookmarksScreen(),
  ));
  await tester.pumpAndSettle();
}

Future<void> _save(BookmarkKind kind, int id, String title,
        {String? subtitle}) =>
    Bookmarks.toggle(
        tracker: 'myanimelist',
        kind: kind,
        id: id,
        title: title,
        subtitle: subtitle);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Bookmarks.store = BookmarkStore();
  });

  test('club, news, featured and stack kinds survive a save and a reload',
      () async {
    await _save(BookmarkKind.club, 1, 'Club');
    await _save(BookmarkKind.news, 2, 'News');
    await _save(BookmarkKind.featured, 3, 'Featured');
    await _save(BookmarkKind.interestStack, 4, 'Stack', subtitle: 'author');

    final reloaded = BookmarkStore();
    await reloaded.ready;
    expect(reloaded.length, 4);
    final stack = reloaded.get(
        Bookmarks.keyOf('myanimelist', BookmarkKind.interestStack, 4))!;
    expect(stack.subtitle, 'author');
    expect(stack.openableId, 4);
    expect(
        reloaded
            .get(Bookmarks.keyOf('myanimelist', BookmarkKind.club, 1))!
            .openableId,
        1);
  });

  test('the old kind names keep their meaning', () {
    // Stored by name: the first six names must never move.
    expect(BookmarkKind.values.take(6).map((k) => k.name), [
      'anime',
      'manga',
      'character',
      'person',
      'forumTopic',
      'user',
    ]);
  });

  test('a stack bookmark opens the address its screen reads the id from', () {
    final id = RegExp(r'/stacks/(\d+)').firstMatch(interestStackUrl(42))?.group(1);
    expect(id, '42');
  });

  testWidgets('forum topics alone show as rows', (tester) async {
    await tester.runAsync(() async {
      await _save(BookmarkKind.forumTopic, 10, 'Topic A', subtitle: 'someone');
      await _save(BookmarkKind.forumTopic, 11, 'Topic B');
    });
    await _pump(tester, const Locale('en'));
    expect(find.byType(BookmarkRow), findsNWidgets(2));
    expect(find.byType(BookmarkCard), findsNothing);
    expect(find.textContaining('someone'), findsOneWidget);
  });

  testWidgets('new kinds have French filter chips and a grid', (tester) async {
    await tester.runAsync(() async {
      await _save(BookmarkKind.club, 1, 'Club');
      await _save(BookmarkKind.interestStack, 4, 'Stack');
      await _save(BookmarkKind.news, 2, 'News');
      await _save(BookmarkKind.featured, 3, 'Featured');
    });
    await _pump(tester, const Locale('fr', 'FR'));
    expect(find.textContaining('Clubs'), findsOneWidget);
    expect(find.textContaining('Piles d’intérêts'), findsOneWidget);
    expect(find.textContaining('Actualités'), findsOneWidget);
    expect(find.byType(BookmarkCard), findsNWidgets(4));

    await tester.ensureVisible(find.textContaining('Piles d’intérêts'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Piles d’intérêts'));
    await tester.pumpAndSettle();
    expect(find.byType(BookmarkCard), findsOneWidget);
    expect(find.text('Stack'), findsOneWidget);
  });
}
