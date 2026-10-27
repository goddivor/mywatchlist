import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a bookmark points to.
enum BookmarkKind { anime, manga, character, person, forumTopic, user }

/// One saved item, identified by `tracker + kind + id`.
///
/// [tracker] is the tracker's name (`myanimelist`, `anilist`, `kitsu`, `simkl`, the
/// `AccountType` enum names), so the same numeric id on two trackers never collides.
/// Only a light snapshot is stored (title, picture, one subtitle line), enough to draw the
/// card without any request. [malId] optionally maps an entry of another tracker to its
/// MyAnimeList id, which is what the detail screens open.
@immutable
class Bookmark {
  final String tracker;
  final BookmarkKind kind;
  final String id;
  final String title;
  final String? imageUrl;
  final String? subtitle;
  final int? malId;
  final DateTime addedAt;

  const Bookmark({
    required this.tracker,
    required this.kind,
    required this.id,
    required this.title,
    required this.addedAt,
    this.imageUrl,
    this.subtitle,
    this.malId,
  });

  /// Unique key: `myanimelist:anime:5114`.
  String get key => Bookmarks.keyOf(tracker, kind, id);

  /// The id the app screens open: the MAL id for MyAnimeList, [malId] otherwise.
  int? get openableId {
    if (kind == BookmarkKind.user) return null;
    if (tracker == 'myanimelist') return int.tryParse(id);
    return malId;
  }

  Map<String, dynamic> toJson() => {
        'tracker': tracker,
        'kind': kind.name,
        'id': id,
        'title': title,
        if (imageUrl != null) 'image': imageUrl,
        if (subtitle != null) 'subtitle': subtitle,
        if (malId != null) 'malId': malId,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };

  /// Null when the map is not a valid bookmark (unknown kind, missing field).
  static Bookmark? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = BookmarkKind.values.asNameMap()[raw['kind']];
    final tracker = raw['tracker'];
    final id = raw['id'];
    final title = raw['title'];
    if (kind == null || tracker is! String || tracker.isEmpty) return null;
    if (id == null || id.toString().isEmpty || title is! String) return null;
    final added = raw['addedAt'];
    return Bookmark(
      tracker: tracker,
      kind: kind,
      id: id.toString(),
      title: title,
      imageUrl: raw['image'] is String ? raw['image'] as String : null,
      subtitle: raw['subtitle'] is String ? raw['subtitle'] as String : null,
      malId: raw['malId'] is int ? raw['malId'] as int : null,
      addedAt: DateTime.fromMillisecondsSinceEpoch(added is int ? added : 0),
    );
  }
}

/// The bookmark list: a [ChangeNotifier] persisted as one JSON string in SharedPreferences.
///
/// Reads are synchronous once [ready] completed (the load starts at construction), so
/// `isBookmarked` is safe in `build`; before that it answers false. Use through [Bookmarks].
class BookmarkStore extends ChangeNotifier {
  BookmarkStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance {
    ready = _load();
  }

  static const String prefsKey = 'bookmarks_v1';

  final Future<SharedPreferences> Function() _prefs;
  final Map<String, Bookmark> _items = {};
  bool _loaded = false;

  /// Completes when the saved list has been read.
  late final Future<void> ready;

  bool get loaded => _loaded;

