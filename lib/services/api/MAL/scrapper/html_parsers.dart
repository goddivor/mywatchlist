// Re-export HtmlParsers from mwl_commons (shared with backend).
export 'package:mwl_commons/src/services/html_parser.dart';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:html/dom.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart' hide Genre;
import 'package:mywatchlist/services/api/MAL/models/all_search_result.dart';

/// Extension that stays in the Flutter app because it depends on [Anime].
class HtmlParsersApp {
  /// Parse MAL's /search/all page to extract results from all categories.
  static AllSearchResult parseAllSearchResults(Document document) {
    final categories = <String, List<Anime>>{};

    for (final type in AllSearchResult.allTypes) {
      categories[type] = [];
    }

    try {
      final articles = document.getElementsByTagName('article');
      for (final article in articles) {
        final items = article.getElementsByClassName('list');
        String? category;
        final List<Anime> data = [];

        for (final item in items) {
          int? id;
          String title = 'Unknown';
          String? imageUrl;
          String? mediaType;
          int? numEpisodes;
          double? mean;
          int? numListUsers;

          // Extract picture and link
          final picSurround = item.getElementsByClassName('picSurround');
          if (picSurround.isNotEmpty) {
            final anchors = picSurround.first.getElementsByTagName('a');
            if (anchors.isNotEmpty) {
              final href = anchors.first.attributes['href'];
              if (href != null) {
                category ??= _getCategoryFromUrl(href);
                id = _extractIdFromUrl(href, category ?? '');
              }
              // Extract image
              final imgs = picSurround.first.getElementsByTagName('img');
              if (imgs.isNotEmpty) {
                final imgAttr = ['news', 'featured'].contains(category)
                    ? 'src'
                    : 'data-src';
                imageUrl = imgs.first.attributes[imgAttr]
                    ?.replaceAll('r/100x140/', '')
                    .replaceAll('r/50x50/', '');
              }
            }
          }

          // Extract info
          String? synopsis;
          String? owner;
          String? dateStr;

          final infoList = item.getElementsByClassName('information');
          if (infoList.isNotEmpty) {
            final anchors = infoList.first.getElementsByTagName('a');
            if (anchors.isNotEmpty) {
              title = anchors.first.text.trim();
            }
            final metaList = infoList.first.getElementsByClassName('fn-grey4');
            if (metaList.isNotEmpty) {
              final infoText = metaList.first.text.trim();
              final lines = infoText
                  .split('\n')
                  .map((l) => l.trim())
                  .where((l) => l.isNotEmpty)
                  .toList();

              if (['anime', 'manga'].contains(category)) {
                final info = parseInfoLines(lines);
                mediaType = info.mediaType;
                numEpisodes = info.count;
                mean = info.score;
                numListUsers = info.members;
              } else {
                synopsis = lines.join(' · ');
                for (final line in lines) {
                  if (line.startsWith('by ')) {
                    owner = line.substring(3).trim();
                  }
                  final dateMatch = RegExp(
                          r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},\s+\d{4}')
                      .firstMatch(line);
                  if (dateMatch != null) {
                    dateStr = dateMatch.group(0);
                  }
                  final membersMatch =
                      RegExp(r'(\d[\d,]*)\s*[Mm]embers').firstMatch(line);
                  if (membersMatch != null) {
                    numListUsers = int.tryParse(
                        membersMatch.group(1)!.replaceAll(',', ''));
                  }
                }
              }
            }
          }

          if (id != null) {
            data.add(Anime(
              id: id,
              title: title,
              imageUrl: imageUrl ?? '',
              score: mean ?? 0.0,
              members: numListUsers ?? 0,
              mediaType: mediaType,
              numEpisodes: numEpisodes,
              synopsis: synopsis,
              status: owner,
              startDate: dateStr,
            ));
          }
        }

        if (category != null &&
            AllSearchResult.allTypes.contains(category) &&
            !categories.containsKey(category)) {
          categories[category] = data;
        } else if (category != null &&
            categories.containsKey(category) &&
            categories[category]!.isEmpty) {
          categories[category] = data;
        }
      }
    } catch (e) {
      // Silently fail - return partial results
    }

    return AllSearchResult(categories: categories);
  }

