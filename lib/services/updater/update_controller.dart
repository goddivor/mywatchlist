import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'release_service.dart';
import 'sha1.dart';

/// Where the update flow stands.
enum UpdatePhase { checking, noRelease, upToDate, available, downloading, verifying, installing, failed }

/// Why the flow ended in [UpdatePhase.failed].
enum UpdateFailure {
  /// GitHub could not be reached or answered badly.
  check,

  /// The release carries no package for this device.
  noApk,

  /// The download did not finish.
  download,

  /// The checksum file is missing or unreadable.
  checksumMissing,

  /// The downloaded file does not match its checksum (it is deleted).
  checksumMismatch,

  /// Installing from this app is not allowed in the system settings.
  permission,

  /// The system installer could not be opened.
  install,
}

/// Raised by a downloader when the user cancels.
class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

/// Lets the controller stop a running download.
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Network side of the flow; replaced by a fake in tests (tests never download).
abstract class UpdateDownloader {
  Future<String> fetchText(Uri url);

  /// Writes [url] to [dest], reporting `(received, total)`; throws [UpdateCancelled] when
  /// [token] is cancelled.
  Future<void> download(Uri url, File dest, CancelToken token, void Function(int received, int? total) onProgress);
}

class HttpUpdateDownloader implements UpdateDownloader {
  final http.Client _client;

  HttpUpdateDownloader({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<String> fetchText(Uri url) async {
    final response = await _client.get(url).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}', uri: url);
    return response.body;
  }

  @override
  Future<void> download(Uri url, File dest, CancelToken token, void Function(int, int?) onProgress) async {
    final response = await _client.send(http.Request('GET', url)).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}', uri: url);
    final total = response.contentLength;
    final sink = dest.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
        if (token.isCancelled) throw const UpdateCancelled();
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      if (token.isCancelled) throw const UpdateCancelled();
      if (total != null && received != total) throw HttpException('Truncated download', uri: url);
    } finally {
      await sink.close();
    }
  }
}

enum InstallResult { started, permissionDenied, failed }

/// Hands the APK to the system installer; replaced by a fake in tests.
abstract class ApkInstaller {
  Future<InstallResult> install(String path);
}

/// Asks for "install unknown apps" if needed, then opens the file; `open_filex` shares it
/// with the package installer as a content:// URI through its FileProvider, whose paths the
/// app's manifest restricts to `<cache>/updates` (res/xml/updater_paths.xml, issue #153).
class SystemApkInstaller implements ApkInstaller {
  @override
  Future<InstallResult> install(String path) async {
    try {
      var status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) return InstallResult.permissionDenied;
      final result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
      return result.type == ResultType.done ? InstallResult.started : InstallResult.failed;
    } catch (e) {
      debugPrint('APK install failed: $e');
      return InstallResult.failed;
    }
  }
}

/// Everything the controller needs from the device, replaceable in tests.
class UpdateEnvironment {
  final UpdateDownloader downloader;
  final ApkInstaller installer;
  final Future<List<String>> Function() abis;
  final Future<Directory> Function() downloadDir;
  final bool supported;

  const UpdateEnvironment({
    required this.downloader,
    required this.installer,
    required this.abis,
    required this.downloadDir,
    required this.supported,
  });

  /// Android only; the folder is `<cache>/updates`, the one `updater_paths.xml` exposes.
  factory UpdateEnvironment.device() => UpdateEnvironment(
        downloader: HttpUpdateDownloader(),
        installer: SystemApkInstaller(),
        abis: () async => (await DeviceInfoPlugin().androidInfo).supportedAbis,
        downloadDir: () async => Directory('${(await getTemporaryDirectory()).path}/updates'),
        supported: !kIsWeb && Platform.isAndroid,
      );
}

/// State machine of "check, download, verify, install", read by the update dialog.
class UpdateController extends ChangeNotifier {
  final String currentVersion;
  final ReleaseService releases;
  final UpdateEnvironment env;

  UpdateController({required this.currentVersion, required this.releases, required this.env});

  UpdatePhase _phase = UpdatePhase.checking;
  UpdateFailure? _failure;
  ReleaseInfo? _release;
  ApkChoice? _choice;
  int _received = 0;
  int? _total;
  CancelToken? _token;
  bool _disposed = false;

  UpdatePhase get phase => _phase;
  UpdateFailure? get failure => _failure;
  ReleaseInfo? get release => _release;
  ApkChoice? get choice => _choice;
  int get received => _received;
  int? get total => _total;
  bool get supported => env.supported;

  /// 0..1, null when the size is unknown.
  double? get progress {
    final t = _total;
    return t == null || t <= 0 ? null : (_received / t).clamp(0.0, 1.0);
  }

  void _set(UpdatePhase phase, [UpdateFailure? failure]) {
    _phase = phase;
    _failure = failure;
    if (!_disposed) notifyListeners();
  }

  /// Asks GitHub for the newest release.
  Future<void> check() async {
    _set(UpdatePhase.checking);
    try {
      final latest = await releases.latest();
      if (_disposed) return;
      _release = latest;
      if (latest == null) return _set(UpdatePhase.noRelease);
      if (!isNewerVersion(currentVersion, latest.tag)) return _set(UpdatePhase.upToDate);
      _choice = pickApk(latest.assets, await _safeAbis());
      if (!_disposed) _set(UpdatePhase.available);
    } catch (e) {
      debugPrint('Update check failed: $e');
      if (!_disposed) _set(UpdatePhase.failed, UpdateFailure.check);
    }
  }

