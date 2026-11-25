import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/bookmarks_screen.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_kind.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_opener.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Bookmarks.store = BookmarkStore();
  });

  test('a Simkl bookmark id keeps the catalogue', () {
    expect(simklBookmarkId(SimklKind.anime, 12), '12');
    expect(simklBookmarkId(SimklKind.movie, 34), 'movie:34');
    expect(parseSimklBookmarkId('12'), (SimklKind.anime, 12));
    expect(parseSimklBookmarkId('tv:56'), (SimklKind.tv, 56));
    expect(parseSimklBookmarkId('weird:56'), isNull);
    expect(parseSimklBookmarkId('x'), isNull);
  });

  testWidgets("each tracker app lists only its own bookmarks", (tester) async {
    await tester.runAsync(() async {
      await S.load(const Locale('en'));
      await Bookmarks.toggle(tracker: 'myanimelist', kind: BookmarkKind.anime, id: 1, title: 'Mal title');
      await Bookmarks.toggle(tracker: 'anilist', kind: BookmarkKind.anime, id: 2, title: 'AniList title');
      await Bookmarks.toggle(tracker: 'simkl', kind: BookmarkKind.anime, id: 'movie:3', title: 'Simkl movie');
    });
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: const BookmarksScreen(tracker: AccountType.anilist),
    ));
    await tester.pumpAndSettle();
    expect(find.text('AniList title'), findsOneWidget);
    expect(find.text('Mal title'), findsNothing);
    expect(find.text('Simkl movie'), findsNothing);
  });
}