  static final _countPattern =
      RegExp(r'\(\s*(\d[\d,]*|\?)\s*(?:eps?|vols?|chs?|chapters?|episodes?)\s*\)', caseSensitive: false);
  static final _scorePattern = RegExp(r'Scored\s+(\d+(?:\.\d+)?)', caseSensitive: false);
  static final _membersPattern = RegExp(r'(\d[\d,]*)\s*members', caseSensitive: false);

  /// Reads the grey info lines of an anime or manga result of /search/all by their pattern, so
  /// their order and line breaks do not matter. MAL used to print `TV (28 eps)` on one line and
  /// now prints `TV` and `(28 eps)` on two; either way `Scored 9.24` is the score (`Scored N/A`
  /// gives none) and `1,537,256 members` the member count. A missing line leaves its field null.
  @visibleForTesting
  static ({String? mediaType, int? count, double? score, int? members}) parseInfoLines(
      List<String> lines) {
    String? mediaType;
    int? count;
    double? score;
    int? members;
    for (final line in lines) {
      final countMatch = _countPattern.firstMatch(line);
      final scoreMatch = _scorePattern.firstMatch(line);
      final membersMatch = _membersPattern.firstMatch(line);
      if (countMatch != null) {
        count ??= int.tryParse(countMatch.group(1)!.replaceAll(',', ''));
      }
      if (scoreMatch != null) score ??= double.tryParse(scoreMatch.group(1)!);
      if (membersMatch != null) {
        members ??= int.tryParse(membersMatch.group(1)!.replaceAll(',', ''));
      }
      // The type is the text of the first line that is not a count, a score or a member count
      // (`TV`, or `TV` before `(28 eps)` in the old one-line form).
      if (mediaType == null && scoreMatch == null && membersMatch == null &&
          !line.toLowerCase().startsWith('scored')) {
        final type = line
            .substring(0, countMatch?.start ?? line.length)
            .replaceAll(RegExp(r'[^a-zA-Z]'), '')
            .trim();
        if (type.isNotEmpty) mediaType = type;
      }
    }
    return (mediaType: mediaType, count: count, score: score, members: members);
  }

  static String? _getCategoryFromUrl(String href) {
    if (href.contains('/anime/')) return 'anime';
    if (href.contains('/manga/')) return 'manga';
    if (href.contains('/character/')) return 'character';
    if (href.contains('/people/')) return 'person';
    if (href.contains('/forum/')) return 'forum';
    if (href.contains('/clubs.php')) return 'club';
    if (href.contains('/featured/')) return 'featured';
    if (href.contains('/news/')) return 'news';
    return null;
  }

  static int? _extractIdFromUrl(String href, String category) {
    try {
      if (['news', 'featured'].contains(category)) {
        final match = RegExp(r'/(?:news|featured)/(\d+)').firstMatch(href);
        return match != null ? int.tryParse(match.group(1)!) : null;
      } else if (['forum', 'club'].contains(category)) {
        final match =
            RegExp(r'[?&](?:topicid|cid|id)=(\d+)').firstMatch(href);
        if (match != null) return int.tryParse(match.group(1)!);
        final numMatch = RegExp(r'(\d+)').allMatches(href).lastOrNull;
        return numMatch != null ? int.tryParse(numMatch.group(1)!) : null;
      } else {
        final trimmed =
            href.endsWith('/') ? href.substring(0, href.length - 1) : href;
        final lastSlash = trimmed.lastIndexOf('/');
        final segment = trimmed.substring(lastSlash + 1);
        final parsed = int.tryParse(segment);
        if (parsed != null) return parsed;
        final beforeLast = trimmed.substring(0, lastSlash);
        final prevSlash = beforeLast.lastIndexOf('/');
        return int.tryParse(beforeLast.substring(prevSlash + 1));
      }
    } catch (_) {}
    return null;
  }
}
