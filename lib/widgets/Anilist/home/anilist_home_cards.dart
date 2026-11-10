import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_character_page.dart' show openAnilistCharacter;
import 'package:mywatchlist/pages/Anilist/anilist_review_page.dart' show openAnilistReview;
import 'package:mywatchlist/pages/Anilist/anilist_staff_page.dart' show openAnilistStaff;
import 'package:mywatchlist/services/api/Anilist/anilist_feeds_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistTitle;
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart'
    show AnilistScorePill, formatAnilistTime;
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/loading/loadingcard.dart';

/// Opens an AniList title of a home or Explore row: always AniList's own page (owner rule,
/// never the MyAnimeList one, mapped or not).
void openAnilistHomeMedia(BuildContext context, AnilistMedia media) =>
    openAnilistTitle(context, category: media.category, id: media.id);

/// A row that failed (with Retry) or came back empty, in the row's own height so the page
/// does not jump.
class AnilistRowMessage extends StatelessWidget {
  const AnilistRowMessage({super.key, required this.failed, this.onRetry});

  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(failed ? Icons.cloud_off_rounded : Icons.inbox_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              failed ? s.Ahx_Row_Failed : s.Ahx_Row_Empty,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          if (failed && onRetry != null) TextButton(onPressed: onRetry, child: Text(s.Ahx_Retry)),
        ],
      ),
    );
  }
}

/// The skeleton of a row of covers.
Widget anilistRowSkeleton({required double cardWidth, required double cardHeight, int count = 6}) =>
    loadingCardList(
      containerHeight: cardHeight,
      height: cardHeight,
      width: cardWidth,
      itemCount: count,
      listPadding: const EdgeInsets.all(8),
    );

/// A cover with AniList's score as a percentage (anilist.co's red / amber / green scale),
/// a badge at the bottom (the next or the trending episode) and the title. Fixed size, so a
/// row never measures its cards. A tap opens the AniList title page.
class AnilistHomeCard extends StatelessWidget {
  const AnilistHomeCard({
    super.key,
    required this.media,
    required this.width,
    required this.height,
    this.badge,
    this.badgeIcon,
    this.subtitle,
  });

  final AnilistMedia media;
  final double width;
  final double height;

  /// Bottom badge; by default the next episode of an airing title.
  final String? badge;
  final IconData? badgeIcon;

  /// One line under the title (e.g. why a title is recommended).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final next = media.nextEpisode;
    final badge = this.badge ?? (next != null ? S.current.Al_Episode_Short(next) : null);
    final score = media.score;
    return SizedBox(
      width: width,
      height: height,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openAnilistHomeMedia(context, media),
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
                        child: Icon(Icons.image_not_supported_outlined, color: cs.onSurfaceVariant),
                      ),
                    ),
                    if (score != null)
                      PositionedDirectional(
                        top: 6,
                        start: 6,
                        child: AnilistScorePill(score: (score * 10).round()),
                      ),
                    if (badge != null)
                      PositionedDirectional(
                        bottom: 6,
                        start: 6,
                        child: _Badge(label: badge, icon: badgeIcon),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                media.title,
                maxLines: subtitle == null ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: cs.onPrimaryContainer),
              const SizedBox(width: 2),
            ],
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// A lazy horizontal row of fixed-extent cards.
class AnilistCardRow extends StatelessWidget {
  const AnilistCardRow({
    super.key,
    required this.count,
    required this.extent,
    required this.height,
    required this.itemBuilder,
  });

  final int count;

  /// Width of one card.
  final double extent;
  final double height;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemExtent: extent + 8,
        itemCount: count,
        itemBuilder: (context, i) => RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: itemBuilder(context, i),
          ),
        ),
      ),
    );
  }
}

/// A row of [AnilistHomeCard]s.
class AnilistMediaCardRow extends StatelessWidget {
  const AnilistMediaCardRow({
    super.key,
    required this.items,
    required this.cardWidth,
    required this.cardHeight,
  });

  final List<AnilistMedia> items;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) => AnilistCardRow(
        count: items.length,
        extent: cardWidth,
        height: cardHeight,
        itemBuilder: (context, i) =>
            AnilistHomeCard(media: items[i], width: cardWidth, height: cardHeight),
      );
}

/// Trends of the day: each card shows the episode that made the title trend.
class AnilistTrendRow extends StatelessWidget {
  const AnilistTrendRow({super.key, required this.items, required this.cardWidth, required this.cardHeight});

  final List<AnilistTrend> items;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) => AnilistCardRow(
        count: items.length,
        extent: cardWidth,
        height: cardHeight,
        itemBuilder: (context, i) {
          final t = items[i];
          return AnilistHomeCard(
            media: t.media,
            width: cardWidth,
            height: cardHeight,
            badge: t.episode == null ? null : S.current.Al_Episode_Short(t.episode!),
            badgeIcon: t.episode == null ? null : Icons.trending_up_rounded,
          );
        },
      );
}

