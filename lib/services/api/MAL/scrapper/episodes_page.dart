import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_episode.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';

/// One episode of an anime, as listed on MyAnimeList's episode page
/// (`/anime/{id}/_/episode`) and completed with Jikan's filler / recap flags.
@immutable
class EpisodeEntry {
  final int number;
  final String title;

  /// Romaji title, empty when MAL gives none.
  final String romaji;

  /// Japanese title, empty when MAL gives none.
  final String japanese;

  /// Air date when it could be read ("Oct 24, 1998" or Jikan's ISO date).
  final DateTime? aired;

  /// Raw MAL text when [aired] could not be parsed ("Oct 1998", "?").
  final String airedText;

  /// Fans' episode score (1 to 5), null while nobody voted.
  final double? score;

  /// Id of the episode's discussion topic, null when MAL has none.
  final int? topicId;

  /// Replies in the discussion topic.
  final int replies;

  final bool filler;
  final bool recap;

  /// MAL page of the episode (synopsis, videos).
  final String? url;

  const EpisodeEntry({
    required this.number,
    required this.title,
    this.romaji = '',
    this.japanese = '',
    this.aired,
    this.airedText = '',
    this.score,
    this.topicId,
    this.replies = 0,
    this.filler = false,
    this.recap = false,
    this.url,
  });

  EpisodeEntry copyWith({bool? filler, bool? recap}) => EpisodeEntry(
        number: number,
        title: title,
        romaji: romaji,
        japanese: japanese,
        aired: aired,
        airedText: airedText,
        score: score,
        topicId: topicId,
        replies: replies,
        filler: filler ?? this.filler,
        recap: recap ?? this.recap,
        url: url,
      );
}

/// One page (100 episodes at most) of the episode list.
@immutable
class EpisodesPage {
  final List<EpisodeEntry> episodes;

  /// Episodes MAL lists for the whole anime, null when unknown.
  final int? total;

  /// Offset of this page and of every page ("1 - 100" is offset 0).
  final int offset;
  final List<int> offsets;

  const EpisodesPage({
    required this.episodes,
    this.total,
    this.offset = 0,
    this.offsets = const [0],
  });

  bool get hasMore => offsets.any((o) => o > offset);
}

/// Episode list of an anime: MyAnimeList's own page first, Jikan when MAL does
/// not answer, Jikan's `filler` / `recap` flags merged into either.
class MalEpisodesPage {
  MalEpisodesPage._();

  /// Episodes per page on MAL (the `offset` step).
  static const int pageSize = 100;

  static const Duration timeout = Duration(seconds: 12);

  /// MAL serves its mobile layout (other markup) to an Android user agent:
  /// the parser reads the desktop one.
  static const Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static Uri listUrl(int animeId, int offset) => Uri.parse(
      'https://myanimelist.net/anime/$animeId/_/episode?offset=$offset');

  static Uri episodeUrl(int animeId, int number) =>
      Uri.parse('https://myanimelist.net/anime/$animeId/_/episode/$number');

  /// GET of one page, body as text; throws on a non-200 status or after
  /// [timeout]. Replaceable in tests.
  static Future<String> Function(Uri url) fetch = _fetch;

  /// Jikan page of episodes (1-based). Replaceable in tests.
  static Future<List<AnimeEpisode>> Function(int animeId, int page) jikanPage =
      _jikanPage;

  /// Tests parse on the calling isolate.
  @visibleForTesting
  static bool parseInline = false;

  static final Map<String, EpisodesPage> _cache = {};

  /// Restores the real network access and empties the cache (tests).
  @visibleForTesting
  static void reset() {
    fetch = _fetch;
    jikanPage = _jikanPage;
    parseInline = false;
    _cache.clear();
  }

  /// Page of [animeId] starting at [offset]. Throws only when neither MAL nor
  /// Jikan answered. Pages are kept in memory for the session.
  static Future<EpisodesPage> load(int animeId, {int offset = 0}) async {
    final key = '$animeId:$offset';
    final cached = _cache[key];
    if (cached != null) return cached;

    final jikan = _flags(animeId, offset ~/ pageSize + 1);
    EpisodesPage? page;
    Object? error;
    try {
      final body = await fetch(listUrl(animeId, offset));
      final parsed = parseInline
          ? parseEpisodeList(body, offset: offset)
          : await compute(_parseEpisodeListIn, (body, offset));
      if (parsed.episodes.isNotEmpty) page = parsed;
    } catch (e) {
      error = e;
    }
    final extra = await jikan;
    if (page == null) {
      if (extra != null && extra.isNotEmpty) {
        page = _fromJikan(extra, offset);
      } else if (error != null) {
        throw error;
      } else {
        page = EpisodesPage(episodes: const [], total: 0, offset: offset);
      }
    } else if (extra != null) {
      page = _merge(page, extra);
    }
    if (_cache.length >= 12) _cache.remove(_cache.keys.first);
    return _cache[key] = page;
  }

  /// Synopsis of one episode read from its MAL page; null when it has none.
  static Future<String?> loadSynopsis(int animeId, int number) async {
    final body = await fetch(episodeUrl(animeId, number));
    return parseInline
        ? parseEpisodeSynopsis(body)
        : compute(parseEpisodeSynopsis, body);
  }

  static Future<List<AnimeEpisode>?> _flags(int animeId, int page) async {
    try {
      return await jikanPage(animeId, page);
    } catch (e) {
      if (kDebugMode) debugPrint('Jikan episodes failed: $e');
      return null;
    }
  }

