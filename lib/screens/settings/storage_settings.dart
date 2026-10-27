import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/main.dart' show restartApp;
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/private_notes/private_notes_store.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Page scaffold of About, Backup and Storage: large collapsing title and a lazy list.
class SettingsScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsScaffold({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(title)),
          SliverList.list(children: children),
          SliverToBoxAdapter(
            child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }
}

/// One row of a [PrefGroup]: icon badge, title, optional subtitle and trailing widget.
/// A null [onTap] shows the row disabled. [danger] tints the badge with the danger role.
class SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  const SettingsActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final role = AppColors.of(context).danger;
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
      enabled: onTap != null,
      leading: danger
          ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: role.container,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: role.onContainer),
            )
          : PrefIcon(icon),
      title: Text(title, style: danger ? TextStyle(color: role.color) : null),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ??
          (onTap == null
              ? null
              : Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant)),
      onTap: onTap,
    );
  }
}

/// "12.3 MB" for a byte count (1024 steps, one decimal from KB up).
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(1)} ${units[i]}';
}

/// What the Storage page measures and clears.
class StorageUsage {
  final int images;
  final int temp;
  final int dataBytes;
  final int dataEntries;
  final int bookmarks;
  final int notes;

  const StorageUsage({
    required this.images,
    required this.temp,
    required this.dataBytes,
    required this.dataEntries,
    required this.bookmarks,
    required this.notes,
  });

  int get cachesTotal => images + temp + dataBytes;
}

/// The cache folder of `flutter_cache_manager` inside the temporary directory.
const String _imageCacheFolder = 'libCachedImageData';

/// Sizes of the image cache and of the other temporary files; runs in an isolate.
({int images, int other}) _scanTemp(String tempPath) {
  var images = 0, other = 0;
  final dir = Directory(tempPath);
  if (!dir.existsSync()) return (images: 0, other: 0);
  for (final entity in dir.listSync(followLinks: false)) {
    final isImages = entity.uri.pathSegments.where((s) => s.isNotEmpty).last == _imageCacheFolder;
    var size = 0;
    if (entity is File) {
      size = entity.lengthSync();
    } else if (entity is Directory) {
      for (final f in entity.listSync(recursive: true, followLinks: false)) {
        if (f is File) size += f.lengthSync();
      }
    }
    if (isImages) {
      images += size;
    } else {
      other += size;
    }
  }
  return (images: images, other: other);
}

/// Deletes the image cache folder; isolate.
void _deleteImages(String tempPath) {
  final dir = Directory('$tempPath/$_imageCacheFolder');
  try {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } catch (_) {
    // Files in use stay; the next clear takes them.
  }
}

/// Deletes everything in the temporary directory except the image cache; isolate.
void _deleteTemp(String tempPath) {
  final dir = Directory(tempPath);
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync(followLinks: false)) {
    if (entity.uri.pathSegments.where((s) => s.isNotEmpty).last == _imageCacheFolder) continue;
    try {
      entity.deleteSync(recursive: true);
    } catch (_) {
      // A file in use stays; the next clear takes it.
    }
  }
}

/// Measures and clears the caches of the app. Static so tests and other screens reuse it.
abstract final class AppStorage {
  static Future<StorageUsage> measure() async {
    var images = 0, other = 0;
    try {
      final temp = await getTemporaryDirectory();
      final scan = await Isolate.run(() => _scanTemp(temp.path));
      images = scan.images;
      other = scan.other;
    } catch (e) {
      debugPrint('Storage scan failed: $e');
    }
    final data = await CacheManager.instance.dataCacheStats();
    final notes = await PrivateNotesStore.instance.export();
    return StorageUsage(
      images: images,
      temp: other,
      dataBytes: data.bytes,
      dataEntries: data.entries,
      bookmarks: Bookmarks.listenable.length,
      notes: (notes['notes'] as Map).length,
    );
  }

