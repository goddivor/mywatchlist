import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/tracker_add_status.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TrackerAddStatus.resetAll();
  });

  test('Plan to watch until a status is picked', () async {
    await TrackerAddStatus.loadAll();
    for (final t in [AccountType.anilist, AccountType.kitsu, AccountType.simkl]) {
      expect(TrackerAddStatus.of(t, anime: true), ListEntryStatus.planned);
      expect(TrackerAddStatus.of(t, anime: false), ListEntryStatus.planned);
    }
  });

  test('each tracker and category keeps its own status, saved and read back', () async {
    TrackerAddStatus.set(AccountType.kitsu, ListEntryStatus.current, anime: true);
    await Future<void>.delayed(Duration.zero);
    expect(TrackerAddStatus.of(AccountType.kitsu, anime: false), ListEntryStatus.planned);
    expect(TrackerAddStatus.of(AccountType.anilist, anime: true), ListEntryStatus.planned);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('default_add_status_kitsu_anime'), 'current');

    TrackerAddStatus.resetAll();
    await TrackerAddStatus.loadAll();
    expect(TrackerAddStatus.of(AccountType.kitsu, anime: true), ListEntryStatus.current);
  });

  testWidgets('the settings row picks the status of its own tracker', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: [S.delegate],
      home: Scaffold(body: TrackerAddStatusTile(tracker: AccountType.anilist, anime: false)),
    ));
    expect(find.text('Status for added manga'), findsOneWidget);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading').last);
    await tester.pumpAndSettle();
    expect(TrackerAddStatus.of(AccountType.anilist, anime: false), ListEntryStatus.current);
    expect(TrackerAddStatus.of(AccountType.kitsu, anime: false), ListEntryStatus.planned);
    expect(find.text('Reading'), findsOneWidget);
  });
}
