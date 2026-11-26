import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/user/user_mal_v2.dart';

/// MyWatchList's own back-end (Vercel), which keeps the avatar frames: who may wear which frame,
/// until when, and the frame each user wears.
const String kAvatarFramesApi = 'https://mywatchlist-api.vercel.app';

/// A frame drawn around an avatar. [scale] is the frame size over the avatar size; [dx] and [dy]
/// shift the frame (in avatar sizes) so the avatar sits in its hole.
@immutable
class AvatarFrame {
  final String id;
  final String imageUrl;
  final double scale;
  final double dx;
  final double dy;

  const AvatarFrame({
    required this.id,
    required this.imageUrl,
    this.scale = 1.3,
    this.dx = 0,
    this.dy = 0,
  });

  static AvatarFrame? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final url = json['imageUrl'];
    if (id is! String || url is! String || url.isEmpty) return null;
    double number(Object? v, double fallback) => v is num && v.isFinite ? v.toDouble() : fallback;
    return AvatarFrame(
      id: id,
      imageUrl: url,
      scale: number(json['scale'], 1.3).clamp(1.0, 2.0),
      dx: number(json['dx'], 0).clamp(-0.5, 0.5),
      dy: number(json['dy'], 0).clamp(-0.5, 0.5),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarFrame &&
      other.id == id &&
      other.imageUrl == imageUrl &&
      other.scale == scale &&
      other.dx == dx &&
      other.dy == dy;

  @override
  int get hashCode => Object.hash(id, imageUrl, scale, dx, dy);
}

/// A frame the signed-in account may wear, with the end of that right (null: no end).
@immutable
class OwnedFrame {
  final AvatarFrame frame;
  final String name;
  final DateTime? expiresAt;

  const OwnedFrame({required this.frame, required this.name, this.expiresAt});
}

/// The frames of the signed-in MAL account and the one it wears.
@immutable
class MyFrames {
  final List<OwnedFrame> available;
  final String? equipped;

  const MyFrames({required this.available, this.equipped});

  static MyFrames fromJson(Map<String, dynamic> json) {
    final list = json['available'];
    final available = <OwnedFrame>[];
    if (list is List) {
      for (final item in list) {
        final frame = AvatarFrame.fromJson(item);
        if (item is! Map || frame == null) continue;
        final name = item['name'];
        final expires = item['expiresAt'];
        available.add(OwnedFrame(
          frame: frame,
          name: name is String ? name : frame.id,
          expiresAt: expires is String ? DateTime.tryParse(expires) : null,
        ));
      }
    }
    final equipped = json['equipped'];
    return MyFrames(available: available, equipped: equipped is String ? equipped : null);
  }
}

/// Reads the frames MAL users wear. Avatars ask for their user ([frameOf]); the names asked
/// within [batchWindow] (zero: in the same frame build, without a timer) go in one request, and answers (no frame included) are kept [ttl].
/// Listeners hear when a cached answer changes (e.g. after [equip]).
class AvatarFrames extends ChangeNotifier {
  AvatarFrames({
    http.Client? client,
    this.baseUrl = kAvatarFramesApi,
    this.ttl = const Duration(minutes: 2),
    this.failureTtl = const Duration(minutes: 1),
    this.batchWindow = Duration.zero,
    DateTime Function()? now,
    Future<http.Response?> Function(Future<http.Response> Function(http.Client, String))? authenticated,
  })  : _client = client,
        _now = now ?? DateTime.now,
        _authenticated = authenticated;

  static AvatarFrames instance = AvatarFrames();

  /// Most names one request carries (the back-end takes 60).
  static const int maxBatch = 50;

  final http.Client? _client;
  final String baseUrl;
  final Duration ttl;
  final Duration failureTtl;
  final Duration batchWindow;
  final DateTime Function() _now;
  final Future<http.Response?> Function(Future<http.Response> Function(http.Client, String))? _authenticated;

  final Map<String, ({AvatarFrame? frame, DateTime until})> _cache = {};
  final Map<String, Completer<AvatarFrame?>> _waiting = {};
  Timer? _flush;
  bool _scheduled = false;

  static String _key(String username) => username.trim().toLowerCase();

  /// Whether a fresh answer is cached for [username] (it may be "no frame").
  bool isKnown(String username) {
    final entry = _cache[_key(username)];
    return entry != null && entry.until.isAfter(_now());
  }

