import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/notifications_screen.dart';
import 'package:mywatchlist/services/notifications/mal_hub.dart';
import 'package:mywatchlist/services/notifications/mal_hub_texts.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/mal_web/notification_tiles.dart' show hubAgo;

/// The MAL home's "Friends activity" row (#339): the latest list updates of the user's MAL
/// friends, read through [MalNotificationsHub.loadActivity] (the notifications screen's Friends
/// tab and its 3 h refresh), [HomeSectionPreference.itemCount] at most. Hidden without a MAL
/// session, while nothing has loaded, and when the friends have no recent update. A card opens
/// the title; its avatar opens the friend's profile; "View all" opens the Friends tab.
class HomeFriendsActivitySection extends StatefulWidget {
  final HomeSectionPreference section;

  /// Bumped by a pull to refresh of the home.
  final int refresh;
  final MalNotificationsHub? hub;
  final DateTime Function()? now;

  const HomeFriendsActivitySection({super.key, required this.section, this.refresh = 0, this.hub, this.now});

  @override
  State<HomeFriendsActivitySection> createState() => _HomeFriendsActivitySectionState();
}

class _HomeFriendsActivitySectionState extends State<HomeFriendsActivitySection> {
  MalNotificationsHub get _hub => widget.hub ?? MalNotificationsHub.instance;

  @override
  void initState() {
    super.initState();
    _hub.loadActivity();
  }

  @override
  void didUpdateWidget(covariant HomeFriendsActivitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) _hub.loadActivity(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _hub,
      builder: (context, _) {
        final rows = _hub.activity.take(widget.section.itemCount).toList();
        if (_hub.activityStatus == MalHubStatus.noAccount || rows.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: widget.section.getDisplayTitle(),
                onTap: () => MalNotificationsScreen.open(context, tab: 1),
              ),
              SizedBox(
                height: FriendActivityCard.height,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => FriendActivityCard(
                    activity: rows[i],
                    now: widget.now?.call(),
                    onTap: () => AppRoutes.openContent(context, id: rows[i].malId, category: rows[i].category),
                    onFriendTap: () => AppRoutes.openUserProfile(
                      context,
                      tracker: AccountType.myanimelist,
                      username: rows[i].friend,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A compact card of [HomeFriendsActivitySection]: friend avatar and name, the title, the status
/// chip in its list colour, the episode or chapter, and how long ago.
class FriendActivityCard extends StatelessWidget {
  static const double width = 190;
  static const double height = 150;

  final FriendActivity activity;
  final VoidCallback onTap;
  final VoidCallback onFriendTap;
  final DateTime? now;

  const FriendActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
    required this.onFriendTap,
    this.now,
  });

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
      if (date != null) hubAgo(date.toLocal(), strings: s, now: now),
    ].join(' · ');
    final avatar = activity.friendImageUrl;
    return SizedBox(
      width: width,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onFriendTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      avatar == null || avatar.isEmpty
                          ? CircleAvatar(
                              radius: 14,
                              backgroundColor: scheme.secondaryContainer,
                              child: Icon(Icons.person_outline, size: 16, color: scheme.onSecondaryContainer),
                            )
                          : AppImage(
                              url: avatar,
                              width: 28,
                              height: 28,
                              borderRadius: BorderRadius.circular(14),
                              placeholderColor: scheme.surfaceContainerHighest,
                            ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(activity.friend,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(activity.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: role?.container ?? scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    friendStatusLabel(activity, s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: role?.onContainer ?? scheme.onSurfaceVariant),
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
