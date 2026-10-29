import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage, nullOrEmpty;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/episodes/episodes_screen.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/episodes_page.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/score_reveal.dart';

/// Rank (with an "18+" mark for MAL's `black` / `gray` entries), score (tap
/// to reveal when hidden), scoring users, type and count, then labelled
/// facts: the user's next episode (anime being watched), season /
/// serialization, popularity, studios / authors and members with the
/// favourites count of the MAL page. Right of the cover.
class DetailHeaderMeta extends StatelessWidget {
  final DetailData data;

  const DetailHeaderMeta({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    // Numbers in the app's language: "2,169" in English, "2 169" in French.
    final locale = Localizations.localeOf(context).toString();
    final countFormat = NumberFormat.decimalPattern(locale);
    final ratingFormat = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2);
    final content = data.content;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final faded = scheme.onSurface.withValues(alpha: .65);

    final next = nextEpisodeToWatch(data);
    // One more fact for the next episode: the gaps shrink instead of the text.
    final factGap = next == null ? 9.0 : 5.0;
    Widget fact(String label, String value, {int maxLines = 1, Widget? trailing}) => Padding(
          padding: EdgeInsets.only(top: factGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: faded)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(value,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
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
                Row(
                  children: [
                    Flexible(
                      child: Semantics(
                        label: s.Dh_Rank,
                        child: Text(
                          content?.rank == null ? '# ?' : '# ${countFormat.format(content!.rank)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge,
                        ),
                      ),
                    ),
                    if (isNsfwRating(content?.nsfw)) ...[
                      const SizedBox(width: 8),
                      const AdultChip(),
                    ],
                  ],
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
                          mean == null ? '?' : ratingFormat.format(mean),
                          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${scoringUsers == null ? '?' : countFormat.format(scoringUsers)} ${s.Dh_Users}',
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
                if (next != null)
                  _NextEpisodeFact(
                    animeId: data.id,
                    title: data.title,
                    number: next,
                    gap: factGap,
                    labelStyle: textTheme.bodySmall?.copyWith(color: faded),
                    valueStyle: textTheme.labelLarge,
                  ),
                fact(data.isAnime ? s.Dh_Aired : s.Dh_Serialization,
                    _seasonOrSerialization(content)),
                fact(s.Dh_Popularity,
                    '# ${content?.popularity == null ? '?' : countFormat.format(content!.popularity)}'),
                fact(data.isAnime ? s.Dh_Studios : s.Dh_Authors, _studiosOrAuthors(content),
                    maxLines: 2),
                fact(
                  s.Dh_Members,
                  countFormat.format(content?.numListUsers ?? 0),
                  trailing: _favorites(context, countFormat),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ♥ and the favourites count read from the MAL page, after the members.
  Widget? _favorites(BuildContext context, NumberFormat format) {
    final value = data.html?['favorites'];
    if (value is! num || value <= 0) return null;
    final text = format.format(value);
    final style = Theme.of(context).textTheme.labelLarge;
    return Semantics(
      label: S.current.Dsb_Favorites_Semantics(text),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 14, color: AppColors.of(context).dropped.color),
            const SizedBox(width: 3),
            Text(text, maxLines: 1, style: style),
          ],
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
        ? content?.studios?.map((e) => e.name.trim()).toList()
        : content?.authors?.map((e) => authorName(e.author.firstName, e.author.lastName)).toList();
    final shown = names?.where((n) => n.isNotEmpty).toList();
    return nullOrEmpty(shown) ? '?' : shown!.join(', ');
  }
}

/// MAL's `black` (adult) and `gray` (may not be safe) ratings get the "18+" mark.
bool isNsfwRating(String? nsfw) => nsfw == 'black' || nsfw == 'gray';

/// Number of the next episode the user has to watch, or null: an anime of
/// the user's MyAnimeList list (the only list status this page reads) that is
/// watched, on hold or rewatched, and not finished yet. Planned, completed and
/// dropped titles have no "next".
int? nextEpisodeToWatch(DetailData data) {
  if (!data.isAnime) return null;
  final content = data.content;
  final entry = content?.myListStatus;
  if (content == null || entry == null) return null;
  final active = entry.status == 'watching' ||
      entry.status == 'on_hold' ||
      (entry.status == 'completed' && entry.isRewatching);
  if (!active) return null;
  final next = entry.numEpisodesWatched + 1;
  final total = content.numEpisodes ?? 0;
  if (total > 0 && next > total) return null;
  return next;
}

/// The "18+" chip of the header (danger tokens, readable in every theme).
class AdultChip extends StatelessWidget {
  const AdultChip({super.key});

  @override
  Widget build(BuildContext context) {
    final role = AppColors.of(context).danger;
    return Semantics(
      label: S.current.Dsb_Adult_Semantics,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: role.container,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            S.current.Dsb_Adult,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: role.onContainer,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

/// "Next episode: Ep 8 · Title": the number at once, the title once the
/// episode list (shared cache with the Episodes section) knows it. A tap
/// opens the episode list.
class _NextEpisodeFact extends StatefulWidget {
  final int animeId;
  final String title;
  final int number;
  final double gap;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _NextEpisodeFact({
    required this.animeId,
    required this.title,
    required this.number,
    required this.gap,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  State<_NextEpisodeFact> createState() => _NextEpisodeFactState();
}

class _NextEpisodeFactState extends State<_NextEpisodeFact> {
  String? _episodeTitle;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _NextEpisodeFact oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.number != widget.number || oldWidget.animeId != widget.animeId) {
      _episodeTitle = null;
      _load();
    }
  }

  Future<void> _load() async {
    final number = widget.number;
    final offset = (number - 1) ~/ MalEpisodesPage.pageSize * MalEpisodesPage.pageSize;
    try {
      final page = await MalEpisodesPage.load(widget.animeId, offset: offset);
      if (!mounted || number != widget.number) return;
      final title = episodeTitle(page, number);
      if (title != null) setState(() => _episodeTitle = title);
    } catch (_) {
      // The number alone stays: the title is an extra.
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final title = _episodeTitle;
    final value = title == null
        ? s.Dsb_Next_Episode_Number(widget.number)
        : s.Dsb_Next_Episode_Title(widget.number, title);
    return Padding(
      padding: EdgeInsets.only(top: widget.gap),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => gotoPage(
          context: context,
          newPage: EpisodesScreen(animeId: widget.animeId, title: widget.title),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.Dsb_Next_Episode,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: widget.labelStyle),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: widget.valueStyle),
          ],
        ),
      ),
    );
  }
}

/// Title of episode [number] in [page] (English, else romaji, else
/// Japanese); null when the page does not list it or MAL gives no title.
String? episodeTitle(EpisodesPage page, int number) {
  for (final e in page.episodes) {
    if (e.number != number) continue;
    for (final t in [e.title, e.romaji, e.japanese]) {
      if (t.trim().isNotEmpty) return t.trim();
    }
    return null;
  }
  return null;
}

/// "First Last" of a MAL author; MAL leaves one of the two empty for
/// pen names (e.g. "Nabana"), which must not leave a stray comma or space.
String authorName(String firstName, String lastName) =>
    [firstName.trim(), lastName.trim()].where((p) => p.isNotEmpty).join(' ');

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
