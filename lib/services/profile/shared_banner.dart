import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/frames/avatar_frames.dart' show kAvatarFramesApi;
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What [SharedBanners.sync] did.
enum BannerSync {
  /// Nothing to do: the local banner is the one online, or there is none anywhere.
  upToDate,

  /// Removed on another phone: removed here too.
  removedLocal,

  /// Removed on this phone while it could not reach the back-end: removed online too.
  removedOnline,

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

  static String _stateKey(String username) => 'shared_banner_state:${username.trim().toLowerCase()}';

  /// The hashes of the local and the online banner at the last sync, null when never synced.
  static Future<({String? local, String? online})?> lastSync(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey(username));
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (local: map['local'] as String?, online: map['online'] as String?);
  }

  static Future<void> _remember(String username, {String? local, String? online}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey(username), jsonEncode({'local': local, 'online': online}));
  }

  /// Makes the local banner and the online one the same, in the background. What changed since
  /// the last sync decides:
  /// - only this phone's banner (picked, removed, or set before this update) → online follows;
  /// - only the online one (changed or removed on another phone) → this phone follows;
  /// - never synced (first launch after the update, new phone): the online banner wins when
  ///   there is one, else the local one is uploaded.
  /// [save] stores downloaded bytes as the local banner; [removeLocal] drops it.
  Future<BannerSync> sync({
    required String username,
    required String? localPath,
    required Future<void> Function(List<int> bytes) save,
    Future<void> Function()? removeLocal,
  }) async {
    try {
      final mine = await _auth((client, token) => client.get(Uri.parse('$baseUrl/api/banner/mine'), headers: _headers(token)));
      if (mine == null || mine.statusCode != 200) return BannerSync.failed;
      final body = jsonDecode(utf8.decode(mine.bodyBytes)) as Map<String, dynamic>;
      final onlineHash = body['hash'] as String?;
      final onlineUrl = body['url'] as String?;

      final file = localPath == null ? null : File(localPath);
      final bytes = file != null && await file.exists() ? await file.readAsBytes() : null;
      final localHash = bytes == null ? null : hashOf(bytes);
      final last = await lastSync(username);

      if (localHash == null && onlineHash == null) {
        await _remember(username);
        return BannerSync.upToDate;
      }
      if (localHash != null && localHash == onlineHash) {
        await _remember(username, local: localHash, online: onlineHash);
        return BannerSync.upToDate;
      }
      final localChanged = last == null || last.local != localHash;
      final onlineChanged = last == null || last.online != onlineHash;
      if (!localChanged && !onlineChanged) return BannerSync.upToDate;

      // The online banner wins when it changed (or on the first sync, when there is one).
      final takeOnline = onlineChanged && (last != null || onlineHash != null);
      if (takeOnline) {
        if (onlineUrl == null) {
          if (removeLocal != null && bytes != null) await removeLocal();
          await _remember(username);
          return bytes == null ? BannerSync.upToDate : BannerSync.removedLocal;
        }
        final download = await _get(Uri.parse(onlineUrl));
        if (download.statusCode != 200 || download.bodyBytes.isEmpty) return BannerSync.failed;
        await save(download.bodyBytes);
        await _remember(username, local: hashOf(download.bodyBytes), online: onlineHash);
        return BannerSync.downloaded;
      }
      if (bytes == null) {
        // Removed on this phone (e.g. offline at the time): remove it online too.
        return await remove(username: username) ? BannerSync.removedOnline : BannerSync.failed;
      }
      return await upload(username: username, bytes: bytes) ? BannerSync.uploaded : BannerSync.failed;
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
      await _remember(username, local: hash, online: hash);
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
      await _remember(username);
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
