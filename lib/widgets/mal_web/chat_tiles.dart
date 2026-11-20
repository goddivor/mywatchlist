import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_conversations.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/message_markup_view.dart';
import 'package:mywatchlist/widgets/mal_web/message_tiles.dart';
import 'package:mywatchlist/widgets/user/profile/profile_comments.dart' show formatCommentDate;

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// The time of a conversation's last message, as messaging apps write it: the hour today,
/// "Yesterday", then the date.
String conversationTime(BuildContext context, MalMessage last, {DateTime? now}) {
  final locale = messageLocale(context);
  final at = parseMalMessageDate(last.date, now: now);
  if (at == null) return last.date == null ? '' : formatCommentDate(last.date!, locale);
  final today = now ?? DateTime.now();
  if (_sameDay(at, today)) return DateFormat.Hm(locale).format(at);
  if (_sameDay(at, today.subtract(const Duration(days: 1)))) return S.of(context).Yesterday;
  if (at.year == today.year) return DateFormat.MMMd(locale).format(at);
  return DateFormat.yMd(locale).format(at);
}

/// The ticks of one of the user's messages: a clock while sending, two ticks once sent,
/// coloured ticks once read, a red mark when it failed.
class MalSendStateIcon extends StatelessWidget {
  const MalSendStateIcon({super.key, required this.state, this.color, this.size = 16});

  final MalSendState state;

  /// Colour of the clock and of the grey ticks.
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = S.of(context);
    final muted = color ?? scheme.onSurfaceVariant;
    final (IconData icon, Color tint, String label) = switch (state) {
      MalSendState.sending => (Icons.schedule_rounded, muted, s.Pc_Sending),
      MalSendState.sent => (Icons.done_all_rounded, muted, s.Pc_Sent),
      MalSendState.read => (Icons.done_all_rounded, _readColor(scheme), s.Pc_Read),
      MalSendState.failed => (Icons.error_rounded, scheme.error, s.Pc_Failed),
    };
    return Semantics(label: label, child: Icon(icon, size: size, color: tint));
  }
}

/// The colour of read ticks: blue, as in messaging apps, light enough on a dark bubble.
Color _readColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark ? const Color(0xFF53BDEB) : const Color(0xFF1E88E5);

/// One person in the list of conversations: picture, name, time of the last message, its
/// start (with the ticks when the user wrote it) and the unread count.
class MalConversationTile extends StatelessWidget {
  const MalConversationTile({super.key, required this.conversation, this.onTap, this.onLongPress, this.pending});

  final MalConversation conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The state of a message of the user still in the outbox, newer than the rows.
  final MalSendState? pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = conversation.last;
    final unread = conversation.unread;
    final mine = last.isSent;
    final state = pending ??
        (mine ? (last.recipientRead == true ? MalSendState.read : MalSendState.sent) : null);
    final text = last.preview.isNotEmpty ? last.preview : last.subject;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            ForumAvatar(
              username: conversation.counterpart,
              url: conversation.avatarUrl,
              size: 48,
              tappable: false,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.counterpart,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        conversationTime(context, last),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: unread > 0 ? scheme.primary : scheme.onSurfaceVariant,
                          fontWeight: unread > 0 ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (state != null) ...[
                        MalSendStateIcon(state: state),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: MalMessagePreview(
                          text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: unread > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
                            fontWeight: unread > 0 ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                      if (unread > 0)
                        Semantics(
                          label: S.of(context).Pc_Unread(unread),
                          child: Container(
                            margin: const EdgeInsetsDirectional.only(start: 8),
                            constraints: const BoxConstraints(minWidth: 22),
                            height: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: ExcludeSemantics(
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A chip in the middle of the chat: a day ("Today", a date) or the subject of the MAL
/// thread the next messages belong to.
class MalChatChip extends StatelessWidget {
  const MalChatChip({super.key, required this.text, this.subtle = false});

  final String text;

  /// The subject chips are lighter than the day ones.
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: subtle ? Colors.transparent : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: subtle ? Border.all(color: scheme.outlineVariant) : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// The day chip of [at].
String chatDayLabel(BuildContext context, DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final s = S.of(context);
  if (_sameDay(at, today)) return s.Today;
  if (_sameDay(at, today.subtract(const Duration(days: 1)))) return s.Yesterday;
  final locale = messageLocale(context);
  return at.year == today.year
      ? DateFormat.MMMMd(locale).format(at)
      : DateFormat.yMMMMd(locale).format(at);
}

/// One message of the chat: the user's on the end side in the accent colour, the other
/// person's on the start side. The time and, for the user's messages, the ticks sit in the
/// bottom corner. A failed message has a red mark and is tapped to be sent again.
class MalChatBubble extends StatelessWidget {
  const MalChatBubble({super.key, required this.message, this.onTap, this.onLongPress});

  final MalChatMessage message;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = message.isMine;
    final failed = message.state == MalSendState.failed;
    final background = mine ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final foreground = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    final meta = foreground.withValues(alpha: 0.7);
    final at = message.at;
    final time = at != null
        ? DateFormat.Hm(messageLocale(context)).format(at)
        : (message.dateText == null ? '' : formatCommentDate(message.dateText!, messageLocale(context)));
    final maxWidth = MediaQuery.sizeOf(context).width * 0.8;
    final imageWidth = (maxWidth - 52).clamp(120.0, 260.0);
    final state = message.state;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(16),
          topEnd: const Radius.circular(16),
          bottomStart: Radius.circular(mine ? 16 : 4),
          bottomEnd: Radius.circular(mine ? 4 : 16),
        ),
        border: failed ? Border.all(color: scheme.error, width: 1.2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: MalMessageMarkup(
              message.html,
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              imageWidth: imageWidth,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (time.isNotEmpty)
                Text(time, style: theme.textTheme.labelSmall?.copyWith(color: meta, fontSize: 11)),
              if (mine && state != null) ...[
                const SizedBox(width: 4),
                MalSendStateIcon(state: state, color: meta, size: 15),
              ],
            ],
          ),
        ],
      ),
    );
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onLongPress: onLongPress,
              child: bubble,
            ),
            if (failed)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                child: Text(
                  S.of(context).Pc_Failed,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
