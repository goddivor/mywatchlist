import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/forum/forum_topics_screen.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

/// Displays a forum category with expandable boards list.
class BoardWidget extends StatefulWidget {
  final Forum forum;
  final int forumIndex;

  const BoardWidget({
    super.key,
    required this.forum,
    required this.forumIndex,
  });

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  bool _isExpanded = false;

  // Images matching the 4 MAL forum categories:
  // 0=MyAnimeList, 1=Anime & Manga, 2=General, 3=Archive
  static const _forumImages = [
    'assets/images/mal-icon.png',
    'assets/images/anime-icon.png',
    'assets/images/general-icon.png',
  ];

  // Icons per board inside each forum category (matching DailyAL)
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

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    if (_isExpanded) {
      Navigator.of(context).pop();
    } else {
      _showBoardsModal();
    }
  }

  void _showBoardsModal() {
    _isExpanded = true;
    _iconController.forward();
    setState(() {});

    showCupertinoModalPopup(
      context: context,
      builder: (_) => _buildBoardsSheet(),
    ).then((_) {
      if (mounted) {
        _isExpanded = false;
        _iconController.reverse();
        setState(() {});
      }
    });
  }

  Widget _buildBoardsSheet() {
    final theme = Theme.of(context);
    final boards = widget.forum.boards ?? [];

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                widget.forum.title ?? '',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            // Boards list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: boards.length,
                itemBuilder: (context, index) {
                  final board = boards[index];
                  return _buildBoardTile(board, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardTile(Board board, int boardIndex) {
    final theme = Theme.of(context);
    final hasSubBoards =
        board.subBoards != null && board.subBoards!.isNotEmpty;

    final icons = _boardIcons[widget.forumIndex];
    final icon = icons != null && boardIndex < icons.length
        ? icons[boardIndex]
        : Icons.forum_outlined;

    return ListTile(
      leading: Icon(
        icon,
        color: theme.colorScheme.primary,
        size: 20,
      ),
      title: Text(
        board.title ?? '',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: board.description != null
          ? Text(
              board.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: hasSubBoards
          ? PopupMenuButton<SubBoard>(
              icon: Icon(
                Icons.arrow_drop_down,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onSelected: (subBoard) {
                Navigator.of(context).pop(); // Close modal
                _navigateToTopics(
                  subBoardId: subBoard.id,
                  title: subBoard.title ?? board.title ?? '',
                );
              },
              itemBuilder: (_) => board.subBoards!
                  .map((sb) => PopupMenuItem<SubBoard>(
                        value: sb,
                        child: Text(sb.title ?? ''),
                      ))
                  .toList(),
            )
          : Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
      onTap: () {
        Navigator.of(context).pop(); // Close modal
        _navigateToTopics(
          boardId: board.id,
          title: board.title ?? '',
        );
      },
    );
  }

  void _navigateToTopics(
      {int? boardId, int? subBoardId, required String title}) {
    gotoPage(
      context: context,
      newPage: ForumTopicsScreen(
        boardId: boardId,
        subBoardId: subBoardId,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageIndex = widget.forumIndex % _forumImages.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _toggleExpand,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                AvatarWidget(
                  height: 50,
                  width: 50,
                  radius: BorderRadius.circular(7),
                  isNetworkImage: false,
                  url: _forumImages[imageIndex],
                  userRoundBorderforLoading: false,
                  borderWidth: 0,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.forum.title ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _iconController,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
