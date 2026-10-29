import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/account_selection.dart';
import 'package:mywatchlist/user/accounts/account_status.dart' show kTrackers;
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seen on the emulator: after the MyAnimeList website login the home showed AniList while
/// MAL was the active account. The login puts MAL in `INPROGRESS` for a moment; the active
/// account must not move to the next connected tracker during that moment.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final users = UserManager.instance;
  const mal = AccountType.myanimelist;
  const ani = AccountType.anilist;

  void setUser(AccountType t, AuthStatus status, {String? name}) {
    final u = users.getUserByTracker(t)!;
    u.status = status;
    u.needsReLogin = false;
    u.username = name;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    for (final t in kTrackers) {
      setUser(t, AuthStatus.UNAUTHENTICATED);
    }
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('the active tracker stays while its sign in runs', () {
    expect(
      resolveSelection(
          current: mal, connected: [ani], expired: const [], connecting: [mal]),
      mal,
    );
    // A tracker that is only connecting is never picked as the new account.
    expect(
      resolveSelection(
          current: AccountType.none,
          connected: const [],
          expired: const [],
          connecting: [mal]),
      AccountType.none,
    );
  });

  test('MAL stays active through a second MAL sign in while AniList is connected',
      () async {
    setUser(mal, AuthStatus.AUTHENTICATED, name: 'neo');
    setUser(ani, AuthStatus.AUTHENTICATED, name: 'trin');
    final bloc = AccountBloc()..add(LoadAccountEvent());
    await settle();
    expect((bloc.state as AccountLoaded).selectedAccountType, mal);

    // The website login starts: MAL reports INPROGRESS.
    setUser(mal, AuthStatus.INPROGRESS, name: 'neo');
    bloc.add(ForceUpdateAccountsEvent());
    await settle();
    expect((bloc.state as AccountLoaded).selectedAccountType, mal);
    expect(users.currentTracker, mal);

    // The login ends.
    setUser(mal, AuthStatus.AUTHENTICATED, name: 'neo');
    bloc.add(ForceUpdateAccountsEvent());
    await settle();
    expect((bloc.state as AccountLoaded).selectedAccountType, mal);
    await bloc.close();
  });
}
