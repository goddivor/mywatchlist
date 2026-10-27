import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';

/// A club member: picture, name and, for staff, their position. Tapping opens the quick profile.
class ClubMemberTile extends StatelessWidget {
  const ClubMemberTile({super.key, required this.member, this.position});

  final ClubMember member;
  final String? position;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = member.username ?? '';
    return ListTile(
      onTap: () => openForumUser(context, name),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ForumAvatar(username: name, url: member.imageUrl, size: 48, tappable: false),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurface),
      ),
      trailing: position == null ? null : StaffBadge(position!),
    );
  }
}

/// A club comment: author, date, staff position and the comment's HTML.
class ClubCommentTile extends StatelessWidget {
  const ClubCommentTile({super.key, required this.comment, this.position});

  final ClubComment comment;
  final String? position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = comment.by?.username ?? '';
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ForumAvatar(username: name, url: comment.by?.imageUrl, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => openForumUser(context, name),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (comment.longAgo != null && comment.longAgo!.isNotEmpty)
                      Text(
                        comment.longAgo!,
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (position != null) ...[
                const SizedBox(width: 8),
                StaffBadge(position!),
              ],
            ],
          ),
          if (comment.content != null && comment.content!.isNotEmpty) ...[
            const SizedBox(height: 10),
            MalHtmlBody(comment.content!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface)),
          ],
        ],
      ),
    );
  }
}

/// Posts in a club topic: MAL gives the number of replies, the topic holds one more post.
int clubTopicPostCount(String? replies) {
  if (replies == null) return 0;
  final match = RegExp(r'\d+').firstMatch(replies);
  return match == null ? 0 : (int.tryParse(match.group(0)!) ?? 0) + 1;
}

/// A topic of a club forum: title, author, number of posts and time of the last post.
class ClubTopicTile extends StatelessWidget {
  const ClubTopicTile({super.key, required this.topic});

  final ClubForumTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final posts = clubTopicPostCount(topic.replies);
    final subtitle = [
      if (topic.createdBy != null && topic.createdBy!.isNotEmpty) topic.createdBy!,
      if (posts > 0) S.current.Fc_Posts_Count(posts),
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        topic.title ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      trailing: topic.lastPostTime == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                topic.lastPostTime!,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
      onTap: topic.id == null
          ? null
          : () => gotoPage(
                context: context,
                newPage: ForumPostsScreen(
                  topic: ForumTopicsData(
                    id: topic.id,
                    title: topic.title,
                    createdBy: ForumUser(name: topic.createdBy),
                    numberOfPosts: posts > 0 ? posts : null,
                  ),
                ),
              ),
    );
  }
}
