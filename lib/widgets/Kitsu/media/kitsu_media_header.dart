import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/header/header_background.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_format.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Expanded part of the title page's app bar, DailyAL's detail header: the banner faded into
/// the page, the title on two lines (long press copies it), the cover and the meta column (rank,
/// score, users, favourites, format, dates). Its height is fixed ([extent]) so nothing jumps
/// when the record arrives.
class KitsuMediaHeader extends StatelessWidget {
  static const double titleHeight = 62;
  static const double coverWidth = 130;
  static const double coverHeight = 195;
  static const double gap = 10;

  final KitsuMediaDetail? detail;
  final KitsuMediaKind kind;
  final String fallbackTitle;
  final String? fallbackPoster;

  const KitsuMediaHeader({
    super.key,
    required this.detail,
    required this.kind,
    required this.fallbackTitle,
    this.fallbackPoster,
  });

  static double extent(BuildContext context) =>
      MediaQuery.paddingOf(context).top + kToolbarHeight + titleHeight + gap + coverHeight + 18;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final name = d?.titles.display.isNotEmpty == true ? d!.titles.display : fallbackTitle;
    final poster = d?.poster?.url ?? fallbackPoster;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        DetailHeaderBackground(url: d?.banner?.url ?? poster),
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + kToolbarHeight),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: SizedBox(height: titleHeight, width: double.infinity, child: Center(child: _Title(name))),
              ),
              const SizedBox(height: gap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: coverHeight,
                  child: Row(
                    children: [
                      AppImage(
                        url: poster,
                        width: coverWidth,
                        height: coverHeight,
                        borderRadius: BorderRadius.circular(14),
                        placeholderColor: scheme.surfaceContainerHighest,
                        semanticLabel: name,
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: d == null ? const SizedBox.shrink() : _Meta(d)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;

  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        await Clipboard.setData(ClipboardData(text: text));
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(S.current.Kmp_Title_Copied)));
      },
      child: AutoSizeText(
        text,
        maxLines: 2,
        minFontSize: 14,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// DailyAL's meta column: "# rank" at 20, star and score at 26, users, then the format, the
/// status and the dates.
class _Meta extends StatelessWidget {
  final KitsuMediaDetail d;

  const _Meta(this.d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final anime = d.kind == KitsuMediaKind.anime;
    final total = anime ? d.episodeCount : d.chapterCount;
    final format = [
      if (d.subtype != null) KitsuMediaFormat.subtype(d.subtype),
      if (total != null && total > 0) '(${anime ? S.current.Kmp_Episodes_Short(total) : S.current.Kmp_Chapters_Short(total)})',
    ].join(' ');
    final rating = d.averageRating;
    final counts = [
      if (d.userCount != null && d.userCount! > 0) KitsuMediaFormat.users(d.userCount!),
    ];
    final label = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final status = KitsuMediaFormat.status(d.status, d.kind);
    final dates = KitsuMediaFormat.span(d.startDate, d.endDate);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 26, color: colors.score.color),
              const SizedBox(width: 4),
              Text(rating == null ? '?' : KitsuMediaFormat.score(rating), style: const TextStyle(fontSize: 26)),
            ],
          ),
          if (d.averageRatingRank != null)
            Text(S.current.Kmp_Rank_Rated(KitsuMediaFormat.count(d.averageRatingRank!)),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
          if (d.userCountRank != null)
            Text(S.current.Kmp_Rank_Popular(KitsuMediaFormat.count(d.userCountRank!)),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
          for (final line in counts) Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
          if (format.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(format, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          if (status.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
          ],
          if (dates.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(anime ? S.current.Kmp_Aired : S.current.Kmp_Published,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: label),
            Text(dates, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
          ],
        ],
      ),
    );
  }
}
