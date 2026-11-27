import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/apps/kitsu/kitsu_app_settings_page.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';

/// The Kitsu account is its own app, laid out like Kitsu's: Feed, Search, Quick update in the
/// middle (where it opens), Library and Profile.
void main() {
  test('the home shell hands a Kitsu account to the Kitsu app, every page kept', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(source, contains('if (tracker == AccountType.kitsu) return const KitsuApp();'));
    final app = File('lib/apps/kitsu/kitsu_app.dart').readAsStringSync();
    for (final page in [
      'KitsuForumPage(showAppBar: false)',
      'KitsuExplorePage(embedded: true)',
      'KitsuHomePage(embedded: true)',
      'KitsuUserPage(embedded: true)',
      'KitsuUserProfilePage(isSelf: true',
    ]) {
      expect(app, contains(page), reason: page);
    }
    expect(app, contains('int _index = KitsuApp.home;'), reason: 'opens on Quick update');
  });

  test('the Kitsu settings have no MyAnimeList-only page', () {
    const malOnly = {
      // The home layout is per tracker since #348: not MyAnimeList-only any more.
      SettingsSection.animeManga,
      SettingsSection.dub,
      SettingsSection.dataSources,
      SettingsSection.userPreferences,
    };
    expect(KitsuAppSettingsPage.appSections.where(malOnly.contains), isEmpty);
  });
}
