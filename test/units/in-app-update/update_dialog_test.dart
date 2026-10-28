import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/updater/release_service.dart';
import 'package:mywatchlist/services/updater/update_controller.dart';
import 'package:mywatchlist/services/updater/update_dialog.dart';

import '../../helpers/pump_app.dart';

class _Releases implements ReleaseService {
  final ReleaseInfo? release;
  final bool fail;

  _Releases(this.release, {this.fail = false});

  @override
  Future<ReleaseInfo?> latest() async {
    if (fail) throw const SocketException('offline');
    return release;
  }

  @override
  Future<ReleaseInfo?> forVersion(String version) async => release;
}

class _NeverDownloads implements UpdateDownloader {
  @override
  Future<String> fetchText(Uri url) => throw StateError('no network in tests');

  @override
  Future<void> download(Uri url, File dest, CancelToken token, void Function(int, int?) onProgress) =>
      throw StateError('no network in tests');
}

class _NeverInstalls implements ApkInstaller {
  @override
  Future<InstallResult> install(String path) => throw StateError('no install in tests');
}

UpdateEnvironment _env({bool supported = true}) => UpdateEnvironment(
      downloader: _NeverDownloads(),
      installer: _NeverInstalls(),
      abis: () async => const ['arm64-v8a'],
      downloadDir: () async => Directory.systemTemp,
      supported: supported,
    );

Future<void> _open(WidgetTester tester, ReleaseService releases, {bool supported = true}) async {
  await S.load(const Locale('en'));
  await pumpInApp(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => UpdateDialog(
            current: '2026.10.1',
            releases: releases,
            environment: _env(supported: supported),
            onOpen: (_) {},
          ),
        ),
        child: const Text('go'),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the download button for a newer release', (tester) async {
    final release = ReleaseInfo(
      tag: '2026.10.2',
      url: 'https://x',
      assets: const [
        ReleaseAsset(name: 'MyWatchList-v2026.10.2-universal.apk', url: 'https://x/a', size: 2048),
        ReleaseAsset(name: 'MyWatchList-v2026.10.2-universal.apk.sha1', url: 'https://x/b'),
      ],
    );
    await _open(tester, _Releases(release));
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Download and install'), findsOneWidget);
    expect(find.textContaining('2.0 KB'), findsOneWidget);
  });

  testWidgets('hides the installer on platforms other than Android', (tester) async {
    final release = ReleaseInfo(tag: '2026.10.2', url: 'https://x');
    await _open(tester, _Releases(release), supported: false);
    expect(find.text('Download and install'), findsNothing);
    expect(find.text('View release'), findsOneWidget);
  });

  testWidgets('up to date', (tester) async {
    await _open(tester, _Releases(const ReleaseInfo(tag: '2026.10.1', url: 'https://x')));
    expect(find.text('You are up to date'), findsOneWidget);
  });

  testWidgets('network error shows Try again', (tester) async {
    await _open(tester, _Releases(null, fail: true));
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('no release published', (tester) async {
    await _open(tester, _Releases(null));
    expect(find.text('No release has been published yet.'), findsOneWidget);
  });
}
