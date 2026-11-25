import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mwl_commons/mwl_commons.dart' show HtmlParsers;
import 'package:mywatchlist/constants/constants.dart' show displayTimeAgo;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_tiles.dart' show splitArticleByLine;
import 'package:mywatchlist/services/api/MAL/scrapper/title_clubs.dart';
import 'package:mywatchlist/widgets/common/spoiler_text.dart';

// The title clubs page: MAL's layout table holds the sidebar ("Popularity: #17 Members: …")
// and the club blocks (`div.borderClass` with a `<small>` count).
const _titleClubs = '''
<table><tr>
<td class="borderClass"><div>Popularity: #17</div><div>Members: 2,749,092</div></td>
<td><h2 id="related_clubs">Related Clubs</h2>
<div class="borderClass"><a href="/clubs.php?cid=20081">Recommendation Club</a> <small>34685 members</small></div>
<div class="borderClass"><a href="/clubs.php?cid=18051">One Piece</a> <small>1 member</small></div>
</td></tr></table>''';

// A profile's clubs page: the site menu links forum topics (`topicid=` holds `cid=`).
const _userClubs = '''
<ul><li><a href="https://myanimelist.net/forum?topicid=2245806&amp;_location=mal_h_m">2026 Challenge</a></li>
<li><a href="https://myanimelist.net/forum?topicid=2248536&amp;_location=mal_h_m">2026 Challenge</a></li>
<li><a href="https://myanimelist.net/clubs.php">Clubs</a></li></ul>
<div id="content"><ol><li><a href="/clubs.php?cid=41">Naruto Club</a></li>
<li><a href="/clubs.php?cid=8766">Naruto Fan Club</a></li></ol></div>''';

void main() {
  setUpAll(() => S.load(const Locale('en')));

  group('title clubs (#365)', () {
    test('each club reads its own member count, not the sidebar', () {
      final clubs = TitleClubs.parse(_titleClubs);
      expect(clubs.map((c) => c.name), ['Recommendation Club', 'One Piece']);
      expect(clubs.map((c) => c.members), ['34685', '1']);
    });

    test('the label is pluralised', () {
      expect(S.current.Fc_Members_Count(1), '1 member');
      expect(S.current.Fc_Members_Count(34685), '34685 members');
    });
  });

  test('profile clubs keep the clubs only, once each (#363)', () {
    final clubs = HtmlParsers.parseUserClubs(html_parser.parse(_userClubs))['clubs'] as List;
    expect(clubs.map((c) => c['name']), ['Naruto Club', 'Naruto Fan Club']);
    expect(clubs.map((c) => c['id']), [41, 8766]);
  });

  group('spoilers (#368)', () {
    test('splitSpoilers separates the blocks and drops the markers', () {
      final parts = splitSpoilers('Devil fruit:\n[Spoiler]Hito Hito no Mi, Model: Nika[/Spoiler]\n'
          'Bounty: [spoiler]3,000,000,000[/spoiler]');
      expect(parts, [
        (text: 'Devil fruit:', spoiler: false),
        (text: 'Hito Hito no Mi, Model: Nika', spoiler: true),
        (text: 'Bounty:', spoiler: false),
        (text: '3,000,000,000', spoiler: true),
      ]);
      expect(splitSpoilers('No spoiler here'), [(text: 'No spoiler here', spoiler: false)]);
    });

    testWidgets('a spoiler stays hidden until tapped', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SpoilerText('Luffy. [Spoiler]Gear 5[/Spoiler]')),
      ));
      expect(find.text('Luffy.'), findsOneWidget);
      expect(find.text('Gear 5'), findsNothing);
      expect(find.textContaining('[Spoiler]'), findsNothing);
      await tester.tap(find.text('Show Spoiler'));
      await tester.pump();
      expect(find.text('Gear 5'), findsOneWidget);
      expect(find.text('Hide Spoiler'), findsOneWidget);
    });
  });

  group('wording (#369)', () {
    test('a year ago, single spaces', () {
      final now = DateTime.now();
      expect(displayTimeAgo(now.subtract(const Duration(days: 400))), 'a year ago');
      expect(displayTimeAgo(now.subtract(const Duration(minutes: 19))), '19 minutes ago');
      expect(displayTimeAgo(now.subtract(const Duration(hours: 5))), '5 hours ago');
      expect(displayTimeAgo(now.subtract(const Duration(days: 3))), '3 days ago');
    });

    test('graph count is pluralised', () {
      expect(S.current.Rg_Titles(1), '1 title');
      expect(S.current.Rg_Titles(4), '4 titles');
    });

    test('article by-line splits the author and pluralises the comments', () {
      expect(splitArticleByLine('Nioxys 0 Comment'), (author: 'Nioxys', comments: 0));
      expect(splitArticleByLine('Syureria  27 Comments'), (author: 'Syureria', comments: 27));
      expect(splitArticleByLine('Luna'), (author: 'Luna', comments: null));
      expect(S.current.Dp_News_Comments(0), '0 comments');
      expect(S.current.Dp_News_Comments(1), '1 comment');
    });
  });
}
