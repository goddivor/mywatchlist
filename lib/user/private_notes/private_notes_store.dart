import 'package:shared_preferences/shared_preferences.dart';

/// Local-only notes, one per list entry (DailyAL "private note").
///
/// A note never leaves the device: it is not sent to any tracker. Each note is
/// one SharedPreferences string under `private_note_v1:<tracker>:<category>:<id>`
/// (`mal:anime:5114`), so anime and manga ids never collide and a later tracker
/// gets its own namespace. An empty note is removed, not stored.
///
/// The backup unit uses [export] and [import] to carry the notes.
class PrivateNotesStore {
  PrivateNotesStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  /// The app-wide store.
  static final PrivateNotesStore instance = PrivateNotesStore();

  /// Version of the [export] payload.
  static const int exportVersion = 1;
  static const String _prefix = 'private_note_v1:';

  final Future<SharedPreferences> Function() _prefs;

  /// Key of an entry inside [export]'s `notes` map: `mal:anime:5114`.
  static String entryKey(int id, String category, {String tracker = 'mal'}) =>
      '$tracker:${category.toLowerCase()}:$id';

  /// The note of the entry, or null when it has none.
  Future<String?> read(int id, String category,
      {String tracker = 'mal'}) async {
    final prefs = await _prefs();
    return prefs.getString(_prefix + entryKey(id, category, tracker: tracker));
  }

  /// Saves [note]; blank text deletes the note.
  Future<void> write(int id, String category, String note,
      {String tracker = 'mal'}) async {
    final prefs = await _prefs();
    final key = _prefix + entryKey(id, category, tracker: tracker);
    if (note.trim().isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, note);
    }
  }

  /// Every note, as a JSON-ready map:
  /// `{"version": 1, "notes": {"mal:anime:5114": "text", ...}}`.
  Future<Map<String, dynamic>> export() async {
    final prefs = await _prefs();
    final notes = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        notes[key.substring(_prefix.length)] = value;
      }
    }
    return {'version': exportVersion, 'notes': notes};
  }

  /// Restores notes from an [export] payload and returns how many were written.
  ///
  /// With [replace] every existing note is deleted first; otherwise the
  /// imported notes overwrite the ones with the same key and the others stay.
  /// Malformed entries are skipped; a payload from a newer version throws a
  /// [FormatException] instead of guessing its shape.
  Future<int> import(Map<String, dynamic> data, {bool replace = false}) async {
    final version = data['version'];
    if (version is! int || version > exportVersion) {
      throw FormatException('Unsupported private notes version: $version');
    }
    final notes = data['notes'];
    if (notes is! Map) {
      throw const FormatException('Private notes payload has no notes map');
    }
    final prefs = await _prefs();
    if (replace) {
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(_prefix)) await prefs.remove(key);
      }
    }
    var count = 0;
    for (final entry in notes.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || !_validKey.hasMatch(key)) continue;
      if (value is! String || value.trim().isEmpty) continue;
      await prefs.setString(_prefix + key, value);
      count++;
    }
    return count;
  }

  static final RegExp _validKey = RegExp(r'^[a-z0-9_]+:[a-z0-9_]+:\d+$');
}
