import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_likes_sheet.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumAvatar;

/// "now", "5 min", "3 h", "2 d", then the date in the app locale.
String formatAnilistTime(DateTime? time, {DateTime? now}) {
  if (time == null) return '';
  final s = S.current;
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return s.Als_Time_Now;
  if (diff.inHours < 1) return s.Als_Time_Minutes(diff.inMinutes);
  if (diff.inDays < 1) return s.Als_Time_Hours(diff.inHours);
  if (diff.inDays < 7) return s.Als_Time_Days(diff.inDays);
  final locale = Intl.getCurrentLocale();
  final sameYear = time.year == (now ?? DateTime.now()).year;
  return (sameYear ? DateFormat.MMMd(locale) : DateFormat.yMMMd(locale)).format(time);
}

/// The message of a failed AniList call.
String anilistErrorText(Object error) {
  final s = S.current;
  if (error is AnilistRateLimited) return s.Anilist_Rate_Limited(error.retryAfter.inSeconds);
  if (error is AnilistSessionExpired) return s.Al_Session_Expired;
  return s.Als_Action_Failed;
}

/// Checks an AniList account is signed in before a write; otherwise offers to sign in and
/// returns false.
bool requireAnilistSignIn(BuildContext context, {AnilistSocialService? service}) {
  if ((service ?? AnilistSocialService.instance).signedIn) return true;
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    content: Text(S.current.Als_Sign_In_To_Act),
    action: SnackBarAction(
      label: S.current.Al_Sign_In,
      onPressed: () => AppRoutes.signInAgain(context, AccountType.anilist),
    ),
  ));
  return false;
}

/// Runs an AniList write: refuses without an account (see [requireAnilistSignIn]), shows the
/// error in a snackbar (with "Sign in again" for a dead session). Returns null on failure.
Future<T?> runAnilistWrite<T>(
  BuildContext context,
  Future<T> Function() write, {
  AnilistSocialService? service,
}) async {
  if (!requireAnilistSignIn(context, service: service)) return null;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    return await write();
  } catch (e) {
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      content: Text(anilistErrorText(e)),
      action: e is AnilistSessionExpired && context.mounted
          ? SnackBarAction(
              label: S.current.Al_Sign_In_Again,
              onPressed: () => AppRoutes.signInAgain(context, AccountType.anilist),
            )
          : null,
    ));
    return null;
  }
}

/// Asks before deleting; true when confirmed.
Future<bool> confirmAnilistDelete(BuildContext context, String title) async {
  final s = S.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(s.Cancel),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(s.Delete),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Avatar, name and time of a post; the name and the picture open the profile.
class AnilistAuthorLine extends StatelessWidget {
  const AnilistAuthorLine({
    super.key,
    required this.user,
    this.time,
    this.size = 36,
    this.trailing,
    this.subtitle,
  });

  final AnilistSocialUser? user;
  final DateTime? time;
  final double size;
  final Widget? trailing;

  /// Under the name instead of the time (e.g. "to Someone" for a message).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = user?.name ?? '';
    final second = subtitle ?? formatAnilistTime(time);
    return Row(
      children: [
        GestureDetector(
          onTap: () => openAnilistUser(context, name),
          child: ForumAvatar(username: name, url: user?.avatarUrl, size: size, tappable: false),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => openAnilistUser(context, name),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (second.isNotEmpty)
                  Text(
                    second,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A heart with the like count: the heart likes or unlikes; the count, or a long press on
/// the heart, opens who liked it.
class AnilistLikeButton extends StatelessWidget {
  const AnilistLikeButton({
    super.key,
    required this.isLiked,
    required this.count,
    required this.onToggle,
    required this.type,
    required this.id,
  });

  final bool isLiked;
  final int count;
  final VoidCallback onToggle;
  final AnilistLikeable type;
  final int id;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = S.of(context);
    final color = isLiked ? scheme.error : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onLongPress: count > 0 ? () => showAnilistLikes(context, type: type, id: id) : null,
          child: IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: isLiked ? s.Als_Unlike : s.Als_Like,
          isSelected: isLiked,
          onPressed: onToggle,
          icon: Icon(Icons.favorite_border, size: 20, color: color),
          selectedIcon: Icon(Icons.favorite, size: 20, color: color),
          ),
        ),
        if (count > 0)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => showAnilistLikes(context, type: type, id: id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                NumberFormat.compact(locale: Intl.getCurrentLocale()).format(count),
                semanticsLabel: s.Als_Likes_Count(count),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
              ),
            ),
          ),
      ],
    );
  }
}

/// Toggles a like at once on screen, then keeps what AniList answers (or rolls back on
/// failure). [apply] redraws the item with a like state.
Future<void> toggleAnilistLike(
  BuildContext context, {
  required AnilistLikeable type,
  required int id,
  required bool isLiked,
  required int count,
  required void Function(bool isLiked, int count) apply,
  AnilistSocialService? service,
}) async {
  final svc = service ?? AnilistSocialService.instance;
  if (!requireAnilistSignIn(context, service: svc)) return;
  apply(!isLiked, (count + (isLiked ? -1 : 1)).clamp(0, 1 << 31));
  final result = await runAnilistWrite(context, () => svc.toggleLike(type, id), service: svc);
  if (result == null) {
    apply(isLiked, count);
  } else {
    apply(result.isLiked, result.likeCount);
  }
}

/// A small pill (category, title) on a tonal background.
class AnilistTag extends StatelessWidget {
  const AnilistTag({super.key, required this.label, this.onTap, this.leading});

  final String label;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 4)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The footer of a paged list: a spinner while loading, Retry after a failure, else nothing.
class AnilistPageFooter extends StatelessWidget {
  const AnilistPageFooter({super.key, required this.loading, required this.failed, required this.onRetry});

  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : failed
                ? TextButton(onPressed: onRetry, child: Text(S.of(context).Al_Retry))
                : const SizedBox.shrink(),
      ),
    );
  }
}

/// The "write a reply" bar pinned under a page.
class AnilistReplyBar extends StatelessWidget {
  const AnilistReplyBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.mode_comment_outlined, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Text(
                    S.of(context).Als_Write_Reply,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A review score the AniList way (anilist.co, AniHyou): "77%" on a tonal pill coloured by
/// anilist.co's scale (under 50 red, 50-74 amber, 75 and up green).
class AnilistScorePill extends StatelessWidget {
  const AnilistScorePill({super.key, required this.score, this.large = false});

  /// 0-100.
  final int score;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final role = score >= 75
        ? tokens.success
        : score >= 50
            ? tokens.warning
            : tokens.danger;
    final theme = Theme.of(context).textTheme;
    final style = (large ? theme.titleMedium : theme.labelMedium)
        ?.copyWith(color: role.onContainer, fontWeight: FontWeight.w700);
    return DecoratedBox(
      decoration: BoxDecoration(color: role.container, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: large ? 10 : 6, vertical: large ? 4 : 2),
        child: Text(
          NumberFormat.percentPattern(Intl.getCurrentLocale()).format(score / 100),
          style: style,
        ),
      ),
    );
  }
}
