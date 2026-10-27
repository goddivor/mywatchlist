import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Bookmarks.store = BookmarkStore();
  });

  Future<bool> toggle(String tracker, BookmarkKind kind, Object id,
          {String title = 'T'}) =>
      Bookmarks.toggle(tracker: tracker, kind: kind, id: id, title: title);

  test('toggle adds then removes, and tells the new state', () async {
    expect(await toggle('myanimelist', BookmarkKind.anime, 1), isTrue);
    expect(
        Bookmarks.isBookmarked(
            tracker: 'myanimelist', kind: BookmarkKind.anime, id: 1),
        isTrue);
    expect(await toggle('myanimelist', BookmarkKind.anime, 1), isFalse);
    expect(Bookmarks.listenable.length, 0);
  });

  test('the key includes tracker, kind and id', () async {
    await toggle('myanimelist', BookmarkKind.anime, 1);
    expect(
        Bookmarks.isBookmarked(
            tracker: 'anilist', kind: BookmarkKind.anime, id: 1),
        isFalse);
    expect(
        Bookmarks.isBookmarked(
            tracker: 'myanimelist', kind: BookmarkKind.manga, id: 1),
        isFalse);
  });

  test('the list is saved and reloaded by a new store', () async {
    await toggle('kitsu', BookmarkKind.manga, 'abc', title: 'Berserk');
    final fresh = BookmarkStore();
    await fresh.ready;
    final b = fresh.get('kitsu:manga:abc');
    expect(b?.title, 'Berserk');
  });

  test('notifies listeners on change', () async {
    var calls = 0;
    Bookmarks.listenable.addListener(() => calls++);
    await toggle('simkl', BookmarkKind.anime, 9);
    await toggle('simkl', BookmarkKind.anime, 9);
    expect(calls, greaterThanOrEqualTo(2));
  });

  test('export then import restores everything, skipping bad entries', () async {
    await toggle('myanimelist', BookmarkKind.character, 5);
    await toggle('anilist', BookmarkKind.anime, 7);
    final data = await Bookmarks.export();
    (data['bookmarks'] as List).add({'kind': 'nope'});

    await Bookmarks.listenable.clear();
    expect(Bookmarks.listenable.length, 0);
    expect(await Bookmarks.import(data), 2);
    expect(Bookmarks.listenable.length, 2);
  });

  test('replace drops the current list; a newer version throws', () async {
    await toggle('myanimelist', BookmarkKind.anime, 1);
    final data = await Bookmarks.export();
    await toggle('myanimelist', BookmarkKind.anime, 2);
    await Bookmarks.import(data, replace: true);
    expect(Bookmarks.listenable.length, 1);
    expect(() => Bookmarks.import({'version': 99, 'bookmarks': []}),
        throwsFormatException);
  });

  test('openableId uses the MAL id for other trackers', () {
    final b = Bookmark(
        tracker: 'anilist',
        kind: BookmarkKind.anime,
        id: '1',
        title: 'x',
        malId: 5114,
        addedAt: DateTime(2026));
    expect(b.openableId, 5114);
  });
}
