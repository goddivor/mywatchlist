import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/SimKl/scrapper/simkl_page_parser.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';

/// Offline: pages saved from simkl.com on 2026-10-28 (scripts, styles and SVGs stripped) and the
/// examples of Simkl's OpenAPI document (api.simkl.org/openapi.json, "verified against the live API").
String fixture(String name) => File('test/units/simkl-media-page/fixtures/$name').readAsStringSync();

void main() {
  group('API record', () {
    test('B1: ratings, rank, drop rate, airs, trailers, recommendations, relations, studios', () {
      final t = SimklTitle.fromJson(jsonDecode(fixture('simkl_anime_831411.json')))!;
      expect(t.simklId, 831411);
      expect(t.slug, 'kimetsu-no-yaiba');
      expect(t.malId, 38000);
      expect(t.enTitle, 'Demon Slayer: Kimetsu no Yaiba');
      expect(t.rank, 14);
      expect(t.dropRate, 0.8);
      expect(t.simklRating!.rating, 8.7);
      expect(t.simklRating!.votes, 1850);
      expect(t.malRating!.votes, 1620000);
      expect(t.imdbRating, isNull);
      expect(t.airs!.day, 'Sunday');
      expect(t.airs!.time, '23:15');
      expect(t.airs!.timezone, 'Asia/Tokyo');
      expect(t.trailers.single.youtubeId, 'VQGCKyvzIM4');
      expect(t.studios, ['ufotable']);
      expect(t.genres, ['Action', 'Adventure', 'Fantasy']);
      expect(t.totalEpisodes, 55);
      expect(t.posterUrl, 'https://simkl.in/posters/10/108215c95bbe0c40c_m.jpg');
      expect(t.fanartUrl, 'https://simkl.in/fanart/11/11108654def22b4f7_mobile.jpg');
      final rec = t.recommendations.single;
      expect(rec.title, 'Jujutsu Kaisen');
      expect(rec.usersPercent, 24);
      expect(rec.usersCount, 75);
      expect(rec.simklId, 1211265);
      expect(t.relations.map((r) => r.relationType), ['sequel', 'summary']);
      expect(t.altTitles, contains('鬼滅の刃'));
    });

    test('a record without optional blocks still parses', () {
      final t = SimklTitle.fromJson(jsonDecode(fixture('simkl_anime_40190.json')))!;
      expect(t.title, 'Death Note');
      expect(t.malId, 1535);
      expect(t.trailers, isEmpty);
      expect(t.recommendations, isEmpty);
      expect(t.imdbRating, isNotNull);
    });

    test('unknown id ([]) gives null', () {
      expect(SimklTitle.fromJson(jsonDecode('[]')), isNull);
    });

    test('B2: episodes and specials', () {
      final eps = SimklEpisode.listFrom(jsonDecode(fixture('simkl_episodes_aot.json')));
      expect(eps, hasLength(2));
      expect(eps[0].number, 1);
      expect(eps[0].isSpecial, isFalse);
      expect(eps[0].imageUrl, 'https://simkl.in/episodes/26/26148581d640c58b8_w.jpg');
      expect(eps[0].date!.toUtc(), DateTime.utc(2013, 4, 6, 6));
      expect(eps[1].isSpecial, isTrue);
      expect(eps[1].number, isNull);
      expect(eps[1].title, 'Picture Drama 3');
    });
  });

  group('title page', () {
    late SimklTitlePage frieren;
    late SimklTitlePage mashle;

    setUpAll(() {
      frieren = parseSimklTitlePage(fixture('simkl_title_frieren.html'));
      mashle = parseSimklTitlePage(fixture('simkl_title_mashle.html'));
    });

    test('C1: watcher distribution by status', () {
      final w = frieren.watchers!;
      expect(w.total, 34432);
      expect(w.buckets.map((b) => b.status), SimklWatcherStatus.values);
      expect(w.buckets.map((b) => b.users), [5727, 6500, 21255, 487, 463]);
      expect(w.buckets.first.percent, 16.6);
      // An upcoming title has no Completed bar.
      expect(mashle.watchers!.buckets.map((b) => b.status), isNot(contains(SimklWatcherStatus.completed)));
      expect(mashle.watchers!.total, 2414);
    });

    test('C7: counters', () {
      final c = frieren.counters!;
      expect(c.reactions, 245);
      expect(c.reviews, 6);
      expect(c.comments, 3);
      expect(c.memos, 236);
      expect(mashle.counters!.reviews, 0);
      expect(mashle.counters!.comments, 0);
    });

    test('C3: review cards with sub-scores and the summary', () {
      final r = frieren.reviews!;
      expect(r.summary!.positivePercent, 100);
      expect(r.summary!.positive, 6);
      expect(r.summary!.negative, 0);
      expect(r.items, hasLength(3));
      final first = r.items.first;
      expect(first.author, 'CapnBlaze');
      expect(first.date, 'March 13, 2024');
      expect(first.title, 'One of the best anime there are.');
      expect(first.url, 'https://simkl.com/anime/1990194/sousou-no-frieren/review/181260');
      expect(first.overall, 9);
      expect(first.tone, SimklReviewTone.positive);
      expect(first.scores, {
        SimklReviewAspect.story: 10,
        SimklReviewAspect.animation: 8,
        SimklReviewAspect.sound: 8,
        SimklReviewAspect.character: 8,
        SimklReviewAspect.enjoyment: 10,
      });
      expect(first.truncated, isTrue);
      expect(first.text, startsWith("Fantastic story I haven't seen in other anime\n\nThere is much"));
      expect(first.text, isNot(contains('read more')));
      expect(first.helpful, 1);
      expect(first.helpfulTotal, 1);
      expect(first.avatarUrl, isNull, reason: 'guest picture dropped');
      // No review yet: no summary, no card, but the block is there.
      expect(mashle.reviews!.summary, isNull);
      expect(mashle.reviews!.items, isEmpty);
    });

    test('C9: tags, links, studios, producers, licensors', () {
      expect(frieren.tags, hasLength(76));
      expect(frieren.tags!.first, 'magic circles');
      expect(frieren.tags, contains('mono no aware'));
      expect(frieren.studios, ['Madhouse']);
      expect(frieren.producers, contains('Aniplex'));
      expect(frieren.licensors, ['Crunchyroll']);
      final links = frieren.links!;
      expect(links.map((l) => l.name), containsAll(['MAL', 'AniList', 'Kitsu', 'LiveChart']));
      expect(links.firstWhere((l) => l.name == 'MAL').url, 'http://myanimelist.net/anime/52991/');
      expect(mashle.licensors, isNull, reason: 'no Licensors row on that page');
      expect(mashle.tags, ['japanese production']);
    });

    test('a page without the blocks hides every section', () {
      final p = parseSimklTitlePage('<html><body><p>Just a moment...</p></body></html>');
      expect(p.watchers, isNull);
      expect(p.counters, isNull);
      expect(p.reviews, isNull);
      expect(p.tags, isNull);
      expect(p.links, isNull);
    });
  });

  test('reviews page: all six reviews', () {
    final r = parseSimklReviews(fixture('simkl_reviews_frieren.html'))!;
    expect(r.items, hasLength(6));
    expect(r.summary!.positive, 6);
    expect(r.items.every((e) => e.author.isNotEmpty && e.text.isNotEmpty), isTrue);
  });

  test('C4: comments page', () {
    final c = parseSimklComments(fixture('simkl_comments_frieren.html'))!;
    expect(c, hasLength(3));
    expect(c.first.id, '17264');
    expect(c.first.author, 'RecycledDoom');
    expect(c.first.likes, 1);
    expect(c.first.ago, '2 years ago');
    expect(c.first.exactTime, '23:49 July 1, 2024');
    expect(c.first.text, startsWith('Show is great.'));
    expect(c.first.avatarUrl, 'https://simkl.in/avatars/59/5903066_100.jpg?1675719119');
    expect(c.first.spoiler, isFalse);
    expect(c.first.depth, 0);
    expect(c[2].vip, isTrue);
    expect(parseSimklComments('<div class="SimklTVCommentsItem"><p>changed</p></div>'), isNull);
    expect(parseSimklComments('<html></html>'), isEmpty);
  });

  test('C5: memos page with their rating bucket', () {
    final m = parseSimklMemos(fixture('simkl_memos_frieren.html'))!;
    expect(m, hasLength(230)); // 235 cards, 5 without a name or a text
    expect(m.first.author, 'Rivka');
    expect(m.first.text, 'Watched 2023-24');
    expect(m.first.likes, 1);
    expect(m.first.minStars, 6);
    expect(m.first.maxStars, 10);
    expect(m.any((e) => e.maxStars == 5), isTrue);
    expect(parseSimklMemos('<html></html>'), isNull);
  });
}
