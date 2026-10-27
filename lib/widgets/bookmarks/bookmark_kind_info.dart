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
    }
  }
}
