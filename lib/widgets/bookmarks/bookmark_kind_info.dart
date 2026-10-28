import 'package:flutter/material.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// Translated label and icon of a [BookmarkKind]; read inside `build`, never cached.
extension BookmarkKindInfo on BookmarkKind {
  String get label {
    switch (this) {
      case BookmarkKind.anime:
        return S.current.Bm_Kind_Anime;
      case BookmarkKind.manga:
        return S.current.Bm_Kind_Manga;
      case BookmarkKind.character:
        return S.current.Bm_Kind_Character;
      case BookmarkKind.person:
        return S.current.Bm_Kind_Person;
      case BookmarkKind.forumTopic:
        return S.current.Bm_Kind_Forum;
      case BookmarkKind.user:
        return S.current.Bm_Kind_User;
      case BookmarkKind.club:
        return S.current.Bme_Kind_Club;
      case BookmarkKind.news:
        return S.current.Bme_Kind_News;
      case BookmarkKind.featured:
        return S.current.Bme_Kind_Featured;
      case BookmarkKind.interestStack:
        return S.current.Bme_Kind_Stack;
    }
  }

  IconData get icon {
    switch (this) {
      case BookmarkKind.anime:
        return Icons.movie_outlined;
      case BookmarkKind.manga:
        return Icons.menu_book_outlined;
      case BookmarkKind.character:
        return Icons.face_outlined;
      case BookmarkKind.person:
        return Icons.mic_none_outlined;
      case BookmarkKind.forumTopic:
        return Icons.forum_outlined;
      case BookmarkKind.user:
        return Icons.person_outline;
      case BookmarkKind.club:
        return Icons.groups_outlined;
      case BookmarkKind.news:
        return Icons.newspaper_outlined;
      case BookmarkKind.featured:
        return Icons.article_outlined;
      case BookmarkKind.interestStack:
        return Icons.layers_outlined;
    }
  }

  /// Kinds that rarely carry a picture: the bookmarks screen lists them as rows, as DailyAL
  /// lists its forum topics, instead of a grid of empty covers.
  bool get listsAsRows => this == BookmarkKind.forumTopic;
}
