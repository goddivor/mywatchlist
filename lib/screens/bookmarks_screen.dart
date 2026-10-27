import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/settings/coming_soon_page.dart';

/// Saved anime, manga, characters and people (DAL `BookMarksWidget`).
///
/// Stub created by the app shell; open it with `AppRoutes.openBookmarks`. The bookmarks
/// unit replaces the body.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ComingSoonPage(
      title: S.current.Bookmarks,
      icon: Icons.bookmark_outline,
    );
  }
}
