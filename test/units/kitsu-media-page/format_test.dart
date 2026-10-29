import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_cards.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_format.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => LanguageBloc.apply('en'));

  test('Kitsu percentages show as a percentage, as Kitsu shows it', () {
    expect(KitsuMediaFormat.score(88.85), '89%');
    expect(KitsuMediaFormat.score(90), '90%');
  });

  test('histogram: the 19 steps fold into 10 whole points and no vote is lost', () {
    final r = KitsuRatingFrequencies.parse(fixtureJson('rating_frequencies'));
    final buckets = KitsuRatingHistogram.buckets(r);
    expect(buckets, hasLength(10));
    expect(buckets.fold(0, (a, b) => a + b), r.total);
    expect(buckets[0], r[1] + r[2]);
    expect(buckets[9], r[19] + r[20]);
  });

  test('enums become words, an unknown one is made readable', () {
    expect(KitsuMediaFormat.status('CURRENT', KitsuMediaKind.anime), 'Airing');
    expect(KitsuMediaFormat.status('CURRENT', KitsuMediaKind.manga), 'Publishing');
    expect(KitsuMediaFormat.status('SOMETHING_NEW', KitsuMediaKind.anime), 'Something new');
    expect(KitsuMediaFormat.subtype('ONESHOT'), 'One-shot');
    expect(KitsuMediaFormat.subtype('TV'), 'TV');
    expect(KitsuMediaFormat.relation('ALTERNATIVE_VERSION'), 'Alternative version');
    expect(KitsuMediaFormat.relation('NEW_KIND'), 'New kind');
    expect(KitsuMediaFormat.season('FALL', DateTime(2023, 9, 29)), 'Fall 2023');
    expect(KitsuMediaFormat.minutes(24), '24 min');
    expect(KitsuMediaFormat.minutes(125), '2 h 5 min');
  });

  test('external ids: known sites have a page, the others have none', () {
    final mal = KitsuMediaFormat.externalSite(const KitsuMapping('MYANIMELIST_MANGA', '42'));
    expect(mal.url, 'https://myanimelist.net/manga/42');
    final other = KitsuMediaFormat.externalSite(const KitsuMapping('THETVDB_SERIES', '9'));
    expect(other.name, 'Thetvdb Series');
    expect(other.url, isNull);
  });

  test('trailer picture and page url', () {
    expect(KitsuTrailerCard.thumbnail('abc'), 'https://img.youtube.com/vi/abc/hqdefault.jpg');
    expect(KitsuMediaFormat.pageUrl(KitsuMediaKind.manga, 'berserk'), 'https://kitsu.app/manga/berserk');
  });
}
