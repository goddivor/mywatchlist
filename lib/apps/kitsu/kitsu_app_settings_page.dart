import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart' show launchWebView;
import 'package:mywatchlist/widgets/common/tracker_youtube_player.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/widgets/common/tracker_add_status.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

/// The settings of the Kitsu app: the Kitsu account and its settings on kitsu.app (profile,
/// library, notifications, privacy: the API has no settings call), then the settings of
/// MyWatchList as a whole. MyAnimeList's own pages are not here.
class KitsuAppSettingsPage extends StatelessWidget {
  const KitsuAppSettingsPage({super.key});

  static const String kitsuSettingsUrl = 'https://kitsu.app/settings';

  /// The MyWatchList pages that apply whatever the tracker.
  static const List<SettingsSection> appSections = [
    SettingsSection.theme,
    SettingsSection.language,
    SettingsSection.notifications,
    SettingsSection.listPreferences,
    SettingsSection.backup,
    SettingsSection.storage,
    SettingsSection.about,
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final image = context.select<AccountBloc, String?>(
      (bloc) => bloc.state is AccountLoaded ? (bloc.state as AccountLoaded).profileImageUrl : null,
    );
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );
    return Scaffold(
      appBar: AppBar(title: Text(s.Kta_Settings_Title)),
      body: ListView(
        children: [
          ListTile(
            leading: AvatarWidget(url: image, isNetworkImage: image != null, height: 44, width: 44),
            title: Text(UserKitsuV2.instance.username ?? 'Kitsu'),
            subtitle: Text(s.Kta_Settings_Account),
            trailing: const Icon(Icons.swap_horiz_rounded),
            onTap: () => AppRoutes.openManageAccounts(context),
          ),
          header('Kitsu'),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(s.Kta_Settings_On_Kitsu),
            subtitle: Text(s.Kta_Settings_On_Kitsu_Desc),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => launchWebView(kitsuSettingsUrl, context: context),
          ),
          const TrackerAddStatusTile(tracker: AccountType.kitsu, anime: true),
          const TrackerAddStatusTile(tracker: AccountType.kitsu, anime: false),
          const TrackerYoutubeSwitch(tracker: AccountType.kitsu),
          header('MyWatchList'),
          for (final section in appSections)
            ListTile(
              leading: Icon(section.icon),
              title: Text(section.title),
              subtitle: Text(section.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => AppRoutes.openSettingsPage(context, section),
            ),
          SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}
