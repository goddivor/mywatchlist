import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/apps/anilist/anilist_app_settings_page.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';

/// The AniList account is its own app, laid out like anilist.co: Home (activity, overview),
/// List, Browse, Forum (kept: AniList has one) and Profile, with the AniList search, bell,
/// settings and account switcher in every bar.
void main() {
  test('the home shell hands an AniList account to the AniList app', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(source, contains('if (tracker == AccountType.anilist) return const AnilistApp();'));
    final app = File('lib/apps/anilist/anilist_app.dart').readAsStringSync();
    for (final page in [
      'AnilistActivityFeed()',
      'AnilistHomePage(embedded: true)',
      'AnilistUserPage(embedded: true)',
      'AnilistExplorePage(embedded: true)',
      'AnilistForumPage(embedded: true)',
      'AnilistUserProfilePage(isSelf: true',
    ]) {
      expect(app, contains(page), reason: 'every AniList page is kept: $page');
    }
  });

  test('the AniList settings have no MyAnimeList-only page', () {
    const malOnly = {
      SettingsSection.homePage,
      SettingsSection.animeManga,
      SettingsSection.dub,
      SettingsSection.dataSources,
      SettingsSection.userPreferences,
    };
    expect(AnilistAppSettingsPage.appSections.where(malOnly.contains), isEmpty);
  });
}
