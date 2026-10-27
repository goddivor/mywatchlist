import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show nullOrEmpty;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/common/score_reveal.dart';

/// Rank, score (tap to reveal when hidden), scoring users, type and count,
/// then labelled facts: season / serialization, popularity, studios /
/// authors and members. Right of the cover.
class DetailHeaderMeta extends StatelessWidget {
  final DetailData data;

  const DetailHeaderMeta({super.key, required this.data});

  static final NumberFormat _countFormat =
      NumberFormat.currency(decimalDigits: 0, name: '');
  static final NumberFormat _ratingFormat = NumberFormat.currency(name: '');

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final content = data.content;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final faded = scheme.onSurface.withValues(alpha: .65);

    Widget fact(String label, String value, {int maxLines = 1}) => Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: faded)),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge),
            ],
          ),
        );

    final mean = content?.mean;
    final scoringUsers = content?.numScoringUsers;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      // Shrinks as a whole instead of overflowing with a large system font.
      child: LayoutBuilder(
        builder: (context, constraints) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: s.Dh_Rank,
                  child: Text(
                    content?.rank == null ? '# ?' : '# ${content!.rank}',
                    style: textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(height: 24, child: Image.asset('assets/images/star.png')),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ScoreReveal(
                        iconSize: 24,
                        child: Text(
                          mean == null ? '?' : _ratingFormat.format(mean),
                          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${scoringUsers == null ? '?' : _countFormat.format(scoringUsers)} ${s.Dh_Users}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  _typeAndCount(content),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(color: faded),
                ),
                fact(data.isAnime ? s.Dh_Aired : s.Dh_Serialization,
                    _seasonOrSerialization(content)),
                fact(s.Dh_Popularity, '# ${content?.popularity?.toString() ?? '?'}'),
                fact(data.isAnime ? s.Dh_Studios : s.Dh_Authors, _studiosOrAuthors(content),
                    maxLines: 2),
                fact(s.Dh_Members, _countFormat.format(content?.numListUsers ?? 0)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "TV (12 eps)" / "MANGA (3 vols)"; the count is left out when MAL says 0.
  String _typeAndCount(MalAnime? content) {
    final type = content?.mediaType?.toUpperCase().replaceAll('_', ' ') ?? '?';
    final count = data.isAnime ? content?.numEpisodes : content?.numVolumes;
    if (count == 0) return type;
    final countText = count?.toString() ?? '?';
    return '$type ${data.isAnime ? S.current.Dh_Episodes(countText) : S.current.Dh_Volumes(countText)}';
  }

  String _seasonOrSerialization(MalAnime? content) {
    if (data.isAnime) {
      final season = content?.startSeason;
      if (season == null) return '?';
      return '${seasonName(season.season)} ${season.year}';
    }
    final names = content?.serialization?.map((e) => e.name).toList();
    return nullOrEmpty(names) ? '?' : names!.join(', ');
  }

  String _studiosOrAuthors(MalAnime? content) {
    final names = data.isAnime
        ? content?.studios?.map((e) => e.name).toList()
        : content?.authors?.map((e) => e.author.firstName).toList();
    return nullOrEmpty(names) ? '?' : names!.join(', ');
  }
}

/// Translated season name from MAL's `winter` / `spring` / `summer` / `fall`;
/// unknown values are capitalised as they come.
String seasonName(String season) {
  final s = S.current;
  return switch (season.toLowerCase()) {
    'winter' => s.Dh_Winter,
    'spring' => s.Dh_Spring,
    'summer' => s.Dh_Summer,
    'fall' || 'autumn' => s.Dh_Fall,
    final other => other.isEmpty ? '?' : other[0].toUpperCase() + other.substring(1),
  };
}
