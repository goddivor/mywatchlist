import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_character_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_staff_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media_detail.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart' show AnilistRecommendationVote;
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_format.dart';
import 'package:mywatchlist/widgets/Anilist/people/anilist_people_ui.dart'
    show anilistLanguageLabel, anilistRoleLabel;
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistTitle;
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// A horizontal lazy row with a fixed item extent.
class AnilistMediaStrip extends StatelessWidget {
  const AnilistMediaStrip({
    super.key,
    required this.height,
    required this.itemWidth,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double height;
  final double itemWidth;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemExtent: itemWidth + 8,
          itemCount: itemCount,
          itemBuilder: (context, i) => RepaintBoundary(
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: itemBuilder(context, i)),
          ),
        ),
      );
}

/// A cover with a small label on top (relation type) and the user's status as a dot.
class AnilistTitleCard extends StatelessWidget {
  const AnilistTitleCard({super.key, required this.media, this.label, this.width = 104, this.footer});

  static const double coverHeight = 148;

  final AnilistTitleRef media;
  final String? label;
  final double width;

  /// Under the title (the recommendation votes).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = AppColors.of(context).statusOf(media.listStatus);
    final meta = [
      if (label != null) label!,
      if (label == null && media.format != null) AnilistLabels.format(media.format!),
    ].join();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => openAnilistTitle(context, category: media.category, id: media.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: width,
            height: coverHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(
                  url: media.coverUrl,
                  borderRadius: BorderRadius.circular(10),
                  placeholderColor: scheme.surfaceContainerHighest,
                ),
                if (status != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: status.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: status.onColor, width: 1.5),
                      ),
                      child: const SizedBox(width: 12, height: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (meta.isNotEmpty)
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
            ),
          Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// The community rating of a recommendation with the user's up / down vote.
class AnilistVoteBar extends StatelessWidget {
  const AnilistVoteBar({super.key, required this.recommendation, required this.onVote});

  final AnilistRecommendation recommendation;
  final ValueChanged<AnilistRecommendationVote> onVote;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final r = recommendation;
    final up = r.userRating == AnilistRecommendationVote.up;
    final down = r.userRating == AnilistRecommendationVote.down;
    Widget button(IconData icon, bool on, String tip, AnilistRecommendationVote vote) => SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 18,
            tooltip: tip,
            color: on ? scheme.primary : scheme.onSurfaceVariant,
            icon: Icon(icon),
            onPressed: () => onVote(on ? AnilistRecommendationVote.none : vote),
          ),
        );
    return Row(
      children: [
        button(up ? Icons.thumb_up : Icons.thumb_up_outlined, up, s.Amp_Vote_Up, AnilistRecommendationVote.up),
        Expanded(
          child: Text(
            r.rating > 0 ? '+${AnilistMediaFormat.compact(r.rating)}' : AnilistMediaFormat.compact(r.rating),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        button(down ? Icons.thumb_down : Icons.thumb_down_outlined, down, s.Amp_Vote_Down,
            AnilistRecommendationVote.down),
      ],
    );
  }
}

/// A character with their voice actor (in the language asked): both open their pages.
class AnilistCastCard extends StatelessWidget {
  const AnilistCastCard({super.key, required this.edge});

  static const double height = 92;

  final AnilistCastEdge edge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final va = edge.voiceActors.firstOrNull;
    Widget side(AnilistMediaPerson p, String? sub, VoidCallback onTap, {bool end = false}) => Expanded(
          child: InkWell(
            onTap: onTap,
            child: Row(
              textDirection: end ? TextDirection.rtl : null,
              children: [
                AppImage(
                  url: p.imageUrl,
                  width: 60,
                  height: height,
                  placeholderColor: scheme.surfaceContainerHighest,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          textAlign: end ? TextAlign.end : TextAlign.start, style: theme.textTheme.bodySmall),
                      if (sub != null)
                        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            side(edge.character, anilistRoleLabel(edge.role),
                () => openAnilistCharacter(context, edge.character.id)),
            if (va != null)
              side(va, va.language == null ? null : anilistLanguageLabel(va.language!),
                  () => openAnilistStaff(context, va.id),
                  end: true),
          ],
        ),
      ),
    );
  }
}

/// A staff member and their role.
class AnilistStaffCard extends StatelessWidget {
  const AnilistStaffCard({super.key, required this.edge});

  final AnilistStaffEdge edge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openAnilistStaff(context, edge.person.id),
        child: SizedBox(
          height: AnilistCastCard.height,
          child: Row(
            children: [
              AppImage(
                url: edge.person.imageUrl,
                width: 60,
                height: AnilistCastCard.height,
                placeholderColor: scheme.surfaceContainerHighest,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(edge.person.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium),
                    if (edge.role != null)
                      Text(edge.role!, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
