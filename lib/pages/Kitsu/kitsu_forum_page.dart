import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// The Forum tab for Kitsu. Kitsu's community (groups, feeds, posts) has no public API that
/// fits a forum, so the tab says so and opens Kitsu's site instead of showing a dead page.
class KitsuForumPage extends StatelessWidget {
  const KitsuForumPage({super.key});

  static const String siteUrl = 'https://kitsu.app';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          AppBarHome(title: s.Hw_Tab_Forum, showBookmarks: false, showCalendar: false),
          Expanded(
            child: ProfileMessage(
              icon: Icons.forum_outlined,
              title: s.Kitsu_Forum_Title,
              body: s.Kitsu_Forum_Body,
              actionLabel: s.Kitsu_Open_Site,
              onAction: () => launchWebView(siteUrl, context: context),
            ),
          ),
        ],
      ),
    );
  }
}
