import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_social.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_paged_tab.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart';

/// The "Reactions" tab: the short takes the user wrote on titles, newest first.
class KitsuReactionsTab extends StatelessWidget {
  final String slug;
  final KitsuSocial? social;

  const KitsuReactionsTab({super.key, required this.slug, this.social});

  @override
  Widget build(BuildContext context) {
    final api = social ?? KitsuSocial.instance;
    return KitsuPagedList<KitsuReaction>(
      storageKey: 'kitsu_reactions_$slug',
      createPager: () => KitsuPager((page) => api.reactions(slug, page)),
      emptyText: S.of(context).Kitsu_Reactions_Empty,
      itemBuilder: (context, reaction) => _ReactionCard(key: ValueKey(reaction.id), reaction: reaction),
    );
  }
}

class _ReactionCard extends StatelessWidget {
  final KitsuReaction reaction;

  const _ReactionCard({super.key, required this.reaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final media = reaction.media;
    final isAnime = media?.kind != KitsuMediaKind.manga;
    final meta = [
      if (reaction.progress > 0)
        isAnime
            ? s.Kitsu_Reaction_Progress_Anime(reaction.progress)
            : s.Kitsu_Reaction_Progress_Manga(reaction.progress),
      kitsuTimeAgo(reaction.createdAt),
    ].where((e) => e.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (media != null)
          KitsuMediaLine(
            media: media,
            headline: reaction.text,
            detail: meta,
            trailing: reaction.likes > 0
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.favorite_border_rounded, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${reaction.likes}', style: theme.textTheme.labelMedium),
                  ])
                : null,
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(reaction.text, style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}
