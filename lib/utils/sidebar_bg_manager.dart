import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/utils/file_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pictures picked from the gallery for the sidebar header and the home background.
///
/// The sidebar picture has its own key ([keySidebarImagePath]). The home background path is
/// owned by `ThemeBloc` (`bg_image_path`, `custom_bg_image_path`): this class only saves and
/// deletes the file, the caller sends `ThemeBackgroundChanged`. Both used to share
/// `bg_image_path` (and the legacy `UserMal.pref.bgImagePath`), so changing one overwrote the
/// other and the sidebar cleared the home background when it pointed to an asset.
class SidebarBackgroundManager {
  static final SidebarBackgroundManager _instance = SidebarBackgroundManager._internal();

  factory SidebarBackgroundManager() => _instance;

  SidebarBackgroundManager._internal();

  static SidebarBackgroundManager get instance => _instance;

  final FileHelper _fileHelper = FileHelper.instance;

  static const String keySidebarImagePath = 'sidebar_bg_image_path_v1';

  /// Pick and save a new sidebar background image.
  Future<String?> setNewBackgroundImage({
    bool compress = true,
    BuildContext? context,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await _sidebarPath(prefs);
    final path = await _pickAndSave(
      prefix: 'sidebar_bg',
      compress: compress,
      context: context,
    );
    if (path == null) return null;
    await prefs.setString(keySidebarImagePath, path);
    await _deleteIfUnused(prefs, previous, except: path);
    if (context != null && context.mounted) {
      _snack(context, S.current.Theme_Bg_Updated);
    }
    return path;
  }

  /// Pick and save a new home background image. [previousPath] (the former custom image) is
  /// deleted unless the sidebar still shows it. Returns the new file path, or null.
  Future<String?> pickHomeBackgroundImage({
    String? previousPath,
    BuildContext? context,
  }) async {
    final path = await _pickAndSave(prefix: 'home_bg', compress: true, context: context);
    if (path == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await _deleteIfUnused(prefs, previousPath, except: path, keepHome: false);
    if (context != null && context.mounted) {
      _snack(context, S.current.Theme_Bg_Updated);
    }
    return path;
  }

  /// Deletes a home background file the user removed (kept if the sidebar uses it).
  Future<void> deleteHomeBackgroundImage(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    await _deleteIfUnused(prefs, path, keepHome: false);
  }

  /// Remove the current sidebar background image.
  Future<bool> removeBackgroundImage({BuildContext? context}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await _sidebarPath(prefs);
      if (current == null || current.isEmpty) return false;
      await prefs.remove(keySidebarImagePath);
      await _deleteIfUnused(prefs, current);
      if (context != null && context.mounted) {
        _snack(context, S.current.Theme_Bg_Removed);
      }
      return true;
    } catch (e) {
      debugPrint('Error removing background image: $e');
      if (context != null && context.mounted) {
        _snack(context, S.current.Theme_Bg_Remove_Failed, error: true);
      }
      return false;
    }
  }

  /// The current sidebar background image, if its file still exists.
  Future<String?> getCurrentBackgroundImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await _sidebarPath(prefs);
    if (current == null || current.isEmpty) return null;
    if (!await _fileHelper.fileExists(current)) {
      await prefs.remove(keySidebarImagePath);
      return null;
    }
    return current;
  }

  /// The saved sidebar path; adopts the legacy shared key once when it held a sidebar file.
  Future<String?> _sidebarPath(SharedPreferences prefs) async {
    final own = prefs.getString(keySidebarImagePath);
    if (own != null) return own;
    final legacy = prefs.getString(ThemeBloc.keyBgImagePath);
    if (legacy != null && legacy.contains('sidebar_bg') && File(legacy).existsSync()) {
      await prefs.setString(keySidebarImagePath, legacy);
      return legacy;
    }
    return null;
  }

  Future<String?> _pickAndSave({
    required String prefix,
    required bool compress,
    BuildContext? context,
  }) async {
    try {
      final File? picked = await _fileHelper.pickImageFromGallery(
        compress: compress,
        maxWidth: 1920,
        maxHeight: 1080,
        quality: 85,
      );
      if (picked == null) return null;
      final File? saved = await _fileHelper.saveImageToAppDirectory(picked, prefix: prefix);
      if (saved == null) throw Exception('Failed to save background image');
      return saved.path;
    } catch (e) {
      debugPrint('Error setting new background image: $e');
      if (context != null && context.mounted) {
        _snack(context, S.current.Theme_Bg_Failed, error: true);
      }
      return null;
    }
  }

  /// Deletes [path] unless it is [except], an asset, or still shown by the other surface.
  Future<void> _deleteIfUnused(
    SharedPreferences prefs,
    String? path, {
    String? except,
    bool keepHome = true,
  }) async {
    if (path == null || path.isEmpty || path == except || path.startsWith('assets/')) return;
    await _sidebarPath(prefs); // Adopt the legacy sidebar file first, so it is never deleted.
    final inUse = <String?>{
      prefs.getString(keySidebarImagePath),
      if (keepHome) prefs.getString(ThemeBloc.keyBgImagePath),
      if (keepHome) prefs.getString(ThemeBloc.keyCustomBgImagePath),
    };
    if (inUse.contains(path)) return;
    await _fileHelper.deleteFile(path);
  }

  void _snack(BuildContext context, String message, {bool error = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: error ? TextStyle(color: cs.onErrorContainer) : null,
        ),
        backgroundColor: error ? cs.errorContainer : null,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
