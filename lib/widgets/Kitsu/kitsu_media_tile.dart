import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_open.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// A poster tile of the Kitsu catalogue (browse grid, favorites): cover, mean score badge, the
/// title on two lines and the type with the year. A tap opens the title's Kitsu page.
class KitsuMediaTile extends StatelessWidget {
  final KitsuMedia media;

  const KitsuMediaTile({super.key, required this.media});

  /// Grid of tiles for a view [width] dp wide with [padding] dp on each side: at least two
  /// columns, about 130 dp each, a 2:3 cover and the fixed text block.
  static SliverGridDelegate gridDelegate(double width, {double padding = 12}) {
    final columns = (width / 130).floor().clamp(2, 8);
    const gap = 10.0;
    final tile = (width - 2 * padding - (columns - 1) * gap) / columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: gap,
      childAspectRatio: tile / (tile * 1.5 + textHeight),
    );
  }

  /// Height of the text block under the cover (two title lines plus the subtitle).
  static const double textHeight = 62;

  String? get _subtitle {
    final year = media.startDate != null && media.startDate!.length >= 4
        ? media.startDate!.substring(0, 4)
        : null;
    final type = media.subtype;
    return [if (type != null) type, if (year != null) year].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = AppColors.of(context);
    final score = media.meanScore;
    return InkWell(
      onTap: () => openKitsuMedia(context, media),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(
                  url: media.largePosterUrl ?? media.posterUrl,
                  borderRadius: BorderRadius.circular(12),
                  placeholderColor: scheme.surfaceContainerHighest,
                  semanticLabel: media.title,
                ),
                if (score != null)
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.imageScrim.withValues(alpha: AppColors.imageScrimOpacity),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 14, color: tokens.onImageScrim),
                            const SizedBox(width: 2),
                            Text(
                              NumberFormat('0.0').format(score),
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: tokens.onImageScrim, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: textHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(media.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                  if (_subtitle != null && _subtitle!.isNotEmpty)
                    Text(_subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
