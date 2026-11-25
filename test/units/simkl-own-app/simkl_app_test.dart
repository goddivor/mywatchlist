import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/apps/simkl/simkl_settings_page.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';
import 'package:mywatchlist/screens/home_screen.dart';

/// The Simkl account is its own app: its own bottom bar (catalogues, calendar, profile, no
/// forum), search, settings, and a loading screen when the account changes.
void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
  });

  test('the home shell hands a Simkl account to the Simkl app', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(source, contains('if (tracker == AccountType.simkl) return const SimklApp();'));
    final app = File('lib/apps/simkl/simkl_app.dart').readAsStringSync();
    expect(app, isNot(contains('Forum')), reason: 'Simkl has no forum');
    expect(app, contains('SimklExplorePage(kind: kind)'), reason: 'the search is Simkl\'s, in the catalogue');
  });

  test('the Simkl settings have no MyAnimeList-only page', () {
    const malOnly = {
      // The home layout is per tracker since #348: not MyAnimeList-only any more.
      SettingsSection.animeManga,
      SettingsSection.dub,
      SettingsSection.dataSources,
      SettingsSection.userPreferences,
    };
    expect(SimklSettingsPage.appSections.where(malOnly.contains), isEmpty);
  });

  testWidgets('switching the account shows which app opens', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TrackerSwitchScreen(tracker: AccountType.simkl)));
    expect(find.text('Opening Simkl'), findsOneWidget);
  });
}
