import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_html.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';

/// Indent of one reply level; deeper levels than [maxIndentLevels] stay at that indent.
const double _indentStep = 14;
const int maxIndentLevels = 5;

/// One forum comment of a thread's tree, drawn flat (the page lists the tree depth first):
/// a guide line per reply level, author and time, like, the text, then Reply and the fold
/// toggle of its replies. Own comments get Edit and Delete in the menu.
class AnilistCommentTile extends StatelessWidget {
  const AnilistCommentTile({
    super.key,
    required this.comment,
    required this.depth,
    required this.onLike,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFold,
    this.folded = false,
    this.mine = false,
    this.canReply = true,
    this.highlighted = false,
    this.service,
  });

  final AnilistComment comment;
  final int depth;
  final bool folded;
  final bool mine;
  final bool canReply;

  /// The comment a link pointed to.
  final bool highlighted;
  final void Function(bool isLiked, int count) onLike;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFold;
  final AnilistSocialService? service;

  int get _replyCount => comment.flattened.length - 1;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final level = depth.clamp(0, maxIndentLevels);
    final indent = level * _indentStep;
    final width = MediaQuery.sizeOf(context).width;

    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnilistAuthorLine(
            user: comment.user,
            time: comment.createdAt,
            size: depth == 0 ? 34 : 28,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnilistLikeButton(
                  isLiked: comment.isLiked,
                  count: comment.likeCount,
                  type: AnilistLikeable.threadComment,
                  id: comment.id,
                  onToggle: () => toggleAnilistLike(
                    context,
                    type: AnilistLikeable.threadComment,
                    id: comment.id,
                    isLiked: comment.isLiked,
                    count: comment.likeCount,
                    service: service,
                    apply: onLike,
                  ),
                ),
                if (mine)
                  PopupMenuButton<int>(
                    icon: Icon(Icons.more_vert, size: 20, color: scheme.onSurfaceVariant),
                    onSelected: (v) => v == 0 ? onEdit() : onDelete(),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 0, child: Text(s.Edit)),
                      PopupMenuItem(value: 1, child: Text(s.Delete)),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, end: 12),
            child: AnilistHtml(comment.html, maxImageWidth: width - indent - 40),
          ),
          Row(
            children: [
              if (canReply)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  onPressed: onReply,
                  child: Text(s.Als_Reply),
                ),
              if (comment.children.isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: onToggleFold,
                  icon: Icon(folded ? Icons.expand_more : Icons.expand_less, size: 18),
                  label: Text(folded ? s.Al_Replies(_replyCount) : s.Als_Hide_Replies),
                ),
            ],
          ),
        ],
      ),
    );

    return ColoredBox(
      color: highlighted ? scheme.primaryContainer.withValues(alpha: 0.35) : Colors.transparent,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: 4 + indent),
        child: depth == 0
            ? content
            : DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(color: scheme.outlineVariant, width: 2),
                  ),
                ),
                child: content,
              ),
      ),
    );
  }
}
