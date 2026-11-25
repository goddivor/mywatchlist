import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PreferencesBloc> _bloc({AccountType tracker = AccountType.myanimelist}) async {
  final shared = await SharedPreferences.getInstance();
  return PreferencesBloc(store: PreferencesStore(shared), tracker: tracker);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Preferences.reset();
  });

  test('a setting changed on one tracker stays on that tracker (#349)', () async {
    final bloc = await _bloc();
    final nsfw = bloc.state.general.nsfw;
    bloc.add(GeneralPreferencesChanged((p) => p.copyWith(nsfw: !nsfw)));
    await bloc.stream.first;
    expect(Preferences.general.nsfw, !nsfw);

    bloc.add(const PreferencesTrackerChanged(AccountType.anilist));
    await bloc.stream.first;
    expect(bloc.tracker, AccountType.anilist);
    expect(Preferences.general.nsfw, nsfw, reason: 'AniList keeps its own value');

    bloc.add(const PreferencesTrackerChanged(AccountType.myanimelist));
    await bloc.stream.first;
    expect(Preferences.general.nsfw, !nsfw, reason: 'back on MAL, its value');
    await bloc.close();
  });

  test('values saved before the split are every tracker\'s starting point', () async {
    final shared = await SharedPreferences.getInstance();
    final global = PreferencesStore(shared);
    final start = global.read();
    await global.write(start.copyWith(general: start.general.copyWith(nsfw: !start.general.nsfw)));
    final kitsu = await _bloc(tracker: AccountType.kitsu);
    expect(kitsu.state.general.nsfw, !start.general.nsfw);
    await kitsu.close();
  });

  test('the time zone is an app setting, shared by every tracker', () async {
    final bloc = await _bloc();
    final zone = bloc.state.content.timezone;
    final next = TimezonePref.values.firstWhere((z) => z != zone);
    bloc.add(ContentPreferencesChanged((p) => p.copyWith(timezone: next)));
    await bloc.stream.first;
    bloc.add(const PreferencesTrackerChanged(AccountType.simkl));
    // Simkl's settings equal the current ones here, so the bloc emits nothing: wait a turn.
    await Future<void>.delayed(Duration.zero);
    expect(bloc.tracker, AccountType.simkl);
    expect(Preferences.content.timezone, next);
    await bloc.close();
  });
}