  /// Downloads the package for this device, checks its SHA-1, then opens the installer.
  Future<void> downloadAndInstall() async {
    final release = _release;
    if (release == null || _phase == UpdatePhase.downloading || _phase == UpdatePhase.verifying) return;
    final choice = pickApk(release.assets, await _safeAbis());
    _choice = choice;
    if (choice == null) return _set(UpdatePhase.failed, UpdateFailure.noApk);
    final sha = choice.sha1;
    if (sha == null) return _set(UpdatePhase.failed, UpdateFailure.checksumMissing);

    final token = _token = CancelToken();
    _received = 0;
    _total = choice.apk.size > 0 ? choice.apk.size : null;
    _set(UpdatePhase.downloading);
    File? file;
    try {
      final expected = parseSha1File(await env.downloader.fetchText(Uri.parse(sha.url)));
      if (expected == null) return _set(UpdatePhase.failed, UpdateFailure.checksumMissing);
      if (token.isCancelled) return _set(UpdatePhase.available);

      final dir = await env.downloadDir();
      await _clean(dir);
      await dir.create(recursive: true);
      file = File('${dir.path}/${_safeName(choice.apk.name)}');
      await env.downloader.download(Uri.parse(choice.apk.url), file, token, (received, total) {
        _received = received;
        _total = total ?? _total;
        if (!_disposed) notifyListeners();
      });
      if (_disposed) return;

      _set(UpdatePhase.verifying);
      final actual = await sha1OfStream(file.openRead());
      if (actual != expected) {
        await _delete(file);
        return _set(UpdatePhase.failed, UpdateFailure.checksumMismatch);
      }
      final result = await env.installer.install(file.path);
      switch (result) {
        case InstallResult.started:
          _set(UpdatePhase.installing);
        case InstallResult.permissionDenied:
          _set(UpdatePhase.failed, UpdateFailure.permission);
        case InstallResult.failed:
          _set(UpdatePhase.failed, UpdateFailure.install);
      }
    } on UpdateCancelled {
      if (file != null) await _delete(file);
      if (!_disposed) _set(UpdatePhase.available);
    } catch (e) {
      debugPrint('Update download failed: $e');
      if (file != null) await _delete(file);
      if (!_disposed) _set(UpdatePhase.failed, UpdateFailure.download);
    }
  }

  /// Stops a running download; the partial file is deleted.
  void cancel() => _token?.cancel();

  /// Back to the screen offered after a failure that happened after the release was known.
  Future<void> retry() => _failure == UpdateFailure.check ? check() : downloadAndInstall();

  Future<List<String>> _safeAbis() async {
    try {
      return await env.abis();
    } catch (_) {
      return const [];
    }
  }

  static String _safeName(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<void> _clean(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel();
    super.dispose();
  }
}

/// "12.3 MB" style size, base 1024.
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '$bytes B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// The silent update check made once the home shell is on screen (DailyAL parity): at most
/// one GitHub request per [interval], never on F-Droid builds, never raising. A release is
/// offered once; the dialog it opens re-reads it from [prefetched], so no second request.
class LaunchUpdateCheck {
  static const String keyLastCheck = 'update_last_check_v1';
  static const String keyNotifiedTag = 'update_notified_tag_v1';
  static const Duration interval = Duration(hours: 24);

  final ReleaseService releases;
  final String currentVersion;
  final DateTime Function() now;

  /// False on F-Droid builds and on platforms that cannot install an APK.
  final bool enabled;

  LaunchUpdateCheck({
    required this.releases,
    required this.currentVersion,
    this.enabled = true,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  /// The release to announce, or null (disabled, checked today, up to date, already
  /// announced, offline or any failure).
  Future<ReleaseInfo?> run(SharedPreferences prefs) async {
    if (!enabled) return null;
    try {
      final last = prefs.getInt(keyLastCheck);
      final current = now();
      if (last != null) {
        final elapsed = current.difference(DateTime.fromMillisecondsSinceEpoch(last));
        if (!elapsed.isNegative && elapsed < interval) return null;
      }
      final latest = await releases.latest();
      await prefs.setInt(keyLastCheck, current.millisecondsSinceEpoch);
      if (latest == null || !isNewerVersion(currentVersion, latest.tag)) return null;
      if (prefs.getString(keyNotifiedTag) == latest.tag) return null;
      return latest;
    } catch (e) {
      debugPrint('Launch update check failed: $e');
      return null;
    }
  }

  /// Remembers that [tag] was shown, so it is not offered again.
  Future<void> markNotified(SharedPreferences prefs, String tag) => prefs.setString(keyNotifiedTag, tag);

  /// A [ReleaseService] that answers [release] to the first `latest()`, then asks GitHub.
  static ReleaseService prefetched(ReleaseService inner, ReleaseInfo release) => _PrefetchedReleases(inner, release);
}

class _PrefetchedReleases extends ReleaseService {
  final ReleaseService _inner;
  ReleaseInfo? _first;

  _PrefetchedReleases(this._inner, ReleaseInfo this._first);

  @override
  Future<ReleaseInfo?> latest() {
    final first = _first;
    if (first == null) return _inner.latest();
    _first = null;
    return Future.value(first);
  }

  @override
  Future<ReleaseInfo?> forVersion(String version) => _inner.forVersion(version);
}
