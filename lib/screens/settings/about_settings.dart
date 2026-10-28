import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/screens/settings/storage_settings.dart';
import 'package:mywatchlist/services/updater/release_service.dart';
import 'package:mywatchlist/services/updater/update_controller.dart';
import 'package:mywatchlist/services/updater/update_dialog.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

export 'package:mywatchlist/services/updater/release_service.dart'
    show ReleaseInfo, ReleaseService, ReleaseAsset, isNewerVersion;

const String _repo = updaterRepo;
const String _repoUrl = updaterRepoUrl;
const String _malTermsUrl = 'https://myanimelist.net/static/apiagreement.html';

/// Settings > About: version, changelog, update check, feedback entries, project links and
/// licences.
class AboutSettingsPage extends StatefulWidget {
  /// Replaceable in tests.
  final ReleaseService? releases;

  /// Download and install side of the update dialog; replaceable in tests (they never download).
  final UpdateEnvironment? updateEnvironment;

  const AboutSettingsPage({super.key, this.releases, this.updateEnvironment});

  @override
  State<AboutSettingsPage> createState() => _AboutSettingsPageState();
}

class _AboutSettingsPageState extends State<AboutSettingsPage> {
  PackageInfo? _info;
  late final ReleaseService _releases = widget.releases ?? ReleaseService();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _info = info);
    } catch (e) {
      debugPrint('Package info failed: $e');
    }
  }

  String get _version => _info?.version ?? '';

  String get _platform => kIsWeb ? 'web' : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

  void _open(String url) => launchWebView(url, context: context);

  void _issue({required String label, required String title}) {
    final uri = Uri.parse('$_repoUrl/issues/new').replace(queryParameters: {
      'labels': label,
      'title': title,
      'body': S.current.Abt_Issue_Body(_version, _platform),
    });
    _open(uri.toString());
  }

  Future<void> _showChangelog() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ChangelogSheet(version: _version, releases: _releases, onOpen: _open),
    );
  }

  Future<void> _checkUpdates() {
    return showDialog<void>(
      context: context,
      builder: (_) => UpdateDialog(
        current: _version,
        releases: _releases,
        environment: widget.updateEnvironment,
        onOpen: _open,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return SettingsScaffold(
      title: SettingsSection.about.title,
      children: [
        _Hero(
          version: info == null ? null : S.current.Abt_Version_Value(info.version, info.buildNumber),
        ),
        PrefGroup(
          title: S.current.Abt_Section_Release,
          children: [
            SettingsActionTile(
              icon: Icons.new_releases_outlined,
              title: S.current.ChangeLog,
              subtitle: S.current.Abt_Changelog_Desc,
              onTap: info == null ? null : _showChangelog,
            ),
            SettingsActionTile(
              icon: Icons.system_update_alt_rounded,
              title: S.current.Check_for_updates,
              subtitle: S.current.Abt_Check_Updates_Desc,
              onTap: info == null ? null : _checkUpdates,
            ),
          ],
        ),
        PrefGroup(
          title: S.current.Abt_Section_Feedback,
          children: [
            SettingsActionTile(
              icon: Icons.bug_report_outlined,
              title: S.current.Abt_Report_Bug,
              subtitle: S.current.Abt_Report_Bug_Desc,
              onTap: () => _issue(label: 'bug', title: S.current.Abt_Report_Bug),
            ),
            SettingsActionTile(
              icon: Icons.lightbulb_outline_rounded,
              title: S.current.Abt_Suggest_Feature,
              subtitle: S.current.Abt_Suggest_Feature_Desc,
              onTap: () => _issue(label: 'enhancement', title: S.current.Abt_Suggest_Feature),
            ),
            SettingsActionTile(
              icon: Icons.forum_outlined,
              title: S.current.Abt_Browse_Issues,
              subtitle: S.current.Abt_Browse_Issues_Desc,
              onTap: () => _open('$_repoUrl/issues'),
            ),
          ],
        ),
        PrefGroup(
          title: S.current.Abt_Section_Project,
          children: [
            SettingsActionTile(
              icon: Icons.code_rounded,
              title: S.current.Abt_Source_Code,
              subtitle: _repo,
              onTap: () => _open(_repoUrl),
            ),
            SettingsActionTile(
              icon: Icons.inventory_2_outlined,
              title: S.current.Abt_Releases,
              subtitle: S.current.Abt_Releases_Desc,
              onTap: () => _open('$_repoUrl/releases'),
            ),
            SettingsActionTile(
              icon: Icons.description_outlined,
              title: S.current.Licenses,
              subtitle: S.current.Abt_Licenses_Desc,
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'MyWatchList',
                applicationVersion: info == null ? null : '${info.version}+${info.buildNumber}',
              ),
            ),
            SettingsActionTile(
              icon: Icons.gavel_rounded,
              title: S.current.Abt_Mal_Terms,
              subtitle: S.current.Abt_Mal_Terms_Desc,
              onTap: () => _open(_malTermsUrl),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          child: Text(
            S.current.Abt_Unofficial,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final String? version;

  const _Hero({required this.version});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/mwl-black-bg.png',
              width: 88,
              height: 88,
              cacheWidth: 264,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => Container(
                width: 88,
                height: 88,
                color: colors.primaryContainer,
                child: Icon(Icons.movie_outlined, size: 40, color: colors.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'MyWatchList',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            version ?? S.current.Loading,
            style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            S.current.Abt_Tagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Release notes of this version, loaded from GitHub with retry and an "open" fallback.
class _ChangelogSheet extends StatefulWidget {
  final String version;
  final ReleaseService releases;
  final void Function(String url) onOpen;

  const _ChangelogSheet({required this.version, required this.releases, required this.onOpen});

  @override
  State<_ChangelogSheet> createState() => _ChangelogSheetState();
}

class _ChangelogSheetState extends State<_ChangelogSheet> {
  late Future<ReleaseInfo?> _future = widget.releases.forVersion(widget.version);

  void _retry() => setState(() => _future = widget.releases.forVersion(widget.version));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(S.current.Abt_Changelog_Title, style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
            child: Text(
              S.current.Abt_Changelog_For(widget.version),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: FutureBuilder<ReleaseInfo?>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _Message(
                    text: S.current.Abt_Load_Failed,
                    actionLabel: S.current.Abt_Try_Again,
                    onAction: _retry,
                  );
                }
                final release = snap.data;
                if (release == null) {
                  return _Message(
                    text: S.current.Abt_Release_Not_Found,
                    actionLabel: S.current.Abt_Open_On_GitHub,
                    onAction: () => widget.onOpen('$_repoUrl/releases'),
                  );
                }
                final lines = (release.body ?? '').trim().split(RegExp(r'\r?\n'));
                if (lines.length == 1 && lines.first.isEmpty) {
                  return _Message(
                    text: S.current.Abt_Changelog_Empty,
                    actionLabel: S.current.Abt_Open_On_GitHub,
                    onAction: () => widget.onOpen(release.url),
                  );
                }
                return ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: lines.length + 1,
                  itemBuilder: (context, i) => i == lines.length
                      ? Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => widget.onOpen(release.url),
                            child: Text(S.current.Abt_Open_On_GitHub),
                          ),
                        )
                      : _NoteLine(lines[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of release notes: `#` headings, `-`/`*` bullets, plain text; bold and code
/// markers are dropped.
class _NoteLine extends StatelessWidget {
  final String line;

  const _NoteLine(this.line);

  static String _clean(String s) => s.replaceAll('**', '').replaceAll('`', '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = line.trim();
    if (text.isEmpty) return const SizedBox(height: 8);
    final heading = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(text);
    if (heading != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          _clean(heading.group(1)!),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }
    final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(text);
    if (bullet != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10, start: 4),
              child: Text('•', style: theme.textTheme.bodyMedium),
            ),
            Expanded(child: Text(_clean(bullet.group(1)!), style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
    }
    return Text(_clean(text), style: theme.textTheme.bodyMedium);
  }
}

class _Message extends StatelessWidget {
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _Message({required this.text, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
