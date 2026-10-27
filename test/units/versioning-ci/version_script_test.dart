import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs tools/release/version.sh (bash) against a throwaway pubspec.
ProcessResult _run(List<String> args, {String? pubspec, Map<String, String>? env}) {
  return Process.runSync(
    'bash',
    ['tools/release/version.sh', ...args],
    environment: {
      if (pubspec != null) 'PUBSPEC': pubspec,
      ...?env,
    },
  );
}

void main() {
  late Directory tmp;
  late File pubspec;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mwl_version_');
    pubspec = File('${tmp.path}/pubspec.yaml')
      ..writeAsStringSync('name: app\nversion: 2026.9.2+10\n\ndependencies:\n  version: any\n');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  group('check', () {
    test('accepts yyyy.m.n', () {
      for (final v in ['2026.1.1', '2026.10.12', '2027.12.3']) {
        expect(_run(['check', v]).exitCode, 0, reason: v);
      }
    });

    test('rejects other shapes', () {
      for (final v in ['1.0.0', '2026.01.1', '2026.13.1', '2026.10.0', '2026.10', 'v2026.10.1', '2026.10.1+3']) {
        expect(_run(['check', v]).exitCode, isNot(0), reason: v);
      }
    });
  });

  group('set', () {
    test('a new name adds 1 to the build code and touches only the version line', () {
      final r = _run(['set', '2026.10.1'], pubspec: pubspec.path);
      expect(r.exitCode, 0);
      expect(r.stdout.toString().trim(), '2026.10.1+11');
      expect(
        pubspec.readAsStringSync(),
        'name: app\nversion: 2026.10.1+11\n\ndependencies:\n  version: any\n',
      );
    });

    test('the same name keeps the build code', () {
      expect(_run(['set', '2026.9.2'], pubspec: pubspec.path).stdout.toString().trim(), '2026.9.2+10');
    });

    test('an explicit code wins', () {
      expect(_run(['set', '2026.10.1', '42'], pubspec: pubspec.path).stdout.toString().trim(), '2026.10.1+42');
    });

    test('an invalid version leaves the file alone', () {
      final before = pubspec.readAsStringSync();
      expect(_run(['set', '1.0.0'], pubspec: pubspec.path).exitCode, isNot(0));
      expect(pubspec.readAsStringSync(), before);
    });
  });

  group('current and next', () {
    test('current prints the pubspec version', () {
      expect(_run(['current'], pubspec: pubspec.path).stdout.toString().trim(), '2026.9.2+10');
    });

    test('next increments the counter of the month, ignoring other tags', () {
      final r = _run(
        ['next', '2026.10.1', '2026.10.3', '2026.9.9', 'junk'],
        env: {'MWL_NOW': '2026.10'},
      );
      expect(r.stdout.toString().trim(), '2026.10.4');
    });

    test('next starts a new month at 1', () {
      final r = _run(['next', '2026.9.4'], env: {'MWL_NOW': '2026.10'});
      expect(r.stdout.toString().trim(), '2026.10.1');
    });
  });
}
