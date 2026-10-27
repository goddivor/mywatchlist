import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/notifications_settings.dart';
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

Future<({PreferencesBloc bloc, FakeBackend backend, NotificationService service})> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  FakeBackend? backend,
}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await S.load(locale);
  final bloc = PreferencesBloc(store: PreferencesStore(prefs));
  addTearDown(bloc.close);
  final fake = backend ?? FakeBackend();
  final service = NotificationService(
    backend: fake,
    texts: const FakeTexts(),
    readPrefs: () => bloc.state.notifications,
    loadCandidates: () async => const [],
    loadEpisodes: () async => const [],
    fetchCover: (_, __) async => null,
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: UserManager.instance,
      child: BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: NotificationSettingsPage(service: service),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (bloc: bloc, backend: fake, service: service);
}

void main() {
  testWidgets('the master switch asks for the permission, then subscribes', (tester) async {
    final env = await _pump(tester);
    expect(env.bloc.state.notifications.enabled, isFalse);
    await tester.tap(find.text('Airing reminders'));
    await tester.pumpAndSettle();
    expect(env.backend.requestCalls, 1);
    expect(env.bloc.state.notifications.enabled, isTrue);
    await tester.tap(find.text('Airing reminders'));
    await tester.pumpAndSettle();
    expect(env.bloc.state.notifications.enabled, isFalse);
  });

  testWidgets('a refused permission keeps the reminders off and says so', (tester) async {
    final backend = FakeBackend(permission: const NotificationPermissions())..grantOnRequest = false;
    final env = await _pump(tester, backend: backend);
    await tester.tap(find.text('Airing reminders'));
    await tester.pumpAndSettle();
    expect(env.bloc.state.notifications.enabled, isFalse);
    expect(find.text('Notifications were not allowed, so reminders stay off.'), findsOneWidget);
  });

  testWidgets('the list and image switches write the contract', (tester) async {
    final env = await _pump(tester);
    await tester.tap(find.text('Watching list'));
    await tester.pumpAndSettle();
    expect(env.bloc.state.notifications.watchingList, isFalse);
    await tester.tap(find.text('Large cover'));
    await tester.pumpAndSettle();
    expect(env.bloc.state.notifications.largeImage, isFalse);
  });

  testWidgets('the test button schedules a notification that opens an anime', (tester) async {
    final env = await _pump(tester);
    await tester.tap(find.text('Send a test notification'));
    await tester.pumpAndSettle();
    expect(env.backend.scheduled.single.payload, startsWith('anime:'));
    expect(find.text('Test notification sent. It appears in 2 seconds.'), findsOneWidget);
  });

  testWidgets('French: every label of the page is translated', (tester) async {
    await _pump(tester, locale: const Locale('fr', 'FR'));
    expect(find.text('Rappels de diffusion'), findsOneWidget);
    expect(find.text('Envoyer une notification de test'), findsOneWidget);
    expect(find.text('Airing reminders'), findsNothing);
    expect(find.text('Send a test notification'), findsNothing);
    expect(find.text('Large cover'), findsNothing);
    expect(find.text('Tools'), findsNothing);
  });
}
