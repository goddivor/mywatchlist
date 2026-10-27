import 'package:flutter/material.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_topics_data.dart';
import 'package:mywatchlist/utils/app_routes.dart';

/// Opens the screen a [bookmark] points to. The detail, character and forum screens are
/// MyAnimeList screens, so an entry of another tracker opens through its `malId`; without
/// one a message explains why nothing opened.
Future<void> openBookmark(BuildContext context, Bookmark bookmark) async {
  final tracker = AccountType.values.asNameMap()[bookmark.tracker] ?? AccountType.none;
  switch (bookmark.kind) {
    case BookmarkKind.user:
      return AppRoutes.openUserProfile(context,
          tracker: tracker, username: bookmark.id);
    case BookmarkKind.anime:
    case BookmarkKind.manga:
    case BookmarkKind.character:
    case BookmarkKind.person:
    case BookmarkKind.forumTopic:
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
        default:
          return AppRoutes.push<void>(context,
              ForumPostsScreen(topic: ForumTopicsData(id: id, title: bookmark.title)));
      }
  }
}
