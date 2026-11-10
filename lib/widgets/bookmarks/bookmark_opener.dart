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
import 'package:mywatchlist/utils/app_routes.dart';

/// Opens the screen a [bookmark] points to. The detail, character, forum, club, article and
/// interest stack screens are MyAnimeList screens, so an entry of another tracker opens
/// through its `malId`; without one a message explains why nothing opened.
Future<void> openBookmark(BuildContext context, Bookmark bookmark) async {
  final tracker =
      AccountType.values.asNameMap()[bookmark.tracker] ?? AccountType.none;
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
