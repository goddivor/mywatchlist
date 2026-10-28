import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_profile_view.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
    await initializeDateFormatting();
  });

  Future<void> pump(WidgetTester tester, Future<SimklProfileData> Function({bool force}) loader) async {
    SharedPreferences.setMockInitialValues({});
    final bloc = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
    addTearDown(bloc.close);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: BlocProvider.value(value: bloc, child: SimklProfileView(loader: loader)),
    ));
  }

  testWidgets('shows the account, the numbers and the recent activity', (tester) async {
    final list = [
      const ListEntryView(
          id: 1, category: 'anime', title: 'First show', status: ListEntryStatus.completed, score: 9, progress: 12, total: 12),
      ListEntryView(
          id: 2,
          category: 'anime',
          title: 'Second show',
          status: ListEntryStatus.current,
          progress: 3,
          total: 12,
          updatedAt: DateTime.utc(2026, 10, 1)),
    ];
    await pump(
      tester,
      ({bool force = false}) async => SimklProfileData(
        UserProfSimkl(name: 'Hailey', joinedAt: DateTime.utc(2020, 5, 1), location: 'Lomé', bio: 'Hello there'),
        SimklListStats.from(list),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hailey'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('15'), findsOneWidget, reason: 'episodes watched');
    expect(find.text('9.00'), findsOneWidget, reason: 'mean score');
    expect(find.text('Latest activity'), findsOneWidget);
    expect(find.text('Second show'), findsOneWidget);
  });

  testWidgets('an empty list says so instead of drawing empty charts', (tester) async {
    await pump(tester,
        ({bool force = false}) async => SimklProfileData(null, SimklListStats.from(const [])));
    await tester.pumpAndSettle();
    expect(find.textContaining('list is empty'), findsOneWidget);
    expect(find.text('Latest activity'), findsNothing);
  });

  testWidgets('a failed load offers Retry, and retrying loads again', (tester) async {
    var calls = 0;
    await pump(tester, ({bool force = false}) async {
      calls++;
      if (calls == 1) throw const SimklHttpError(500);
      return SimklProfileData(null, SimklListStats.from(const []));
    });
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    expect(calls, 2);
  });

  testWidgets('a dead session asks to sign in again', (tester) async {
    await pump(tester, ({bool force = false}) async => throw const SimklSessionExpired());
    await tester.pumpAndSettle();
    expect(find.text('Your Simkl session has expired'), findsOneWidget);
    expect(find.text('Sign in again'), findsOneWidget);
  });
}