  /// Every bookmark, newest first.
  List<Bookmark> get all => (_items.values.toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt)));

  int get length => _items.length;

  Future<void> _load() async {
    try {
      final raw = (await _prefs()).getString(prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final e in list) {
            final b = Bookmark.tryFromJson(e);
            if (b != null) _items[b.key] = b;
          }
        }
      }
    } catch (_) {
      // A corrupt value starts an empty list rather than blocking the app.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await _prefs();
    await prefs.setString(
        prefsKey, jsonEncode(_items.values.map((b) => b.toJson()).toList()));
  }

  bool contains(String key) => _items.containsKey(key);

  Bookmark? get(String key) => _items[key];

  Future<void> put(Bookmark bookmark) async {
    await ready;
    _items[bookmark.key] = bookmark;
    notifyListeners();
    await _save();
  }

  Future<bool> remove(String key) async {
    await ready;
    if (_items.remove(key) == null) return false;
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> clear({String? tracker}) async {
    await ready;
    if (tracker == null) {
      _items.clear();
    } else {
      _items.removeWhere((_, b) => b.tracker == tracker);
    }
    notifyListeners();
    await _save();
  }

  /// `{"version": 1, "bookmarks": [...]}`, JSON-ready.
  Future<Map<String, dynamic>> export() async {
    await ready;
    return {
      'version': Bookmarks.exportVersion,
      'bookmarks': all.map((b) => b.toJson()).toList(),
    };
  }

  /// Restores an [export] payload and returns how many bookmarks were read. With [replace]
  /// the current list is dropped first; otherwise the imported entries win on a same key
  /// and the others stay. Invalid entries are skipped; a newer version throws a
  /// [FormatException].
  Future<int> import(Map<String, dynamic> data, {bool replace = false}) async {
    await ready;
    final version = data['version'];
    if (version is! int || version > Bookmarks.exportVersion) {
      throw FormatException('Unsupported bookmarks version: $version');
    }
    final list = data['bookmarks'];
    if (list is! List) {
      throw const FormatException('Bookmarks payload has no bookmarks list');
    }
    if (replace) _items.clear();
    var count = 0;
    for (final e in list) {
      final b = Bookmark.tryFromJson(e);
      if (b == null) continue;
      _items[b.key] = b;
      count++;
    }
    notifyListeners();
    await _save();
    return count;
  }
}

/// The API other units call.
///
/// ```dart
/// // Toggle (adds with the snapshot, removes when present); returns the new state.
/// final saved = await Bookmarks.toggle(
///   tracker: 'myanimelist', kind: BookmarkKind.anime, id: 5114,
///   title: 'Fullmetal Alchemist: Brotherhood', imageUrl: url,
/// );
/// // In build (rebuild on change):
/// ListenableBuilder(listenable: Bookmarks.listenable, builder: (_, __) =>
///     Icon(Bookmarks.isBookmarked(tracker: 'myanimelist', kind: BookmarkKind.anime, id: 5114)
///         ? Icons.bookmark : Icons.bookmark_border));
/// ```
/// The `widgets/bookmarks/bookmark_button.dart` widgets wrap exactly this.
abstract final class Bookmarks {
  static const int exportVersion = 1;

  static BookmarkStore _store = BookmarkStore();

  /// The store, a [Listenable] that fires on every add, remove, clear and import.
  static BookmarkStore get listenable => _store;

  /// Replaces the store (tests).
  @visibleForTesting
  static set store(BookmarkStore value) => _store = value;

  static String keyOf(String tracker, BookmarkKind kind, Object id) =>
      '$tracker:${kind.name}:$id';

  static bool isBookmarked({
    required String tracker,
    required BookmarkKind kind,
    required Object id,
  }) =>
      _store.contains(keyOf(tracker, kind, id));

  /// Adds the item (with its snapshot) or removes it; returns true when it is now saved.
  static Future<bool> toggle({
    required String tracker,
    required BookmarkKind kind,
    required Object id,
    required String title,
    String? imageUrl,
    String? subtitle,
    int? malId,
  }) async {
    await _store.ready;
    final key = keyOf(tracker, kind, id);
    if (_store.contains(key)) {
      await _store.remove(key);
      return false;
    }
    await _store.put(Bookmark(
      tracker: tracker,
      kind: kind,
      id: id.toString(),
      title: title,
      imageUrl: imageUrl,
      subtitle: subtitle,
      malId: malId,
      addedAt: DateTime.now(),
    ));
    return true;
  }

  static Future<void> add(Bookmark bookmark) => _store.put(bookmark);

  static Future<bool> remove({
    required String tracker,
    required BookmarkKind kind,
    required Object id,
  }) =>
      _store.remove(keyOf(tracker, kind, id));

  /// Backup API: see [BookmarkStore.export] and [BookmarkStore.import].
  static Future<Map<String, dynamic>> export() => _store.export();

  static Future<int> import(Map<String, dynamic> data, {bool replace = false}) =>
      _store.import(data, replace: replace);
}
