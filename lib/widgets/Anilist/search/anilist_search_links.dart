import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/pages/Anilist/anilist_character_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_staff_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_studio_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistTitle;

/// Where the search's taps go. A title opens the native AniList title page
/// ([openAnilistTitle]), never the MyAnimeList page, mapped or not.
Future<void> openAnilistSearchTitle(BuildContext context,
        {required String category, required int id, String? title, String? coverUrl}) =>
    openAnilistTitle(context, category: category, id: id, title: title, coverUrl: coverUrl);

/// Characters, staff and studios open their AniList pages; a user opens their AniList
/// profile in the app.
Future<void> openAnilistSearchHit(BuildContext context, AnilistSearchHit hit) {
  switch (hit.kind) {
    case AnilistSearchKind.users:
      return AppRoutes.openUserProfile(context, tracker: AccountType.anilist, username: hit.name);
    case AnilistSearchKind.characters:
      return openAnilistCharacter(context, hit.id);
    case AnilistSearchKind.staff:
      return openAnilistStaff(context, hit.id);
    case AnilistSearchKind.studios:
      return openAnilistStudio(context, hit.id);
    case AnilistSearchKind.anime:
    case AnilistSearchKind.manga:
      return openAnilistTitle(context,
          category: hit.kind == AnilistSearchKind.manga ? 'manga' : 'anime', id: hit.id, title: hit.name);
  }
}
