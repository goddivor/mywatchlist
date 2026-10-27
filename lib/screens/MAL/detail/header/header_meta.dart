import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';

/// Rank, score, scoring users, type and counts, season / serialization,
/// popularity, studios / authors and members, right of the cover.
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
    final textTheme = Theme.of(context).textTheme;
    TextStyle? faded(TextStyle? style) =>
        style?.copyWith(color: style.color?.withValues(alpha: .7));
    final labelStyle = faded(textTheme.bodySmall);

    Widget label(String text) =>
        Text(text, overflow: TextOverflow.ellipsis, style: labelStyle);
    Widget value(String text, TextStyle? style) =>
        Text(text, overflow: TextOverflow.ellipsis, style: style);

    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          value(content?.rank == null ? '# ?' : '# ${content!.rank}',
              const TextStyle(fontSize: 20)),
          const SizedBox(height: 7),
          Row(
            children: [
              SizedBox(height: 22, child: Image.asset('assets/images/star.png')),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${content?.mean == null ? '?' : _ratingFormat.format(content!.mean)} ',
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${content?.numScoringUsers == null ? '?' : _countFormat.format(content!.numScoringUsers)} ${s.Users}',
            style: textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          value(_typeAndCount(content), faded(textTheme.bodyMedium)),
          const SizedBox(height: 10),
          label(data.isAnime ? s.Aired : s.Serialization),
          const SizedBox(height: 3),
          value(_seasonOrSerialization(content), textTheme.labelMedium),
          const SizedBox(height: 10),
          label(s.Popularity),
          const SizedBox(height: 3),
          value('# ${content?.popularity?.toString() ?? '?'}',
              textTheme.labelSmall),
          const SizedBox(height: 10),
          label(data.isAnime ? s.Studios : s.Authors),
          const SizedBox(height: 3),
          value(_studiosOrAuthors(content), textTheme.labelSmall),
          const SizedBox(height: 10),
          label(s.Members),
          const SizedBox(height: 3),
          value(_countFormat.format(content?.numListUsers ?? 0.0),
              textTheme.labelSmall),
        ],
      ),
    );
  }

  /// "TV (12 eps)" / "MANGA (3 vols)"; the count is left out when MAL says 0.
  String _typeAndCount(MalAnime? content) {
    final type = content?.mediaType?.toUpperCase() ?? '?';
    final count = data.isAnime ? content?.numEpisodes : content?.numVolumes;
    if (count == 0) return '$type ';
    final countText = count?.toString() ?? '?';
    return '$type ${data.isAnime ? S.current.Detail_Episode_Count(countText) : S.current.Detail_Volume_Count(countText)}';
  }

  String _seasonOrSerialization(MalAnime? content) {
    if (data.isAnime) {
      final season = content?.startSeason;
      return '${season?.season.capitalise() ?? '?'} ${season?.year.toString() ?? '?'}';
    }
    final names = content?.serialization?.map((e) => e.name).toList();
    return nullOrEmpty(names) ? '?' : names!.join(',');
  }

  String _studiosOrAuthors(MalAnime? content) {
    final names = data.isAnime
        ? content?.studios?.map((e) => e.name).toList()
        : content?.authors?.map((e) => e.author.firstName).toList();
    return nullOrEmpty(names) ? '?' : names!.join(',');
  }
}
