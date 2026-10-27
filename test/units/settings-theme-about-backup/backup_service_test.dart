import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/backup_settings.dart';
import 'package:mywatchlist/screens/settings/storage_settings.dart';
import 'package:mywatchlist/user/private_notes/private_notes_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> seed(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    Bookmarks.store = BookmarkStore();
    return SharedPreferences.getInstance();
  }

  test('create carries settings, bookmarks and notes, never tokens or paths', () async {
    final prefs = await seed({
      'prefs_general_v1': '{"a":1}',
      'font_family': 'Roboto',
      'show_bg': true,
      'seed_color': 4280391411,
      'custom_seed_colors_v1': ['1', '2'],
      'bg_image_path': '/data/user/0/x/bg.jpg',
      'download_path': '/sdcard/Pictures',
      'homepage - news': 'cache',
      'private_note_v1:mal:anime:5114': 'great',
    });
    await Bookmarks.toggle(
        tracker: 'myanimelist', kind: BookmarkKind.anime, id: 1, title: 'A');
    final raw = await BackupService.create(appVersion: '2026.10.1+1', prefs: prefs);
    final bundle = BackupService.parse(raw);
    expect(bundle.settings.keys,
        unorderedEquals(['prefs_general_v1', 'font_family', 'show_bg', 'seed_color', 'custom_seed_colors_v1']));
    expect(bundle.bookmarksCount, 1);
    expect(bundle.notesCount, 1);
    expect(bundle.appVersion, '2026.10.1+1');
    expect(bundle.createdAt, isNotNull);
  });

  test('parse refuses other files and newer formats', () {
    expect(() => BackupService.parse('nope'), throwsFormatException);
    expect(() => BackupService.parse('[]'), throwsFormatException);
    expect(() => BackupService.parse(jsonEncode({'app': 'other', 'format': 1})),
        throwsFormatException);
    expect(() => BackupService.parse(jsonEncode({'app': 'mywatchlist', 'format': 99})),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('newer'))));
  });

  test('parse drops unknown keys and bad values from the file', () {
    final bundle = BackupService.parse(jsonEncode({
      'app': 'mywatchlist',
      'format': 1,
      'settings': {
        'font_family': 'Lato',
        'user': 'secret-token',
        'show_bg': {'x': 1},
        'user_list_view_v1:mal:anime': '{}',
      },
    }));
    expect(bundle.settings.keys, unorderedEquals(['font_family', 'user_list_view_v1:mal:anime']));
  });

  test('merge keeps what the device has, replace removes it', () async {
    final prefs = await seed({'font_family': 'Roboto', 'show_bg': false});
    await Bookmarks.toggle(
        tracker: 'kitsu', kind: BookmarkKind.manga, id: 'x', title: 'Local');
    final file = BackupBundle(
      version: 1,
      settings: {'font_family': 'Lato'},
      bookmarks: {
        'version': 1,
        'bookmarks': [
          {
            'tracker': 'myanimelist',
            'kind': 'anime',
            'id': '7',
            'title': 'File',
            'added': 5,
          }
        ],
      },
    );
    final merged = await BackupService.restore(file, prefs: prefs);
    expect(merged.settings, 1);
    expect(prefs.getString('font_family'), 'Lato');
    expect(prefs.getBool('show_bg'), false);
    expect(Bookmarks.listenable.length, greaterThanOrEqualTo(1));
    expect(Bookmarks.listenable.contains('kitsu:manga:x'), isTrue);

    await BackupService.restore(file, replace: true, prefs: prefs);
    expect(prefs.containsKey('show_bg'), isFalse);
    expect(Bookmarks.listenable.contains('kitsu:manga:x'), isFalse);
  });

  test('unchosen sections are left alone', () async {
    final prefs = await seed({'font_family': 'Roboto'});
    final result = await BackupService.restore(
      BackupBundle(version: 1, settings: {'font_family': 'Lato'}),
      sections: {BackupSection.notes},
      prefs: prefs,
    );
    expect(result.settings, 0);
    expect(prefs.getString('font_family'), 'Roboto');
  });

  test('notes round-trip through the backup', () async {
    final prefs = await seed({'private_note_v1:mal:anime:1': 'hello'});
    final raw = await BackupService.create(prefs: prefs);
    await prefs.remove('private_note_v1:mal:anime:1');
    final result = await BackupService.restore(BackupService.parse(raw), prefs: prefs);
    expect(result.notes, 1);
    expect(await PrivateNotesStore.instance.read(1, 'anime'), 'hello');
  });

  test('data cache keys are the cache prefixes only', () async {
    final prefs = await seed({
      'homepage - news': 'x',
      'cached_user_profile_v1_bob': 'yyyy',
      'font_family': 'Roboto',
      'bookmarks_v1': '[]',
    });
    expect(CacheManager.isDataCacheKey('homepage - a'), isTrue);
    expect(CacheManager.isDataCacheKey('bookmarks_v1'), isFalse);
    final stats = await CacheManager.instance.dataCacheStats();
    expect(stats.entries, 2);
    expect(await CacheManager.instance.clearDataCaches(), 2);
    expect(prefs.getKeys(), containsAll(['font_family', 'bookmarks_v1']));
  });

  test('formatBytes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
  });

  testWidgets('review sheet returns the chosen sections and mode', (tester) async {
    await S.load(const Locale('en'));
    RestoreChoice? choice;
    final bundle = BackupBundle(
      version: 1,
      settings: {'font_family': 'Lato'},
      bookmarks: {'version': 1, 'bookmarks': [{}, {}]},
    );
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              choice = await showModalBottomSheet<RestoreChoice>(
                context: context,
                isScrollControlled: true,
                builder: (_) => RestoreReviewSheet(
                  bundle: bundle,
                  device: const BackupBundle(version: 1),
                ),
              );
            },
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.Bkp_Item_Settings));
    await tester.tap(find.text(S.current.Bkp_Mode_Replace));
    await tester.pump();
    await tester.tap(find.text(S.current.Bkp_Replace_Action));
    await tester.pumpAndSettle();
    expect(choice!.replace, isTrue);
    expect(choice!.sections, {BackupSection.bookmarks});
  });
}
