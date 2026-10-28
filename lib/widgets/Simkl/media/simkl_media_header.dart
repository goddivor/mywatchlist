import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/header/header_background.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Expanded part of the title page's app bar, DailyAL's detail header: faded background
/// picture, the title on two lines (long press copies it), the cover and the meta column
/// (rank, Simkl score and votes, format and episodes, aired, MyAnimeList score, drop rate,
/// studios). Its height is fixed ([extent]) so nothing jumps when the record arrives.
class SimklMediaHeader extends StatelessWidget {
  static const double titleHeight = 62;
  static const double coverWidth = 130;
  static const double coverHeight = 195;
  static const double gap = 10;

  final SimklTitle? title;
  final String fallbackTitle;
  final String? fallbackPoster;

  const SimklMediaHeader({super.key, required this.title, required this.fallbackTitle, this.fallbackPoster});

  static double extent(BuildContext context) =>
      MediaQuery.paddingOf(context).top + kToolbarHeight + titleHeight + gap + coverHeight + 18;

  @override
  Widget build(BuildContext context) {
    final t = title;
    final name = t?.title ?? fallbackTitle;
    final poster = t?.posterUrl ?? fallbackPoster;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        DetailHeaderBackground(url: t?.fanartUrl ?? poster),
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
                      Expanded(child: t == null ? const SizedBox.shrink() : _Meta(t)),
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
          ..showSnackBar(SnackBar(content: Text(S.current.Smp_Title_Copied)));
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

/// DailyAL's meta column: "# rank" at 20, star + score at 26, votes, then label / value pairs.
class _Meta extends StatelessWidget {
  final SimklTitle t;

  const _Meta(this.t);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final rating = t.simklRating;
    final type = SimklFormat.type(t.animeType);
    final eps = t.totalEpisodes;
    final format = [
      if (type != null) type,
      if (eps != null && eps > 0) '(${S.current.Smp_Episodes_Short(eps)})',
    ].join(' ');
    final aired = t.seasonNameYear ?? SimklFormat.aired(t);
    final mal = t.malRating;
    final pairs = <(String, String)>[
      if (aired != null) (S.current.Smp_Aired, aired),
      if (mal != null) (S.current.Smp_Mal, '★ ${SimklFormat.score(mal.rating)}'),
      if (t.dropRate != null) (S.current.Smp_Drop_Rate, SimklFormat.percent(t.dropRate!)),
      if (t.studios.isNotEmpty) (S.current.Smp_Studios, t.studios.join(', ')),
    ];
    final label = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.rank == null ? '# ?' : S.current.Smp_Rank(SimklFormat.count(t.rank!)),
            maxLines: 1,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.star_rounded, size: 26, color: colors.score.color),
              const SizedBox(width: 4),
              Text(rating == null ? '?' : SimklFormat.score(rating.rating), style: const TextStyle(fontSize: 26)),
            ],
          ),
          if (rating?.votes != null)
            Text(SimklFormat.votes(rating!.votes!), style: theme.textTheme.labelSmall),
          if (format.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(format, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          for (final (k, v) in pairs.take(3)) ...[
            const SizedBox(height: 7),
            Text(k, maxLines: 1, overflow: TextOverflow.ellipsis, style: label),
            const SizedBox(height: 1),
            Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
          ],
        ],
      ),
    );
  }
}
