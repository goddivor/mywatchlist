import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/user/preferences/app_preferences.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/user/preferences/general_preferences.dart';
import 'package:mywatchlist/user/preferences/list_preferences.dart';
import 'package:mywatchlist/user/preferences/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists [AppPreferences] in SharedPreferences: one JSON string per group.
///
/// Reading never throws: a missing, corrupted or partly unknown group falls back to its
/// defaults field by field. Usable without the bloc (background isolate, notification
/// callbacks): `PreferencesStore(await SharedPreferences.getInstance()).read()`.
class PreferencesStore {
  static const String keyGeneral = 'prefs_general_v1';
  static const String keyContent = 'prefs_content_v1';
  static const String keyList = 'prefs_list_v1';
  static const String keyNotifications = 'prefs_notifications_v1';

  /// Written by `UserPreference.setTimezonePref` before this contract existed.
  static const String legacyKeyTimezone = 'timezone_pref';

  final SharedPreferences prefs;

  const PreferencesStore(this.prefs);

  /// Saved preferences, with legacy values folded in when their group was never saved.
  AppPreferences read() {
    return AppPreferences(
      general: GeneralPreferences.fromJson(_decode(keyGeneral) ?? const {}),
      content: _readContent(),
      list: ListPreferences.fromJson(_decode(keyList) ?? const {}),
      notifications: NotificationPreferences.fromJson(_decode(keyNotifications) ?? const {}),
    );
  }

  /// Moves legacy keys into the new groups and deletes them. Idempotent; `main` awaits it
  /// once before creating the bloc.
  Future<void> migrateLegacy() async {
    if (prefs.containsKey(legacyKeyTimezone)) {
      if (!prefs.containsKey(keyContent)) {
        await _write(keyContent, _readContent().toJson());
      }
      await prefs.remove(legacyKeyTimezone);
    }
  }

  /// Saves the groups of [next] that differ from [previous] (all of them when null).
  Future<void> write(AppPreferences next, {AppPreferences? previous}) async {
    if (previous == null || next.general != previous.general) {
      await _write(keyGeneral, next.general.toJson());
    }
    if (previous == null || next.content != previous.content) {
      await _write(keyContent, next.content.toJson());
    }
    if (previous == null || next.list != previous.list) {
      await _write(keyList, next.list.toJson());
    }
    if (previous == null || next.notifications != previous.notifications) {
      await _write(keyNotifications, next.notifications.toJson());
    }
  }

  /// Deletes every saved group (back to defaults).
  Future<void> clear() async {
    for (final key in const [keyGeneral, keyContent, keyList, keyNotifications]) {
      await prefs.remove(key);
    }
  }

  ContentPreferences _readContent() {
    final saved = _decode(keyContent);
    if (saved != null) return ContentPreferences.fromJson(saved);
    final legacy = prefs.getString(legacyKeyTimezone);
    return ContentPreferences.fromJson({if (legacy != null) 'timezone': legacy});
  }

  Map<String, dynamic>? _decode(String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (e) {
      debugPrint('PreferencesStore: unreadable $key, using defaults ($e)');
    }
    return null;
  }

  Future<void> _write(String key, Map<String, dynamic> json) =>
      prefs.setString(key, jsonEncode(json));
}
