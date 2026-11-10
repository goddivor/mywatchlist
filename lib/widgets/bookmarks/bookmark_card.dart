import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_kind_info.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// One bookmark in the grid: cover, title, subtitle and tracker line, and a remove button.
/// No opacity layer, blur or shadow (repeated item): the remove button is an alpha circle.
class BookmarkCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const BookmarkCard({
    super.key,
    required this.bookmark,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final line = bookmarkLine(bookmark);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(
                  url: bookmark.imageUrl,
                  borderRadius: BorderRadius.circular(12),
                  placeholderColor: colors.surfaceContainerHighest,
                  errorWidget: (_) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(bookmark.kind.icon,
                        color: colors.onSurfaceVariant, size: 32),
                  ),
                ),
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton.filled(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: S.current.Kit_Remove_Bookmark,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.of(context).imageScrim,
                        foregroundColor: AppColors.of(context).onImageScrim,
                      ),
                      onPressed: onRemove,
                      icon: const Icon(Icons.bookmark),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            bookmark.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
          ),
          if (line.isNotEmpty)
            Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// The secondary line of a bookmark: its subtitle, then its tracker.
String bookmarkLine(Bookmark bookmark) {
  final tracker = AppRoutes.trackerLabel(
      AccountType.values.asNameMap()[bookmark.tracker] ?? AccountType.none);
  return [
    if (bookmark.subtitle != null && bookmark.subtitle!.isNotEmpty)
      bookmark.subtitle!,
    if (tracker.isNotEmpty) tracker,
  ].join(' · ');
}

/// One picture-less bookmark (a forum topic) as a row: kind icon, title, secondary line and
/// the filled bookmark that removes it.
class BookmarkRow extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const BookmarkRow({
    super.key,
    required this.bookmark,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final line = bookmarkLine(bookmark);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      leading: CircleAvatar(
        backgroundColor: colors.secondaryContainer,
        foregroundColor: colors.onSecondaryContainer,
        child: Icon(bookmark.kind.icon, size: 22),
      ),
      title: Text(
        bookmark.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: line.isEmpty
          ? null
          : Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
      trailing: IconButton(
        tooltip: S.current.Kit_Remove_Bookmark,
        color: colors.primary,
        icon: const Icon(Icons.bookmark),
        onPressed: onRemove,
      ),
    );
  }
}
