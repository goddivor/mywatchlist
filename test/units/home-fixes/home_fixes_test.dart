import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/home/maintenance_notice.dart';

class _FakeAccountBloc extends Fake implements AccountBloc {
  final _controller = StreamController<AccountState>.broadcast();
  @override
  AccountState state = AccountInitial();
  @override
  Stream<AccountState> get stream => _controller.stream;
  @override
  bool get isClosed => false;
  void emitState(AccountState s) {
    state = s;
    _controller.add(s);
  }
}

AccountLoaded _loaded(AccountType selected, String name) => AccountLoaded(
      selectedAccountType: selected,
      profileImageUrl: null,
      availableAccounts: [Account(name: name, typeAcc: selected, imageUrl: '')],
    );

HomeSectionPreference _section() => HomeSectionPreference(type: SectionType.userList);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cache key depends on tracker and account', () {
    String key(AccountType t, String? id) => HomeUserListSection.cacheKeyFor(
        tracker: t, accountId: id, category: 'anime', status: null, itemCount: 10);
    expect(key(AccountType.myanimelist, 'a'), isNot(key(AccountType.myanimelist, 'b')));
    expect(key(AccountType.myanimelist, 'a'), isNot(key(AccountType.anilist, 'a')));
    expect(key(AccountType.myanimelist, 'a'), startsWith(HomeUserListSection.cachePrefix));
  });

  test('clearPrefix drops only the user-list entries', () {
    HomeSectionCache.clear();
    HomeSectionCache.put('userlist:x', 1);
    HomeSectionCache.put('forum:1', 2);
    HomeSectionCache.clearPrefix(HomeUserListSection.cachePrefix);
    expect(HomeSectionCache.fresh<int>('userlist:x', const Duration(hours: 1)), isNull);
    expect(HomeSectionCache.fresh<int>('forum:1', const Duration(hours: 1)), 2);
  });

  testWidgets('switching account invalidates the user-list section cache', (tester) async {
    HomeSectionCache.clear();
    final bloc = _FakeAccountBloc()..state = _loaded(AccountType.myanimelist, 'alice');
    HomeSectionCache.put('userlist:mal:alice:anime:all:10', ['alice list']);
    HomeSectionCache.put('forum:1', ['topics']);

    await tester.pumpWidget(BlocProvider<AccountBloc>.value(
      value: bloc,
      child: MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: HomeUserListSection(
            section: _section(),
            cardWidth: 100,
            cardHeight: 150,
          ),
        ),
      ),
    ));

    bloc.emitState(_loaded(AccountType.myanimelist, 'alice')); // same account: kept
    await tester.pump();
    expect(HomeSectionCache.fresh<List>('userlist:mal:alice:anime:all:10', const Duration(hours: 1)),
        isNotNull);

    bloc.emitState(_loaded(AccountType.anilist, 'bob')); // switched
    await tester.pump();
    expect(HomeSectionCache.fresh<List>('userlist:mal:alice:anime:all:10', const Duration(hours: 1)),
        isNull);
    expect(HomeSectionCache.fresh<List>('forum:1', const Duration(hours: 1)), isNotNull);
  });

  testWidgets('maintenance dialog shows once even when checks race', (tester) async {
    resetMalMaintenanceNoticeForTest();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Builder(builder: (context) {
        return TextButton(
          onPressed: () {
            checkMalMaintenance(context, probe: () async => true);
            checkMalMaintenance(context, probe: () async => true);
          },
          child: const Text('go'),
        );
      }),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
