import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/updater/release_service.dart';
import 'package:mywatchlist/services/updater/sha1.dart';
import 'package:mywatchlist/services/updater/update_controller.dart';

const _tag = '2026.10.2';

ReleaseAsset _asset(String name, {int size = 0}) =>
    ReleaseAsset(name: name, url: 'https://example.invalid/$name', size: size);

List<ReleaseAsset> _assets() => [
      for (final suffix in ['armeabi-v7a', 'arm64-v8a', 'x86_64', 'universal']) ...[
        _asset('MyWatchList-v$_tag-$suffix.apk', size: 10),
        _asset('MyWatchList-v$_tag-$suffix.apk.sha1'),
      ],
    ];

class _FakeDownloader implements UpdateDownloader {
  final List<int> bytes;
  final String checksumText;
  final bool fail;
  final List<String> requested = [];

  _FakeDownloader(this.bytes, this.checksumText, {this.fail = false});

  @override
  Future<String> fetchText(Uri url) async {
    requested.add(url.toString());
    return checksumText;
  }

  @override
  Future<void> download(Uri url, File dest, CancelToken token, void Function(int, int?) onProgress) async {
    requested.add(url.toString());
    if (fail) throw const HttpException('boom');
    await dest.writeAsBytes(bytes);
    onProgress(bytes.length, bytes.length);
  }
}

class _FakeInstaller implements ApkInstaller {
  final InstallResult result;
  final List<String> installed = [];

  _FakeInstaller([this.result = InstallResult.started]);

  @override
  Future<InstallResult> install(String path) async {
    installed.add(path);
    return result;
  }
}

class _FakeReleases implements ReleaseService {
  final ReleaseInfo? release;
  final bool fail;

  _FakeReleases(this.release, {this.fail = false});

  @override
  Future<ReleaseInfo?> latest() async {
    if (fail) throw const SocketException('offline');
    return release;
  }

  @override
  Future<ReleaseInfo?> forVersion(String version) async => release;
}

