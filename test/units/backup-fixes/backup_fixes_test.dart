import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/storage_settings.dart';
import 'package:mywatchlist/user/private_notes/private_notes_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _bm(String id) =>
    {'tracker': 'myanimelist', 'kind': 'anime', 'id': id, 'title': 'T$id', 'addedAt': 1};

String _file({Object? bookmarks, Object? notes, Map<String, Object>? settings}) => jsonEncode({
      'app': 'mywatchlist',
      'format': 1,
      'settings': settings ?? {'font_family': 'Lato'},
      if (bookmarks != null) 'bookmarks': bookmarks,
      if (notes != null) 'notes': notes,
    });

void main() {
  Future<SharedPreferences> seed(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    Bookmarks.store = BookmarkStore();
    return SharedPreferences.getInstance();
  }

  test('accent_season_v1 travels with a backup', () async {
    final prefs = await seed({'accent_season_v1': 'auto'});
    final bundle = BackupService.parse(await BackupService.create(prefs: prefs));
    expect(bundle.settings['accent_season_v1'], 'auto');
    await prefs.remove('accent_season_v1');
    await BackupService.restore(bundle, prefs: prefs);
    expect(prefs.getString('accent_season_v1'), 'auto');
  });

  test('a section without a valid version refuses the whole file', () {
    for (final bad in [
      {'bookmarks': [_bm('1')]},
      {'version': 'x', 'bookmarks': [_bm('1')]},
      {'version': 0, 'bookmarks': [_bm('1')]},
    ]) {
      expect(() => BackupService.parse(_file(bookmarks: bad)),
          throwsA(isA<BackupSectionException>().having((e) => e.section, 'section', 'bookmarks')));
    }
    expect(() => BackupService.parse(_file(notes: {'version': 1, 'notes': []})),
        throwsA(isA<BackupSectionException>().having((e) => e.section, 'section', 'notes')));
    expect(() => BackupService.parse(_file(bookmarks: {'version': 1})),
        throwsA(isA<BackupSectionException>()));
  });

  test('a newer section version is reported as too new', () {
    expect(
      () => BackupService.parse(_file(notes: {'version': 9, 'notes': <String, String>{}})),
      throwsA(isA<BackupSectionException>().having((e) => e.tooNew, 'tooNew', isTrue)),
    );
  });

  test('a bad section restores nothing, even from a hand-built bundle', () async {
    final prefs = await seed({'font_family': 'Roboto', 'private_note_v1:mal:anime:1': 'keep'});
    final bundle = BackupBundle(
      version: 1,
      settings: {'font_family': 'Lato'},
      bookmarks: {'version': 1, 'bookmarks': [_bm('1')]},
      notes: {'version': 99, 'notes': {'mal:anime:2': 'x'}},
    );
    await expectLater(BackupService.restore(bundle, prefs: prefs),
        throwsA(isA<BackupSectionException>()));
    expect(prefs.getString('font_family'), 'Roboto');
    expect(Bookmarks.listenable.length, 0);
    expect(prefs.getString('private_note_v1:mal:anime:2'), isNull);
    expect(prefs.getString('private_note_v1:mal:anime:1'), 'keep');
  });

  test('preview counts equal restored counts', () async {
    final prefs = await seed({});
    final raw = _file(
      settings: {'font_family': 'Lato', 'unknown_key': 'x', 'show_bg': {'bad': 1}},
      bookmarks: {
        'version': 1,
        'bookmarks': [_bm('1'), _bm('1'), _bm('2'), {'kind': 'nope'}, 'junk'],
      },
      notes: {
        'version': 1,
        'notes': {'mal:anime:1': 'a', 'bad key': 'b', 'mal:anime:2': '  ', 'mal:manga:3': 'c'},
      },
    );
    final bundle = BackupService.parse(raw);
    expect(bundle.settingsCount, 1);
    expect(bundle.bookmarksCount, 2);
    expect(bundle.notesCount, 2);
    final result = await BackupService.restore(bundle, prefs: prefs);
    expect(result.settings, bundle.settingsCount);
    expect(result.bookmarks, bundle.bookmarksCount);
    expect(result.notes, bundle.notesCount);
  });

  test('a write that fails midway puts the device back', () async {
    final prefs = await seed({'font_family': 'Roboto'});
    await Bookmarks.toggle(
        tracker: 'kitsu', kind: BookmarkKind.manga, id: 'x', title: 'Local');
    final bundle = BackupBundle(
      version: 1,
      settings: {'font_family': 'Lato'},
      bookmarks: {'version': 1, 'bookmarks': [_bm('7')]},
      notes: {'version': 1, 'notes': {'mal:anime:1': 'n'}},
    );
    final failing = _FailingNotes();
    await expectLater(
        BackupService.restore(bundle, replace: true, prefs: prefs, notesStore: failing),
        throwsA(isA<StateError>()));
    expect(prefs.getString('font_family'), 'Roboto');
    expect(Bookmarks.listenable.contains('kitsu:manga:x'), isTrue);
    expect(Bookmarks.listenable.contains('myanimelist:anime:7'), isFalse);
  });

  test('formatBytes uses the app language', () async {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1.5 KB');
    await S.load(const Locale('fr', 'FR'));
    final mo = (115.4 * 1024 * 1024).round();
    expect(formatBytes(mo), '115,4 Mo');
    expect(formatBytes(512), '512 o');
    await S.load(const Locale('en'));
    expect(formatBytes(mo), '115.4 MB');
  });
}

class _FailingNotes extends PrivateNotesStore {
  @override
  Future<int> import(Map<String, dynamic> data, {bool replace = false}) =>
      throw StateError('disk full');
}
