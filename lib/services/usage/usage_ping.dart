import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/frames/avatar_frames.dart' show kAvatarFramesApi;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Anonymous usage count: once a day at most, the app tells MyWatchList's back-end that this
/// install was used. It sends a random install id (made on this phone, tied to no account), the
/// app version, the platform, the language and which trackers are connected. Nothing else: no
/// name, no account id, no list.
class UsagePing {
  UsagePing({http.Client? client, this.baseUrl = kAvatarFramesApi, DateTime Function()? now})
      : _client = client,
        _now = now ?? DateTime.now;

  static UsagePing instance = UsagePing();

  static const String installIdKey = 'usage_install_id';
  static const String lastDayKey = 'usage_last_ping_day';

  final http.Client? _client;
  final String baseUrl;
  final DateTime Function() _now;

  static String trackerName(AccountType type) => switch (type) {
        AccountType.myanimelist => 'mal',
        AccountType.anilist => 'anilist',
        AccountType.kitsu => 'kitsu',
        AccountType.simkl => 'simkl',
        AccountType.none => '',
      };

  /// The id of this install, made on first use (32 hex characters).
  static Future<String> installId(SharedPreferences prefs) async {
    final saved = prefs.getString(installIdKey);
    if (saved != null && RegExp(r'^[0-9a-f]{32}$').hasMatch(saved)) return saved;
    final id = const Uuid().v4().replaceAll('-', '');
    await prefs.setString(installIdKey, id);
    return id;
  }

  /// Sends today's ping unless it was already sent today (UTC). Returns whether it was sent.
  /// Silent on any failure: it is tried again at the next launch.
  Future<bool> maybeSend({
    required String version,
    required String platform,
    required String locale,
    required List<AccountType> trackers,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final day = _now().toUtc().toIso8601String().substring(0, 10);
      if (prefs.getString(lastDayKey) == day) return false;
      final body = jsonEncode({
        'installId': await installId(prefs),
        'version': version,
        'platform': platform,
        'locale': locale,
        'trackers': [for (final t in trackers) if (trackerName(t).isNotEmpty) trackerName(t)],
      });
      final uri = Uri.parse('$baseUrl/api/ping');
      const headers = {'content-type': 'application/json'};
      final client = _client;
      final response = await (client != null
              ? client.post(uri, headers: headers, body: body)
              : http.post(uri, headers: headers, body: body))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;
      await prefs.setString(lastDayKey, day);
      return true;
    } catch (e) {
      debugPrint('UsagePing: not sent ($e)');
      return false;
    }
  }
}
