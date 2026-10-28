import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String updaterRepo = 'goddivor/mywatchlist';
const String updaterRepoUrl = 'https://github.com/$updaterRepo';

/// One file attached to a GitHub release.
class ReleaseAsset {
  final String name;
  final String url;
  final int size;

  const ReleaseAsset({required this.name, required this.url, this.size = 0});

  /// Null when the entry has no usable name or download URL.
  static ReleaseAsset? tryParse(Object? json) {
    if (json is! Map) return null;
    final name = json['name'], url = json['browser_download_url'];
    if (name is! String || url is! String || name.isEmpty || url.isEmpty) return null;
    final size = json['size'];
    return ReleaseAsset(name: name, url: url, size: size is int ? size : 0);
  }
}

/// A GitHub release, as much of it as the About page and the updater need.
class ReleaseInfo {
  final String tag;
  final String? body;
  final String url;
  final List<ReleaseAsset> assets;

  const ReleaseInfo({required this.tag, this.body, required this.url, this.assets = const []});

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    if (tag is! String || tag.isEmpty) {
      throw const FormatException('Release without a tag');
    }
    final rawAssets = json['assets'];
    return ReleaseInfo(
      tag: tag,
      body: json['body'] is String ? json['body'] as String : null,
      url: json['html_url'] is String ? json['html_url'] as String : '$updaterRepoUrl/releases/tag/$tag',
      assets: rawAssets is List
          ? rawAssets.map(ReleaseAsset.tryParse).whereType<ReleaseAsset>().toList()
          : const [],
    );
  }
}

/// Reads releases of the project from the GitHub API.
class ReleaseService {
  final http.Client _client;

  ReleaseService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _api = Uri.parse('https://api.github.com/repos/$updaterRepo/releases');

  /// The release published for [version] (tag `2026.10.1`), or null when there is none.
  Future<ReleaseInfo?> forVersion(String version) => _get('tags/$version');

  /// The newest release, or null when none was published.
  Future<ReleaseInfo?> latest() => _get('latest');

  Future<ReleaseInfo?> _get(String path) async {
    final response = await _client.get(
      Uri.parse('$_api/$path'),
      headers: const {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw HttpException('GitHub answered ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException('Unexpected answer');
    return ReleaseInfo.fromJson(decoded);
  }
}

/// The numeric parts of a `yyyy.m.n` version (a leading `v` and a `+build` suffix ignored),
/// or null when it is not made of dot separated numbers.
List<int>? parseVersionName(String v) {
  final core = v.trim().replaceFirst(RegExp('^[vV]'), '').split('+').first;
  final parts = core.split('.').map(int.tryParse).toList();
  return parts.contains(null) || parts.isEmpty ? null : parts.cast<int>();
}

/// True when [latest] is a higher `yyyy.m.n` than [current]; unreadable versions never count
/// as newer. The build code (`+n`) is not part of a release tag, so it is ignored.
bool isNewerVersion(String current, String latest) {
  final a = parseVersionName(current), b = parseVersionName(latest);
  if (a == null || b == null) return false;
  for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (y != x) return y > x;
  }
  return false;
}

/// The package to install, with the checksum file published next to it (null when absent).
class ApkChoice {
  final ReleaseAsset apk;
  final ReleaseAsset? sha1;

  const ApkChoice(this.apk, this.sha1);
}

/// Picks the APK built for the first of the device's [abis] that the release carries (split
/// APKs `...-<abi>.apk`), else the universal one (`...-universal.apk`); null when none exists.
ApkChoice? pickApk(List<ReleaseAsset> assets, List<String> abis) {
  ReleaseAsset? find(String suffix) {
    for (final a in assets) {
      if (a.name.toLowerCase().endsWith(suffix)) return a;
    }
    return null;
  }

  final apk = [for (final abi in abis) find('-${abi.toLowerCase()}.apk')]
          .whereType<ReleaseAsset>()
          .firstOrNull ??
      find('-universal.apk');
  if (apk == null) return null;
  ReleaseAsset? sha;
  for (final a in assets) {
    if (a.name == '${apk.name}.sha1') sha = a;
  }
  return ApkChoice(apk, sha);
}