void main() {
  late Directory tmp;
  final bytes = utf8.encode('hello apk');
  // sha1("hello apk") computed by the implementation under test is checked against a known vector below.

  setUp(() => tmp = Directory.systemTemp.createTempSync('mwl_updater_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  UpdateController build({
    required _FakeDownloader downloader,
    required _FakeInstaller installer,
    ReleaseService? releases,
    List<String> abis = const ['arm64-v8a', 'armeabi-v7a'],
    String current = '2026.10.1',
  }) {
    return UpdateController(
      currentVersion: current,
      releases: releases ?? _FakeReleases(ReleaseInfo(tag: _tag, url: 'https://x', assets: _assets())),
      env: UpdateEnvironment(
        downloader: downloader,
        installer: installer,
        abis: () async => abis,
        downloadDir: () async => Directory('${tmp.path}/updates'),
        supported: true,
      ),
    );
  }

  group('sha1', () {
    test('matches known vectors', () async {
      expect(await sha1OfStream(Stream.value(utf8.encode('abc'))), 'a9993e364706816aba3e25717850c26c9cd0d89d');
      expect(await sha1OfStream(const Stream.empty()), 'da39a3ee5e6b4b0d3255bfef95601890afd80709');
      final long = utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq');
      expect(await sha1OfStream(Stream.fromIterable([long.sublist(0, 7), long.sublist(7)])),
          '84983e441c3bd26ebaae4aa1f95129e5e54670f1');
    });

    test('parseSha1File reads the sha1sum format', () {
      expect(parseSha1File('A9993E364706816ABA3E25717850C26C9CD0D89D  file.apk\n'),
          'a9993e364706816aba3e25717850c26c9cd0d89d');
      expect(parseSha1File('not a hash'), isNull);
    });
  });

  group('version and asset choice', () {
    test('compares yyyy.m.n+code against a tag', () {
      expect(isNewerVersion('2026.10.1+3', '2026.10.2'), isTrue);
      expect(isNewerVersion('2026.10.2+4', '2026.10.2'), isFalse);
      expect(isNewerVersion('2026.9.7', '2026.10.1'), isTrue);
      expect(isNewerVersion('2027.1.1', '2026.12.9'), isFalse);
    });

    test('picks the first supported ABI, else universal, else null', () {
      expect(pickApk(_assets(), ['arm64-v8a', 'armeabi-v7a'])!.apk.name, endsWith('-arm64-v8a.apk'));
      expect(pickApk(_assets(), ['riscv64', 'armeabi-v7a'])!.apk.name, endsWith('-armeabi-v7a.apk'));
      final choice = pickApk(_assets(), ['mips'])!;
      expect(choice.apk.name, endsWith('-universal.apk'));
      expect(choice.sha1!.name, '${choice.apk.name}.sha1');
      expect(pickApk([_asset('notes.txt')], ['arm64-v8a']), isNull);
    });

    test('parses assets from the GitHub JSON', () {
      final info = ReleaseInfo.fromJson({
        'tag_name': _tag,
        'assets': [
          {'name': 'a.apk', 'browser_download_url': 'https://x/a.apk', 'size': 5},
          {'name': 'broken'},
        ],
      });
      expect(info.assets, hasLength(1));
      expect(info.assets.single.size, 5);
    });
  });

  group('UpdateController', () {
    test('reports up to date, no release and network errors', () async {
      final upToDate = build(
        downloader: _FakeDownloader(bytes, ''),
        installer: _FakeInstaller(),
        current: _tag,
      );
      await upToDate.check();
      expect(upToDate.phase, UpdatePhase.upToDate);

      final none = build(
        downloader: _FakeDownloader(bytes, ''),
        installer: _FakeInstaller(),
        releases: _FakeReleases(null),
      );
      await none.check();
      expect(none.phase, UpdatePhase.noRelease);

      final offline = build(
        downloader: _FakeDownloader(bytes, ''),
        installer: _FakeInstaller(),
        releases: _FakeReleases(null, fail: true),
      );
      await offline.check();
      expect(offline.phase, UpdatePhase.failed);
      expect(offline.failure, UpdateFailure.check);
    });

    test('downloads, verifies the sha1 and installs', () async {
      final sum = await sha1OfStream(Stream.value(bytes));
      final downloader = _FakeDownloader(bytes, '$sum  file.apk');
      final installer = _FakeInstaller();
      final c = build(downloader: downloader, installer: installer);
      await c.check();
      expect(c.phase, UpdatePhase.available);
      expect(c.choice!.apk.name, endsWith('-arm64-v8a.apk'));
      await c.downloadAndInstall();
      expect(c.phase, UpdatePhase.installing);
      expect(installer.installed.single, endsWith('MyWatchList-v$_tag-arm64-v8a.apk'));
      expect(File(installer.installed.single).existsSync(), isTrue);
    });

    test('a checksum mismatch deletes the file and never installs', () async {
      final downloader = _FakeDownloader(bytes, '${'0' * 40}  file.apk');
      final installer = _FakeInstaller();
      final c = build(downloader: downloader, installer: installer);
      await c.check();
      await c.downloadAndInstall();
      expect(c.phase, UpdatePhase.failed);
      expect(c.failure, UpdateFailure.checksumMismatch);
      expect(installer.installed, isEmpty);
      expect(Directory('${tmp.path}/updates').listSync(), isEmpty);
    });

    test('a failed download offers a retry state and never installs', () async {
      final sum = await sha1OfStream(Stream.value(bytes));
      final installer = _FakeInstaller();
      final c = build(downloader: _FakeDownloader(bytes, sum, fail: true), installer: installer);
      await c.check();
      await c.downloadAndInstall();
      expect(c.failure, UpdateFailure.download);
      expect(installer.installed, isEmpty);
    });

    test('a release without checksum or without a package is refused', () async {
      final noSha = ReleaseInfo(
        tag: _tag,
        url: 'https://x',
        assets: [_asset('MyWatchList-v$_tag-universal.apk')],
      );
      final c1 = build(
        downloader: _FakeDownloader(bytes, ''),
        installer: _FakeInstaller(),
        releases: _FakeReleases(noSha),
      );
      await c1.check();
      await c1.downloadAndInstall();
      expect(c1.failure, UpdateFailure.checksumMissing);

      final c2 = build(
        downloader: _FakeDownloader(bytes, ''),
        installer: _FakeInstaller(),
        releases: _FakeReleases(ReleaseInfo(tag: _tag, url: 'https://x')),
      );
      await c2.check();
      await c2.downloadAndInstall();
      expect(c2.failure, UpdateFailure.noApk);
    });

    test('installer refusals map to failures', () async {
      final sum = await sha1OfStream(Stream.value(bytes));
      final denied = build(
        downloader: _FakeDownloader(bytes, sum),
        installer: _FakeInstaller(InstallResult.permissionDenied),
      );
      await denied.check();
      await denied.downloadAndInstall();
      expect(denied.failure, UpdateFailure.permission);
    });
  });

  test('formatBytes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(45 * 1024 * 1024), '45.0 MB');
  });
}
