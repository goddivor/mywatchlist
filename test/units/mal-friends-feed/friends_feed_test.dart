import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_store.dart';
import 'package:mywatchlist/services/notifications/mal_hub.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/MAL/home/friends_activity_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/no_network.dart';

FriendActivity _row(int i, {String status = 'watching'}) => FriendActivity(
      friend: 'friend$i',
      category: 'anime',
      malId: 100 + i,
      title: 'Title $i',
      link: 'https://myanimelist.net/anime/${100 + i}',
      statusText: 'Watching',
      status: status,
      progress: i,
      total: 12,
      date: DateTime.utc(2026, 11, 25, 10),
    );

class _Friends extends FriendsActivityApi {
  _Friends(this.rows);
  final List<FriendActivity> rows;
  @override
  Future<List<FriendActivity>> load(String username, {void Function(List<FriendActivity> partial)? onProgress}) async =>
      rows;
}

late Directory _dir;

MalNotificationsHub _hub({required bool signedIn, List<FriendActivity> rows = const []}) => MalNotificationsHub(
      malSignedIn: () => signedIn,
      malUsername: () => signedIn ? 'me' : null,
      friends: _Friends(rows),
      store: MalWebStore(directory: () async => _dir, saveDelay: Duration.zero),
    );

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _dir = Directory.systemTemp.createTempSync('mwl_friends');
  });
  tearDown(() => _dir.deleteSync(recursive: true));

  test('new layouts have the Friends activity row right after the news', () {
    final types = MalHomePreferences().sections.map((s) => s.type).toList();
    expect(types.indexOf(SectionType.friendsActivity), types.indexOf(SectionType.news) + 1);
  });

  test('a saved layout gets the row once; removing it afterwards sticks', () {
    final saved = MalHomePreferences.fromJson({
      'sections': [
        HomeSectionPreference(type: SectionType.news).toJson(),
        HomeSectionPreference(type: SectionType.topScore).toJson(),
      ],
    });
    expect(saved.sections.map((s) => s.type), [SectionType.news, SectionType.friendsActivity, SectionType.topScore]);

    saved.sections.removeWhere((s) => s.type == SectionType.friendsActivity);
    final again = MalHomePreferences.fromJson(saved.toJson());
    expect(again.sections.map((s) => s.type), isNot(contains(SectionType.friendsActivity)));
  });

  testWidgets('the row lists the friends updates, at most the section count', (tester) async {
    final hub = _hub(signedIn: true, rows: [for (var i = 1; i <= 5; i++) _row(i)]);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: Scaffold(
        body: HomeFriendsActivitySection(
          section: HomeSectionPreference(type: SectionType.friendsActivity, itemCount: 3),
          hub: hub,
          now: () => DateTime.utc(2026, 11, 25, 12),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Friends activity'), findsOneWidget);
    expect(find.byType(FriendActivityCard), findsNWidgets(3));
    expect(find.text('friend1'), findsOneWidget);
  });

  testWidgets('hidden without a MAL session', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: Scaffold(
        body: HomeFriendsActivitySection(
          section: HomeSectionPreference(type: SectionType.friendsActivity),
          hub: _hub(signedIn: false),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Friends activity'), findsNothing);
  });
}
