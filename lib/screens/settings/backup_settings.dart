import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/main.dart' show restartApp;
import 'package:mywatchlist/pages/settings/settings_section.dart';
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/screens/settings/storage_settings.dart';
import 'package:mywatchlist/utils/file_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// What the user picked in the restore review.
class RestoreChoice {
  final Set<BackupSection> sections;
  final bool replace;
  const RestoreChoice(this.sections, this.replace);
}

/// Settings > Backup and restore: save or share one JSON file, and restore from one after
/// a review that shows what it holds and lets the user choose sections and merge/replace.
class BackupRestoreSettingsPage extends StatefulWidget {
  const BackupRestoreSettingsPage({super.key});

  @override
  State<BackupRestoreSettingsPage> createState() => _BackupRestoreSettingsPageState();
}

class _BackupRestoreSettingsPageState extends State<BackupRestoreSettingsPage> {
  bool _busy = false;

  String get _fileName =>
      'mywatchlist_backup_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.json';

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String> _build() async {
    String? version;
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    return CacheManager.instance.getBackUpData(appVersion: version);
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _guard(() async {
        try {
          final name = _fileName;
          await FileStorage.writeFile(await _build(), name);
          if (mounted) _say(S.current.Bkp_Saved(name));
        } catch (e) {
          debugPrint('Backup save failed: $e');
          if (mounted) _say(S.current.Bkp_Save_Failed);
        }
      });

  Future<void> _share() => _guard(() async {
        try {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$_fileName');
          await file.writeAsString(await _build());
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'application/json')],
            subject: S.current.Bkp_Share_Subject,
          );
        } catch (e) {
          debugPrint('Backup share failed: $e');
          if (mounted) _say(S.current.Bkp_Share_Failed);
        }
      });

  Future<void> _restore() => _guard(() async {
        final BackupBundle bundle;
        try {
          final picked = await FilePicker.platform.pickFiles(withData: false);
          final path = picked?.files.single.path;
          if (path == null) return;
          final file = File(path);
          if (await file.length() > BackupService.maxBytes) {
            if (mounted) _say(S.current.Bkp_Too_Big);
            return;
          }
          final raw = utf8.decode(await file.readAsBytes());
          bundle = raw.length > 200 * 1024
              ? await compute(BackupService.parse, raw)
              : BackupService.parse(raw);
        } on FormatException catch (e) {
          if (!mounted) return;
          _say(e.message.contains('newer') ? S.current.Bkp_Too_New : S.current.Bkp_Not_A_Backup);
          return;
        } catch (e) {
          debugPrint('Backup read failed: $e');
          if (mounted) _say(S.current.Bkp_Read_Failed);
          return;
        }
        if (!mounted) return;
        if (bundle.isEmpty) {
          _say(S.current.Bkp_Empty);
          return;
        }
        final here = await BackupService.current();
        if (!mounted) return;
        final choice = await showModalBottomSheet<RestoreChoice>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => RestoreReviewSheet(bundle: bundle, device: here),
        );
        if (choice == null || !mounted) return;
        try {
          final result = await BackupService.restore(
            bundle,
            sections: choice.sections,
            replace: choice.replace,
          );
          if (!mounted) return;
          await _showDone(result);
        } catch (e) {
          debugPrint('Restore failed: $e');
          if (mounted) _say(S.current.Bkp_Restore_Failed);
        }
      });

  Future<void> _showDone(BackupRestoreResult result) async {
    final needsRestart = result.settings > 0;
    await showDialog<void>(
      context: context,
      barrierDismissible: !needsRestart,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline_rounded),
        title: Text(S.current.Bkp_Done_Title),
        content: Text([
          S.current.Bkp_Done_Counts(result.settings, result.bookmarks, result.notes),
          if (needsRestart) S.current.Bkp_Done_Restart,
        ].join('\n\n')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(needsRestart ? S.current.Bkp_Restart : S.current.Close),
          ),
        ],
      ),
    );
    if (needsRestart && mounted) restartApp(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SettingsScaffold(
      title: SettingsSection.backup.title,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: _busy ? const LinearProgressIndicator() : const SizedBox(width: double.infinity),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: colors.onSecondaryContainer),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.current.Bkp_Intro_Title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          S.current.Bkp_Intro_Body,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: colors.onSecondaryContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        PrefGroup(
          title: S.current.Bkp_Section_Backup,
          children: [
            SettingsActionTile(
              icon: Icons.save_alt_rounded,
              title: S.current.Bkp_Save_File,
              subtitle: S.current.Bkp_Save_File_Desc,
              onTap: _busy ? null : _save,
            ),
            SettingsActionTile(
              icon: Icons.ios_share_rounded,
              title: S.current.Bkp_Share,
              subtitle: S.current.Bkp_Share_Desc,
              onTap: _busy ? null : _share,
            ),
          ],
        ),
        PrefGroup(
          title: S.current.Bkp_Section_Restore,
          children: [
            SettingsActionTile(
              icon: Icons.restore_rounded,
              title: S.current.Bkp_Restore_File,
              subtitle: S.current.Bkp_Restore_File_Desc,
              onTap: _busy ? null : _restore,
            ),
          ],
        ),
      ],
    );
  }
}

