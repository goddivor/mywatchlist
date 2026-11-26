import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/frames/avatar_frames.dart' show kAvatarFramesApi;
import 'package:mywatchlist/user/user_mal_v2.dart';

/// What [SharedBanners.sync] did.
enum BannerSync {
  /// Nothing to do: the local banner is the one online, or there is none anywhere.
  upToDate,

  /// The local banner was not online (set before the update, or changed): it was uploaded.
  uploaded,

  /// No local banner but one online (new phone, reinstall): it was downloaded.
  downloaded,

  /// Signed out of MAL, offline, or the back-end failed: tried again at the next launch.
  failed,
}

/// The banner a MAL user sets in the sidebar, shared through MyWatchList's back-end so every
/// user sees it on that user's profile, and so it follows the MAL account to another phone.
///
/// The back-end keeps, per MAL account, the SHA-1 of the uploaded file: comparing it with the
/// local file tells whether the local banner is online, without sending it.
class SharedBanners {
  SharedBanners({
    http.Client? client,
    this.baseUrl = kAvatarFramesApi,
    this.ttl = const Duration(minutes: 2),
    DateTime Function()? now,
    Future<http.Response?> Function(Future<http.Response> Function(http.Client, String))? authenticated,
  })  : _client = client,
        _now = now ?? DateTime.now,
        _authenticated = authenticated;

  static SharedBanners instance = SharedBanners();

  final http.Client? _client;
  final String baseUrl;
  final Duration ttl;
  final DateTime Function() _now;
  final Future<http.Response?> Function(Future<http.Response> Function(http.Client, String))? _authenticated;

  final Map<String, ({String? url, DateTime until})> _cache = {};
  final Map<String, Future<String?>> _loading = {};

  Future<http.Response> _get(Uri uri) {
    final client = _client;
    return (client != null ? client.get(uri) : http.get(uri)).timeout(const Duration(seconds: 10));
  }

  Future<http.Response?> _auth(Future<http.Response> Function(http.Client, String) send) =>
      _authenticated != null ? _authenticated(send) : UserMalV2.instance.sendAuthenticated(send);

  Map<String, String> _headers(String token) => {'Authorization': 'Bearer $token', 'content-type': 'application/json'};

  /// The banner [username] shares (null: none, or the back-end could not answer).
  Future<String?> urlOf(String username) {
    final key = username.trim().toLowerCase();
    if (key.isEmpty) return Future.value();
    final cached = _cache[key];
    if (cached != null && cached.until.isAfter(_now())) return Future.value(cached.url);
    // A block, not `=> remove(...)`: remove returns this very future, and whenComplete would
    // wait for it (itself) forever.
    return _loading[key] ??= _fetch(key).whenComplete(() {
      _loading.remove(key);
    });
  }

  Future<String?> _fetch(String key) async {
    try {
      final response = await _get(Uri.parse('$baseUrl/api/banner').replace(queryParameters: {'user': key}));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final url = body is Map && body['url'] is String ? body['url'] as String : null;
      _cache[key] = (url: url, until: _now().add(ttl));
      return url;
    } catch (e) {
      debugPrint('SharedBanners: lookup failed ($e)');
      return null;
    }
  }

  static String hashOf(List<int> bytes) => sha1.convert(bytes).toString();

  /// Makes the local banner and the online one the same, in the background:
  /// - local banner not online (e.g. set before this update) → uploaded;
  /// - no local banner but one online (another phone, reinstall) → downloaded with [save];
  /// - otherwise nothing.
  /// [localPath] is the current local banner; [save] stores downloaded bytes as the local one.
  Future<BannerSync> sync({
    required String username,
    required String? localPath,
    required Future<void> Function(List<int> bytes) save,
  }) async {
    try {
      final mine = await _auth((client, token) => client.get(Uri.parse('$baseUrl/api/banner/mine'), headers: _headers(token)));
      if (mine == null || mine.statusCode != 200) return BannerSync.failed;
      final body = jsonDecode(utf8.decode(mine.bodyBytes)) as Map<String, dynamic>;
      final onlineHash = body['hash'] as String?;
      final onlineUrl = body['url'] as String?;

      final file = localPath == null ? null : File(localPath);
      if (file != null && await file.exists()) {
        final bytes = await file.readAsBytes();
        if (hashOf(bytes) == onlineHash) return BannerSync.upToDate;
        return await upload(username: username, bytes: bytes) ? BannerSync.uploaded : BannerSync.failed;
      }
      if (onlineUrl == null) return BannerSync.upToDate;
      final download = await _get(Uri.parse(onlineUrl));
      if (download.statusCode != 200 || download.bodyBytes.isEmpty) return BannerSync.failed;
      await save(download.bodyBytes);
      return BannerSync.downloaded;
    } catch (e) {
      debugPrint('SharedBanners: sync failed ($e)');
      return BannerSync.failed;
    }
  }

  /// Uploads [bytes] as the signed-in MAL account's banner: the back-end signs an upload for that
  /// account only, the file goes straight to Cloudinary, then the back-end records it.
  Future<bool> upload({required String username, required List<int> bytes}) async {
    try {
      final signed = await _auth((client, token) => client.post(Uri.parse('$baseUrl/api/banner/mine'), headers: _headers(token)));
      if (signed == null || signed.statusCode != 200) return false;
      final ticket = jsonDecode(utf8.decode(signed.bodyBytes)) as Map<String, dynamic>;
      final request = http.MultipartRequest('POST', Uri.parse(ticket['url'] as String))
        ..fields.addAll({for (final e in (ticket['fields'] as Map).entries) '${e.key}': '${e.value}'})
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'banner.jpg'));
      final client = _client ?? http.Client();
      try {
        final sent = await client.send(request).timeout(const Duration(seconds: 60));
        await sent.stream.drain<void>();
        if (sent.statusCode != 200) return false;
      } finally {
        if (_client == null) client.close();
      }
      final hash = hashOf(bytes);
      final recorded = await _auth((client, token) => client.put(
            Uri.parse('$baseUrl/api/banner'),
            headers: _headers(token),
            body: jsonEncode({'hash': hash}),
          ));
      if (recorded == null || recorded.statusCode != 200) return false;
      final url = (jsonDecode(utf8.decode(recorded.bodyBytes)) as Map)['url'] as String?;
      _cache[username.trim().toLowerCase()] = (url: url, until: _now().add(ttl));
      return true;
    } catch (e) {
      debugPrint('SharedBanners: upload failed ($e)');
      return false;
    }
  }

  /// Removes the signed-in MAL account's banner from the back-end.
  Future<bool> remove({required String username}) async {
    try {
      final response = await _auth((client, token) => client.delete(Uri.parse('$baseUrl/api/banner'), headers: _headers(token)));
      if (response == null || response.statusCode != 200) return false;
      _cache[username.trim().toLowerCase()] = (url: null, until: _now().add(ttl));
      return true;
    } catch (e) {
      debugPrint('SharedBanners: remove failed ($e)');
      return false;
    }
  }

  @visibleForTesting
  void reset() {
    _cache.clear();
    _loading.clear();
  }
}
