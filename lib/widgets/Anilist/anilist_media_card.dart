import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistTitle;
import 'package:mywatchlist/widgets/Anilist/search/anilist_result_tiles.dart' show anilistScoreRole;
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Opens [media] on the native AniList title page ([openAnilistTitle]), mapped to
/// MyAnimeList or not.
void openAnilistMedia(BuildContext context, AnilistMedia media) {
  openAnilistTitle(context,
      category: media.category, id: media.id, title: media.title, coverUrl: media.coverUrl);
}

/// A cover with its title, the AniList score on the cover (AniList's own `82%`, on
/// anilist.co's red / amber / green scale) and, for an airing anime, the
/// next episode. Fixed size so a row never measures its cards.
class AnilistMediaCard extends StatelessWidget {
  final AnilistMedia media;
  final double width;
  final double height;

  const AnilistMediaCard({
    super.key,
    required this.media,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final next = media.nextEpisode;
    return SizedBox(
      width: width,
      height: height,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openAnilistMedia(context, media),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(
                      url: media.coverUrl,
                      borderRadius: BorderRadius.circular(10),
                      placeholderColor: cs.surfaceContainerHighest,
                      errorWidget: (_) => ColoredBox(
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: cs.onSurfaceVariant),
                      ),
                    ),
                    if (media.score != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _Badge(
                          background: anilistScoreRole(context, (media.score! * 10).round()).container,
                          foreground: anilistScoreRole(context, (media.score! * 10).round()).onContainer,
                          icon: Icons.sentiment_satisfied_alt_rounded,
                          label: NumberFormat.percentPattern(Intl.getCurrentLocale())
                              .format(media.score! / 10),
                        ),
                      ),
                    if (next != null)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: _Badge(
                          background: cs.primaryContainer,
                          foreground: cs.onPrimaryContainer,
                          label: S.current.Al_Episode_Short(next),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                media.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color background;
  final Color foreground;
  final IconData? icon;
  final String label;

  const _Badge({
    required this.background,
    required this.foreground,
    this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: foreground),
              const SizedBox(width: 2),
            ],
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal row of [AnilistMediaCard]s: lazy, with a fixed item extent.
class AnilistMediaRow extends StatelessWidget {
  final List<AnilistMedia> items;
  final double cardWidth;
  final double cardHeight;

  const AnilistMediaRow({
    super.key,
    required this.items,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemExtent: cardWidth + 8,
        itemCount: items.length,
        itemBuilder: (context, i) => RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnilistMediaCard(media: items[i], width: cardWidth, height: cardHeight),
          ),
        ),
      ),
    );
  }
}
