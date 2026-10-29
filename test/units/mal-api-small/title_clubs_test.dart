import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/title_clubs.dart';

const _page = '''
<table>
<tr><td><a href="/clubs.php?cid=12"><img data-src="https://cdn/12.jpg"></a></td>
<td><a href="https://myanimelist.net/clubs.php?cid=12">Fans of X</a> 1,234 members</td></tr>
<tr><td><a href="/clubs.php?cid=12">Fans of X</a></td></tr>
<tr><td><a href="/clubs.php?cid=40">Other club</a> 5 members</td></tr>
<tr><td><a href="/clubs.php?cid=7">  </a></td></tr>
</table>''';

void main() {
  test('parse lists each club once with name, image and members', () {
    final clubs = TitleClubs.parse(_page);
    expect(clubs.map((c) => c.id), [12, 40]);
    expect(clubs[0].name, 'Fans of X');
    expect(clubs[0].imgUrl, 'https://cdn/12.jpg');
    expect(clubs[0].members, '1,234');
    expect(clubs[1].imgUrl, isNull);
  });

  test('url targets the right category', () {
    expect(TitleClubs.url(5).path, '/anime/5/_/clubs');
    expect(TitleClubs.url(5, category: 'manga').path, '/manga/5/_/clubs');
  });

  test('fetch parses a 200 and throws otherwise', () async {
    final ok = await TitleClubs.fetch(1, get: (_) async => (status: 200, body: _page));
    expect(ok, hasLength(2));
    expect(TitleClubs.fetch(1, get: (_) async => (status: 503, body: '')), throwsException);
  });
}
