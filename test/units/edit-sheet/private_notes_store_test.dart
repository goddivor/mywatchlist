import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/user/private_notes/private_notes_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a note is kept per category and survives a new store', () async {
    await PrivateNotesStore().write(5114, 'anime', 'Rewatch with dub');
    await PrivateNotesStore().write(5114, 'manga', 'Other one');

    final fresh = PrivateNotesStore();
    expect(await fresh.read(5114, 'anime'), 'Rewatch with dub');
    expect(await fresh.read(5114, 'manga'), 'Other one');
    expect(await fresh.read(1, 'anime'), isNull);
  });

  test('a blank note removes the note', () async {
    final store = PrivateNotesStore();
    await store.write(1, 'anime', 'x');
    await store.write(1, 'anime', '   ');
    expect(await store.read(1, 'anime'), isNull);
    expect((await store.export())['notes'], isEmpty);
  });

  test('export then import restores every note', () async {
    final store = PrivateNotesStore();
    await store.write(1, 'anime', 'one');
    await store.write(2, 'manga', 'two\nlines');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unrelated', 'kept out');
    final backup = await store.export();
    expect(backup, {
      'version': 1,
      'notes': {'mal:anime:1': 'one', 'mal:manga:2': 'two\nlines'},
    });

    SharedPreferences.setMockInitialValues({});
    final restored = PrivateNotesStore();
    expect(await restored.import(backup), 2);
    expect(await restored.read(2, 'manga'), 'two\nlines');
  });

  test('import merges by default and replaces on demand', () async {
    final store = PrivateNotesStore();
    await store.write(1, 'anime', 'old');
    await store.write(3, 'anime', 'stays');
    await store.import({
      'version': 1,
      'notes': {'mal:anime:1': 'new', 'bad key': 'skipped', 'mal:anime:4': 5},
    });
    expect(await store.read(1, 'anime'), 'new');
    expect(await store.read(3, 'anime'), 'stays');

    await store.import({
      'version': 1,
      'notes': {'mal:anime:9': 'only'},
    }, replace: true);
    expect(await store.read(3, 'anime'), isNull);
    expect(await store.read(9, 'anime'), 'only');
  });

  test('a payload from a newer version is refused', () async {
    expect(
      () => PrivateNotesStore().import({'version': 2, 'notes': {}}),
      throwsFormatException,
    );
  });
}
