import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// What the app last read of the MyAnimeList website (notifications, friends' activity,
/// messages, chats), kept on the device so screens show it at once and refresh it quietly.
/// The background job writes it too. One file per MAL user; nothing is kept for another one.
class MalWebStore {
  MalWebStore({Future<Directory> Function()? directory, this.saveDelay = const Duration(milliseconds: 400)})
      : _directory = directory ?? getApplicationSupportDirectory;

  static MalWebStore instance = MalWebStore();

  final Future<Directory> Function() _directory;
  final Duration saveDelay;

  Map<String, Object?> _sections = {};
  String? _user;
  Future<void>? _loading;
  Timer? _saveTimer;

  /// The MAL user whose data is loaded.
  String? get user => _user;

  bool get isLoaded => _user != null;

  static String _fileName(String user) {
    final safe = user.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    return 'mal_web_$safe.json';
  }

  Future<File> _file(String user) async => File('${(await _directory()).path}/${_fileName(user)}');

  /// Reads the saved data of [user] once (again when the user changes). Never throws.
  Future<void> load(String? user) {
    final name = user?.trim();
    if (name == null || name.isEmpty) return Future.value();
    if (_user?.toLowerCase() == name.toLowerCase()) return _loading ?? Future.value();
    _saveTimer?.cancel();
    _user = name;
    _sections = {};
    return _loading = () async {
      try {
        final file = await _file(name);
        if (!await file.exists()) return;
        final data = jsonDecode(await file.readAsString());
        if (data is Map && _user == name) {
          _sections = {...data.map((k, v) => MapEntry('$k', v)), ..._sections};
        }
      } catch (e) {
        debugPrint('MAL web store: $e');
      }
    }();
  }

  /// The saved JSON of [section], or null.
  Object? read(String section) => _sections[section];

  /// Saves [value] (JSON) as [section]; the file is written shortly after, once for a burst.
  void write(String section, Object? value) {
    if (_user == null) return;
    if (value == null) {
      _sections.remove(section);
    } else {
      _sections[section] = value;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(flush()));
  }

  /// Writes the file now.
  Future<void> flush() async {
    _saveTimer?.cancel();
    final user = _user;
    if (user == null) return;
    try {
      final file = await _file(user);
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(_sections), flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('MAL web store save: $e');
    }
  }

  @visibleForTesting
  void reset() {
    _saveTimer?.cancel();
    _sections = {};
    _user = null;
    _loading = null;
  }
}
