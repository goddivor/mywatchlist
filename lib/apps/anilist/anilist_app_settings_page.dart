import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_settings_page.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/tracker_youtube_player.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/widgets/common/tracker_add_status.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

/// The settings of the AniList app: the AniList account and its own settings (titles, lists,
/// adult content, notifications, activity, profile: [AnilistSettingsPage], saved on AniList),
/// then the settings of MyWatchList as a whole. MyAnimeList's own pages are not here.
class AnilistAppSettingsPage extends StatelessWidget {
  const AnilistAppSettingsPage({super.key});

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
      appBar: AppBar(title: Text(s.Ala_Settings_Title)),
      body: ListView(
        children: [
          ListTile(
            leading: AvatarWidget(url: image, isNetworkImage: image != null, height: 44, width: 44),
            title: Text(UserAnilistV2.instance.username ?? 'AniList'),
            subtitle: Text(s.Ala_Settings_Account),
            trailing: const Icon(Icons.swap_horiz_rounded),
            onTap: () => AppRoutes.openManageAccounts(context),
          ),
          header('AniList'),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: Text(s.Ala_Settings_Anilist),
            subtitle: Text(s.Ala_Settings_Anilist_Desc),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AnilistSettingsPage()),
            ),
          ),
          const TrackerAddStatusTile(tracker: AccountType.anilist, anime: true),
          const TrackerAddStatusTile(tracker: AccountType.anilist, anime: false),
          const TrackerYoutubeSwitch(tracker: AccountType.anilist),
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
