import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_activity_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_composer.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_html.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// The sentence of a list update before the title ("Watched episode 5 of"), in the app
/// language; AniList's own English words when it sends a verb the app does not know.
String anilistListStatusText(String? status, String? progress) {
  final s = S.current;
  final verb = (status ?? '').trim().toLowerCase();
  final p = (progress ?? '').trim();
  final count = p.contains('-') ? 2 : 1;
  if (p.isNotEmpty) {
    switch (verb) {
      case 'watched episode':
        return s.Als_Status_Watched(count, p);
      case 'rewatched episode':
        return s.Als_Status_Rewatched_Episode(count, p);
      case 'read chapter':
        return s.Als_Status_Read(count, p);
      case 'reread chapter':
        return s.Als_Status_Reread_Chapter(count, p);
    }
  }
  return switch (verb) {
    'completed' => s.Als_Status_Completed,
    'dropped' => s.Als_Status_Dropped,
    'paused watching' || 'paused reading' => s.Als_Status_Paused,
    'plans to watch' => s.Als_Status_Plans_Watch,
    'plans to read' => s.Als_Status_Plans_Read,
    'rewatched' => s.Als_Status_Rewatched,
    'reread' => s.Als_Status_Reread,
    _ => [
        if (verb.isNotEmpty) verb[0].toUpperCase() + verb.substring(1),
        if (p.isNotEmpty) p,
      ].join(' '),
  };
}

/// One post of the activity feed: author, time, the status text, the list update (cover,
/// "Watched episode 5 of …") or the message, then replies and likes. A tap opens the
/// activity with its replies ([openable]); the menu subscribes, pins, edits, deletes (own
/// posts) or opens anilist.co.
class AnilistActivityTile extends StatelessWidget {
  const AnilistActivityTile({
    super.key,
    required this.activity,
    required this.onChanged,
    this.onDeleted,
    this.viewerId,
    this.openable = true,
    this.service,
  });

  final AnilistActivity activity;

  /// Called with the activity after a like, subscribe, pin or edit.
  final ValueChanged<AnilistActivity> onChanged;
  final VoidCallback? onDeleted;

  /// The signed-in user's id: their own posts get edit, pin and delete.
  final int? viewerId;
  final bool openable;
  final AnilistSocialService? service;

  AnilistSocialService get _service => service ?? AnilistSocialService.instance;

  bool get _mine => viewerId != null && activity.user?.id == viewerId;

  Future<void> _open(BuildContext context) async {
    final updated = await openAnilistActivity(context, activity.id, initial: activity);
    if (updated != null) onChanged(updated);
  }

