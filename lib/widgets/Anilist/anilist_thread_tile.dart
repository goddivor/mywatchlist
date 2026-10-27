import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// One AniList forum thread: title, author, counts and the last reply date. A tap opens the
/// thread on anilist.co (the app has no thread reader for AniList).
class AnilistThreadTile extends StatelessWidget {
  final AnilistThread thread;

  const AnilistThreadTile({super.key, required this.thread});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = S.of(context);
    final replied = thread.repliedAt;
    final info = [
      if (thread.author != null) thread.author!,
      s.Al_Replies(thread.replyCount),
      s.Al_Views(thread.viewCount),
      if (replied != null) DateFormat.MMMd().format(replied),
    ].join(' · ');
    return InkWell(
      onTap: () => openLink(context, thread.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: AppImage(
                url: thread.avatarUrl,
                width: 40,
                height: 40,
                placeholderColor: cs.secondaryContainer,
                errorWidget: (_) => ColoredBox(
                  color: cs.secondaryContainer,
                  child: Icon(Icons.person, color: cs.onSecondaryContainer),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (thread.sticky)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 4),
                          child: Icon(Icons.push_pin_outlined, size: 16, color: cs.primary),
                        ),
                      if (thread.locked)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 4),
                          child: Icon(Icons.lock_outline, size: 16, color: cs.onSurfaceVariant),
                        ),
                      Expanded(
                        child: Text(
                          thread.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (thread.categories.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final c in thread.categories.take(3))
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: Text(
                                c,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: cs.onSecondaryContainer),
                              ),
                            ),
                          ),
                      ],
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