  static Future<void> clearImages() async {
    // flutter_cache_manager is not a direct dependency: empty its folder; entries whose
    // file is gone are downloaded again on the next request.
    final temp = await getTemporaryDirectory();
    await Isolate.run(() => _deleteImages(temp.path));
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  static Future<void> clearTemp() async {
    final temp = await getTemporaryDirectory();
    await Isolate.run(() => _deleteTemp(temp.path));
  }

  static Future<void> clearData() async {
    await CacheManager.instance.clearDataCaches();
    await ListStatusCache.instance.clear();
  }

  /// Deletes settings, bookmarks, notes and caches. Accounts (secure storage) stay.
  static Future<void> eraseAll() async {
    await Bookmarks.listenable.clear();
    await PrivateNotesStore.instance.import(
      {'version': PrivateNotesStore.exportVersion, 'notes': const <String, dynamic>{}},
      replace: true,
    );
    await clearImages();
    await clearTemp();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

/// Settings > Storage: what the caches take, a button per cache, and the erase-everything
/// action with a backup shortcut.
class StorageSettingsPage extends StatefulWidget {
  const StorageSettingsPage({super.key});

  @override
  State<StorageSettingsPage> createState() => _StorageSettingsPageState();
}

class _StorageSettingsPageState extends State<StorageSettingsPage> {
  StorageUsage? _usage;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final usage = await AppStorage.measure();
    if (mounted) setState(() => _usage = usage);
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(String id, Future<void> Function() action, String label) async {
    if (_busy.isNotEmpty) return;
    setState(() => _busy.add(id));
    try {
      await action();
      if (mounted) _say(id == 'all' ? S.current.Sto_Cleared_All : S.current.Sto_Cleared(label));
    } catch (e) {
      debugPrint('Storage clear $id failed: $e');
      if (mounted) _say(S.current.Sto_Clear_Failed);
    }
    if (mounted) setState(() => _busy.remove(id));
    await _refresh();
  }

  Future<void> _clearAll() => _run('all', () async {
        await AppStorage.clearImages();
        await AppStorage.clearTemp();
        await AppStorage.clearData();
      }, '');

  Future<void> _erase() async {
    final colors = Theme.of(context).colorScheme;
    final choice = await showDialog<_EraseChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.delete_forever_rounded, color: AppColors.of(dialogContext).danger.color),
        title: Text(S.current.Sto_Erase_Title),
        content: Text(S.current.Sto_Erase_Body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_EraseChoice.backup),
            child: Text(S.current.Sto_Backup_First),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(S.current.Cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(_EraseChoice.erase),
            child: Text(S.current.Sto_Erase_Confirm),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == _EraseChoice.backup) {
      await AppRoutes.openSettingsPage(context, SettingsSection.backup);
      return;
    }
    setState(() => _busy.add('erase'));
    try {
      await AppStorage.eraseAll();
      if (!mounted) return;
      _say(S.current.Sto_Erased);
      restartApp(context);
    } catch (e) {
      debugPrint('Erase failed: $e');
      if (mounted) {
        setState(() => _busy.remove('erase'));
        _say(S.current.Sto_Clear_Failed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usage = _usage;
    final idle = _busy.isEmpty;
    return SettingsScaffold(
      title: S.current.Settings_Storage,
      children: [
        _Summary(usage: usage, busy: _busy.contains('all'), onClear: idle ? _clearAll : null),
        PrefGroup(
          title: S.current.Sto_Section_Caches,
          description: S.current.Sto_Section_Caches_Desc,
          children: [
            _CacheTile(
              icon: Icons.image_outlined,
              title: S.current.Sto_Images,
              subtitle: S.current.Sto_Images_Desc,
              size: usage == null ? null : formatBytes(usage.images),
              busy: _busy.contains('images'),
              onClear: idle && (usage?.images ?? 1) > 0
                  ? () => _run('images', AppStorage.clearImages, S.current.Sto_Images)
                  : null,
            ),
            _CacheTile(
              icon: Icons.folder_zip_outlined,
              title: S.current.Sto_Temp,
              subtitle: S.current.Sto_Temp_Desc,
              size: usage == null ? null : formatBytes(usage.temp),
              busy: _busy.contains('temp'),
              onClear: idle && (usage?.temp ?? 1) > 0
                  ? () => _run('temp', AppStorage.clearTemp, S.current.Sto_Temp)
                  : null,
            ),
            _CacheTile(
              icon: Icons.dataset_outlined,
              title: S.current.Sto_Data,
              subtitle: usage == null
                  ? S.current.Sto_Data_Desc
                  : '${S.current.Sto_Data_Desc}\n${S.current.Sto_Data_Entries(usage.dataEntries)}',
              size: usage == null ? null : formatBytes(usage.dataBytes),
              busy: _busy.contains('data'),
              onClear: idle && (usage?.dataEntries ?? 1) > 0
                  ? () => _run('data', AppStorage.clearData, S.current.Sto_Data)
                  : null,
            ),
          ],
        ),
        PrefGroup(
          title: S.current.Sto_Section_Data,
          description: S.current.Sto_Section_Data_Desc,
          children: [
            SettingsActionTile(
              icon: Icons.backup_outlined,
              title: S.current.Sto_Backup_First,
              subtitle: usage == null
                  ? S.current.Sto_Backup_First_Desc
                  : '${S.current.Sto_Bookmarks_Count(usage.bookmarks)} · '
                      '${S.current.Sto_Notes_Count(usage.notes)}',
              onTap: () => AppRoutes.openSettingsPage(context, SettingsSection.backup),
            ),
            SettingsActionTile(
              icon: Icons.delete_forever_outlined,
              title: S.current.Sto_Erase,
              subtitle: S.current.Sto_Erase_Desc,
              danger: true,
              trailing: _busy.contains('erase')
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: idle ? _erase : null,
            ),
          ],
        ),
      ],
    );
  }
}

enum _EraseChoice { backup, erase }

class _Summary extends StatelessWidget {
  final StorageUsage? usage;
  final bool busy;
  final VoidCallback? onClear;

  const _Summary({required this.usage, required this.busy, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = usage?.cachesTotal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.current.Sto_Summary_Label,
                style: theme.textTheme.labelLarge?.copyWith(color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 4),
              Text(
                total == null
                    ? S.current.Sto_Calculating
                    : (total == 0 ? S.current.Sto_Summary_Empty : formatBytes(total)),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: total == null || total == 0 ? null : onClear,
                icon: busy
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.cleaning_services_outlined),
                label: Text(S.current.Sto_Clear_All),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CacheTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? size;
  final bool busy;
  final VoidCallback? onClear;

  const _CacheTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.size,
    required this.busy,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
      leading: PrefIcon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      isThreeLine: subtitle.length > 60,
      trailing: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  size ?? '',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      S.current.Sto_Clear,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: onClear == null
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
