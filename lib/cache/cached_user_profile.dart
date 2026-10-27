import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A cached profile payload and when it was stored.
class CachedProfileEntry {
  final Map<String, dynamic> json;
  final DateTime savedAt;

  const CachedProfileEntry(this.json, this.savedAt);

  Duration get age => DateTime.now().difference(savedAt);
}

/// Disk cache of the MyAnimeList profiles the user looked at (one JSON per username, in
/// SharedPreferences). The profile screen shows a fresh entry without any request and falls
/// back to a stale one when the network fails.
class CachedUserProfile {
  CachedUserProfile._();

  static final CachedUserProfile instance = CachedUserProfile._();

  /// A profile younger than this is shown without a request.
  static const Duration freshFor = Duration(hours: 1);

  /// Oldest entry still served when the network fails.
  static const Duration staleFor = Duration(days: 14);

  static const String _prefix = 'cached_user_profile_v1_';

  static String _key(String username) => '$_prefix${username.trim().toLowerCase()}';

  Future<CachedProfileEntry?> read(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(username));
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(map['savedAt'] as String? ?? '');
      final data = map['data'];
      if (savedAt == null || data is! Map<String, dynamic>) return null;
      final entry = CachedProfileEntry(data, savedAt);
      return entry.age > staleFor ? null : entry;
    } catch (e) {
      if (kDebugMode) debugPrint('CachedUserProfile.read: $e');
      return null;
    }
  }

  Future<void> write(String username, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(username),
        jsonEncode({'savedAt': DateTime.now().toIso8601String(), 'data': data}),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('CachedUserProfile.write: $e');
    }
  }

  Future<void> remove(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(username));
    } catch (e) {
      if (kDebugMode) debugPrint('CachedUserProfile.remove: $e');
    }
  }
}
