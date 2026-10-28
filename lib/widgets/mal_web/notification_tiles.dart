import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/notifications_screen.dart';
import 'package:mywatchlist/services/notifications/mal_hub.dart';
import 'package:mywatchlist/services/notifications/mal_hub_texts.dart';
import 'package:mywatchlist/utils/sidebar_extension.dart' show SidebarMenuItem;
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// "3 hours ago" in the app's language (the profile's wording).
String hubAgo(DateTime at, {S? strings, DateTime? now}) {
  final s = strings ?? S.current;
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inMinutes < 1) return s.Prof_Seen_Just_Now;
  if (d.inHours < 1) return s.Prof_Seen_Minutes(d.inMinutes);
  if (d.inDays < 1) return s.Prof_Seen_Hours(d.inHours);
  if (d.inDays < 30) return s.Prof_Seen_Days(d.inDays);
  if (d.inDays < 365) return s.Prof_Seen_Months(d.inDays ~/ 30);
  return s.Prof_Seen_Years(d.inDays ~/ 365);
}

IconData malNotificationIcon(MalNotificationKind kind) => switch (kind) {
      MalNotificationKind.friendRequest => Icons.person_add_alt_1_outlined,
      MalNotificationKind.friendRequestAccept => Icons.how_to_reg_outlined,
      MalNotificationKind.friendRequestDeny => Icons.person_remove_outlined,
      MalNotificationKind.profileComment => Icons.chat_bubble_outline_rounded,
      MalNotificationKind.blogComment => Icons.article_outlined,
      MalNotificationKind.forumQuote => Icons.format_quote_rounded,
      MalNotificationKind.watchedTopicMessage => Icons.forum_outlined,
      MalNotificationKind.userMentionInForumMessage => Icons.alternate_email_rounded,
      MalNotificationKind.userMentionInClubComment => Icons.alternate_email_rounded,
      MalNotificationKind.clubMassMessageInForum => Icons.castle_outlined,
      MalNotificationKind.relatedAnimeAdd => Icons.account_tree_outlined,
      MalNotificationKind.onAir => Icons.live_tv_rounded,
      MalNotificationKind.paymentStripe => Icons.credit_card_outlined,
      MalNotificationKind.unknown => Icons.notifications_none_rounded,
    };

/// A round picture of [url], or a tonal circle with [icon] when there is none.
class _HubAvatar extends StatelessWidget {
  const _HubAvatar({required this.url, required this.icon});

  final String? url;
  final IconData icon;
  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: scheme.onSecondaryContainer),
    );
    final link = url;
    if (link == null || link.isEmpty) return fallback;
    return AppImage(
      url: link,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
      placeholderColor: scheme.surfaceContainerHighest,
      errorWidget: (_) => fallback,
    );
  }
}

/// One item of MAL's notification hub, MALClient's row: type picture, sentence, detail,
/// time, a mark-read button while unread; Accept / Decline on a pending friend request.
class MalNotificationTile extends StatelessWidget {
  const MalNotificationTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onMarkRead,
    this.onAccept,
    this.onDeny,
    this.now,
  });

  final MalNotificationItem item;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;
  final VoidCallback? onAccept;
  final VoidCallback? onDeny;

  /// The clock of the relative times (tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final words = describeMalNotification(item, s);
    final unread = !item.isRead;
    final created = item.createdAt;
    final time = created != null ? hubAgo(created.toLocal(), strings: s, now: now) : item.createdAtForDisplay;
    final pending = item.isPendingFriendRequest && (onAccept != null || onDeny != null);
    return Material(
      color: unread ? scheme.secondaryContainer.withValues(alpha: 0.35) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HubAvatar(url: item.actorImageUrl, icon: malNotificationIcon(item.kind)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      words.headline,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (words.detail != null && words.detail!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        words.detail!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                    if (time != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: unread ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (pending) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.tonal(onPressed: onAccept, child: Text(s.Mn_Accept)),
                          OutlinedButton(onPressed: onDeny, child: Text(s.Mn_Deny)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                child: unread && onMarkRead != null
                    ? IconButton(
                        tooltip: s.Mn_Mark_Read,
                        onPressed: onMarkRead,
                        icon: Icon(Icons.done_rounded, color: scheme.primary, size: 20),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One list update of a friend: avatar, name and status chip, title, progress, time.
class FriendActivityTile extends StatelessWidget {
  const FriendActivityTile({
    super.key,
    required this.activity,
    required this.onTap,
    this.onFriendTap,
    this.now,
  });

  final FriendActivity activity;
  final VoidCallback onTap;
  final VoidCallback? onFriendTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final role = AppColors.of(context).statusOf(activity.status);
    final progress = friendProgressLabel(activity, s);
    final date = activity.date;
    final meta = [
      if (progress != null) progress,
      if (activity.mediaType != null) activity.mediaType!,
      if (date != null) hubAgo(date.toLocal(), strings: s, now: now),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkResponse(
              onTap: onFriendTap,
              radius: 24,
              child: _HubAvatar(url: activity.friendImageUrl, icon: Icons.person_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          activity.friend,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurface),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: role?.container ?? scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          friendStatusLabel(activity, s),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: role?.onContainer ?? scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The unread count of MAL's hub over [child] (99+ past 99).
class MalNotificationsBadge extends StatelessWidget {
  const MalNotificationsBadge({super.key, required this.child, this.hub});

  final Widget child;
  final MalNotificationsHub? hub;

  @override
  Widget build(BuildContext context) {
    final source = hub ?? MalNotificationsHub.instance;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: source.unread,
      child: child,
      builder: (context, count, child) => Badge(
        isLabelVisible: count > 0,
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        label: Text(count > 99 ? '99+' : '$count'),
        child: child,
      ),
    );
  }
}

/// The home header's bell: opens the notifications screen, shows the unread count.
/// Drop-in for the header's action row (same 40 x 40 compact button as its neighbours).
class MalNotificationsBell extends StatelessWidget {
  const MalNotificationsBell({super.key, this.onTap, this.iconSize = 20});

  final VoidCallback? onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: MalNotificationsBadge(child: Icon(Icons.notifications_none_rounded, size: iconSize)),
      tooltip: S.of(context).Mn_Title,
      onPressed: onTap ?? () => MalNotificationsScreen.open(context),
      color: Theme.of(context).colorScheme.onSurface,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
    );
  }
}

/// The sidebar's "Notifications" entry (for `AppSidebar(extraItems:)`), with the count.
SidebarMenuItem malNotificationsSidebarItem(BuildContext context, {VoidCallback? onTap}) {
  return SidebarMenuItem(
    icon: Icons.notifications_none_rounded,
    title: S.of(context).Mn_Title,
    onTap: onTap ?? () => MalNotificationsScreen.open(context),
    trailing: const _UnreadCount(),
  );
}

class _UnreadCount extends StatelessWidget {
  const _UnreadCount();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: MalNotificationsHub.instance.unread,
      builder: (context, count, _) => count == 0
          ? const SizedBox.shrink()
          : Badge(
              backgroundColor: scheme.error,
              textColor: scheme.onError,
              label: Text(count > 99 ? '99+' : '$count'),
            ),
    );
  }
}