/// Bottom sheet that previews a backup against the device and returns the choice, or null
/// on cancel. Nothing is written before the user confirms here.
class RestoreReviewSheet extends StatefulWidget {
  final BackupBundle bundle;
  final BackupBundle device;

  const RestoreReviewSheet({super.key, required this.bundle, required this.device});

  @override
  State<RestoreReviewSheet> createState() => _RestoreReviewSheetState();
}

class _RestoreReviewSheetState extends State<RestoreReviewSheet> {
  late final Set<BackupSection> _sections = {
    if (widget.bundle.settingsCount > 0) BackupSection.settings,
    if (widget.bundle.bookmarksCount > 0) BackupSection.bookmarks,
    if (widget.bundle.notesCount > 0) BackupSection.notes,
  };
  bool _replace = false;

  void _toggle(BackupSection section, bool? on) => setState(() {
        if (on ?? false) {
          _sections.add(section);
        } else {
          _sections.remove(section);
        }
      });

  Widget _row(BackupSection section, String title, int inFile, String subtitle) {
    return CheckboxListTile(
      value: _sections.contains(section),
      onChanged: inFile == 0 ? null : (v) => _toggle(section, v),
      title: Text(title),
      subtitle: Text(subtitle),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final b = widget.bundle;
    final d = widget.device;
    final meta = [
      if (b.createdAt != null)
        S.current.Bkp_Review_Made(DateFormat.yMMMd().add_Hm().format(b.createdAt!)),
      if (b.appVersion != null) S.current.Bkp_Review_Version(b.appVersion!),
    ].join(' · ');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(S.current.Bkp_Review_Title, style: theme.textTheme.titleLarge),
            ),
            if (meta.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                S.current.Bkp_Review_Choose,
                style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
              ),
            ),
            _row(
              BackupSection.settings,
              S.current.Bkp_Item_Settings,
              b.settingsCount,
              S.current.Bkp_Item_Settings_Counts(b.settingsCount),
            ),
            _row(
              BackupSection.bookmarks,
              S.current.Bkp_Item_Bookmarks,
              b.bookmarksCount,
              S.current.Bkp_Item_Counts(b.bookmarksCount, d.bookmarksCount),
            ),
            _row(
              BackupSection.notes,
              S.current.Bkp_Item_Notes,
              b.notesCount,
              S.current.Bkp_Item_Counts(b.notesCount, d.notesCount),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(S.current.Bkp_Mode_Merge)),
                  ButtonSegment(value: true, label: Text(S.current.Bkp_Mode_Replace)),
                ],
                selected: {_replace},
                onSelectionChanged: (v) => setState(() => _replace = v.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _replace ? S.current.Bkp_Mode_Replace_Desc : S.current.Bkp_Mode_Merge_Desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _replace ? colors.error : colors.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(S.current.Cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: _replace
                        ? FilledButton.styleFrom(
                            backgroundColor: colors.error,
                            foregroundColor: colors.onError,
                          )
                        : null,
                    onPressed: _sections.isEmpty
                        ? null
                        : () => Navigator.of(context)
                            .pop(RestoreChoice(Set.of(_sections), _replace)),
                    child: Text(
                      _replace ? S.current.Bkp_Replace_Action : S.current.Bkp_Restore_Action,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
