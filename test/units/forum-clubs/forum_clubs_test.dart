import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/widgets/forum/bbcode_widget.dart';
import 'package:mywatchlist/widgets/forum/club_tiles.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/forum/forum_paged_list.dart';

import '../../helpers/pump_app.dart';

Future<void> _pumpList(
  WidgetTester tester,
  Future<List<int>> Function(int offset) fetch, {
  int pageSize = 2,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForumPagedList<int>(
            fetch: fetch,
            pageSize: pageSize,
            emptyTitle: 'Nothing here',
            itemBuilder: (_, item) => SizedBox(height: 60, child: Text('item $item')),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => S.load(const Locale('en')));

  group('ForumUrls', () {
    test('builds the MAL pages the screens open', () {
      expect(ForumUrls.reply(7), 'https://myanimelist.net/forum/?action=message&topic_id=7');
      expect(ForumUrls.joinClub(3), 'https://myanimelist.net/clubs.php?action=join&id=3');
      expect(ForumUrls.board(boardId: 1), 'https://myanimelist.net/forum/?board=1');
      expect(ForumUrls.board(), 'https://myanimelist.net/forum/');
      expect(
        ForumUrls.report('profile', {'id': '9'}),
        'https://myanimelist.net/modules.php?go=report&type=profile&id=9',
      );
    });
  });

  test('a club topic holds one more post than MAL counts replies', () {
    expect(clubTopicPostCount('41'), 42);
    expect(clubTopicPostCount(null), 0);
    expect(clubTopicPostCount('none'), 0);
  });

  test('BBCode transform is deterministic, so the cache can serve it', () {
    const body = "<div> <spoiler name='x'>hi</spoiler> </div>";
    const widget = BbcodeWidget(body: body);
    expect(widget.applyTransform(body), widget.applyTransform(body));
  });

  group('ForumPagedList', () {
    testWidgets('shows the first page, then asks for the next one at the end', (tester) async {
      final offsets = <int>[];
      await _pumpList(tester, (offset) async {
        offsets.add(offset);
        return offset == 0 ? [1, 2] : [3];
      });
      await tester.pumpAndSettle();
      expect(find.text('item 1'), findsOneWidget);
      expect(find.text('item 2'), findsOneWidget);
      // The short list does not scroll: the widget asks for the next page itself.
      expect(offsets, [0, 2]);
      expect(find.text('item 3'), findsOneWidget);
      expect(find.text('That\'s everything'), findsOneWidget);
    });

    testWidgets('shows the error state and retries', (tester) async {
      var calls = 0;
      await _pumpList(tester, (offset) async {
        calls++;
        if (calls == 1) throw StateError('unreachable');
        return [1];
      }, pageSize: 5);
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load this page"), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('item 1'), findsOneWidget);
      expect(find.text("Couldn't load this page"), findsNothing);
    });

    testWidgets('shows the empty state when the first page is empty', (tester) async {
      await _pumpList(tester, (_) async => <int>[]);
      await tester.pumpAndSettle();
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('tiles', () {
    testWidgets('a member tile shows the name and the staff position', (tester) async {
      await pumpInApp(
        tester,
        ClubMemberTile(member: ClubMember(username: 'Xinil'), position: 'President'),
      );
      expect(find.text('Xinil'), findsOneWidget);
      expect(find.text('President'), findsOneWidget);
    });

    testWidgets('an avatar without picture shows the initials in a clip, not a box', (tester) async {
      await pumpInApp(tester, const ForumAvatar(username: 'abc', tappable: false));
      expect(find.text('AB'), findsOneWidget);
      expect(find.byType(ClipOval), findsOneWidget);
    });
  });
}
