import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ListStatusCache cache;
  late FakeSimkl fake;

  setUpAll(() async {
    await LanguageBloc.apply('en');
    await initializeDateFormatting();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = ListStatusCache(saveDelay: const Duration(days: 1));
    fake = FakeSimkl((r) {
      if (r.method == 'GET') {
        return FakeSimkl.json({
          'anime': [
            simklItem(id: 1, title: 'Frieren', watched: 3, total: 28, lastWatched: '2026-10-02T00:00:00Z', poster: false),
            simklItem(id: 2, title: 'Monster', status: 'completed', watched: 74, total: 74, rating: 9, poster: false),
            simklItem(id: 3, title: 'Planned', status: 'plantowatch', total: 0, poster: false),
          ],
        });
      }
      return FakeSimkl.json({});
    });
  });
  tearDown(() => cache.dispose());

  Future<void> pump(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    final adapter = SimklUserListAdapter(
      service: SimklListService(client: fake.client, owner: () => 'me'),
      owner: () => 'me',
    );
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: UserListView(
          adapter: adapter,
          cache: cache,
          titleBuilder: (context, categorySwitch) => categorySwitch,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the Simkl anime list renders with counts, and a quick +1 writes to the history', (tester) async {
    await pump(tester);
    expect(find.text('Frieren 1'), findsOneWidget);
    expect(find.text('Monster 2'), findsOneWidget);
    expect(find.text('Planned 3'), findsOneWidget);
    expect(find.text('3 / 28 ep.'), findsOneWidget);

    await tester.tap(find.byTooltip('Add one').first);
    await tester.pumpAndSettle();
    expect(find.text('4 / 28 ep.'), findsOneWidget);
    final write = fake.seen.lastWhere((r) => r.method == 'POST');
    expect(write.url.path, '/sync/history');
    expect((write.body as Map)['shows'][0]['episodes'], [
      {'number': 4}
    ]);
    cache.resetForTest();
  });

  testWidgets('the French list has no English left', (tester) async {
    await LanguageBloc.apply('fr_FR');
    addTearDown(() => LanguageBloc.apply('en'));
    await pump(tester, locale: const Locale('fr', 'FR'));
    expect(find.text('Tout'), findsOneWidget);
    expect(find.text('3 / 28 ép.'), findsOneWidget);
    cache.resetForTest();
  });
}
