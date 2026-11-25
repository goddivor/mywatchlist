import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/notifications/notification_payload.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/utils/app_routes.dart';

class _FakeAccountBloc extends Fake implements AccountBloc {
  _FakeAccountBloc(AccountType selected)
      : state = AccountLoaded(
          selectedAccountType: selected,
          profileImageUrl: null,
          availableAccounts: [Account(name: 'me', typeAcc: selected, imageUrl: '')],
        );

  final events = <AccountEvent>[];
  final _controller = StreamController<AccountState>.broadcast();
  @override
  AccountState state;
  @override
  Stream<AccountState> get stream => _controller.stream;
  @override
  bool get isClosed => false;
  @override
  void add(AccountEvent event) => events.add(event);
  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() => S.load(const Locale('en')));

  Future<void> tap(WidgetTester tester, _FakeAccountBloc bloc, String payload,
      {bool connected = true}) async {
    await tester.pumpWidget(BlocProvider<AccountBloc>.value(
      value: bloc,
      child: MaterialApp(
        localizationsDelegates: const [S.delegate],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AppRoutes.openTrackerPayload(context, NotificationPayload.parse(payload)!,
                signedIn: (_) => connected, switchWait: Duration.zero),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets("another connected tracker's notification switches to that tracker first", (tester) async {
    final bloc = _FakeAccountBloc(AccountType.myanimelist);
    await tap(tester, bloc, 'anilist:notifications');
    expect(bloc.events, [ChangeAccountEvent(AccountType.anilist)]);
  });

  testWidgets('a notification of the active tracker does not switch', (tester) async {
    final bloc = _FakeAccountBloc(AccountType.anilist);
    await tap(tester, bloc, 'anilist:notifications');
    expect(bloc.events, isEmpty);
  });

  testWidgets('a tracker that is not signed in is not made active', (tester) async {
    final bloc = _FakeAccountBloc(AccountType.myanimelist);
    await tap(tester, bloc, 'kitsu:notifications', connected: false);
    expect(bloc.events, isEmpty);
  });

  test('legacy payloads keep their own route', () {
    expect(NotificationPayload.parse('anime:21')?.isLegacy, isTrue);
    expect(NotificationPayload.parse('anilist:anime:21')?.isLegacy, isFalse);
  });
}
