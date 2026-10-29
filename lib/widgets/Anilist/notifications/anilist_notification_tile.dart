import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_activity_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_thread_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_notifications_service.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart'
    show formatAnilistTime;
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumAvatar;
import 'package:mywatchlist/utils/web_launcher.dart';

/// The sentence of [n] in the app language, split in the part to show in bold (the user
/// name, empty for notifications without a user) and the rest.
({String lead, String text}) describeAnilistNotification(AnilistNotification n, S s) {
  final name = n.user?.name ?? '';
  final title = n.subject?.title ?? s.Aln_Unknown_Title;
  final thread = n.threadTitle ?? s.Aln_Thread_Fallback;
  final kind = n.kind;
  if (kind == null) {
    return (lead: name, text: n.context ?? '');
  }
  switch (kind) {
    case AnilistNotificationKind.following:
      return (lead: name, text: s.Aln_Following);
    case AnilistNotificationKind.activityMessage:
      return (lead: name, text: s.Aln_Activity_Message);
    case AnilistNotificationKind.activityMention:
      return (lead: name, text: s.Aln_Activity_Mention);
    case AnilistNotificationKind.activityReply:
      return (lead: name, text: s.Aln_Activity_Reply);
    case AnilistNotificationKind.activityReplySubscribed:
      return (lead: name, text: s.Aln_Activity_Reply_Subscribed);
    case AnilistNotificationKind.activityLike:
      return (lead: name, text: s.Aln_Activity_Like);
    case AnilistNotificationKind.activityReplyLike:
      return (lead: name, text: s.Aln_Activity_Reply_Like);
    case AnilistNotificationKind.threadCommentMention:
      return (lead: name, text: s.Aln_Thread_Comment_Mention(thread));
    case AnilistNotificationKind.threadCommentReply:
      return (lead: name, text: s.Aln_Thread_Comment_Reply(thread));
    case AnilistNotificationKind.threadSubscribed:
      return (lead: name, text: s.Aln_Thread_Subscribed(thread));
    case AnilistNotificationKind.threadCommentLike:
      return (lead: name, text: s.Aln_Thread_Comment_Like(thread));
    case AnilistNotificationKind.threadLike:
      return (lead: name, text: s.Aln_Thread_Like(thread));
    case AnilistNotificationKind.airing:
      return (
        lead: '',
        text: n.episode == null ? s.Aln_Airing_No_Episode(title) : s.Aln_Airing(n.episode!, title),
      );
    case AnilistNotificationKind.relatedMediaAddition:
      return (lead: '', text: s.Aln_Related_Added(title));
    case AnilistNotificationKind.mediaDataChange:
      return (lead: '', text: s.Aln_Data_Change(title));
    case AnilistNotificationKind.mediaMerge:
      return (lead: '', text: s.Aln_Merge(n.otherTitle ?? s.Aln_Unknown_Title, title));
    case AnilistNotificationKind.mediaDeletion:
      return (lead: '', text: s.Aln_Deletion(n.otherTitle ?? s.Aln_Unknown_Title));
    case AnilistNotificationKind.mediaSubmissionUpdate:
      return (lead: '', text: s.Aln_Media_Submission(n.otherTitle ?? title));
    case AnilistNotificationKind.staffSubmissionUpdate:
      return (lead: '', text: s.Aln_Staff_Submission(title));
    case AnilistNotificationKind.characterSubmissionUpdate:
      return (lead: '', text: s.Aln_Character_Submission(title));
  }
}

/// Opens what [n] is about inside the app: titles through [openAnilistTitle] (never the MAL
/// page), activities and threads on their screens, a follower on their profile. Staff and
/// character submissions open anilist.co (no in-app page).
Future<void> openAnilistNotification(BuildContext context, AnilistNotification n) async {
  final kind = n.kind;
  if (kind == null) return;
  final subject = n.subject;
  if (kind == AnilistNotificationKind.following) {
    return openAnilistUser(context, n.user?.name);
  }
  if (kind.isActivity && n.activityId != null) {
    await openAnilistActivity(context, n.activityId!);
    return;
  }
  if (kind.isThread && n.threadId != null) {
    return openAnilistThread(context, n.threadId!, commentId: n.commentId);
  }
  if (subject == null) return;
  if (subject.isMedia) {
    return openAnilistTitle(context, category: subject.type, id: subject.id);
  }
  return openLink(context, 'https://anilist.co/${subject.type}/${subject.id}', confirm: false);
}

/// One row of the inbox: cover (titles) or avatar (people), the sentence, its time, and a
/// dot while it is unread. A tap opens its target.
class AnilistNotificationTile extends StatelessWidget {
  const AnilistNotificationTile({
    super.key,
    required this.notification,
    required this.unread,
    this.onOpen,
  });

  final AnilistNotification notification;
  final bool unread;

  /// Replaces the default navigation (tests).
  final VoidCallback? onOpen;

  static const double _size = 48;

  Widget _leading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = notification;
    if (n.kind?.hasUser ?? false) {
      return ForumAvatar(
          username: n.user?.name, url: n.user?.avatarUrl, size: _size, tappable: false);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AppImage(
        url: n.subject?.imageUrl,
        width: _size,
        height: _size * 1.3,
        placeholderColor: scheme.secondaryContainer,
        errorWidget: (_) => ColoredBox(
          color: scheme.secondaryContainer,
          child: Icon(Icons.notifications_none, color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final n = notification;
    final sentence = describeAnilistNotification(n, s);
    final extra = [if (n.status != null) n.status!, if (n.reason != null) n.reason!].join(' · ');
    final time = formatAnilistTime(n.createdAt);
    return Material(
      color: unread ? scheme.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
      child: InkWell(
        onTap: onOpen ?? () => openAnilistNotification(context, n),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _leading(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        if (sentence.lead.isNotEmpty)
                          TextSpan(
                              text: '${sentence.lead} ',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: sentence.text),
                      ]),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (extra.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          extra,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    if (time.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          time,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              if (unread)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
                  child: Semantics(
                    label: s.Aln_Unread,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                      child: const SizedBox(width: 8, height: 8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
