import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

ProcessResult _version(List<String> args) => Process.runSync('bash', ['tools/release/version.sh', ...args]);

int _code(String version) => int.parse(_version(['code', version]).stdout.toString().trim());

void main() {
  group('version.sh code', () {
    test('derives yy*10000 + m*100 + n from the tag', () {
      expect(_code('2026.10.1'), 261001);
      expect(_code('2026.1.12'), 260112);
      expect(_code('2027.12.99'), 271299);
    });

    test('is strictly increasing across counters, months and years', () {
      final tags = ['2026.9.9', '2026.10.1', '2026.10.2', '2026.10.10', '2026.11.1', '2026.12.3', '2027.1.1'];
      final codes = tags.map(_code).toList();
      for (var i = 1; i < codes.length; i++) {
        expect(codes[i], greaterThan(codes[i - 1]), reason: '${tags[i - 1]} -> ${tags[i]}');
      }
    });

    test('exceeds the committed pubspec code, so CI never goes backwards', () {
      final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
      final committed = int.parse(line.split('+').last.trim());
      expect(_code('2026.10.1'), greaterThan(committed));
    });

    test('rejects an invalid version and a counter above 99', () {
      expect(_version(['code', '1.0.0']).exitCode, isNot(0));
      expect(_version(['code', '2026.10.100']).exitCode, isNot(0));
      expect(_version(['code']).exitCode, isNot(0));
    });

    test('feeds set so the workflow writes the derived code', () {
      final tmp = Directory.systemTemp.createTempSync('mwl_rf_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final pubspec = File('${tmp.path}/pubspec.yaml')..writeAsStringSync('name: a\nversion: 2026.10.1+1\n');
      final r = Process.runSync(
        'bash',
        ['tools/release/version.sh', 'set', '2026.10.2', '${_code('2026.10.2')}'],
        environment: {'PUBSPEC': pubspec.path},
      );
      expect(r.stdout.toString().trim(), '2026.10.2+261002');
    });

    test('the release workflow passes the derived code to set', () {
      final yml = File('.github/workflows/release.yml').readAsStringSync();
      expect(yml, contains('version.sh code "\$VERSION"'));
      expect(yml, contains('version.sh set "\$VERSION" "\$CODE"'));
    });
  });

  group('AndroidManifest.xml', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('launcher label is MyWatchList', () {
      expect(manifest, contains('android:label="MyWatchList"'));
      expect(manifest, isNot(contains('android:label="mywatchlist"')));
    });

    test('the update provider is restricted to updater_paths', () {
      expect(manifest, contains('android:name="com.crazecoder.openfile.FileProvider"'));
      expect(manifest, contains('\${applicationId}.fileProvider.com.crazecoder.openfile'));
      expect(manifest, contains('android:resource="@xml/updater_paths"'));
      expect(manifest, contains('tools:replace="android:resource"'));
      expect(manifest, isNot(contains('@xml/filepaths')));
      expect(manifest, contains('xmlns:tools='));
    });

    test('updater_paths exposes only the updates cache', () {
      final paths = File('android/app/src/main/res/xml/updater_paths.xml').readAsStringSync();
      expect(paths, contains('<cache-path'));
      expect(paths, contains('path="updates/"'));
      expect(paths, isNot(contains('root-path')));
      expect(paths, isNot(contains('files-path')));
      expect(paths, isNot(contains('external')));
    });
  });
}
