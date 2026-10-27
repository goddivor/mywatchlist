import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/anime_manga_settings.dart';
import 'package:mywatchlist/screens/settings/list_prefs_settings.dart';
import 'package:mywatchlist/screens/settings/user_prefs_settings.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PreferencesBloc> _pump(WidgetTester tester, Widget page, {Locale locale = const Locale('en')}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await S.load(locale);
  final bloc = PreferencesBloc(store: PreferencesStore(prefs));
  addTearDown(bloc.close);
  await tester.pumpWidget(
    BlocProvider.value(
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
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return bloc;
}

void main() {
  testWidgets('user prefs: a switch writes the contract and persists', (tester) async {
    final bloc = await _pump(tester, const UserPrefSettingsPage());
    expect(bloc.state.general.nsfw, isFalse);
    await tester.tap(find.text('Adult content'));
    await tester.pumpAndSettle();
    expect(bloc.state.general.nsfw, isTrue);
    // A fresh read of the storage sees the change (survives a restart).
    final reread = PreferencesStore(bloc.store.prefs).read();
    expect(reread.general.nsfw, isTrue);
  });

  testWidgets('user prefs: the title language picker changes the preference', (tester) async {
    final bloc = await _pump(tester, const UserPrefSettingsPage());
    expect(bloc.state.general.preferredTitle.name, 'ro');
    await tester.tap(find.text('Title language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japanese').last);
    await tester.pumpAndSettle();
    expect(bloc.state.general.preferredTitle.name, 'ja');
  });

  testWidgets('user prefs: restore defaults after confirmation', (tester) async {
    final bloc = await _pump(tester, const UserPrefSettingsPage());
    bloc.add(GeneralPreferencesChanged((p) => p.copyWith(nsfw: true, dubLanguage: 'french')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(bloc.state.general.nsfw, isFalse);
    expect(bloc.state.general.dubLanguage, 'french', reason: 'dub options are not on this page');
  });

  testWidgets('anime/manga: hiding a section updates the order list', (tester) async {
    final bloc = await _pump(tester, const AnimeMangaSettingsPage());
    expect(bloc.state.content.animeTabs.first.visible, isTrue);
    await tester.tap(find.byTooltip('Hide Synopsis'));
    await tester.pumpAndSettle();
    expect(bloc.state.content.animeTabs.first.visible, isFalse);
    expect(bloc.state.content.mangaTabs.first.visible, isTrue);
  });

  testWidgets('list prefs: create, duplicate and delete a card layout', (tester) async {
    final bloc = await _pump(tester, const ListPreferenceSettingsPage());
    expect(find.text('No custom layout yet. The built-in views are used.'), findsOneWidget);
    await tester.tap(find.text('New layout'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Compact');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(bloc.state.list.cardProfiles.single.profileName, 'Compact');
    expect(bloc.state.list.cardProfiles.single.id, isNotEmpty);

    await tester.tap(find.byTooltip('Layout actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    expect(bloc.state.list.cardProfiles.map((p) => p.profileName), ['Compact', 'Compact (copy)']);

    await tester.tap(find.byTooltip('Layout actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(bloc.state.list.cardProfiles.map((p) => p.profileName), ['Compact (copy)']);
  });

  testWidgets('list prefs: default category picker persists', (tester) async {
    final bloc = await _pump(tester, const ListPreferenceSettingsPage());
    await tester.tap(find.text('Default list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manga').last);
    await tester.pumpAndSettle();
    expect(bloc.state.list.defaultCategory, ListCategory.manga);
    expect(PreferencesStore(bloc.store.prefs).read().list.defaultCategory, ListCategory.manga);
  });

  testWidgets('pages are translated in French', (tester) async {
    await _pump(tester, const UserPrefSettingsPage(), locale: const Locale('fr', 'FR'));
    expect(find.text('Langue des titres'), findsOneWidget);
    expect(find.text('Adult content'), findsNothing);
    await S.load(const Locale('en'));
  });
}
