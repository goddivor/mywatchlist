import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_sections.dart' show simklPagePadding;
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Simkl's 16:9 fanart behind the app bar, with a scrim at the top (toolbar icons) and at the
/// bottom (where the poster overlaps). Simkl has no fanart placeholder: without one, the page
/// has no hero ([SimklMediaHero.extent] gives the toolbar only).
class SimklMediaHero extends StatelessWidget {
  final String? fanartUrl;

  const SimklMediaHero({super.key, required this.fanartUrl});

  /// Expanded height of the app bar (status bar included).
  static double extent(BuildContext context, {required bool hasFanart}) {
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    if (!hasFanart) return top;
    final hero = MediaQuery.sizeOf(context).width * 9 / 16;
    return hero < top + 40 ? top + 40 : hero;
  }

  @override
  Widget build(BuildContext context) {
    final url = fanartUrl;
    final colors = AppColors.of(context);
    final page = Theme.of(context).scaffoldBackgroundColor;
    if (url == null) return ColoredBox(color: page);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
        AppImage(url: url, fit: BoxFit.cover, errorWidget: (_) => const SizedBox.shrink()),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.35, 0.7, 1],
              colors: [
                colors.imageScrim,
                colors.imageScrim.withValues(alpha: 0),
                page.withValues(alpha: 0),
                page,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A toolbar button readable on the fanart and on the collapsed bar: a round scrim behind it.
class SimklHeroButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const SimklHeroButton({super.key, required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(backgroundColor: colors.imageScrim, foregroundColor: colors.onImageScrim),
        icon: Icon(icon),
      ),
    );
  }
}

/// Poster (overlapping the hero's bottom when there is one), the title, the other form of the
/// title and Simkl's meta line: years · network · total time · episodes · format · age rating.
class SimklTitleBlock extends StatelessWidget {
  static const double posterWidth = 108;
  static const double posterHeight = 162;

  final SimklTitle? title;
  final String fallbackTitle;
  final String? fallbackPoster;
  final bool overlap;

  const SimklTitleBlock({
    super.key,
    required this.title,
    required this.fallbackTitle,
    this.fallbackPoster,
    this.overlap = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = title;
    final name = t?.title ?? fallbackTitle;
    final other = t?.enTitle != null && t!.enTitle != name ? t.enTitle : null;
    final meta = t == null ? '' : metaLine(t);
    final shift = overlap ? 48.0 : 0.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(simklPagePadding, overlap ? 0 : 8, simklPagePadding, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: Offset(0, -shift),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
              ),
              child: AppImage(
                url: t?.posterUrl ?? fallbackPoster,
                width: posterWidth,
                height: posterHeight,
                borderRadius: BorderRadius.circular(10),
                placeholderColor: scheme.surfaceContainerHighest,
                semanticLabel: name,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CopyableTitle(name),
                  if (other != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      other,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(meta, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "2019 – 2024 · Fuji TV · 1d 22h · 55 eps · TV · TV-MA".
  static String metaLine(SimklTitle t) {
    final first = int.tryParse((t.firstAired ?? '').split('-').first);
    final last = int.tryParse((t.lastAired ?? '').split('-').first);
    final start = first ?? t.year;
    final years = start == null
        ? null
        : (last != null && last != start && SimklFormat.status(t.status) == S.current.Smp_Status_Ended)
            ? '$start – $last'
            : '$start';
    final eps = t.totalEpisodes;
    final runtime = t.runtime;
    return [
      if (years != null) years,
      if (t.network != null) t.network!,
      if (eps != null && eps > 1 && runtime != null && runtime > 0) SimklFormat.minutes(eps * runtime),
      if (eps != null && eps > 0) S.current.Smp_Episodes_Short(eps),
      if (SimklFormat.type(t.animeType) case final type?) type,
      if (t.certification != null) t.certification!,
    ].join(' · ');
  }
}

class _CopyableTitle extends StatelessWidget {
  final String text;

  const _CopyableTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        await Clipboard.setData(ClipboardData(text: text));
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(S.current.Smp_Title_Copied)));
      },
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The ratings strip under the title: Simkl, MyAnimeList and IMDb scores with their votes, the
/// Simkl rank and the drop rate. A source Simkl has no figure for is left out.
class SimklRatingStrip extends StatelessWidget {
  final SimklTitle title;

  const SimklRatingStrip({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = title;
    final colors = AppColors.of(context);
    final chips = <Widget>[
      if (t.simklRating case final r?) _RatingChip(source: 'Simkl', rating: r, star: colors.score.color),
      if (t.malRating case final r?) _RatingChip(source: 'MAL', rating: r),
      if (t.imdbRating case final r?) _RatingChip(source: S.current.Smp_Imdb, rating: r),
      if (t.rank != null) _PlainChip(value: S.current.Smp_Rank(SimklFormat.count(t.rank!)), icon: Icons.leaderboard_outlined),
      if (t.dropRate != null)
        _PlainChip(label: S.current.Smp_Drop_Rate, value: SimklFormat.percent(t.dropRate!), icon: Icons.trending_down_rounded),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(simklPagePadding, 4, simklPagePadding, 0),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }
}

class _ChipShell extends StatelessWidget {
  final Widget child;

  const _ChipShell({required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: child),
      );
}

class _RatingChip extends StatelessWidget {
  final String source;
  final SimklRating rating;
  final Color? star;

  const _RatingChip({required this.source, required this.rating, this.star});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _ChipShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(source, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: 6),
            Icon(Icons.star_rounded, size: 16, color: star ?? scheme.onSurfaceVariant),
            const SizedBox(width: 2),
            Text(SimklFormat.score(rating.rating), style: theme.textTheme.titleSmall),
          ]),
          if (rating.votes != null)
            Text(
              SimklFormat.votes(rating.votes!),
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _PlainChip extends StatelessWidget {
  final String? label;
  final String value;
  final IconData icon;

  const _PlainChip({this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _ChipShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Text(label!, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 4),
            Text(value, style: theme.textTheme.titleSmall),
          ]),
        ],
      ),
    );
  }
}
