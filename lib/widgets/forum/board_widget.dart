import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/forum/forum_topics_screen.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';

/// A forum category (MyAnimeList, Anime & Manga, General, Archive): a card that opens a sheet
/// listing its boards, each with its sub-boards underneath.
class BoardWidget extends StatelessWidget {
  final Forum forum;
  final int forumIndex;

  const BoardWidget({
    super.key,
    required this.forum,
    required this.forumIndex,
  });

  // Pictures of the 4 MAL forum categories (the last one reuses the first).
  static const _forumImages = [
    'assets/images/mal-icon.png',
    'assets/images/anime-icon.png',
    'assets/images/general-icon.png',
  ];

  // Icons per board inside each forum category.
  static const Map<int, List<IconData>> _boardIcons = {
    0: [
      Icons.announcement,
      Icons.info,
      Icons.storage,
      Icons.support_rounded,
      Icons.bubble_chart,
      Icons.wine_bar_rounded,
      Icons.ac_unit,
    ],
    1: [
      Icons.new_releases_sharp,
      Icons.recommend,
      Icons.people_alt_rounded,
      Icons.animation,
      Icons.book,
    ],
    2: [
      Icons.add_to_queue_sharp,
      Icons.gamepad,
      Icons.music_note,
      Icons.fiber_new_sharp,
      Icons.opacity,
      Icons.content_cut,
      Icons.games_outlined,
    ],
    3: [
      Icons.archive_outlined,
      Icons.disabled_by_default,
    ],
  };

  void _openTopics(BuildContext context, {int? boardId, int? subBoardId, required String title}) {
    gotoPage(
      context: context,
      newPage: ForumTopicsScreen(boardId: boardId, subBoardId: subBoardId, title: title),
    );
  }

  void _showBoards(BuildContext context) {
    final boards = forum.boards ?? const <Board>[];
    final icons = _boardIcons[forumIndex];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        void open({int? boardId, int? subBoardId, required String title}) {
          Navigator.of(sheetContext).pop();
          _openTopics(context, boardId: boardId, subBoardId: subBoardId, title: title);
        }

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    forum.title ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: boards.length,
                  itemBuilder: (context, index) {
                    final board = boards[index];
                    final icon = icons != null && index < icons.length
                        ? icons[index]
                        : Icons.forum_outlined;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: Icon(icon, color: scheme.primary, size: 22),
                          title: Text(
                            board.title ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          subtitle: board.description == null
                              ? null
                              : Text(
                                  board.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                          trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                          onTap: () => open(boardId: board.id, title: board.title ?? ''),
                        ),
                        for (final sub in board.subBoards ?? const <SubBoard>[])
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsetsDirectional.only(start: 72, end: 16),
                            title: Text(
                              sub.title ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface),
                            ),
                            onTap: () => open(
                              subBoardId: sub.id,
                              title: sub.title ?? board.title ?? '',
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final image = _forumImages[forumIndex % _forumImages.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showBoards(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(image, width: 50, height: 50, cacheWidth: 150, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    forum.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.expand_less, size: 22, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
