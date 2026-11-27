import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/cache/dub_info.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';

const _entries = [
  ListEntryView(id: 1, malId: 1, category: 'anime', title: 'Dubbed'),
  ListEntryView(id: 2, malId: 2, category: 'anime', title: 'Partial'),
  ListEntryView(id: 3, malId: 3, category: 'anime', title: 'Sub only'),
];

/// Turns the dub setting on (it is off by default, with or without a preferences bloc).
Future<PreferencesBloc> _dubOn() async {
  SharedPreferences.setMockInitialValues({});
  final bloc = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
  bloc.add(GeneralPreferencesChanged((p) => p.copyWith(showDubStatus: true)));
  await bloc.stream.first;
  expect(Preferences.general.showDubStatus, isTrue);
  return bloc;
}

bool _hasDubFacet({required bool isAnime}) =>
    facetsFor(_entries, isAnime: isAnime).any((f) => f.key == ListFacetKeys.dub);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DubInfo saved;

  setUpAll(() => S.load(const Locale('en')));

  setUp(() async {
    saved = DubInfo.instance;
    final info = DubInfo.instance = DubInfo(
      fetch: (_) async => '{"dubbed":[1],"partial":[2]}',
      readCache: (key, {required allowStale}) async => null,
      writeCache: (_, __) async {},
      parse: (body) async => parseDubJson(body),
    );
    await info.ensureLoaded();
  });

  tearDown(() {
    DubInfo.instance = saved;
    Preferences.reset();
  });

  test('the dub facet shows only while the dub setting is on, for anime', () async {
    expect(Preferences.general.showDubStatus, isFalse);
    expect(_hasDubFacet(isAnime: true), isFalse);

    final on = await _dubOn();
    expect(_hasDubFacet(isAnime: true), isTrue);
    expect(_hasDubFacet(isAnime: false), isFalse);
    final facet = facetsFor(_entries, isAnime: true).firstWhere((f) => f.key == ListFacetKeys.dub);
    expect(facet.label, S.current.UserList_Facet_Dub);
    expect(facet.options.map((o) => o.label), [S.current.Dub_Status_Full, S.current.Dub_Status_Partial]);
    await on.close();
  });

  test('one tap keeps the dubbed titles; exclude keeps the others', () async {
    final bloc = await _dubOn();
    final dubbed = ListFilter.none.toggle(ListFacetKeys.dub, DubStatus.dubbed.name, allowExclude: true);
    expect(filterEntries(_entries, dubbed).map((e) => e.title), ['Dubbed']);

    final any = dubbed.toggle(ListFacetKeys.dub, DubStatus.partial.name, allowExclude: true);
    expect(filterEntries(_entries, any).map((e) => e.title), ['Dubbed', 'Partial']);

    final noDub = dubbed.toggle(ListFacetKeys.dub, DubStatus.dubbed.name, allowExclude: true);
    expect(filterEntries(_entries, noDub).map((e) => e.title), ['Partial', 'Sub only']);
    await bloc.close();
  });

  test('a saved dub filter is ignored once the setting is off', () {
    expect(Preferences.general.showDubStatus, isFalse);
    final dubbed = ListFilter.none.toggle(ListFacetKeys.dub, DubStatus.dubbed.name);
    expect(filterEntries(_entries, dubbed), hasLength(3));
  });
}
