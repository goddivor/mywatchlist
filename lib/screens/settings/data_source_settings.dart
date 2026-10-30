import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart' show SettingsSection, SettingsSectionInfo, jikanMutedText;
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/services/api/jikan_source.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';

/// Label of a mute duration choice.
String jikanMuteLabel(JikanMuteDuration duration) => switch (duration) {
      JikanMuteDuration.oneWeek => S.current.Dss_One_Week,
      JikanMuteDuration.twoWeeks => S.current.Dss_Two_Weeks,
      JikanMuteDuration.oneMonth => S.current.Dss_One_Month,
      JikanMuteDuration.threeMonths => S.current.Dss_Three_Months,
    };

/// Settings > Data sources: the server answering the anime and manga data (Jikan or
/// Tenrai, one at a time, see [JikanSource]), how long Jikan stays muted after it did not
/// answer, and a test that asks Jikan again now. Follows [source] (the app's
/// [JikanSource.instance] by default) live.
class DataSourceSettingsPage extends StatelessWidget {
  final JikanSource? source;

  const DataSourceSettingsPage({super.key, this.source});

  @override
  Widget build(BuildContext context) {
    final selector = source ?? JikanSource.instance;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(SettingsSection.dataSources.title)),
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: selector,
              builder: (context, _) => PrefGroup(
                title: S.current.Dss_Group,
                children: [
                  _CurrentSourceTile(source: selector),
                  _MuteDurationTile(source: selector),
                  _TestAgainTile(source: selector),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }
}

class _CurrentSourceTile extends StatelessWidget {
  final JikanSource source;
  const _CurrentSourceTile({required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = jikanMutedText(source);
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      leading: const PrefIcon(Icons.dns_outlined),
      title: Text(S.current.Dss_Current),
      subtitle: muted == null
          ? null
          : Text(muted, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          source.active.label,
          style: theme.textTheme.labelLarge?.copyWith(color: colors.onSecondaryContainer),
        ),
      ),
    );
  }
}

class _MuteDurationTile extends StatelessWidget {
  final JikanSource source;
  const _MuteDurationTile({required this.source});

  Future<void> _pick(BuildContext context) async {
    final picked = await showSelectSheet<JikanMuteDuration>(
      context,
      title: S.current.Dss_Mute_Duration,
      selected: source.muteDuration,
      options: [
        for (final d in JikanMuteDuration.values) SelectOption(d, jikanMuteLabel(d)),
      ],
    );
    if (picked != null) await source.setMuteDuration(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
      leading: const PrefIcon(Icons.timer_off_outlined),
      title: Text(S.current.Dss_Mute_Duration),
      subtitle: Text(
        jikanMuteLabel(source.muteDuration),
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
      ),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
      onTap: () => _pick(context),
    );
  }
}

class _TestAgainTile extends StatelessWidget {
  final JikanSource source;
  const _TestAgainTile({required this.source});

  Future<void> _test(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final active = await source.testAgain();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(active == DataSource.jikan ? S.current.Dss_Jikan_Up : S.current.Dss_Jikan_Down),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final probing = source.probing;
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      leading: const PrefIcon(Icons.network_check),
      title: Text(S.current.Dss_Test_Again),
      enabled: !probing,
      trailing: probing
          ? SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.primary),
            )
          : null,
      onTap: probing ? null : () => _test(context),
    );
  }
}
