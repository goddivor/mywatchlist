import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/pages/Simkl/simkl_media_page.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// Opens a Simkl title on the app's native Simkl page (Simkl's own data only; the page keeps
/// "Open on MyAnimeList" in its menu when the title has a MyAnimeList id).
Future<void> openSimklMedia(
  BuildContext context,
  SimklMedia media, {
  SimklDiscoverService? service,
}) =>
    openSimklTitle(
      context,
      simklId: media.simklId,
      slug: media.slug,
      title: media.title,
      posterUrl: media.posterUrl,
    );

/// Opens the native Simkl page of [simklId]; [title] and [posterUrl] show while it loads.
Future<void> openSimklTitle(
  BuildContext context, {
  required int simklId,
  String? slug,
  String? title,
  String? posterUrl,
}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SimklMediaPage(simklId: simklId, slug: slug, title: title, posterUrl: posterUrl),
    ));

/// A poster card of the discover rows and grids: cover, a two-line title, and the rating or the
/// air time under it.
class SimklPosterCard extends StatelessWidget {
  final SimklMedia media;
  /// Width of the card; null fills the width it is given (grid cells).
  final double? width;
  final VoidCallback onTap;

  const SimklPosterCard({super.key, required this.media, this.width, required this.onTap});

  static const double aspect = 1.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detail = _detail(context);
    return Semantics(
      button: true,
      label: media.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (width != null)
                _poster(scheme, width: width, height: width! * aspect)
              else
                AspectRatio(aspectRatio: 1 / aspect, child: _poster(scheme)),
              const SizedBox(height: 6),
              Text(
                media.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              if (detail != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _poster(ColorScheme scheme, {double? width, double? height}) => AppImage(
        url: media.posterUrl,
        width: width,
        height: height,
        borderRadius: BorderRadius.circular(10),
        placeholderColor: scheme.surfaceContainerHighest,
        semanticLabel: media.title,
      );

  String? _detail(BuildContext context) {
    final air = media.airDate;
    if (media.episode != null && air != null) {
      final time = DateFormat.Hm().format(air.toLocal());
      return '${S.of(context).Sk_Episode_Short(media.episode!)} · $time';
    }
    if (media.episode != null) return S.of(context).Sk_Episode_Short(media.episode!);
    final parts = [
      if (media.rating != null) '★ ${media.rating!.toStringAsFixed(1)}',
      if (media.year != null) '${media.year}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// A horizontal row of [SimklPosterCard]s. Built lazily.
class SimklPosterRow extends StatelessWidget {
  final List<SimklMedia> items;
  final double cardWidth;
  final void Function(SimklMedia media) onTap;

  const SimklPosterRow({super.key, required this.items, required this.onTap, this.cardWidth = 116});

  /// Height of the row: cover, two title lines and the detail line (text scale included).
  static double heightFor(BuildContext context, double cardWidth) =>
      cardWidth * SimklPosterCard.aspect + 20 + MediaQuery.textScalerOf(context).scale(46);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightFor(context, cardWidth),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SimklPosterCard(
          media: items[i],
          width: cardWidth,
          onTap: () => onTap(items[i]),
        ),
      ),
    );
  }
}

/// Placeholder row while a section loads: one shared shimmer ticker, theme colours.
class SimklRowSkeleton extends StatelessWidget {
  final double cardWidth;

  const SimklRowSkeleton({super.key, this.cardWidth = 116});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ShimmerColor(
      SizedBox(
        height: SimklPosterRow.heightFor(context, cardWidth),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, __) => Align(
            alignment: Alignment.topCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: SizedBox(width: cardWidth, height: cardWidth * SimklPosterCard.aspect),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sliver grid of [SimklPosterCard]s: as many columns as fit [targetWidth], every cell the same
/// height (cover + two title lines + detail), built lazily.
class SimklMediaGrid extends StatelessWidget {
  final List<SimklMedia> items;
  final void Function(SimklMedia media) onTap;
  final double targetWidth;

  const SimklMediaGrid({super.key, required this.items, required this.onTap, this.targetWidth = 118});

  @override
  Widget build(BuildContext context) {
    final textExtent = 20 + MediaQuery.textScalerOf(context).scale(46);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const padding = 15.0;
        const spacing = 10.0;
        final inner = constraints.crossAxisExtent - padding * 2;
        final columns = (inner / (targetWidth + spacing)).floor().clamp(2, 8);
        final cell = (inner - spacing * (columns - 1)) / columns;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: padding),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: 12,
              mainAxisExtent: cell * SimklPosterCard.aspect + textExtent,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => SimklPosterCard(media: items[i], onTap: () => onTap(items[i])),
          ),
        );
      },
    );
  }
}
