import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/account_status.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/user/accounts/widgets/account_tile.dart';
import 'package:mywatchlist/widgets/common/logout_dialog.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() => LanguageBloc.apply('en'));

  Widget tile(TrackerStatus status,
          {bool active = false,
          VoidCallback? onSelect,
          VoidCallback? onConnect,
          VoidCallback? onCancel,
          VoidCallback? onSignOut}) =>
      SizedBox(
        width: 380,
        child: AccountTile(
          info: TrackerInfo.aniList,
          status: status,
          username: 'neo',
          isActive: active,
          onSelect: onSelect,
          onConnect: onConnect,
          onCancel: onCancel,
          onSignOut: onSignOut,
        ),
      );

  testWidgets('a connected account switches with one tap', (tester) async {
    var taps = 0;
    await pumpInApp(tester, tile(TrackerStatus.connected, onSelect: () => taps++));
    expect(find.text('neo'), findsOneWidget);
    await tester.tap(find.text('neo'));
    expect(taps, 1);
  });

  testWidgets('the active account is marked and is not tappable', (tester) async {
    var taps = 0;
    await pumpInApp(
        tester, tile(TrackerStatus.connected, active: true, onSelect: () => taps++));
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.textContaining(S.current.Acc_Active), findsOneWidget);
    await tester.tap(find.text('neo'));
    expect(taps, 0);
  });

  testWidgets('a dead session offers to sign in again', (tester) async {
    var again = 0;
    await pumpInApp(tester, tile(TrackerStatus.needsSignIn, onConnect: () => again++));
    expect(find.textContaining(S.current.Acc_Session_Expired), findsOneWidget);
    await tester.tap(find.text(S.current.Acc_Sign_In_Again));
    expect(again, 1);
  });

  testWidgets('a sign in that never came back can be cancelled', (tester) async {
    var cancelled = 0;
    await pumpInApp(tester, tile(TrackerStatus.connecting, onCancel: () => cancelled++));
    await tester.tap(find.text(S.current.Cancel));
    expect(cancelled, 1);
  });

  testWidgets('a disconnected tracker has a Connect button', (tester) async {
    var connects = 0;
    await pumpInApp(tester, tile(TrackerStatus.disconnected, onConnect: () => connects++));
    await tester.tap(find.text(S.current.Acc_Connect));
    expect(connects, 1);
  });

  testWidgets('the overflow menu signs out', (tester) async {
    var out = 0;
    await pumpInApp(tester, tile(TrackerStatus.connected, onSignOut: () => out++));
    await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.Acc_Sign_Out));
    expect(out, 1);
  });

  testWidgets('the logout dialog is translated and answers a bool', (tester) async {
    LanguageBloc.apply('fr_FR');
    addTearDown(() => LanguageBloc.apply('en'));
    bool? answer;
    await pumpInApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              answer = await confirmLogout(context, trackerName: 'Kitsu'),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Se déconnecter de Kitsu ?'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });
}
