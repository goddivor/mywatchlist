import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_feeds.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_home_plan.dart';

HomeSectionPreference _s(SectionType type, {bool enabled = true, int count = 15}) =>
    HomeSectionPreference(type: type, enabled: enabled, itemCount: count);

void main() {
  test('MyAnimeList-only sections are skipped, the others become Simkl lists once each', () {
    final plan = simklHomePlan([
      _s(SectionType.news),
      _s(SectionType.upcoming, count: 8),
      _s(SectionType.userList, count: 10),
      _s(SectionType.seasonNow),
      _s(SectionType.topManga),
      _s(SectionType.topAnimeAiring),
      _s(SectionType.topScore, count: 12),
      _s(SectionType.topPopular),
      _s(SectionType.forum),
    ]);
    expect(plan, [
      const SimklHomeBlock(SimklFeed.premieres, 8),
      const SimklHomeBlock(null, 10),
      const SimklHomeBlock(SimklFeed.airing, 15),
      const SimklHomeBlock(SimklFeed.trending, 12),
    ]);
  });

  test('disabled sections are left out, and a disabled user list stays off', () {
    final plan = simklHomePlan([
      _s(SectionType.userList, enabled: false),
      _s(SectionType.topScore, enabled: false),
      _s(SectionType.suggested),
    ]);
    expect(plan, [const SimklHomeBlock(SimklFeed.trending, 15)]);
  });

  test('preferences saved without a user list section show "Continue watching" first', () {
    final plan = simklHomePlan([_s(SectionType.seasonNow)]);
    expect(plan.first.feed, isNull);
    expect(plan.map((b) => b.key), ['continue', 'premieres']);
  });

  test('nothing enabled gives an empty plan', () {
    expect(simklHomePlan([_s(SectionType.seasonNow, enabled: false), _s(SectionType.news)]).map((b) => b.feed),
        [null], reason: 'only the implicit Continue watching');
  });
}
