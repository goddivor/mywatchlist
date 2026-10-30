import 'package:mywatchlist/services/api/MAL/anime_graph_builder.dart';

/// Saved MAL API v2 `GET /anime/{id}?fields=...,related_anime` answers, trimmed to the fields
/// the graph reads.
Map<String, dynamic> malAnime(int id, List<(int, String)> related,
        {int year = 2010}) =>
    {
      'id': id,
      'title': 'Title $id',
      'main_picture': {
        'medium': 'https://cdn.myanimelist.net/images/anime/$id.jpg',
        'large': 'https://cdn.myanimelist.net/images/anime/${id}l.jpg',
      },
      'alternative_titles': {'synonyms': <String>[], 'en': 'English $id', 'ja': ''},
      'mean': 8.0,
      'media_type': 'tv',
      'status': 'finished_airing',
      'start_season': {'year': year, 'season': 'spring'},
      'related_anime': [
        for (final (target, relation) in related)
          {
            'node': {
              'id': target,
              'title': 'Title $target',
              'main_picture': {'medium': '', 'large': ''},
            },
            'relation_type': relation,
            'relation_type_formatted': relation,
          },
      ],
    };

/// A franchise: 1 → 2 → 3 (sequels), 3 has side story 4, 1 has an `other` link to 9 whose
/// sequel is 12; 10 is a `character` link of 1 and 11 an `other` link of 2.
final Map<int, Map<String, dynamic>> franchise = {
  1: malAnime(1, [(2, 'sequel'), (9, 'other'), (10, 'character')]),
  2: malAnime(2, [(1, 'prequel'), (3, 'sequel'), (11, 'other')], year: 2011),
  3: malAnime(3, [(2, 'prequel'), (4, 'side_story')], year: 2012),
  4: malAnime(4, [(3, 'parent_story')], year: 2013),
  9: malAnime(9, [(1, 'other'), (12, 'sequel')], year: 2014),
  12: malAnime(12, [(9, 'prequel')], year: 2015),
  10: malAnime(10, []),
  11: malAnime(11, []),
};

/// A fetch over saved answers that records every id asked; [limitedAt] answers 429 from
/// that id on.
class FakeMal {
  FakeMal(this.answers, {this.limitedAt});

  final Map<int, Map<String, dynamic>> answers;
  final int? limitedAt;
  final List<int> asked = [];
  bool limited = false;

  Future<GraphFetch> call(int id) async {
    asked.add(id);
    await Future<void>.delayed(Duration.zero);
    if (limited || id == limitedAt) {
      limited = true;
      return const GraphFetch.rateLimited();
    }
    final anime = answers[id];
    return anime == null ? const GraphFetch.failed() : GraphFetch.ok(anime);
  }
}

/// [AnimeGraphStore] in memory.
class MemoryGraphStore implements AnimeGraphStore {
  final Map<int, Map<String, dynamic>> saved = {};
  final Map<int, DateTime> savedAt = {};
  DateTime now = DateTime(2026, 10, 30);

  @override
  Future<Map<String, dynamic>?> read(int id, Duration maxAge) async {
    final at = savedAt[id];
    if (at == null || now.difference(at) >= maxAge) return null;
    return saved[id];
  }

  @override
  Future<void> write(int id, Map<String, dynamic> json) async {
    saved[id] = json;
    savedAt[id] = now;
  }
}
