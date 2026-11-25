import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_kind.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_title_language.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart' show launchWebView;
import 'package:mywatchlist/widgets/Simkl/simkl_catalogue.dart';
import 'package:mywatchlist/widgets/common/tracker_youtube_player.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

/// The settings of the Simkl app: the Simkl account and what Simkl itself keeps (title
/// language, notifications and the rest of the account on simkl.com), the catalogue the app
/// opens on, then the settings of MyWatchList as a whole (theme, language, notifications,
/// backup, storage, about). MyAnimeList's own settings (its home sections, anime and manga
/// pages, dubs, data sources) are not here.
class SimklSettingsPage extends StatelessWidget {
  const SimklSettingsPage({super.key});

  static const String simklSettingsUrl = 'https://simkl.com/settings/';

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
    final name = UserSimklV2.instance.username;
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );
    return Scaffold(
      appBar: AppBar(title: Text(s.Skm_Settings_Title)),
      body: ListView(
        children: [
          ListTile(
            leading: AvatarWidget(
              url: image,
              isNetworkImage: image != null,
              height: 44,
              width: 44,
            ),
            title: Text(name ?? 'Simkl'),
            subtitle: Text(s.Skm_Settings_Account),
            trailing: const Icon(Icons.swap_horiz_rounded),
            onTap: () => AppRoutes.openManageAccounts(context),
          ),
          header('Simkl'),
          ValueListenableBuilder<SimklKind>(
            valueListenable: SimklCatalogue.instance,
            builder: (context, kind, _) => ListTile(
              leading: Icon(simklKindIcon(kind)),
              title: Text(s.Skm_Settings_Start_Catalogue),
              subtitle: Text(simklKindLabel(kind)),
              onTap: () async {
                final picked = await showDialog<SimklKind>(
                  context: context,
                  builder: (context) => SimpleDialog(
                    title: Text(s.Skm_Settings_Start_Catalogue),
                    children: [
                      for (final k in SimklKind.values)
                        ListTile(
                          leading: Icon(simklKindIcon(k)),
                          title: Text(simklKindLabel(k)),
                          trailing: k == kind ? const Icon(Icons.check_rounded) : null,
                          onTap: () => Navigator.of(context).pop(k),
                        ),
                    ],
                  ),
                );
                if (picked != null) SimklCatalogue.instance.pick(picked);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(s.Skm_Settings_Title_Language),
            subtitle: Text(switch (SimklTitlePreference.language) {
              SimklTitleLanguage.english => s.Skm_Title_English,
              SimklTitleLanguage.romaji => s.Skm_Title_Romaji,
              SimklTitleLanguage.original => s.Skm_Title_Original,
            }),
            trailing: const Icon(Icons.open_in_new_rounded),
            // Simkl keeps it in the account: it is changed on simkl.com and read from there.
            onTap: () => launchWebView(simklSettingsUrl, context: context),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(s.Skm_Settings_On_Simkl),
            subtitle: Text(s.Skm_Settings_On_Simkl_Desc),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => launchWebView(simklSettingsUrl, context: context),
          ),
          const TrackerYoutubeSwitch(tracker: AccountType.simkl),
          header(s.Skm_Settings_App),
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