  /// The cached frame of [username], null when none or not known yet.
  AvatarFrame? cached(String username) {
    final entry = _cache[_key(username)];
    return entry != null && entry.until.isAfter(_now()) ? entry.frame : null;
  }

  /// The frame [username] wears (null: none, or the back-end could not be reached).
  Future<AvatarFrame?> frameOf(String username) {
    final key = _key(username);
    if (key.isEmpty) return Future.value(null);
    if (isKnown(key)) return Future.value(_cache[key]!.frame);
    final waiting = _waiting[key];
    if (waiting != null) return waiting.future;
    final completer = Completer<AvatarFrame?>();
    _waiting[key] = completer;
    if (!_scheduled) {
      _scheduled = true;
      if (batchWindow == Duration.zero) {
        scheduleMicrotask(_send);
      } else {
        _flush = Timer(batchWindow, _send);
      }
    }
    return completer.future;
  }

  Future<void> _send() async {
    _flush = null;
    _scheduled = false;
    final batch = Map.of(_waiting);
    _waiting.clear();
    final names = batch.keys.toList();
    for (var i = 0; i < names.length; i += maxBatch) {
      final part = names.sublist(i, i + maxBatch > names.length ? names.length : i + maxBatch);
      final found = await _lookup(part);
      final until = _now().add(found == null ? failureTtl : ttl);
      for (final name in part) {
        final frame = found?[name];
        _cache[name] = (frame: frame, until: until);
        batch[name]!.complete(frame);
      }
    }
  }

  /// One request for [names]; null when the back-end could not answer.
  Future<Map<String, AvatarFrame>?> _lookup(List<String> names) async {
    final uri = Uri.parse('$baseUrl/api/frames/equipped')
        .replace(queryParameters: {'tracker': 'mal', 'users': names.join(',')});
    try {
      final client = _client;
      final response = await (client != null ? client.get(uri) : http.get(uri)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final frames = body is Map ? body['frames'] : null;
      if (frames is! Map) return null;
      final result = <String, AvatarFrame>{};
      for (final entry in frames.entries) {
        final frame = AvatarFrame.fromJson(entry.value);
        if (entry.key is String && frame != null) result[entry.key as String] = frame;
      }
      return result;
    } catch (e) {
      debugPrint('AvatarFrames: lookup failed ($e)');
      return null;
    }
  }

  /// Stores [frame] as [username]'s answer and tells the listeners.
  void put(String username, AvatarFrame? frame) {
    final key = _key(username);
    final before = _cache[key]?.frame;
    _cache[key] = (frame: frame, until: _now().add(ttl));
    if (before != frame) notifyListeners();
  }

  Future<http.Response?> _sendAuthenticated(Future<http.Response> Function(http.Client, String) send) =>
      _authenticated != null ? _authenticated(send) : UserMalV2.instance.sendAuthenticated(send);

  /// The signed-in MAL account's frames; null when signed out or unreachable.
  Future<MyFrames?> mine() => _mine(null, put: false);

  /// Wears the frame [frameId] (null: none) on the signed-in MAL account. Returns the new state,
  /// null on failure. [username] is the account's MAL name, so its avatars update at once.
  Future<MyFrames?> equip(String? frameId, {required String username}) async {
    final result = await _mine(frameId, put: true);
    if (result != null) {
      final worn = result.available.where((o) => o.frame.id == result.equipped).map((o) => o.frame);
      put(username, worn.isEmpty ? null : worn.first);
    }
    return result;
  }

  Future<MyFrames?> _mine(String? frameId, {required bool put}) async {
    final uri = Uri.parse('$baseUrl/api/frames/mine');
    try {
      final response = await _sendAuthenticated((client, token) {
        final headers = {'Authorization': 'Bearer $token', 'content-type': 'application/json'};
        return put
            ? client.put(uri, headers: headers, body: jsonEncode({'frameId': frameId}))
            : client.get(uri, headers: headers);
      });
      if (response == null || response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body is Map<String, dynamic> ? MyFrames.fromJson(body) : null;
    } catch (e) {
      debugPrint('AvatarFrames: ${put ? 'equip' : 'mine'} failed ($e)');
      return null;
    }
  }

  @visibleForTesting
  void reset() {
    _flush?.cancel();
    _flush = null;
    _scheduled = false;
    _cache.clear();
    _waiting.clear();
  }
}
