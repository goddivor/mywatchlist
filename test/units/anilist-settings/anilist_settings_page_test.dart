import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_settings_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_settings_service.dart';

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';
import 'anilist_settings_test.dart' show viewer;

class FakeService extends AnilistSettingsService {
  final List<String> calls = [];
  AnilistSettings current = AnilistSettings.fromViewer(viewer);

  @override
  Future<AnilistSettings> load() async => current;

  @override
  Future<AnilistSettings> update({
    String? about,
    AnilistTitleLanguage? titleLanguage,
    AnilistStaffNameLanguage? staffNameLanguage,
    bool? displayAdultContent,
    bool? includeAdultContentInSearch,
    bool? includeAdultContentInQuickSearch,
    bool? displayAdultActivities,
    bool? airingNotifications,
    AnilistScoreFormat? scoreFormat,
    String? rowOrder,
    String? profileColor,
    String? donatorBadge,
    String? timezone,
    int? activityMergeTime,
    bool? restrictMessagesToFollowing,
    Map<String, bool>? notificationOptions,
    Map<String, bool>? disabledListActivity,
    Map<String, Object?>? animeListOptions,
    Map<String, Object?>? mangaListOptions,
  }) async {
    if (displayAdultContent != null) calls.add('adult=$displayAdultContent');
    return current;
  }
}

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  testWidgets('shows the loaded settings and saves a switch through the service', (tester) async {
    final fakeService = FakeService();
    await pumpInApp(tester, AnilistSettingsPage(service: fakeService));
    await tester.pumpAndSettle();
    expect(find.text('AniList settings'), findsOneWidget);
    expect(find.text('English (stylised)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Display adult content'), 300);
    await tester.tap(find.text('Display adult content'));
    await tester.pumpAndSettle();
    expect(fakeService.calls, isNotEmpty);
  });
}
