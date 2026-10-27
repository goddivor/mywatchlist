import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:shared_preferences/shared_preferences.dart';

/// What the cache knows about one entry of the user's list.
@immutable
class CachedListStatus {
  /// The tracker's list status in MAL's words (`watching`, `reading`,
  /// `completed`, `on_hold`, `dropped`, `plan_to_watch`, `plan_to_read`), so
  /// badges read the same whatever the tracker.
  final String status;

  /// The user's score, 0-10 (0 = not scored).
  final int score;

  /// Episodes watched or chapters read.
  final int progress;

  const CachedListStatus({required this.status, this.score = 0, this.progress = 0});

  List<Object> _toJson() => [status, score, progress];

  static CachedListStatus? _fromJson(Object? json) {
    if (json is List && json.isNotEmpty && json[0] is String) {
      int at(int i) => json.length > i && json[i] is int ? json[i] as int : 0;
      return CachedListStatus(status: json[0] as String, score: at(1), progress: at(2));
    }
    if (json is String && json.isNotEmpty) return CachedListStatus(status: json);
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is CachedListStatus &&
      other.status == status &&
      other.score == score &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(status, score, progress);

  @override
  String toString() => 'CachedListStatus($status, $score, $progress)';
}

/// The list status of every anime and manga the user's lists have shown,
/// kept across restarts (DailyAL `UserListCache`, b490f94 / 5f1a965), so that
/// any card (home, search, seasonal, rankings…) can show a status badge
/// without asking the tracker.
///
/// Keys are `(tracker, category, id)` with the tracker's own id: MAL ids for
/// [AccountType.myanimelist]. Writers are the list pages (each loaded page,
/// each edit, each removal); readers never wait for the network.
///
/// ```dart
/// // Anywhere, synchronous (null before the first load or when not listed):
/// final s = ListStatusCache.instance.statusOf(5114, category: 'anime');
/// // A card that follows edits:
/// ValueListenableBuilder(
///   valueListenable: ListStatusCache.instance.watch(5114, category: 'anime'),
///   builder: (context, CachedListStatus? s, _) => s == null ? SizedBox() : Badge(s.status),
/// );
/// ```
///
/// Storage: one SharedPreferences string per tracker and category,
/// `list_status_cache_v1:<tracker>:<category>` =
/// `{"owner": "<username>", "items": {"<id>": [status, score, progress]}}`,
/// written at most once per [saveDelay]. The legacy DailyAL keys are not read.
class ListStatusCache extends ChangeNotifier {
  ListStatusCache({this.saveDelay = const Duration(milliseconds: 600)});

  static ListStatusCache instance = ListStatusCache();

  /// Pause between a change and its write to disk (many changes, one write).
  final Duration saveDelay;

  static const String _prefix = 'list_status_cache_v1';

  final Map<String, Map<int, CachedListStatus>> _items = {};
  final Map<String, String?> _owners = {};
  final Map<String, ValueNotifier<CachedListStatus?>> _watchers = {};
  final Set<String> _dirty = {};
  Future<void>? _loading;
  bool _loaded = false;
  Timer? _saveTimer;

  /// True once the saved statuses are in memory.
  bool get isLoaded => _loaded;

