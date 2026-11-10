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

    test('reads the JSON of the Vue friends page (#vm-friendlist)', () {
      final doc = htmlFixture('''
<html><body><div id="content"><div id="vm-friendlist" data-user-id="42"
  data-initial-data="{&quot;items&quot;:[{&quot;id&quot;:7,&quot;name&quot;:&quot;alice&quot;,&quot;has_pic&quot;:true,&quot;profile_url&quot;:&quot;\\/profile\\/alice&quot;,&quot;pic_url&quot;:&quot;https:\\/\\/x\\/a.jpg&quot;,&quot;time_added_str&quot;:&quot;Apr 6, 2026 3:52 PM&quot;,&quot;time_added&quot;:1775515921,&quot;last_activity&quot;:1793148915},{&quot;id&quot;:8,&quot;name&quot;:&quot;bob&quot;,&quot;has_pic&quot;:false,&quot;profile_url&quot;:&quot;\\/profile\\/bob&quot;,&quot;pic_url&quot;:&quot;https:\\/\\/x\\/kaomoji.png&quot;}],&quot;has_more&quot;:true}"></div></div></body></html>
''');
      final result = HtmlParsers.parseUserFriends(doc);

      expect(result.userId, 42);
      expect(result.hasMore, isTrue);
      expect(result.friends.map((f) => f.user.username), ['alice', 'bob']);
      final alice = result.friends.first;
      expect(alice.user.url, 'https://myanimelist.net/profile/alice');
      expect(alice.user.imageUrl, 'https://x/a.jpg');
      expect(alice.friendSince, 'Apr 6, 2026 3:52 PM');
      expect(alice.id, 7);
      expect(alice.timeAdded, 1775515921);
      expect(alice.lastActivity, 1793148915);
      expect(result.friends.last.user.imageUrl, isEmpty);
      expect(UserFriendsList.fromJson(result.toJson()).friends.first.lastActivity, 1793148915);
    });
  });
}
