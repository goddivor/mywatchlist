import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Build configuration the app relies on at startup (#132): checked on the files themselves.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('the pubspec version is yyyy.m.n+code', () {
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1);
    expect(version, matches(RegExp(r'^20\d{2}\.([1-9]|1[0-2])\.[1-9]\d*\+[1-9]\d*$')));
  });

  test('the DubStatus icon font is declared and bundled', () {
    expect(pubspec, matches(RegExp(r'- family: DubStatus\s+fonts:\s+- asset: assets/fonts/MyDubListIcons\.ttf')));
    expect(File('assets/fonts/MyDubListIcons.ttf').existsSync(), isTrue);
  });

  test('MainActivity receives myanimelist.net links and keeps the OAuth callbacks', () {
    final filter = RegExp(r'<intent-filter android:autoVerify="false">(.*?)</intent-filter>', dotAll: true)
        .firstMatch(manifest)
        ?.group(1);
    expect(filter, isNotNull);
    expect(filter, contains('android.intent.action.VIEW'));
    expect(filter, contains('android.intent.category.BROWSABLE'));
    expect(filter, contains('android:scheme="https"'));
    for (final host in ['myanimelist.net', 'www.myanimelist.net', 'm.myanimelist.net']) {
      expect(filter, contains('android:host="$host"'));
    }
    for (final path in ['/anime', '/manga', '/character', '/people', '/profile', '/forum', '/clubs.php', '/featured', '/news']) {
      expect(filter, contains('android:pathPrefix="$path"'));
    }
    for (final host in ['myanimelist-callback', 'anilist-callback', 'simkl-callback']) {
      expect(manifest, contains('android:host="$host"'));
    }
  });
}
