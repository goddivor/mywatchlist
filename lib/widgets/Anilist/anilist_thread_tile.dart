import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_thread_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_thread_composer.dart'
    show anilistCategoryName;
import 'package:mywatchlist/widgets/common/app_image.dart';

/// A category name of a thread row in the app language.
String _categoryLabel(String name) {
  for (final c in AnilistForumCategory.all) {
    if (c.name == name) return anilistCategoryName(c);
  }
  return name;
}

/// One AniList forum thread: title, author, counts and the last reply date. A tap opens the
/// thread page.
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
      if (replied != null) DateFormat.MMMd(Intl.getCurrentLocale()).format(replied),
    ].join(' · ');
    return InkWell(
      onTap: () => openAnilistThread(context, thread.id),
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
                                _categoryLabel(c),
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
