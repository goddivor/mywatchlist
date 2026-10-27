import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';

/// The "More information" body of the detail screen: facts, alternative titles and genres.
///
/// Every chip is a link to a screen of the app: studios, magazines and genres open the filtered
/// search, authors open their person page, the season opens the season's anime and the media
/// type opens its ranking. Values without a destination are plain text.
///
/// With [isModal] the widget owns its scroll view (DailyAL `isModal`), so a dialog can host it
/// without wrapping it in a second one; otherwise it is a plain column for a parent scroll view.
class MoreInfoWidget extends StatelessWidget {
  final MalAnime? anime;
  final dynamic additionalTitles; // Use dynamic to allow for various types
  final double horizPadding;
  final String category;
  final bool isModal;

  const MoreInfoWidget({
    Key? key,
    this.anime,
    this.additionalTitles,
    required this.horizPadding,
    this.category = "anime",
    this.isModal = false,
  }) : super(key: key);

  bool get _isManga => category == "manga";

  @override
  Widget build(BuildContext context) {
    final content = anime;
    if (content == null) return const SizedBox.shrink();

    final column = Padding(
      padding: EdgeInsets.symmetric(horizontal: horizPadding, vertical: isModal ? 4 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            title: S.current.Mi_Information,
            children: _isManga ? _mangaRows(context, content) : _animeRows(context, content),
          ),
          ..._titlesCard(context, content),
          ..._genresCard(context, content),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (!isModal) return column;
    return Scrollbar(child: SingleChildScrollView(child: column));
  }

  // --- Rows -----------------------------------------------------------------------------------

  List<Widget> _animeRows(BuildContext context, MalAnime a) {
    final season = a.startSeason;
    final seasonType = season == null ? null : seasonMapInverse[season.season.toLowerCase()];
    final studios = a.studios ?? const <Studio>[];
    return [
      _mediaTypeRow(context, a),
      _InfoRow(S.current.Episodes, _text(_count(a.numEpisodes))),
      if (a.status != null) _InfoRow(S.current.Status, _text(_status(a.status!))),
      _InfoRow(S.current.Mi_Mal_Id, _text(a.id.toString())),
      if (season != null)
        _InfoRow(
          S.current.Premiered,
          seasonType == null
              ? _text(_seasonLabel(season.season, season.year))
              : _LinkWrap([
                  _Link(
                    _seasonLabel(season.season, season.year),
                    () => _open(context, GeneralSearchScreen.bySeason(seasonType, season.year)),
                  ),
                ]),
        ),
      _InfoRow(S.current.Aired, _text(_dates(context, a.startDate, a.endDate))),
      if (a.source != null) _InfoRow(S.current.Source, _text(_source(a.source!))),
      if (_broadcast(a) case final broadcast?) _InfoRow(S.current.Broadcast, _text(broadcast)),
      if (_duration(a.averageEpisodeDuration) case final duration?)
        _InfoRow(S.current.Duration, _text(duration)),
      if (a.rating != null) _InfoRow(S.current.Rating, _text(_rating(a.rating!))),
      if (studios.isNotEmpty)
        _InfoRow(
          S.current.Studios,
          _LinkWrap([
            for (final studio in studios)
              _Link(
                studio.name,
                studio.id > 0
                    ? () => _open(context, GeneralSearchScreen.byStudio(id: studio.id, name: studio.name))
                    : null,
              ),
          ]),
        ),
    ];
  }

  List<Widget> _mangaRows(BuildContext context, MalAnime a) {
    final magazines = a.serialization ?? const <MalSerialization>[];
    final authors = a.authors ?? const <MalAuthor>[];
    return [
      _mediaTypeRow(context, a),
      _InfoRow(S.current.Volumes, _text(_count(a.numVolumes))),
      _InfoRow(S.current.Chapters, _text(_count(a.numChapters))),
      if (a.status != null) _InfoRow(S.current.Status, _text(_status(a.status!))),
      _InfoRow(S.current.Mi_Mal_Id, _text(a.id.toString())),
      _InfoRow(S.current.Published, _text(_dates(context, a.startDate, a.endDate))),
      if (magazines.isNotEmpty)
        _InfoRow(
          S.current.Serialization,
          _LinkWrap([
            for (final magazine in magazines)
              _Link(
                magazine.name,
                magazine.id > 0
                    ? () => _open(context, GeneralSearchScreen.byMagazine(id: magazine.id, name: magazine.name))
                    : null,
              ),
          ]),
        ),
      if (authors.isNotEmpty)
        _InfoRow(
          S.current.Authors,
          _LinkWrap([
            for (final author in authors)
              _Link(
                _authorLabel(author),
                author.author.id > 0
                    ? () => _open(context, CharacterScreen(id: author.author.id, category: 'person'))
                    : null,
              ),
          ]),
        ),
    ];
  }

  Widget _mediaTypeRow(BuildContext context, MalAnime a) {
    final type = a.mediaType;
    if (type == null || type.isEmpty) return _InfoRow(S.current.Media, _text(S.current.Mi_Unknown));
    final open = _mediaTypeSearch(type);
    final label = _mediaTypeLabel(type);
    return _InfoRow(
      S.current.Media,
      open == null ? _text(label) : _LinkWrap([_Link(label, () => _open(context, open))]),
    );
  }

  /// The ranking of a media type (`tv`, `movie`, `light_novel`…), or null when no ranking
  /// exists for it (then the type is plain text, not a dead chip).
  GeneralSearchScreen? _mediaTypeSearch(String type) {
    final key = type.toLowerCase();
    if (_isManga) {
      final ranking = switch (key) {
        'manga' => MangaRanking.manga,
        'novel' => MangaRanking.novels,
        'light_novel' => MangaRanking.lightnovels,
        'one_shot' => MangaRanking.oneshots,
        'doujinshi' => MangaRanking.doujin,
        'manhwa' => MangaRanking.manhwa,
        'manhua' => MangaRanking.manhua,
        _ => null,
      };
      return ranking == null ? null : GeneralSearchScreen.byMangaRanking(ranking);
    }
    final ranking = switch (key) {
      'tv' => RankingType.TV,
      'movie' => RankingType.MOVIE,
      'ova' => RankingType.OVA,
      'special' => RankingType.SPECIAL,
      'ona' => RankingType.ONA,
      _ => null,
    };
    return ranking == null ? null : GeneralSearchScreen.byRanking(ranking);
  }

  // --- Alternative titles and genres ------------------------------------------------------------

  List<Widget> _titlesCard(BuildContext context, MalAnime a) {
    final titles = <(String, String)>[
      if (a.title.isNotEmpty) (S.current.Mi_Original, a.title),
      if (a.alternativeTitles?.en case final en? when en.isNotEmpty) (S.current.English, en),
      if (a.alternativeTitles?.ja case final ja? when ja.isNotEmpty) (S.current.Japanese, ja),
      for (final synonym in a.alternativeTitles?.synonyms ?? const <String>[])
        if (synonym.isNotEmpty) (S.current.Synonyms, synonym),
      ..._additionalTitles(),
    ];
    if (titles.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      _InfoCard(
        title: S.current.Mi_Alternative_Titles,
        children: [for (final (label, title) in titles) _InfoRow(label, SelectableText(title), labelWidth: 90)],
      ),
    ];
  }

  List<Widget> _genresCard(BuildContext context, MalAnime a) {
    final genres = a.genres ?? const <Genre>[];
    if (genres.isEmpty) return const [];
    final searchCategory = _isManga ? SearchCategory.manga : SearchCategory.anime;
    return [
      const SizedBox(height: 16),
      _InfoCard(
        title: S.current.Genres,
        children: [
          _LinkWrap([
            for (final genre in genres)
              _Link(
                genre.name.replaceAll('_', ' '),
                genre.name.isEmpty
                    ? null
                    : () => _open(
                          context,
                          GeneralSearchScreen.byGenre(
                            ids: genre.id > 0 ? [genre.id] : const [],
                            names: [genre.name],
                            category: searchCategory,
                          ),
                        ),
              ),
          ]),
        ],
      ),
    ];
  }

  List<(String, String)> _additionalTitles() {
    final raw = additionalTitles;
    if (raw is! List) return const [];
    final result = <(String, String)>[];
    for (final item in raw) {
      String? language;
      String? title;
      if (item is Map) {
        language = item['language']?.toString();
        title = item['title']?.toString();
      } else {
        try {
          language = (item as dynamic).language?.toString();
          title = (item as dynamic).title?.toString();
        } catch (_) {}
      }
      if (language == null || title == null || language.isEmpty || title.isEmpty || title == 'N/A') continue;
      result.add((language, title));
    }
    return result;
  }

  // --- Formatting -------------------------------------------------------------------------------

  void _open(BuildContext context, Widget page) => gotoPage(context: context, newPage: page);

  Widget _text(String value) => SelectableText(value);

  String _count(int? value) => value == null || value == 0 ? S.current.Mi_Unknown : value.toString();

  String _authorLabel(MalAuthor a) {
    final name = '${a.author.firstName} ${a.author.lastName}'.trim();
    return a.role.isEmpty ? name : S.current.Mi_Author_Role(name, a.role);
  }

  String _seasonLabel(String season, int year) {
    final name = switch (season.toLowerCase()) {
      'winter' => S.current.Dh_Winter,
      'spring' => S.current.Dh_Spring,
      'summer' => S.current.Dh_Summer,
      'fall' => S.current.Dh_Fall,
      _ => season.standardize() ?? season,
    };
    return S.current.Mi_Season_Year(name, year.toString());
  }

  /// A MAL date (`2024-04-06`, `2024-04` or `2024`) in the app language; unknown shapes stay raw.
  String _date(BuildContext context, String value) {
    final locale = Localizations.localeOf(context).toString();
    try {
      final full = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      final month = RegExp(r'^\d{4}-\d{2}$');
      if (full.hasMatch(value)) return DateFormat.yMMMd(locale).format(DateTime.parse(value));
      if (month.hasMatch(value)) return DateFormat.yMMM(locale).format(DateTime.parse('$value-01'));
    } catch (_) {}
    return value;
  }

  String _dates(BuildContext context, String? start, String? end) {
    final from = start == null || start.isEmpty ? null : _date(context, start);
    final to = end == null || end.isEmpty ? null : _date(context, end);
    if (from == null && to == null) return S.current.Mi_Unknown;
    if (from != null && from == to) return from;
    return S.current.Mi_Date_Range(from ?? S.current.Mi_Date_Unknown, to ?? S.current.Mi_Date_Unknown);
  }

  String? _broadcast(MalAnime a) {
    final b = a.broadcast;
    if (b == null) return null;
    try {
      final formatted = MalApi.getFormattedAiringDate(b);
      if (formatted != null) return formatted;
    } catch (_) {}
    final day = b.dayOfTheWeek.capitalize() ?? '';
    if (day.isEmpty) return null;
    return b.startTime.isEmpty ? day : S.current.Mi_Broadcast_Jst(day, b.startTime);
  }

  String? _duration(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final total = Duration(seconds: seconds);
    final minutes = total.inMinutes.remainder(60);
    if (total.inHours == 0) return S.current.Mi_Duration_Minutes(minutes);
    return S.current.Mi_Duration_Hours(total.inHours, minutes);
  }

  String _status(String value) => switch (value) {
        'finished_airing' => S.current.Mi_Status_Finished_Airing,
        'currently_airing' => S.current.Mi_Status_Currently_Airing,
        'not_yet_aired' => S.current.Mi_Status_Not_Yet_Aired,
        'finished' => S.current.Mi_Status_Finished,
        'currently_publishing' => S.current.Mi_Status_Currently_Publishing,
        'on_hiatus' => S.current.Mi_Status_On_Hiatus,
        'discontinued' => S.current.Mi_Status_Discontinued,
        'not_yet_published' => S.current.Mi_Status_Not_Yet_Published,
        _ => value.standardize() ?? value,
      };

  String _rating(String value) => switch (value) {
        'g' => S.current.Mi_Rating_G,
        'pg' => S.current.Mi_Rating_Pg,
        'pg_13' => S.current.Mi_Rating_Pg_13,
        'r' => S.current.Mi_Rating_R,
        'r+' => S.current.Mi_Rating_R_Plus,
        'rx' => S.current.Mi_Rating_Rx,
        _ => value.toUpperCase(),
      };

  String _source(String value) => switch (value) {
        'original' => S.current.Mi_Source_Original,
        'manga' => S.current.Mi_Source_Manga,
        '4_koma_manga' => S.current.Mi_Source_Four_Koma,
        'web_manga' => S.current.Mi_Source_Web_Manga,
        'digital_manga' => S.current.Mi_Source_Digital_Manga,
        'novel' => S.current.Mi_Source_Novel,
        'light_novel' => S.current.Mi_Source_Light_Novel,
        'visual_novel' => S.current.Mi_Source_Visual_Novel,
        'game' => S.current.Mi_Source_Game,
        'card_game' => S.current.Mi_Source_Card_Game,
        'book' => S.current.Mi_Source_Book,
        'picture_book' => S.current.Mi_Source_Picture_Book,
        'radio' => S.current.Mi_Source_Radio,
        'music' => S.current.Mi_Source_Music,
        'web_novel' => S.current.Mi_Source_Web_Novel,
        'mixed_media' => S.current.Mi_Source_Mixed_Media,
        'other' => S.current.Mi_Source_Other,
        _ => value.standardize() ?? value,
      };

  /// Short codes (TV, OVA, ONA…) stay upper case in every language; the others are translated.
  String _mediaTypeLabel(String value) => switch (value.toLowerCase()) {
        'movie' => S.current.Mi_Type_Movie,
        'special' => S.current.Mi_Type_Special,
        'tv_special' => S.current.Mi_Type_Tv_Special,
        'music' => S.current.Mi_Type_Music,
        'manga' => S.current.Mi_Type_Manga,
        'novel' => S.current.Mi_Type_Novel,
        'light_novel' => S.current.Mi_Type_Light_Novel,
        'one_shot' => S.current.Mi_Type_One_Shot,
        'doujinshi' => S.current.Mi_Type_Doujinshi,
        'manhwa' => S.current.Mi_Type_Manhwa,
        'manhua' => S.current.Mi_Type_Manhua,
        _ => value.replaceAll('_', ' ').toUpperCase(),
      };
}

/// A titled tonal card (no elevation, theme roles only).
class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A label on the left, its value (text or links) filling the rest of the row.
class _InfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  final double labelWidth;
  const _InfoRow(this.label, this.value, {this.labelWidth = 110});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: DefaultTextStyle.merge(style: theme.textTheme.bodyMedium, child: value),
          ),
        ],
      ),
    );
  }
}

class _Link {
  final String label;

  /// Null for a value that has no destination: it is shown as a disabled-looking plain chip.
  final VoidCallback? onTap;
  const _Link(this.label, this.onTap);
}

/// Chips that open a screen. A link without a destination is plain text, never a dead chip.
class _LinkWrap extends StatelessWidget {
  final List<_Link> links;
  const _LinkWrap(this.links);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 0,
      children: [
        for (final link in links)
          if (link.onTap == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(link.label),
            )
          else
            ActionChip(
              label: Text(link.label),
              onPressed: link.onTap,
              visualDensity: VisualDensity.compact,
              backgroundColor: scheme.secondaryContainer,
              labelStyle: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: scheme.onSecondaryContainer),
              side: BorderSide.none,
            ),
      ],
    );
  }
}
