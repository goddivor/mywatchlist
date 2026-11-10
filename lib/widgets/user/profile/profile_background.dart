import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/utils/file_helper.dart';

/// The picture the signed-in user chose as their profile header, kept on this device (there
/// is no server to share it through, so other people do not see it).
///
/// A [ChangeNotifier]: the header and the pop-up sheet listen to it and repaint after a
/// change.
class ProfileBackgroundStore extends ChangeNotifier {
  ProfileBackgroundStore._();

  static final ProfileBackgroundStore instance = ProfileBackgroundStore._();

  static const String _prefix = 'profile_bg_path_';
  final Map<String, String?> _paths = {};

  static String _key(String username) => '$_prefix${username.trim().toLowerCase()}';

  /// The known path for [username], null when none or not loaded yet (see [load]).
  String? cached(String username) => _paths[_key(username)];

  /// Reads the saved path for [username]; a file that vanished counts as none.
  Future<String?> load(String username) async {
    final key = _key(username);
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(key);
      final exists = path != null && await File(path).exists();
      _paths[key] = exists ? path : null;
    } catch (e) {
      if (kDebugMode) debugPrint('ProfileBackgroundStore.load: $e');
      _paths[key] = null;
    }
    return _paths[key];
  }

  /// Lets the user pick a picture and saves it. Returns false when nothing was saved
  /// (cancelled, unsupported file, disk error).
  Future<bool> pick(String username) async {
    try {
      final helper = FileHelper.instance;
      final picked = await helper.pickImageFromGallery(
        maxWidth: 1600,
        maxHeight: 1000,
      );
      if (picked == null) return false;
      final saved = await helper.saveImageToAppDirectory(picked, prefix: 'profile_bg');
      if (saved == null) return false;
      final previous = _paths[_key(username)] ?? await load(username);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(username), saved.path);
      _paths[_key(username)] = saved.path;
      if (previous != null && previous != saved.path) {
        await helper.deleteFile(previous);
      }
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('ProfileBackgroundStore.pick: $e');
      return false;
    }
  }

  Future<bool> remove(String username) async {
    try {
      final previous = _paths[_key(username)] ?? await load(username);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(username));
      _paths[_key(username)] = null;
      if (previous != null) await FileHelper.instance.deleteFile(previous);
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('ProfileBackgroundStore.remove: $e');
      return false;
    }
  }
}
