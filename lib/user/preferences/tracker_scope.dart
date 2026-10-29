import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/user/preferences/app_preferences.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/user/preferences/general_preferences.dart';
import 'package:mywatchlist/user/preferences/list_preferences.dart';
import 'package:mywatchlist/user/preferences/notification_preferences.dart';
import 'package:mywatchlist/user/preferences/preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which preferences belong to one tracker and where each tracker's copy is stored
/// (owner rule 2026-10-29: switching the active account is switching app, so every
/// tracker-related setting is kept per tracker).
///
/// ## Storage (frozen)
///
/// A tracker's copy of a stored key `<base>` lives under `<base>:<tracker>`, with
/// `<tracker>` = [AccountType.name] ([key]). For the preference groups of
/// [PreferencesStore]:
///
/// * `prefs_general_v1:<tracker>`, `prefs_content_v1:<tracker>`, `prefs_list_v1:<tracker>`
///   hold only that tracker's fields (every field of the group except [appFields]);
/// * the global `prefs_*_v1` blobs keep the app fields, and stay the fallback of a tracker
///   that never saved its own value (so nobody loses a setting and no migration is needed
///   to start reading per tracker);
/// * `prefs_notifications_v1` is never split here (the notifications units own it).
///
/// Other per-tracker keys (home layout, bookmarks filter…) use [key] on their own base.
abstract final class TrackerScope {
  /// The groups of [PreferencesStore] with a per-tracker copy.
  static const List<String> scopedGroups = [
    PreferencesStore.keyGeneral,
    PreferencesStore.keyContent,
    PreferencesStore.keyList,
  ];

  /// Fields (JSON names) of each scoped group shared by every tracker: app behaviour and
  /// looks. Every other field of a scoped group is tracker-scoped, new fields included.
  static const Map<String, Set<String>> appFields = {
    PreferencesStore.keyGeneral: {'keepPagesInMemory', 'statsChartColors'},
    PreferencesStore.keyContent: {'timezone'},
    PreferencesStore.keyList: {},
  };

  /// The trackers that have their own copy (every [AccountType] but `none`).
  static const List<AccountType> trackers = [
    AccountType.myanimelist,
    AccountType.anilist,
    AccountType.kitsu,
    AccountType.simkl,
  ];

  /// The stored key of [tracker]'s copy of [base]: `<base>:<tracker>`. Throws for `none`.
  static String key(String base, AccountType tracker) {
    if (tracker == AccountType.none) {
      throw ArgumentError.value(tracker, 'tracker', 'no per-tracker copy without a tracker');
    }
    return '$base:${tracker.name}';
  }

  /// Whether [field] of [group] is stored per tracker (false for a group not in
  /// [scopedGroups]).
  static bool isTrackerField(String group, String field) =>
      scopedGroups.contains(group) && !(appFields[group]?.contains(field) ?? false);
}

/// Per-tracker reads and writes of [PreferencesStore] (the background isolate, which has no
/// active tracker, reads with an explicit one).
///
/// `readFor(AccountType.none)` / `writeFor(AccountType.none, …)` are [PreferencesStore.read]
/// / [PreferencesStore.write] (no tracker signed in).
extension TrackerScopedPreferences on PreferencesStore {
  /// [tracker]'s preferences: tracker fields from its own copy, falling back field by
  /// field to the global group, app fields and notifications from the global groups.
  AppPreferences readFor(AccountType tracker) {
    if (tracker == AccountType.none) return read();
    Map<String, dynamic> group(String base) {
      final merged = _decodeKey(prefs, base) ?? <String, dynamic>{};
      final own = _decodeKey(prefs, TrackerScope.key(base, tracker));
      if (own != null) {
        own.forEach((field, value) {
          if (TrackerScope.isTrackerField(base, field)) merged[field] = value;
        });
      }
      return merged;
    }

    final global = read();
    return AppPreferences(
      general: GeneralPreferences.fromJson(group(PreferencesStore.keyGeneral)),
      // The global read folds in the legacy time zone key.
      content: ContentPreferences.fromJson({
        ...global.content.toJson(),
        ...group(PreferencesStore.keyContent),
      }),
      list: ListPreferences.fromJson(group(PreferencesStore.keyList)),
      notifications: global.notifications,
    );
  }

  /// Saves [next] as [tracker]'s preferences: tracker fields into its own copy, app fields
  /// into the global groups (other trackers' fallback values are left untouched);
  /// [NotificationPreferences] into the global group. Only groups that differ from
  /// [previous] are written (all of them when null).
  Future<void> writeFor(AccountType tracker, AppPreferences next, {AppPreferences? previous}) async {
    if (tracker == AccountType.none) return write(next, previous: previous);
    Future<void> group(String base, Map<String, dynamic> json) async {
      final own = <String, dynamic>{};
      final global = _decodeKey(prefs, base) ?? <String, dynamic>{};
      json.forEach((field, value) {
        if (TrackerScope.isTrackerField(base, field)) {
          own[field] = value;
        } else {
          global[field] = value;
        }
      });
      await prefs.setString(TrackerScope.key(base, tracker), jsonEncode(own));
      if ((TrackerScope.appFields[base] ?? const {}).isNotEmpty) {
        await prefs.setString(base, jsonEncode(global));
      }
    }

    if (previous == null || next.general != previous.general) {
      await group(PreferencesStore.keyGeneral, next.general.toJson());
    }
    if (previous == null || next.content != previous.content) {
      await group(PreferencesStore.keyContent, next.content.toJson());
    }
    if (previous == null || next.list != previous.list) {
      await group(PreferencesStore.keyList, next.list.toJson());
    }
    if (previous == null || next.notifications != previous.notifications) {
      await prefs.setString(
          PreferencesStore.keyNotifications, jsonEncode(next.notifications.toJson()));
    }
  }

  /// Hook for the one-time move of the global values into every tracker's copy. Does
  /// nothing: [readFor] falls back to the global groups, so no copy is needed yet. The
  /// prefs-per-tracker unit fills it if its split needs one; `main` may await it once
  /// before creating the bloc. Idempotent.
  Future<void> migrateToTrackerScope() async {}

  /// Deletes [tracker]'s own copies (it falls back to the global values again).
  Future<void> clearFor(AccountType tracker) async {
    if (tracker == AccountType.none) return;
    for (final base in TrackerScope.scopedGroups) {
      await prefs.remove(TrackerScope.key(base, tracker));
    }
  }

}

Map<String, dynamic>? _decodeKey(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key);
  if (raw == null) return null;
  try {
    final value = jsonDecode(raw);
    if (value is Map) return Map<String, dynamic>.from(value);
  } catch (e) {
    debugPrint('TrackerScope: unreadable $key, using defaults ($e)');
  }
  return null;
}
