import 'package:flutter/material.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// App bar / header button that bookmarks one item and shows its state. Rebuilds only
/// itself when the bookmark list changes. A snackbar confirms the change with an Undo.
///
/// For an overflow menu use `AppBarMenu(onBookmark: ..., bookmarked: ...)` with
/// [Bookmarks.toggle] and [Bookmarks.isBookmarked] instead.
class BookmarkButton extends StatelessWidget {
  final String tracker;
  final BookmarkKind kind;
  final Object id;
  final String title;
  final String? imageUrl;
  final String? subtitle;
  final int? malId;
  final bool showMessage;

  const BookmarkButton({
    super.key,
    required this.tracker,
    required this.kind,
    required this.id,
    required this.title,
    this.imageUrl,
    this.subtitle,
    this.malId,
    this.showMessage = true,
  });

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = await Bookmarks.toggle(
      tracker: tracker,
      kind: kind,
      id: id,
      title: title,
      imageUrl: imageUrl,
      subtitle: subtitle,
      malId: malId,
    );
    if (!showMessage || messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(saved ? S.current.Bm_Added : S.current.Bm_Removed),
        action: SnackBarAction(
          label: S.current.Bm_Undo,
          onPressed: () => _toggle(context),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Bookmarks.listenable,
      builder: (context, _) {
        final saved =
            Bookmarks.isBookmarked(tracker: tracker, kind: kind, id: id);
        return IconButton(
          tooltip: saved ? S.current.Kit_Remove_Bookmark : S.current.Kit_Bookmark,
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
          onPressed: () => _toggle(context),
        );
      },
    );
  }
}
