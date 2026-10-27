import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/account_status.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// #97 item 2: signing out of a tracker forgets that tracker's list status cache, so the
/// next account (or a signed-out app) never shows the previous user's badges.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final users = UserManager.instance;
  late ListStatusCache cache;

  void connect(AccountType t) {
    final u = users.getUserByTracker(t)!;
    u.status = AuthStatus.AUTHENTICATED;
    u.needsReLogin = false;
    u.username = 'neo';
  }

  void disconnect(AccountType t) {
    final u = users.getUserByTracker(t)!;
    u.status = AuthStatus.UNAUTHENTICATED;
    u.needsReLogin = false;
    u.username = null;
  }

  const watching = CachedListStatus(status: 'watching', score: 8, progress: 3);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    for (final t in kTrackers) {
      disconnect(t);
    }
    cache = ListStatusCache(saveDelay: Duration.zero);
    await cache.ensureLoaded();
    cache.put(1, watching, tracker: AccountType.myanimelist);
    cache.put(2, watching, category: 'manga', tracker: AccountType.myanimelist);
    cache.put(3, watching, tracker: AccountType.anilist);
    await cache.flush();
  });

  tearDown(() => cache.dispose());

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('signing out of a tracker clears its cached statuses, memory and disk', () async {
    connect(AccountType.myanimelist);
    connect(AccountType.anilist);
    final bloc = AccountBloc(listCache: cache)..add(LoadAccountEvent());
    await settle();

    disconnect(AccountType.myanimelist);
    bloc.add(RemoveAccountEvent(AccountType.myanimelist));
    await settle();

    expect(cache.statusOf(1, tracker: AccountType.myanimelist), isNull);
    expect(cache.countOf(category: 'manga', tracker: AccountType.myanimelist), 0);
    // The other tracker keeps its badges.
    expect(cache.statusOf(3, tracker: AccountType.anilist), 'watching');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.contains('myanimelist')), isEmpty);
    expect(prefs.getKeys().where((k) => k.contains('anilist')), isNotEmpty);
    await bloc.close();
  });

  test('a card watching an entry loses its badge on sign out', () async {
    connect(AccountType.myanimelist);
    final badge = cache.watch(1, tracker: AccountType.myanimelist);
    expect(badge.value, watching);
    final bloc = AccountBloc(listCache: cache)..add(LoadAccountEvent());
    await settle();

    bloc.add(RemoveAccountEvent(AccountType.myanimelist));
    await settle();
    expect(badge.value, isNull);
    await bloc.close();
  });

  test('logging out of everything clears every tracker cache', () async {
    connect(AccountType.myanimelist);
    connect(AccountType.anilist);
    final bloc = AccountBloc(listCache: cache)..add(LoadAccountEvent());
    await settle();

    bloc.add(LogoutEvent());
    await settle();
    expect(cache.countOf(tracker: AccountType.myanimelist), 0);
    expect(cache.countOf(tracker: AccountType.anilist), 0);
    await bloc.close();
  });

  test('the bloc uses the shared cache by default', () async {
    final previous = ListStatusCache.instance;
    ListStatusCache.instance = cache;
    addTearDown(() => ListStatusCache.instance = previous);
    connect(AccountType.myanimelist);
    final bloc = AccountBloc()..add(LoadAccountEvent());
    await settle();

    bloc.add(RemoveAccountEvent(AccountType.myanimelist));
    await settle();
    expect(cache.countOf(tracker: AccountType.myanimelist), 0);
    await bloc.close();
  });
}