/// Recommendations from the user's list: the recommended title, and under it the title of
/// the list it comes from.
class AnilistRecommendedRow extends StatelessWidget {
  const AnilistRecommendedRow({super.key, required this.items, required this.cardWidth, required this.cardHeight});

  final List<AnilistRecommendationPair> items;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) => AnilistCardRow(
        count: items.length,
        extent: cardWidth,
        height: cardHeight,
        itemBuilder: (context, i) {
          final r = items[i];
          final from = r.from?.title;
          return AnilistHomeCard(
            media: r.to,
            width: cardWidth,
            height: cardHeight,
            subtitle: from == null || from.isEmpty ? null : S.current.Ahx_Because(from),
          );
        },
      );
}

/// Everyone's latest recommendations as pairs: "if you liked this" cover, then the
/// recommended cover, with the votes. Each cover opens its title.
class AnilistRecommendationPairRow extends StatelessWidget {
  const AnilistRecommendationPairRow({super.key, required this.items});

  final List<AnilistRecommendationPair> items;

  static const double _cover = 84;
  static const double height = _cover * 1.45 + 52;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    Widget cover(String? url, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AppImage(
            url: url,
            width: _cover,
            height: _cover * 1.45,
            borderRadius: BorderRadius.circular(10),
            placeholderColor: cs.surfaceContainerHighest,
          ),
        );
    return AnilistCardRow(
      count: items.length,
      extent: _cover * 2 + 28,
      height: height,
      itemBuilder: (context, i) {
        final r = items[i];
        final from = r.from;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                cover(from?.coverUrl, () {
                  if (from != null) openAnilistTitle(context, category: from.category, id: from.id);
                }),
                SizedBox(
                  width: 28,
                  child: Icon(Icons.arrow_forward_rounded, size: 18, color: cs.onSurfaceVariant),
                ),
                cover(r.to.coverUrl, () => openAnilistHomeMedia(context, r.to)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              r.to.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
            ),
            Text(
              [if (from != null && from.title.isNotEmpty) from.title, if (r.rating > 0) S.current.Ahx_Votes(r.rating)]
                  .join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

/// Characters and staff as round portraits with their name; a tap opens their AniList page.
class AnilistPeopleRow extends StatelessWidget {
  const AnilistPeopleRow({super.key, required this.items, this.showKind = false});

  final List<AnilistPersonCard> items;

  /// Writes "Character" / "Staff" under the name (rows that mix both).
  final bool showKind;

  static const double _size = 84;
  static const double height = _size + 58;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AnilistCardRow(
      count: items.length,
      extent: _size + 8,
      height: height,
      itemBuilder: (context, i) {
        final p = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => p.isStaff
              ? openAnilistStaff(context, p.person.id)
              : openAnilistCharacter(context, p.person.id),
          child: Column(
            children: [
              const SizedBox(height: 4),
              AppImage(
                url: p.person.imageUrl,
                width: _size,
                height: _size,
                borderRadius: BorderRadius.circular(_size / 2),
                placeholderColor: cs.surfaceContainerHighest,
                errorWidget: (_) => CircleAvatar(
                  radius: _size / 2,
                  backgroundColor: cs.surfaceContainerHighest,
                  child: Icon(Icons.person_outline_rounded, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                p.person.name,
                maxLines: showKind ? 1 : 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
              if (showKind)
                Text(
                  p.isStaff ? S.current.Ahx_Staff : S.current.Ahx_Character,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The latest reviews as cards: banner or cover, title, summary, score and reviewer. A tap
/// opens the review in the app.
class AnilistReviewCardRow extends StatelessWidget {
  const AnilistReviewCardRow({super.key, required this.items});

  final List<AnilistReview> items;

  static const double width = 280;
  static const double height = 176;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AnilistCardRow(
      count: items.length,
      extent: width,
      height: height,
      itemBuilder: (context, i) {
        final r = items[i];
        final media = r.media;
        return Material(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openAnilistReview(context, r.id, initial: r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: AppImage(
                    url: media?.bannerUrl ?? media?.coverUrl,
                    alignment: Alignment.topCenter,
                    placeholderColor: cs.surfaceContainerHighest,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          media?.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Text(
                            r.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                        Row(
                          children: [
                            if (r.score > 0) ...[
                              AnilistScorePill(score: r.score),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                [r.user?.name ?? '', formatAnilistTime(r.createdAt)]
                                    .where((t) => t.isNotEmpty)
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A screen of another tab (forum, list) opened from the home: it keeps its own header, and
/// an opaque app bar with a back button and [title] covers that header, so the pushed page
/// can be left like any other.
class AnilistPushedTab extends StatelessWidget {
  const AnilistPushedTab({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: AppBar(
              title: Text(title),
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
