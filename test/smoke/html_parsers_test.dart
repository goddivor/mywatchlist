import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart';

import '../helpers/html_fixtures.dart';

void main() {
  group('HtmlParsers image helpers', () {
    test('stripImageResize removes the resize segment and the query', () {
      expect(
        HtmlParsers.stripImageResize(
          'https://cdn.myanimelist.net/r/100x140/images/anime/1/1.jpg?s=abc',
        ),
        'https://cdn.myanimelist.net/images/anime/1/1.jpg',
      );
    });

    test('getImageUrlByQuality picks the srcset entry of that quality', () {
      final doc = htmlFixture(
        '<img data-srcset="https://x/a.jpg 1x, https://x/a@2x.jpg 2x">',
      );
      final img = doc.querySelector('img');
      expect(HtmlParsers.getImageUrlByQuality(img, '@2x'), 'https://x/a@2x.jpg');
      expect(HtmlParsers.getImageUrlByQuality(null, '@2x'), '');
    });

    test('getOriginalImageQuality prefers data-src and strips resizing', () {
      final doc = htmlFixture(
        '<img src="placeholder.gif" '
        'data-src="https://cdn.myanimelist.net/r/50x70/images/a.jpg?s=1">',
      );
      expect(
        HtmlParsers.getOriginalImageQuality(doc.querySelector('img'), ''),
        'https://cdn.myanimelist.net/images/a.jpg',
      );
    });
  });

  group('HtmlParsers.parseUserFriends', () {
    test('reads every friend card of the page', () {
      final doc = htmlFixture('''
<html><body><div class="friend">
  <div class="boxlist">
    <a href="https://myanimelist.net/profile/alice"><img src="https://x/alice.jpg"></a>
    <div class="title"><a>alice</a></div>
    <div class="data"><span class="fn-grey2">Now</span><span class="fn-grey2">Friends since Jan 1, 2020</span></div>
  </div>
  <div class="boxlist">
    <a href="https://myanimelist.net/profile/bob"></a>
    <div class="title"><a> bob </a></div>
  </div>
</div></body></html>
''');
      final result = HtmlParsers.parseUserFriends(doc);

      expect(result.friends, hasLength(2));
      final alice = result.friends.first;
      expect(alice.user.username, 'alice');
      expect(alice.user.url, 'https://myanimelist.net/profile/alice');
      expect(alice.user.imageUrl, 'https://x/alice.jpg');
      expect(alice.lastOnline, 'Now');
      expect(alice.friendSince, 'Friends since Jan 1, 2020');

      final bob = result.friends.last;
      expect(bob.user.username, 'bob');
      expect(bob.user.imageUrl, isEmpty);
      expect(bob.lastOnline, isEmpty);
    });

    test('returns an empty list for a page without friends or no page', () {
      expect(
        HtmlParsers.parseUserFriends(htmlFixture('<p>none</p>')).friends,
        isEmpty,
      );
      expect(HtmlParsers.parseUserFriends(null).friends, isEmpty);
    });
  });
}
