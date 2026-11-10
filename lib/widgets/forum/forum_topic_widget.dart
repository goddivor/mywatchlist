import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/common/select/select_date.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';

/// Topics hidden from the board lists (MAL's pinned mega-threads that never load as a topic).
const _hiddenTopicIds = [1885985, 1886113, 1983768];

/// "Mar 3, 2025" or MAL's own text ("Today, 5:20 AM") for the last activity of [topic].
String? forumTopicWhen(BuildContext context, ForumTopicsData? topic) {
  if (topic?.lastPostCreatedAt != null) {
    return formatDisplayDate(context, topic!.lastPostCreatedAt!);
  }
  return topic?.lastPostTimeText;
}

/// The topics of a board as slivers: skeleton while [topics] is null and not [failed], an error
/// state with Retry when [failed], an empty state, then one tile per topic and an optional
/// "View all" button.
class ForumTopicsSliver extends StatelessWidget {
  const ForumTopicsSliver({
    super.key,
    required this.topics,
    required this.failed,
    required this.onRetry,
    this.onViewAll,
    this.showMax,
  });

  final List<ForumTopicsData>? topics;
  final bool failed;
  final VoidCallback onRetry;
  final VoidCallback? onViewAll;
  final int? showMax;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return SliverToBoxAdapter(
        child: SizedBox(height: 280, child: ForumMessage.error(onRetry: onRetry, scrollable: false)),
      );
    }
    if (topics == null) {
      return const SliverToBoxAdapter(child: ForumSkeleton(count: 6));
    }
    var list = topics!.where((t) => !_hiddenTopicIds.contains(t.id)).toList();
    if (showMax != null && list.length > showMax!) list = list.sublist(0, showMax!);
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 240,
          child: ForumMessage(
            icon: Icons.forum_outlined,
            title: S.current.Fc_Topics_Empty_Title,
            body: S.current.Fc_Topics_Empty_Body,
            onRetry: onRetry,
            scrollable: false,
          ),
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverList.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => ForumTopicWidget(topic: list[index]),
        ),
        if (onViewAll != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: OutlinedButton(
                onPressed: onViewAll,
                child: Text(S.current.Fc_View_All_Topics),
              ),
            ),
          ),
      ],
    );
  }
}

/// One forum topic like DailyAL's row: a regular-weight title and a single meta line, the author
/// and last activity on the left, the post count on the right. A long press names the last poster.
class ForumTopicWidget extends StatelessWidget {
  const ForumTopicWidget({
    super.key,
    required this.topic,
    this.onUiChange,
    this.onTopicSelect,
    this.isSelected = false,
  });

  final ForumTopicsData topic;
  final VoidCallback? onUiChange;
  final Function(ForumTopicsData)? onTopicSelect;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final when = forumTopicWhen(context, topic);
    final author = topic.createdBy?.name;
    final lastBy = topic.lastPostCreatedBy?.name;
    final meta = [
      if (author != null && author.isNotEmpty) author,
      if (when != null && when.isNotEmpty) when,
    ].join(' · ');
    final metaStyle = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.title ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: metaStyle),
              ),
              if (topic.isLocked == true) ...[
                Tooltip(
                  message: S.current.Fc_Topic_Locked,
                  child: Icon(Icons.lock_outline, size: 14, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
              ],
              Text(S.current.Fc_Posts_Count(topic.numberOfPosts ?? 0), style: metaStyle),
            ],
          ),
        ],
      ),
    );
    if (lastBy != null && when != null) {
      row = Tooltip(
        message: S.current.Fc_Last_Post_At(lastBy, when),
        triggerMode: TooltipTriggerMode.longPress,
        child: row,
      );
    }

    return Material(
      type: isSelected ? MaterialType.canvas : MaterialType.transparency,
      color: isSelected ? scheme.surfaceContainerHighest : null,
      child: InkWell(
        onTap: () {
          if (onTopicSelect != null) {
            onTopicSelect!(topic);
          } else {
            gotoPage(
              context: context,
              newPage: ForumPostsScreen(topic: topic, onUiChange: onUiChange),
            );
          }
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: row,
        ),
      ),
    );
  }
}

/// Title, author, date and number of posts of the topic being read.
class ForumTopicHeader extends StatelessWidget {
  const ForumTopicHeader({super.key, required this.topic});

  final ForumTopicsData? topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final author = topic?.createdBy?.name ?? '';
    final created = topic?.createdAt;
    final meta = [
      if (author.isNotEmpty) author,
      if (created != null) formatDisplayDate(context, created),
    ].join(' · ');
    final posts = topic?.numberOfPosts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((topic?.title ?? '').isNotEmpty)
          Text(
            topic!.title!,
            style: theme.textTheme.titleLarge?.copyWith(color: scheme.onSurface),
          ),
        if (meta.isNotEmpty || posts != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (meta.isNotEmpty)
                Expanded(
                  child: Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                const Spacer(),
              if (posts != null)
                ForumStatChip(
                  icon: Icons.chat_bubble_outline,
                  label: S.current.Fc_Posts_Count(posts),
                ),
              if (topic?.isLocked == true) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: S.current.Fc_Topic_Locked,
                  child: Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