  Future<void> _menu(BuildContext context, _ActivityAction action) async {
    final s = S.of(context);
    switch (action) {
      case _ActivityAction.subscribe:
        final subscribed = await runAnilistWrite(
          context,
          () => _service.setActivitySubscription(activity.id, !activity.isSubscribed),
          service: _service,
        );
        if (subscribed != null) onChanged(activity.copyWith(isSubscribed: subscribed));
      case _ActivityAction.pin:
        final pinned = await runAnilistWrite(
          context,
          () => _service.setActivityPinned(activity.id, !activity.isPinned),
          service: _service,
        );
        if (pinned != null) onChanged(activity.copyWith(isPinned: pinned));
      case _ActivityAction.edit:
        final source = await runAnilistWrite(
          context,
          () => _service.statusSource(activity.id),
          service: _service,
        );
        if (source == null || !context.mounted) return;
        await showAnilistComposer(
          context,
          title: s.Als_Edit_Status,
          sendLabel: s.Save,
          initialText: source,
          service: _service,
          submit: (markdown) async {
            final saved = await _service.saveStatus(markdown, id: activity.id);
            onChanged(activity.copyWith(html: saved.html));
            return true;
          },
        );
      case _ActivityAction.delete:
        if (!await confirmAnilistDelete(context, s.Als_Delete_Activity)) return;
        if (!context.mounted) return;
        final done = await runAnilistWrite(
          context,
          () async {
            await _service.deleteActivity(activity.id);
            return true;
          },
          service: _service,
        );
        if (done == true) onDeleted?.call();
      case _ActivityAction.browser:
        await openLink(context, activity.url, confirm: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final a = activity;
    final signedIn = _service.signedIn;
    final menu = PopupMenuButton<_ActivityAction>(
      icon: Icon(Icons.more_vert, size: 20, color: scheme.onSurfaceVariant),
      onSelected: (action) => _menu(context, action),
      itemBuilder: (context) => [
        if (signedIn)
          PopupMenuItem(
            value: _ActivityAction.subscribe,
            child: Text(a.isSubscribed ? s.Als_Unsubscribe : s.Als_Subscribe),
          ),
        if (_mine && a.kind != AnilistActivityKind.message)
          PopupMenuItem(
            value: _ActivityAction.pin,
            child: Text(a.isPinned ? s.Als_Unpin : s.Als_Pin),
          ),
        if (_mine && a.kind == AnilistActivityKind.text)
          PopupMenuItem(value: _ActivityAction.edit, child: Text(s.Edit)),
        if (_mine) PopupMenuItem(value: _ActivityAction.delete, child: Text(s.Delete)),
        PopupMenuItem(value: _ActivityAction.browser, child: Text(s.Open_In_Browser)),
      ],
    );

    final subtitle = a.kind == AnilistActivityKind.message && a.recipient != null
        ? '${formatAnilistTime(a.createdAt)} · ${s.Als_Message_To(a.recipient!.name)}'
        : null;

    return InkWell(
      onTap: openable ? () => _open(context) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnilistAuthorLine(
              user: a.user,
              time: a.createdAt,
              subtitle: subtitle,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (a.isPinned)
                    Icon(Icons.push_pin, size: 16, semanticLabel: s.Als_Pinned, color: scheme.primary),
                  if (a.isPrivate)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4),
                      child: Icon(Icons.lock_outline,
                          size: 16, semanticLabel: s.Als_Private, color: scheme.onSurfaceVariant),
                    ),
                  menu,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8, end: 12),
              child: a.kind == AnilistActivityKind.list
                  ? _ListUpdate(activity: a)
                  : AnilistHtml(a.html),
            ),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: openable ? () => _open(context) : null,
                  icon: const Icon(Icons.mode_comment_outlined, size: 18),
                  label: Text(
                    a.replyCount > 0 ? '${a.replyCount}' : s.Als_Reply,
                    semanticsLabel: s.Al_Replies(a.replyCount),
                  ),
                ),
                const Spacer(),
                AnilistLikeButton(
                  isLiked: a.isLiked,
                  count: a.likeCount,
                  type: AnilistLikeable.activity,
                  id: a.id,
                  onToggle: () => toggleAnilistLike(
                    context,
                    type: AnilistLikeable.activity,
                    id: a.id,
                    isLiked: a.isLiked,
                    count: a.likeCount,
                    service: _service,
                    apply: (liked, count) =>
                        onChanged(activity.copyWith(isLiked: liked, likeCount: count)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ActivityAction { subscribe, pin, edit, delete, browser }

class _ListUpdate extends StatelessWidget {
  const _ListUpdate({required this.activity});

  final AnilistActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = activity.media;
    final sentence = anilistListStatusText(activity.status, activity.progress);
    void open() {
      if (media != null) openAnilistLink(context, 'https://anilist.co/${media.category}/${media.id}');
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: media == null ? null : open,
      child: Row(
        children: [
          AppImage(
            url: media?.coverUrl,
            width: 46,
            height: 66,
            borderRadius: BorderRadius.circular(6),
            placeholderColor: scheme.surfaceContainerHighest,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$sentence '),
                TextSpan(
                  text: media?.title ?? '',
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                ),
              ]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
