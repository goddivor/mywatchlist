import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/home_screen.dart' show TrackerSwitchScreen;
import 'package:mywatchlist/user/trackers/models/tracker_model.dart' show TrackerInfo;

void main() {
  setUpAll(() => S.load(const Locale('en')));

  for (final tracker in [AccountType.myanimelist, AccountType.anilist, AccountType.kitsu, AccountType.simkl]) {
    testWidgets('${tracker.name}: its round logo inside the ring, then the text', (tester) async {
      await tester.pumpWidget(MaterialApp(home: TrackerSwitchScreen(tracker: tracker)));
      await tester.pump(const Duration(milliseconds: 300));
      final logo = tester.widget<Image>(find.byKey(const ValueKey('tracker-switch-logo')));
      expect((logo.image as AssetImage).assetName, TrackerInfo.of(tracker)!.logoAsset);
      expect(find.ancestor(of: find.byType(Image), matching: find.byType(ClipOval)), findsOneWidget);
      final ring = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
      expect(ring.color, TrackerInfo.of(tracker)!.color);
      expect(find.text('Opening ${TrackerInfo.of(tracker)!.name}'), findsOneWidget);
    });
  }

  testWidgets('reduced motion: the logo is there at once', (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: TrackerSwitchScreen(tracker: AccountType.kitsu)),
    ));
    final fade = tester.widget<FadeTransition>(
        find.ancestor(of: find.byType(ClipOval), matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, 1);
  });
}
