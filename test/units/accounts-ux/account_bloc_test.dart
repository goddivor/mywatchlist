import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final users = UserManager.instance;

  void connect(AccountType t, {String name = 'neo'}) {
    final u = users.getUserByTracker(t)!;
    u.status = AuthStatus.AUTHENTICATED;
    u.needsReLogin = false;
    u.username = name;
  }

  void kill(AccountType t) {
    final u = users.getUserByTracker(t)!;
    u.status = AuthStatus.UNAUTHENTICATED;
    u.needsReLogin = true;
  }

  void disconnect(AccountType t) {
    final u = users.getUserByTracker(t)!;
    u.status = AuthStatus.UNAUTHENTICATED;
    u.needsReLogin = false;
    u.username = null;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    for (final t in [
      AccountType.myanimelist,
      AccountType.anilist,
      AccountType.kitsu,
      AccountType.simkl,
    ]) {
      disconnect(t);
    }
  });

  AccountLoaded loaded(AccountBloc bloc) => bloc.state as AccountLoaded;

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('startup picks the first connected account when nothing is saved', () async {
    connect(AccountType.anilist);
    connect(AccountType.simkl);
    final bloc = AccountBloc()..add(LoadAccountEvent());
    await settle();
    expect(loaded(bloc).selectedAccountType, AccountType.anilist);
    expect(loaded(bloc).availableAccounts.map((a) => a.typeAcc),
        [AccountType.anilist, AccountType.simkl]);
    await bloc.close();
  });

  test('one event switches the account, no confirmation step', () async {
    connect(AccountType.myanimelist);
    connect(AccountType.kitsu);
    final bloc = AccountBloc()..add(LoadAccountEvent());
    await settle();
    bloc.add(ChangeAccountEvent(AccountType.kitsu));
    await settle();
    expect(loaded(bloc).selectedAccountType, AccountType.kitsu);
    // A tracker that is not connected cannot be activated.
    bloc.add(ChangeAccountEvent(AccountType.simkl));
    await settle();
    expect(loaded(bloc).selectedAccountType, AccountType.kitsu);
    await bloc.close();
  });

  test('signing out of the active account activates the next one', () async {
    connect(AccountType.myanimelist);
    connect(AccountType.anilist);
    final bloc = AccountBloc()..add(LoadAccountEvent());
    await settle();
    disconnect(AccountType.myanimelist);
    bloc.add(RemoveAccountEvent(AccountType.myanimelist));
    await settle();
    expect(loaded(bloc).selectedAccountType, AccountType.anilist);
    disconnect(AccountType.anilist);
    bloc.add(RemoveAccountEvent(AccountType.anilist));
    await settle();
    expect(loaded(bloc).selectedAccountType, AccountType.none);
    await bloc.close();
  });

  test('a dead session stays in the list, flagged, and keeps the selection', () async {
    connect(AccountType.myanimelist);
    connect(AccountType.anilist);
    final bloc = AccountBloc()..add(LoadAccountEvent());
    await settle();
    kill(AccountType.myanimelist);
    bloc.add(ForceUpdateAccountsEvent());
    await settle();
    final state = loaded(bloc);
    expect(state.selectedAccountType, AccountType.myanimelist);
    expect(state.availableAccounts.first.needsReLogin, isTrue);
    expect(state.availableAccounts.last.needsReLogin, isFalse);
    await bloc.close();
  });

  test('the first sign in becomes the active account on its own', () async {
    final bloc = AccountBloc()..add(LoadAccountEvent());
    await settle();
    expect(loaded(bloc).selectedAccountType, AccountType.none);
    connect(AccountType.simkl);
    bloc.add(ForceUpdateAccountsEvent());
    await settle();
    expect(loaded(bloc).selectedAccountType, AccountType.simkl);
    await bloc.close();
  });
}
