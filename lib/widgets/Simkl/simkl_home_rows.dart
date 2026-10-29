import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart' show SimklTitle;
import 'package:mywatchlist/services/api/SimKl/simkl_detail_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Header of a Simkl home row: the title, then (for Simkl's own charts, as its terms ask)
/// "on Simkl", and an arrow when the row opens a full list. The whole header is the tap target.
class SimklRowHeader extends StatelessWidget {
  final String title;
  final bool onSimkl;
  final VoidCallback? onTap;

  const SimklRowHeader({super.key, required this.title, this.onSimkl = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.titleLarge;
    return Semantics(
      header: true,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 6, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
              if (onSimkl) ...[
                const SizedBox(width: 6),
                Text(S.current.Skr_On_Simkl, style: style?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              const Spacer(),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simkl's trending chart as wide cards: picture, rank, title, Simkl score and the number of
/// watchers. The picture is the title's fanart (from the trending file), else its poster.
class SimklTrendingCarousel extends StatelessWidget {
  final List<SimklMedia> items;
  final void Function(SimklMedia media) onTap;
  final SimklDetailService? details;

  const SimklTrendingCarousel({super.key, required this.items, required this.onTap, this.details});

  static double heightFor(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * 0.82).clamp(220.0, 420.0);
    return width * 9 / 16;
  }

  @override
  Widget build(BuildContext context) {
    final height = heightFor(context);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _TrendingCard(
          media: items[i],
          rank: i + 1,
          width: height * 16 / 9,
          height: height,
          details: details,
          onTap: () => onTap(items[i]),
        ),
      ),
    );
  }
}

class _TrendingCard extends StatefulWidget {
  final SimklMedia media;
  final int rank;
  final double width;
  final double height;
  final SimklDetailService? details;
  final VoidCallback onTap;

  const _TrendingCard({
    required this.media,
    required this.rank,
    required this.width,
    required this.height,
    required this.details,
    required this.onTap,
  });

  @override
  State<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<_TrendingCard> {
  String? _fanart;

  SimklDetailService get _service => widget.details ?? SimklDetailService.instance;

  @override
  void initState() {
    super.initState();
    // The trending file carries the fanart; a record already kept is the fallback (no record
    // call per card on every home open).
    _fanart = widget.media.fanartUrl ??
        _service.peek<SimklTitle>(SimklDetailService.titleKey(widget.media.simklId))?.fanartUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final m = widget.media;
    final onImage = colors.onImageScrim;
    final details = [
      if (m.rating != null) '★ ${SimklFormat.score(m.rating!)}',
      if (m.watchers != null && m.watchers! > 0) S.current.Skr_Watchers(SimklFormat.compact(m.watchers!)),
      if (SimklFormat.type(m.animeType) case final type?) type,
    ].join(' · ');
    return Semantics(
      button: true,
      label: m.title,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(
                  url: _fanart ?? m.posterUrl,
                  width: widget.width,
                  height: widget.height,
                  alignment: _fanart == null ? const Alignment(0, -0.4) : Alignment.center,
                  placeholderColor: scheme.surfaceContainerHighest,
                ),
                DecoratedBox(decoration: BoxDecoration(gradient: colors.bottomScrimGradient)),
                Positioned(
                  left: 12,
                  top: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: colors.imageScrim, borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Text('#${widget.rank}', style: theme.textTheme.labelLarge?.copyWith(color: onImage)),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(color: onImage, fontWeight: FontWeight.w600),
                      ),
                      if (details.isNotEmpty)
                        Text(details, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(color: onImage)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
