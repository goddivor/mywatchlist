import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media_detail.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';

/// How the AniList title page writes AniList's values.
abstract final class AnilistMediaFormat {
  static String get _locale => Intl.getCurrentLocale();

  /// `312K`, `1.2M` in the app locale.
  static String compact(int n) => NumberFormat.compact(locale: _locale).format(n);

  /// `494,191` in the app locale.
  static String number(int n) => NumberFormat.decimalPattern(_locale).format(n);

  /// AniList's 0-100 score as a percentage (`82%`, `82 %` in French).
  static String percent(int score) => NumberFormat.percentPattern(_locale).format(score / 100);

  /// `2d 3h`, `5h 12m`, `8m` until [at] from [now]; null once passed.
  static String? countdown(DateTime at, {DateTime? now}) {
    final left = at.difference(now ?? DateTime.now());
    if (left.isNegative) return null;
    final s = S.current;
    if (left.inDays > 0) return s.Amp_Time_Days(left.inDays, left.inHours % 24);
    if (left.inHours > 0) return s.Amp_Time_Hours(left.inHours, left.inMinutes % 60);
    return s.Amp_Time_Minutes(left.inMinutes < 1 ? 1 : left.inMinutes);
  }

  /// A `yyyy-MM-dd` / `yyyy-MM` / `yyyy` date in the app locale.
  static String date(String value) {
    final parts = value.split('-').map(int.tryParse).toList();
    final year = parts.isNotEmpty ? parts[0] : null;
    if (year == null) return value;
    final month = parts.length > 1 ? parts[1] : null;
    final day = parts.length > 2 ? parts[2] : null;
    if (month == null) return '$year';
    final d = DateTime(year, month, day ?? 1);
    return day == null
        ? DateFormat.yMMM(_locale).format(d)
        : DateFormat.yMMMd(_locale).format(d);
  }

  /// "#1 Highest rated all time", "#3 Most popular Fall 2023".
  static String ranking(AnilistRanking r) {
    final s = S.current;
    if (r.allTime || r.year == null) {
      return r.rated ? s.Amp_Rank_Rated_All(r.rank) : s.Amp_Rank_Popular_All(r.rank);
    }
    if (r.season != null) {
      final season = AnilistLabels.season(r.season!);
      return r.rated
          ? s.Amp_Rank_Rated_Season(r.rank, season, r.year!)
          : s.Amp_Rank_Popular_Season(r.rank, season, r.year!);
    }
    return r.rated ? s.Amp_Rank_Rated_Year(r.rank, r.year!) : s.Amp_Rank_Popular_Year(r.rank, r.year!);
  }

  /// A `MediaRelation` (version 2) in the app language; English words for unknown values.
  static String relation(String type) {
    final words = type.toLowerCase().replaceAll('_', ' ');
    final raw = words.isEmpty ? type : words[0].toUpperCase() + words.substring(1);
    final s = S.current;
    return switch (type) {
      'ADAPTATION' => s.Amp_Rel_ADAPTATION,
      'PREQUEL' => s.Amp_Rel_PREQUEL,
      'SEQUEL' => s.Amp_Rel_SEQUEL,
      'PARENT' => s.Amp_Rel_PARENT,
      'SIDE_STORY' => s.Amp_Rel_SIDE_STORY,
      'CHARACTER' => s.Amp_Rel_CHARACTER,
      'SUMMARY' => s.Amp_Rel_SUMMARY,
      'ALTERNATIVE' => s.Amp_Rel_ALTERNATIVE,
      'SPIN_OFF' => s.Amp_Rel_SPIN_OFF,
      'OTHER' => s.Amp_Rel_OTHER,
      'SOURCE' => s.Amp_Rel_SOURCE,
      'COMPILATION' => s.Amp_Rel_COMPILATION,
      'CONTAINS' => s.Amp_Rel_CONTAINS,
      _ => raw,
    };
  }

  /// A `#rrggbb` colour of AniList's data (cover accent, a site's brand colour).
  static Color? hexColor(String? hex) {
    final v = hex?.replaceFirst('#', '');
    if (v == null || v.length != 6) return null;
    final rgb = int.tryParse(v, radix: 16);
    return rgb == null ? null : Color.fromARGB(255, (rgb >> 16) & 0xff, (rgb >> 8) & 0xff, rgb & 0xff);
  }
}

/// A user's score in their own AniList format: `85`, `8.5`, stars, or a face.
/// Nothing for 0 (not scored).
class AnilistUserScore extends StatelessWidget {
  const AnilistUserScore({super.key, required this.raw, required this.format, this.style});

  /// 0-100.
  final int raw;
  final AnilistScoreFormat format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (raw <= 0) return const SizedBox.shrink();
    final textStyle = style ?? Theme.of(context).textTheme.labelLarge;
    final color = textStyle?.color ?? Theme.of(context).colorScheme.onSurface;
    final size = (textStyle?.fontSize ?? 14) + 2;
    switch (format) {
      case AnilistScoreFormat.point5:
        final stars = format.fromRaw(raw).round();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(i <= stars ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: color),
          ],
        );
      case AnilistScoreFormat.point3:
        final face = format.fromRaw(raw).round();
        return Icon(
          face <= 1
              ? Icons.sentiment_dissatisfied_rounded
              : face == 2
                  ? Icons.sentiment_neutral_rounded
                  : Icons.sentiment_satisfied_alt_rounded,
          size: size,
          color: color,
        );
      default:
        return Text(format.format(raw), style: textStyle);
    }
  }
}

/// A section title with an optional trailing action.
class AnilistSectionTitle extends StatelessWidget {
  const AnilistSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