  static EpisodesPage _merge(EpisodesPage page, List<AnimeEpisode> jikan) {
    final byNumber = {for (final e in jikan) e.malId: e};
    return EpisodesPage(
      total: page.total,
      offset: page.offset,
      offsets: page.offsets,
      episodes: [
        for (final e in page.episodes)
          if (byNumber[e.number] case final j?)
            e.copyWith(filler: j.filler ?? false, recap: j.recap ?? false)
          else
            e,
      ],
    );
  }

  static EpisodesPage _fromJikan(List<AnimeEpisode> jikan, int offset) {
    return EpisodesPage(
      offset: offset,
      offsets: [offset],
      episodes: [
        for (final j in jikan)
          if (j.malId != null)
            EpisodeEntry(
              number: j.malId!,
              title: j.title?.trim() ?? '',
              romaji: j.titleRomanji?.trim() ?? '',
              japanese: j.titleJapanese?.trim() ?? '',
              aired: DateTime.tryParse(j.aired ?? '')?.toLocal(),
              topicId: _topicId(j.forumUrl),
              filler: j.filler ?? false,
              recap: j.recap ?? false,
              url: j.url,
            ),
      ],
    );
  }

  static Future<String> _fetch(Uri url) async {
    final response = await http.get(url, headers: headers).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('MAL answered ${response.statusCode}', url);
    }
    return response.body;
  }

  static Future<List<AnimeEpisode>> _jikanPage(int animeId, int page) async {
    final response =
        await JikanApi().getAnimeEpisodes(animeId, page: page).timeout(timeout);
    return response.data;
  }
}

EpisodesPage _parseEpisodeListIn((String, int) args) =>
    parseEpisodeList(args.$1, offset: args.$2);

final RegExp _topicIdRe = RegExp(r'topicid=(\d+)');
final RegExp _totalRe = RegExp(r'\((\d+)\s*/\s*(?:\d+|\?)\)');
final RegExp _offsetRe = RegExp(r'offset=(\d+)');

int? _topicId(String? url) {
  final match = _topicIdRe.firstMatch(url ?? '');
  return match == null ? null : int.tryParse(match.group(1)!);
}

String _text(Element? e) => (e?.text ?? '').replaceAll(' ', ' ').trim();

/// Parses `/anime/{id}/_/episode` (rows of `table.episode_list`). Top-level so
/// `compute` can run it on a background isolate.
EpisodesPage parseEpisodeList(String body, {int offset = 0}) {
  final document = html_parser.parse(body);
  final episodes = <EpisodeEntry>[];
  for (final row in document.querySelectorAll('tr.episode-list-data')) {
    final number = int.tryParse(
        row.querySelector('td.episode-number')?.attributes['data-raw'] ??
            _text(row.querySelector('td.episode-number')));
    if (number == null) continue;
    final titleCell = row.querySelector('td.episode-title');
    final link = titleCell?.querySelector('a');
    final alt = _text(titleCell?.querySelector('span'));
    var romaji = alt;
    var japanese = '';
    final paren = alt.indexOf('(');
    if (paren >= 0 && alt.endsWith(')')) {
      romaji = alt.substring(0, paren).trim();
      japanese = alt.substring(paren + 1, alt.length - 1).trim();
    }
    final title = _text(link);
    if (romaji == title) romaji = '';

    final airedText = _text(row.querySelector('td.episode-aired'));
    DateTime? aired;
    try {
      aired = DateFormat('MMM d, yyyy', 'en_US').parseStrict(airedText);
    } catch (_) {}

    final score = double.tryParse(
        row.querySelector('td.episode-poll')?.attributes['data-raw'] ?? '');
    final forum = row.querySelector('td.episode-forum');

    episodes.add(EpisodeEntry(
      number: number,
      title: title,
      romaji: romaji,
      japanese: japanese,
      aired: aired,
      airedText: aired == null && airedText != 'N/A' ? airedText : '',
      score: score != null && score > 0 ? score : null,
      topicId: _topicId(forum?.querySelector('a')?.attributes['href']),
      replies: int.tryParse(forum?.attributes['data-raw'] ?? '') ?? 0,
      url: link?.attributes['href'],
    ));
  }

  final total = _totalRe
      .firstMatch(_text(document.querySelector('h2.h2_overwrite')?.parent))
      ?.group(1);
  final offsets = <int>{offset};
  for (final a in document.querySelectorAll('.pagination a.link')) {
    final o = _offsetRe.firstMatch(a.attributes['href'] ?? '')?.group(1);
    if (o != null) offsets.add(int.parse(o));
  }
  return EpisodesPage(
    episodes: episodes,
    total: total == null ? null : int.tryParse(total),
    offset: offset,
    offsets: offsets.toList()..sort(),
  );
}

/// The synopsis of an episode page (`/anime/{id}/_/episode/{n}`): the text
/// after its "Synopsis" heading. Null when the episode has none.
String? parseEpisodeSynopsis(String body) {
  final document = html_parser.parse(body);
  for (final h2 in document.querySelectorAll('h2')) {
    if (_text(h2) != 'Synopsis') continue;
    final buffer = StringBuffer();
    final siblings = h2.parentNode?.nodes ?? const <Node>[];
    for (var i = siblings.indexOf(h2) + 1; i < siblings.length; i++) {
      final node = siblings[i];
      if (node is Element && node.localName != 'br') break;
      if (node is Text) buffer.write(node.text);
      if (node is Element) buffer.write('\n');
    }
    final text = buffer
        .toString()
        .replaceAll(' ', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
        .trim();
    if (text.isEmpty || text.startsWith('No synopsis')) return null;
    return text;
  }
  return null;
}
