import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/screens/settings/mal_home_settings.dart' show homeSectionAvailable;
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAccountBloc extends Fake implements AccountBloc {
  final _controller = StreamController<AccountState>.broadcast();
  @override
  AccountState state = AccountInitial();
  @override
  Stream<AccountState> get stream => _controller.stream;
  void select(AccountType t) {
    state = AccountLoaded(
      selectedAccountType: t,
      profileImageUrl: null,
      availableAccounts: [Account(name: 'me', typeAcc: t, imageUrl: '')],
    );
    _controller.add(state);
  }
}

String _layout(List<SectionType> types) => jsonEncode(MalHomePreferences(
      sections: [for (final t in types) HomeSectionPreference(type: t)],
    ).toJson());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each tracker saves its own layout', () async {
    SharedPreferences.setMockInitialValues({});
    await MalHomePreferences(sections: [HomeSectionPreference(type: SectionType.forum)])
        .save(tracker: AccountType.anilist);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mal_home_preferences:anilist'), isNotNull);
    expect(prefs.getString('mal_home_preferences'), isNull, reason: 'the shared layout is left alone');
    final kitsu = await MalHomePreferences.load(tracker: AccountType.kitsu);
    expect(kitsu.sections.map((s) => s.type), isNot([SectionType.forum]));
  });

  test("a tracker without its own layout starts from the shared one saved before", () async {
    SharedPreferences.setMockInitialValues({'mal_home_preferences': _layout([SectionType.topScore])});
    final simkl = await MalHomePreferences.load(tracker: AccountType.simkl);
    expect(simkl.sections.map((s) => s.type), contains(SectionType.topScore));
  });

  test('switching account loads that tracker layout', () async {
    SharedPreferences.setMockInitialValues({
      'mal_home_preferences:myanimelist': _layout([SectionType.news]),
      'mal_home_preferences:anilist': _layout([SectionType.forum]),
    });
    final accounts = _FakeAccountBloc()..select(AccountType.myanimelist);
    final bloc = HomePreferencesBloc(accounts: accounts)..add(LoadHomePreferencesEvent());
    await bloc.stream.firstWhere((s) => !s.isLoading && s.preferences.sections.any((x) => x.type == SectionType.news));
    accounts.select(AccountType.anilist);
    final anilist = await bloc.stream.firstWhere((s) => s.preferences.sections.any((x) => x.type == SectionType.forum));
    expect(bloc.tracker, AccountType.anilist);
    expect(anilist.preferences.sections.map((s) => s.type), isNot(contains(SectionType.news)));
    await bloc.close();
  });

  test('the settings only offer what the tracker can draw', () {
    expect(homeSectionAvailable(AccountType.myanimelist, SectionType.features), isTrue);
    expect(homeSectionAvailable(AccountType.anilist, SectionType.features), isFalse);
    expect(homeSectionAvailable(AccountType.anilist, SectionType.forum), isTrue);
    expect(homeSectionAvailable(AccountType.kitsu, SectionType.forum), isFalse);
    expect(homeSectionAvailable(AccountType.simkl, SectionType.topManga), isFalse);
    expect(homeSectionAvailable(AccountType.simkl, SectionType.topScore), isTrue);
  });
}
