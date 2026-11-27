import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/tracker_youtube_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TrackerYoutubePlayer.resetAll();
  });

  test('off by default, and each tracker keeps its own choice', () async {
    for (final t in [AccountType.anilist, AccountType.kitsu, AccountType.simkl]) {
      expect(await TrackerYoutubePlayer.of(t).ensureLoaded(), isFalse);
    }
    TrackerYoutubePlayer.of(AccountType.kitsu).set(true);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('embedded_youtube_kitsu'), isTrue);
    expect(prefs.getBool('embedded_youtube_anilist'), isNull);
    expect(TrackerYoutubePlayer.of(AccountType.anilist).value, isFalse);
    expect(TrackerYoutubePlayer.of(AccountType.simkl).value, isFalse);
  });

  test('the saved choice is read back', () async {
    SharedPreferences.setMockInitialValues({'embedded_youtube_simkl': true});
    expect(await TrackerYoutubePlayer.of(AccountType.simkl).ensureLoaded(), isTrue);
    expect(await TrackerYoutubePlayer.of(AccountType.anilist).ensureLoaded(), isFalse);
  });

  testWidgets('with the switch off, the trailer opens outside', (tester) async {
    var outside = 0;
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    await tester.runAsync(() => playTrackerTrailer(ctx,
        url: 'https://www.youtube.com/watch?v=abcdefghijk',
        tracker: AccountType.anilist,
        outside: () async => outside++));
    expect(outside, 1);
  });

  testWidgets('the switch of one tracker changes only that tracker', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: [S.delegate],
      home: Scaffold(body: TrackerYoutubeSwitch(tracker: AccountType.simkl)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Built-in YouTube player'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(TrackerYoutubePlayer.of(AccountType.simkl).value, isTrue);
    expect(TrackerYoutubePlayer.of(AccountType.kitsu).value, isFalse);
  });
}
