import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/forum/club_screen.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tabs_source.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// The clubs a MyAnimeList user belongs to.
class ClubsSection extends StatelessWidget {
  final String username;

  const ClubsSection({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return AsyncProfileTab<List<ClubHtml>>(
      storageKey: 'clubs_$username',
      loader: () => ProfileTabsSource.clubs(username),
      loadingLabel: S.of(context).Pt_Clubs_Loading,
      isEmpty: (clubs) => clubs.isEmpty,
      emptyBuilder: (context) => ProfileMessage(
        icon: Icons.groups_outlined,
        title: S.of(context).Prof_Clubs_Empty,
      ),
      slivers: (context, clubs) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              S.of(context).Prof_Clubs_Count(clubs.length),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        SliverList.builder(
          itemCount: clubs.length,
          itemBuilder: (context, i) {
            final club = clubs[i];
            return ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: Text(
                club.name ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => gotoPage(
                context: context,
                newPage: ClubScreen(clubHtml: club),
              ),
            );
          },
        ),
      ],
    );
  }
}
