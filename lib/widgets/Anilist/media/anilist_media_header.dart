import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart' show AnilistMediaQuery, AnilistRange;
import 'package:mywatchlist/services/api/Anilist/anilist_media_detail.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_chips.dart' show openAnilistBrowse;
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_format.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_result_tiles.dart' show anilistScoreRole;
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart' show zoomInImage;

/// The banner behind the app bar: `bannerImage`, else the cover blurred and zoomed to fill
/// it (as the AniList apps do), else the cover's colour; it fades into the page.
class AnilistMediaBanner extends StatelessWidget {
  const AnilistMediaBanner({super.key, this.bannerUrl, this.coverUrl, this.coverColor});

  final String? bannerUrl;
  final String? coverUrl;
  final String? coverColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AnilistMediaFormat.hexColor(coverColor) ?? scheme.primaryContainer;
    final scrim = AppColors.of(context).imageScrim;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bannerUrl != null)
          AppImage(url: bannerUrl, placeholderColor: accent, errorWidget: (_) => ColoredBox(color: accent))
        else if (coverUrl != null)
          ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18, tileMode: TileMode.clamp),
              child: AppImage(
                url: coverUrl,
                placeholderColor: accent,
                errorWidget: (_) => ColoredBox(color: accent),
              ),
            ),
          )
        else
          ColoredBox(color: accent),
        // Keeps the app bar icons readable on any picture, then melts into the page.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [scrim.withValues(alpha: 0.45), scrim.withValues(alpha: 0), scheme.surface],
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// Cover over the banner's edge, title (long press copies), the second title, AniList's
/// label rail (format · season · status · 18+ · my status · next episode · behind), the stat
/// row (average and mean as %, popularity, favourites) and the top rankings.
class AnilistMediaHeader extends StatelessWidget {
  const AnilistMediaHeader({super.key, required this.detail});

  final AnilistMediaDetail detail;

  static const double coverWidth = 104;
  static const double coverHeight = 152;
  static const double _overlap = 56;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: detail.title));
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.current.Amp_Copied)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = detail;
    final second = [d.native, d.english, d.romaji]
        .firstWhere((t) => t != null && t != d.title, orElse: () => null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 16,
              top: -_overlap,
              child: GestureDetector(
                onTap: d.coverLargeUrl == null ? null : () => zoomInImage(context, d.coverLargeUrl!),
                child: AppImage(
                  url: d.coverUrl,
                  width: coverWidth,
                  height: coverHeight,
                  borderRadius: BorderRadius.circular(10),
                  placeholderColor: AnilistMediaFormat.hexColor(d.coverColor) ?? scheme.surfaceContainerHighest,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16 + coverWidth + 14, 8, 16, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: coverHeight - _overlap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: () => _copy(context),
                      child: Text(
                        d.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    if (second != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          second,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    const SizedBox(height: 8),
                    AnilistLabelRail(detail: d),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AnilistStatRow(detail: d),
        if (d.topRankings.isNotEmpty) AnilistRankingChips(detail: d, rankings: d.topRankings),
      ],
    );
  }
}

/// Otraku's text rail: small labels, the user's status and the airing ones highlighted.
class AnilistLabelRail extends StatelessWidget {
  const AnilistLabelRail({super.key, required this.detail});

  final AnilistMediaDetail detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    final when = [
      if (d.season != null) AnilistLabels.season(d.season!),
      if (d.seasonYear != null) '${d.seasonYear}' else if (d.startDate != null) d.startDate!.split('-').first,
    ].join(' ');
    final countdown = d.nextAiringAt == null ? null : AnilistMediaFormat.countdown(d.nextAiringAt!);
    final labels = <(String, AppColorRole?)>[
      if (d.format != null) (AnilistLabels.format(d.format!), null),
      if (when.isNotEmpty) (when, null),
      if (d.status != null) (AnilistLabels.status(d.status!), null),
      if (d.isAdult) (s.Amp_Adult, colors.danger),
      if (d.entry?.status != null)
        (AnilistLabels.listStatus(d.entry!.status!, anime: d.isAnime), colors.statusOf(d.entry!.status)),
      if (d.nextEpisode != null && countdown != null)
        (s.Amp_Next_Episode(d.nextEpisode!, countdown), colors.success),
      if (d.behind > 0) (s.Amp_Behind(d.behind), colors.warning),
    ];
    final style = Theme.of(context).textTheme.labelMedium;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (text, role) in labels)
          DecoratedBox(
            decoration: BoxDecoration(
              color: role?.container ?? scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              child: Text(text, style: style?.copyWith(color: role?.onContainer ?? scheme.onSurface)),
            ),
          ),
      ],
    );
  }
}

/// Four number tiles: AniList's average and mean scores as percentages (AniList's own unit,
/// coloured on anilist.co's scale), popularity and favourites.
class AnilistStatRow extends StatelessWidget {
  const AnilistStatRow({super.key, required this.detail});

  final AnilistMediaDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = detail;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget tile(String value, String caption, {Color? color, IconData? icon}) => Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: color ?? scheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: color ?? scheme.onSurface, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          tile(
            d.weightedScore == null ? '-' : AnilistMediaFormat.percent(d.weightedScore!),
            s.Amp_Average,
            color: d.weightedScore == null ? null : anilistScoreRole(context, d.weightedScore!).color,
          ),
          tile(
            d.meanScore == null ? '-' : AnilistMediaFormat.percent(d.meanScore!),
            s.Amp_Mean,
            color: d.meanScore == null ? null : anilistScoreRole(context, d.meanScore!).color,
          ),
          tile(AnilistMediaFormat.compact(d.popularity), s.Popularity, icon: Icons.people_alt_outlined),
          tile(AnilistMediaFormat.compact(d.favourites), s.Favorites, icon: Icons.favorite_outline),
        ],
      ),
    );
  }
}

/// Opens the titles a ranking counts: same sort, season / year and format.
void openAnilistRanking(BuildContext context, AnilistMediaDetail d, AnilistRanking r) {
  final year = r.allTime ? null : r.year;
  openAnilistBrowse(
    context,
    AnilistMediaFormat.ranking(r).replaceFirst(RegExp(r'^\S*\s'), ''),
    AnilistMediaQuery(
      category: d.category,
      sort: r.rated ? 'SCORE_DESC' : 'POPULARITY_DESC',
      season: year == null ? null : r.season,
      seasonYear: r.season == null ? null : year,
      years: year != null && r.season == null ? AnilistRange(min: year, max: year) : AnilistRange.any,
      formats: r.format == null ? const [] : [r.format!],
    ),
  );
}

/// Tappable ranking chips ("#1 Highest rated all time"); a tap opens that ranking.
class AnilistRankingChips extends StatelessWidget {
  const AnilistRankingChips({super.key, required this.detail, required this.rankings});

  final AnilistMediaDetail detail;
  final List<AnilistRanking> rankings;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final r in rankings)
            ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(r.rated ? Icons.star_rounded : Icons.favorite_rounded,
                  size: 18, color: r.rated ? colors.score.color : colors.danger.color),
              label: Text(AnilistMediaFormat.ranking(r)),
              onPressed: () => openAnilistRanking(context, detail, r),
            ),
        ],
      ),
    );
  }
}