  /// Loads the saved statuses once; later calls return the same future.
  /// Called by the list pages; call it early (e.g. at startup) so cards
  /// have badges from the first frame.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith('$_prefix:')) continue;
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) continue;
        final bucket = key.substring(_prefix.length + 1);
        final decoded = raw.length > 32 * 1024
            ? await compute(_decode, raw)
            : _decode(raw);
        if (decoded == null) continue;
        final items = _items.putIfAbsent(bucket, () => {});
        // Entries written while loading are newer than the saved ones.
        decoded.items.forEach((id, value) => items.putIfAbsent(id, () => value));
        _owners.putIfAbsent(bucket, () => decoded.owner);
      }
    } catch (e) {
      debugPrint('ListStatusCache load: $e');
    }
    _loaded = true;
    for (final entry in _watchers.entries) {
      entry.value.value = _lookup(entry.key);
    }
    notifyListeners();
  }

  static String _bucket(AccountType tracker, String category) =>
      '${tracker.name}:$category';

  static String _watchKey(AccountType tracker, String category, int id) =>
      '${_bucket(tracker, category)}:$id';

  CachedListStatus? _lookup(String watchKey) {
    final cut = watchKey.lastIndexOf(':');
    final id = int.tryParse(watchKey.substring(cut + 1));
    if (id == null) return null;
    return _items[watchKey.substring(0, cut)]?[id];
  }

  /// The cached entry, or null when the id is not on the user's list (or
  /// was never shown).
  CachedListStatus? entryOf(int? id,
      {String category = 'anime', AccountType tracker = AccountType.myanimelist}) {
    if (id == null) return null;
    return _items[_bucket(tracker, category)]?[id];
  }

  /// The cached list status (`watching`, `completed`…), or null.
  String? statusOf(int? id,
          {String category = 'anime', AccountType tracker = AccountType.myanimelist}) =>
      entryOf(id, category: category, tracker: tracker)?.status;

  /// A listenable that follows one entry (null = not listed). Cheap: one
  /// notifier per watched id, shared by every caller.
  ValueListenable<CachedListStatus?> watch(int id,
      {String category = 'anime', AccountType tracker = AccountType.myanimelist}) {
    final key = _watchKey(tracker, category, id);
    return _watchers.putIfAbsent(
        key, () => ValueNotifier(entryOf(id, category: category, tracker: tracker)));
  }

  /// Number of entries known for [tracker] and [category].
  int countOf({String category = 'anime', AccountType tracker = AccountType.myanimelist}) =>
      _items[_bucket(tracker, category)]?.length ?? 0;

  /// Ties the [tracker] cache to [owner] (the signed-in username): a cache
  /// written for another account is dropped, so a new account never shows the
  /// previous one's badges. A null [owner] (not known yet) changes nothing.
  void bindOwner(AccountType tracker, String? owner) {
    if (owner == null || owner.isEmpty) return;
    for (final category in const ['anime', 'manga']) {
      final bucket = _bucket(tracker, category);
      final current = _owners[bucket];
      if (current == owner) continue;
      if (current != null && (_items[bucket]?.isNotEmpty ?? false)) {
        _items[bucket]?.clear();
        _refreshWatchers(bucket);
      }
      _owners[bucket] = owner;
      _markDirty(bucket);
    }
    notifyListeners();
  }

  /// Records the status of [id] (list page load or edit).
  void put(int id, CachedListStatus value,
      {String category = 'anime', AccountType tracker = AccountType.myanimelist}) {
    putAll({id: value}, category: category, tracker: tracker);
  }

  /// Records many statuses at once (one notification, one write).
  void putAll(Map<int, CachedListStatus> values,
      {String category = 'anime', AccountType tracker = AccountType.myanimelist}) {
    if (values.isEmpty) return;
    final bucket = _bucket(tracker, category);
    final items = _items.putIfAbsent(bucket, () => {});
    var changed = false;
    values.forEach((id, value) {
      if (items[id] == value) return;
      items[id] = value;
      changed = true;
      _watchers['$bucket:$id']?.value = value;
    });
    if (!changed) return;
    _markDirty(bucket);
    notifyListeners();
  }

  /// Forgets [id] (removed from the list).
  void remove(int id,
      {String category = 'anime', AccountType tracker = AccountType.myanimelist}) {
    final bucket = _bucket(tracker, category);
    if (_items[bucket]?.remove(id) == null) return;
    _watchers['$bucket:$id']?.value = null;
    _markDirty(bucket);
    notifyListeners();
  }

  /// Replaces every cached status of one list status of [category]: entries
  /// cached with a status in [statuses] but absent from [values] are dropped
  /// (they moved or left the list on another device). Use it after loading a
  /// whole status tab; [statuses] null means the whole list.
  void replaceStatuses(Map<int, CachedListStatus> values,
      {required Set<String>? statuses,
      String category = 'anime',
      AccountType tracker = AccountType.myanimelist}) {
    final bucket = _bucket(tracker, category);
    final items = _items.putIfAbsent(bucket, () => {});
    final stale = [
      for (final e in items.entries)
        if ((statuses == null || statuses.contains(e.value.status)) &&
            !values.containsKey(e.key))
          e.key,
    ];
    var changed = stale.isNotEmpty;
    for (final id in stale) {
      items.remove(id);
      _watchers['$bucket:$id']?.value = null;
    }
    values.forEach((id, value) {
      if (items[id] == value) return;
      items[id] = value;
      changed = true;
      _watchers['$bucket:$id']?.value = value;
    });
    if (!changed) return;
    _markDirty(bucket);
    notifyListeners();
  }

  /// Forgets everything of [tracker] (sign out), or everything.
  Future<void> clear({AccountType? tracker}) async {
    final buckets = _items.keys
        .where((b) => tracker == null || b.startsWith('${tracker.name}:'))
        .toList();
    for (final b in buckets) {
      _items.remove(b);
      _owners.remove(b);
      _refreshWatchers(b);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final b in buckets) {
        await prefs.remove('$_prefix:$b');
      }
    } catch (e) {
      debugPrint('ListStatusCache clear: $e');
    }
  }

  void _refreshWatchers(String bucket) {
    for (final entry in _watchers.entries) {
      if (entry.key.startsWith('$bucket:')) entry.value.value = _lookup(entry.key);
    }
  }

  void _markDirty(String bucket) {
    _dirty.add(bucket);
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, flush);
  }

  /// Writes pending changes now (tests, app pause).
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_dirty.isEmpty) return;
    // Never write a bucket before the saved one is merged into memory.
    if (!_loaded) await ensureLoaded();
    final buckets = _dirty.toList();
    _dirty.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final b in buckets) {
        final items = _items[b] ?? const {};
        await prefs.setString(
          '$_prefix:$b',
          jsonEncode({
            'owner': _owners[b],
            'items': {for (final e in items.entries) '${e.key}': e.value._toJson()},
          }),
        );
      }
    } catch (e) {
      debugPrint('ListStatusCache save: $e');
    }
  }

  /// Forgets the in-memory state (tests).
  @visibleForTesting
  void resetForTest() {
    _saveTimer?.cancel();
    _items.clear();
    _owners.clear();
    _dirty.clear();
    _loading = null;
    _loaded = false;
    for (final w in _watchers.values) {
      w.value = null;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final w in _watchers.values) {
      w.dispose();
    }
    super.dispose();
  }
}

class _Decoded {
  final String? owner;
  final Map<int, CachedListStatus> items;
  const _Decoded(this.owner, this.items);
}

_Decoded? _decode(String raw) {
  try {
    final json = jsonDecode(raw);
    if (json is! Map) return null;
    final owner = json['owner'] is String ? json['owner'] as String : null;
    final items = <int, CachedListStatus>{};
    final map = json['items'];
    if (map is Map) {
      map.forEach((key, value) {
        final id = int.tryParse('$key');
        final status = CachedListStatus._fromJson(value);
        if (id != null && status != null) items[id] = status;
      });
    }
    return _Decoded(owner, items);
  } catch (_) {
    return null;
  }
}
