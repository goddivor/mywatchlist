import 'package:flutter/material.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/MAL/featured_screen.dart';
import 'package:mywatchlist/screens/MAL/interest_stack_detail_screen.dart';
import 'package:mywatchlist/screens/forum/club_screen.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_topics_data.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart'
    show InterestStack;
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuMediaKind;
import 'package:mywatchlist/services/api/SimKl/simkl_kind.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistTitle;
import 'package:mywatchlist/widgets/Kitsu/kitsu_open.dart' show openKitsuTitle;
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart' show openSimklTitle;

/// Opens the screen a [bookmark] points to. The detail, character, forum, club, article and
/// interest stack screens are MyAnimeList screens, so an entry of another tracker opens
/// through its `malId`; without one a message explains why nothing opened.
/// The bookmark id of a Simkl title: the Simkl id, prefixed by its catalogue when it is not an
/// anime (`tv:123`, `movie:456`), so the bookmark reopens the right page.
String simklBookmarkId(SimklKind kind, int simklId) =>
    kind == SimklKind.anime ? '$simklId' : '${kind.name}:$simklId';

/// The catalogue and Simkl id of [simklBookmarkId]; null when [id] is not one.
(SimklKind, int)? parseSimklBookmarkId(String id) {
  final parts = id.split(':');
  final simklId = int.tryParse(parts.last);
  if (simklId == null || parts.length > 2) return null;
  final kind = parts.length == 1 ? SimklKind.anime : SimklKind.values.asNameMap()[parts.first];
  return kind == null ? null : (kind, simklId);
}

Future<void> openBookmark(BuildContext context, Bookmark bookmark) async {
  final tracker =
      AccountType.values.asNameMap()[bookmark.tracker] ?? AccountType.none;
  // Owner rule: a title of AniList, Kitsu or Simkl opens that tracker's own page.
  if (bookmark.kind == BookmarkKind.anime || bookmark.kind == BookmarkKind.manga) {
    final manga = bookmark.kind == BookmarkKind.manga;
    switch (tracker) {
      case AccountType.anilist:
        final id = int.tryParse(bookmark.id);
        if (id != null) {
          return openAnilistTitle(context,
              category: manga ? 'manga' : 'anime', id: id, title: bookmark.title, coverUrl: bookmark.imageUrl);
        }
      case AccountType.kitsu:
        return openKitsuTitle(context,
            kind: manga ? KitsuMediaKind.manga : KitsuMediaKind.anime,
            id: bookmark.id,
            title: bookmark.title,
            posterUrl: bookmark.imageUrl);
      case AccountType.simkl:
        final parsed = parseSimklBookmarkId(bookmark.id);
        if (parsed != null) {
          return openSimklTitle(context,
              simklId: parsed.$2, kind: parsed.$1, title: bookmark.title, posterUrl: bookmark.imageUrl);
        }
      case AccountType.myanimelist || AccountType.none:
        break;
    }
  }
  if (bookmark.kind == BookmarkKind.user) {
    return AppRoutes.openUserProfile(context,
        tracker: tracker, username: bookmark.id);
  }
  final id = bookmark.openableId ??
      (bookmark.kind == BookmarkKind.forumTopic
          ? int.tryParse(bookmark.id)
          : null);
  if (id == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.current.Bm_Cannot_Open)));
    return;
  }
  final image = bookmark.imageUrl;
  switch (bookmark.kind) {
    case BookmarkKind.anime:
      return AppRoutes.openContent(context, id: id, category: 'anime');
    case BookmarkKind.manga:
      return AppRoutes.openContent(context, id: id, category: 'manga');
    case BookmarkKind.character:
      return AppRoutes.push<void>(
          context, CharacterScreen(id: id, category: 'character'));
    case BookmarkKind.person:
      return AppRoutes.push<void>(
          context, CharacterScreen(id: id, category: 'person'));
    case BookmarkKind.forumTopic:
      return AppRoutes.push<void>(context,
          ForumPostsScreen(topic: ForumTopicsData(id: id, title: bookmark.title)));
    case BookmarkKind.club:
      return AppRoutes.push<void>(
          context,
          ClubScreen(
              clubHtml:
                  ClubHtml(id: id, name: bookmark.title, imgUrl: image)));
    case BookmarkKind.news:
    case BookmarkKind.featured:
      return AppRoutes.push<void>(
          context,
          FeaturedScreen(
            id: id,
            featureTitle: bookmark.title,
            imgUrl: image,
            category: bookmark.kind.name,
          ));
    case BookmarkKind.interestStack:
      return AppRoutes.push<void>(
          context,
          InterestStackDetailScreen(
            stack: InterestStack(
              url: interestStackUrl(id),
              title: bookmark.title,
              imageUrls: [if (image != null && image.isNotEmpty) image],
              username: bookmark.subtitle,
            ),
          ));
    case BookmarkKind.user:
      return;
  }
}

/// The MyAnimeList address of interest stack [id], the form its screen reads the id from.
String interestStackUrl(int id) => 'https://myanimelist.net/stacks/$id';
