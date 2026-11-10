import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/user_preference.dart';
import 'package:mywatchlist/utils/app_routes.dart';

/// Settings hub: one tile per [SettingsSection], grouped by theme (DAL `SettingsPage`).
///
/// Every tile opens its page through [AppRoutes.settingsPageFor]; pages not built yet are
/// "coming soon" stubs owned by their feature unit.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// Groups of the hub, in display order.
const List<(String Function(), List<SettingsSection>)> _groups = [
  (_accountTitle, [SettingsSection.accounts]),
  (
    _appearanceTitle,
    [SettingsSection.theme, SettingsSection.language, SettingsSection.homePage],
  ),
  (
    _contentTitle,
    [
      SettingsSection.userPreferences,
      SettingsSection.listPreferences,
      SettingsSection.animeManga,
      SettingsSection.dub,
      SettingsSection.notifications,
    ],
  ),
  (
    _dataTitle,
    [SettingsSection.downloads, SettingsSection.backup, SettingsSection.storage],
  ),
  (_infoTitle, [SettingsSection.about]),
];

String _accountTitle() => S.current.Settings_Section_Account;
String _appearanceTitle() => S.current.Settings_Section_Appearance;
String _contentTitle() => S.current.Settings_Section_Content;
String _dataTitle() => S.current.Settings_Section_Data;
String _infoTitle() => S.current.Settings_Section_Info;

class _SettingsPageState extends State<SettingsPage> {
  bool _crossTrackerEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final enabled = await UserPreference().getCrossTrackerEnabled();
    if (mounted) setState(() => _crossTrackerEnabled = enabled);
  }

  Future<void> _setCrossTracker(bool value) async {
    setState(() => _crossTrackerEnabled = value);
    await UserPreference().setCrossTrackerEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(S.current.Settings)),
          for (final (title, sections) in _groups) ...[
            SliverToBoxAdapter(child: _SectionHeader(title())),
            SliverToBoxAdapter(
              child: _SettingsGroup(
                children: [
                  if (sections.first == SettingsSection.downloads)
                    _SettingsTile(
                      icon: Icons.sync,
                      title: S.current.Settings_Cross_Sync,
                      subtitle: S.current.Settings_Cross_Sync_Desc,
                      onTap: () => _setCrossTracker(!_crossTrackerEnabled),
                      trailing: Switch(
                        value: _crossTrackerEnabled,
                        onChanged: _setCrossTracker,
                      ),
                    ),
                  for (final section in sections)
                    _SettingsTile(
                      icon: section.icon,
                      title: section.title,
                      subtitle: section.description,
                      onTap: () =>
                          AppRoutes.openSettingsPage(context, section),
                    ),
                ],
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Text(
                '${S.current.Made_With_Flutter} Flutter',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(28, 20, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Rounded surface holding the tiles of one group, separated by inset dividers.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 72,
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: colors.onPrimaryContainer),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
      ),
      trailing: trailing ??
          Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
    );
  }
}
