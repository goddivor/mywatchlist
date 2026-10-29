import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';

/// Where the search's taps go: the one place to change once the native AniList pages exist.
///
/// Owner rule (2026-10-29): an AniList title never opens the MyAnimeList page, mapped or
/// not. Until `anilist-media-page` ships `openAnilistTitle` (`anilist-social` adds the helper
/// in `lib/widgets/Anilist/social/anilist_links.dart`), a title opens on anilist.co; switch
/// [openAnilistSearchTitle]'s body to that helper then.
Future<void> openAnilistSearchTitle(BuildContext context, {required String category, required int id}) =>
    openLink(context, 'https://anilist.co/${category == 'manga' ? 'manga' : 'anime'}/$id', confirm: false);

/// A character, staff member or studio opens on anilist.co until `anilist-people-pages`
/// ships their screens; a user opens their AniList profile in the app.
Future<void> openAnilistSearchHit(BuildContext context, AnilistSearchHit hit) {
  if (hit.kind == AnilistSearchKind.users) {
    return AppRoutes.openUserProfile(context, tracker: AccountType.anilist, username: hit.name);
  }
  return openLink(context, hit.url, confirm: false);
}
