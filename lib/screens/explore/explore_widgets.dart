import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_images.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/loading/loadingcard.dart';

/// Side margin shared by every Explore section.
const double kExplorePadding = 16;

/// Compact count ("12K") in the app language.
String compactCount(BuildContext context, num value) =>
    NumberFormat.compact(locale: Localizations.localeOf(context).toString()).format(value);

/// Title row of a section, with an optional "View all" button.
class ExploreSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const ExploreSectionHeader({super.key, required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kExplorePadding, 24, kExplorePadding - 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.current.View_All),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Loads a section when it is first built (a sliver builds it only near the viewport, so a
/// section below the fold costs nothing until the user scrolls to it) and shows a skeleton, the
/// data, an empty note, or an error with "Try again".
class AsyncSection<T> extends StatefulWidget {
  /// Changes when the data must be loaded again (e.g. Anime to Manga).
  final String reloadKey;
  final Future<T> Function() load;
  final bool Function(T data) isEmpty;
  final Widget Function(BuildContext context, T data) builder;
  final Widget skeleton;

  const AsyncSection({
    super.key,
    required this.reloadKey,
    required this.load,
    required this.builder,
    required this.skeleton,
    this.isEmpty = _never,
  });

  static bool _never(Object? _) => false;

  @override
  State<AsyncSection<T>> createState() => _AsyncSectionState<T>();
}

class _AsyncSectionState<T> extends State<AsyncSection<T>> {
  late Future<T> _future = widget.load();

  @override
  void didUpdateWidget(AsyncSection<T> old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) _future = widget.load();
  }

  void _retry() {
    final next = widget.load();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SectionMessage(
            icon: Icons.cloud_off_rounded,
            text: S.current.Explore_Section_Failed,
            onRetry: _retry,
          );
        }
        if (!snapshot.hasData) return widget.skeleton;
        final data = snapshot.data as T;
        if (widget.isEmpty(data)) {
          return SectionMessage(icon: Icons.inbox_outlined, text: S.current.Explore_Section_Empty);
        }
        return widget.builder(context, data);
      },
    );
  }
}

/// A short note for an empty or failed section, with an optional retry button.
class SectionMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  const SectionMessage({super.key, required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kExplorePadding, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(S.current.Explore_Try_Again)),
        ],
      ),
    );
  }
}

/// Placeholder row of a horizontal section.
Widget horizontalSkeleton({double height = 200, double width = 130}) => loadingCardList(
      containerHeight: height + 10,
      height: height,
      width: width,
      listPadding: const EdgeInsets.symmetric(horizontal: kExplorePadding - 5),
    );

/// A rounded tonal tile with an icon and a label: rankings and genre groups.
///
/// Flat alpha colour from [hue] (no gradient shader, no network picture), so a row of tiles costs
/// nothing to scroll.
class ExploreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? caption;
  final double hue;
  final VoidCallback onTap;
  final double width;
  final double height;

  const ExploreTile({
    super.key,
    required this.icon,
    required this.label,
    required this.hue,
    required this.onTap,
    this.caption,
    this.width = 148,
    this.height = 92,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = HSLColor.fromAHSL(1, hue % 360, dark ? 0.35 : 0.55, dark ? 0.24 : 0.88).toColor();
    final accent = HSLColor.fromAHSL(1, hue % 360, dark ? 0.6 : 0.65, dark ? 0.7 : 0.38).toColor();
    final textColor = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: base,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent, size: 24),
                const Spacer(),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: textColor, fontWeight: FontWeight.w600, fontSize: 13, height: 1.15),
                ),
                if (caption != null)
                  Text(caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Poster with a title under it (recommended pair members, characters, people).
class PosterTile extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final double width;
  final double imageHeight;
  final Widget? badge;

  /// Drawn at the bottom start corner of the picture (the favourites count of a person).
  final Widget? bottomBadge;
  final bool round;

  const PosterTile({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.width = 110,
    this.imageHeight = 156,
    this.badge,
    this.bottomBadge,
    this.round = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(round ? imageHeight : 12);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AppImage(
                  url: imageUrl,
                  width: width,
                  height: imageHeight,
                  borderRadius: radius,
                ),
                if (badge != null) PositionedDirectional(top: 6, start: 6, child: badge!),
                if (bottomBadge != null)
                  PositionedDirectional(bottom: 6, start: 6, child: bottomBadge!),
              ],
            ),
            const SizedBox(height: 6),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            if (subtitle != null)
              Text(subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Small rounded label drawn over a picture, on the `imageScrim` token (flat, no blur).
class CornerBadge extends StatelessWidget {
  final String text;
  final IconData? icon;

  /// Colour of [icon]; the label stays `onImageScrim`.
  final Color? iconColor;

  /// Read by screen readers instead of [text] (e.g. "12,345 favourites" for "12K").
  final String? semanticLabel;

  const CornerBadge(this.text, {super.key, this.icon, this.iconColor, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final badge = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.imageScrim,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: iconColor ?? tokens.onImageScrim),
              const SizedBox(width: 3),
            ],
            Text(text,
                style: TextStyle(
                    color: tokens.onImageScrim, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
    if (semanticLabel == null) return badge;
    return Semantics(label: semanticLabel, excludeSemantics: true, child: badge);
  }
}

/// A DailyAL Explore card: its bundled picture under the `imageScrim` token with the label
/// centred in `onImageScrim` (DailyAL fades the picture to 30 % behind the text; a flat scrim
/// keeps the same look and stays readable on every picture, in every theme mode).
///
/// The picture is decoded at the card's size (never above the 225 px source), so a row of
/// cards scrolls without decoding full pictures. Without a picture the card is an
/// [ExploreTile]; [hidden] replaces the picture by a flat block (adult content with NSFW off).
class ExplorePictureCard extends StatelessWidget {
  final String? asset;
  final String label;
  final String? caption;
  final IconData icon;
  final double hue;
  final VoidCallback onTap;
  final double width;
  final double height;
  final bool hidden;

  const ExplorePictureCard({
    super.key,
    required this.asset,
    required this.label,
    required this.icon,
    required this.hue,
    required this.onTap,
    this.caption,
    this.width = 148,
    this.height = 100,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    if (asset == null && !hidden) {
      return ExploreTile(
        icon: icon,
        label: label,
        caption: caption,
        hue: hue,
        onTap: onTap,
        width: width,
        height: height,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final tokens = AppColors.of(context);
    final foreground = hidden ? scheme.onSurfaceVariant : tokens.onImageScrim;
    final text = Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hidden) ...[
            Icon(Icons.eighteen_up_rating_rounded, color: foreground, size: 22),
            const SizedBox(height: 4),
          ],
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: hidden ? scheme.onSurface : foreground,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.15),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: foreground, fontSize: 11.5)),
          ],
        ],
      ),
    );
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: hidden ? scheme.surfaceContainerHighest : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!hidden && asset != null) ...[
              LayoutBuilder(builder: (context, constraints) {
                final ratio = MediaQuery.devicePixelRatioOf(context);
                final w = constraints.maxWidth.isFinite ? constraints.maxWidth : width;
                final decode = (w * ratio).round().clamp(32, ExploreImages.sourceWidth);
                return Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  cacheWidth: decode,
                  excludeFromSemantics: true,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                );
              }),
              ColoredBox(color: tokens.imageScrim),
            ],
            Center(child: text),
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}
