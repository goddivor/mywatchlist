import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tabs_source.dart';
import 'package:mywatchlist/screens/user_profile/sections/reviews_section.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_view.dart';
import 'package:mywatchlist/services/api/MAL/mal_user_prof.dart';

String _fixture(String name) =>
    File('test/units/mal-profile-extras/fixtures/$name').readAsStringSync();

void main() {
  group('profile pages (saved fixtures)', () {
    test('reviews: title, score, tags, full text, reactions, next page', () {
      final page = parseProfileReviewsPage((_fixture('reviews_p1.html'), 1));
      expect(page.items, hasLength(2));
      expect(page.hasNext, isTrue);
      final first = page.items.first;
      expect(first.media.id, 1190);
      expect(first.media.category, 'manga');
      expect(first.media.title, 'Asatte Dance');
      expect(first.score, 7);
      expect(first.id, 829);
      expect(first.reactions, 81);
      expect(first.date, DateTime(2007, 9, 9));
      expect(first.tags, ['Recommended']);
      expect(first.text, contains('Give it a read.'));
      expect(first.text, isNot(contains('...')));
      expect(first.text, contains('"fun"'));
      expect(first.url, 'https://myanimelist.net/reviews.php?id=829');
      expect(first.toAnimeReview('Xinil').user?.username, 'Xinil');
    });

    test('reviews: no link to the following page on the last one', () {
      expect(parseProfileReviewsPage((_fixture('reviews_p1.html'), 2)).hasNext, isFalse);
    });

    test('recommendations: both titles, reason and date', () {
      final page = parseProfileRecommendationsPage((_fixture('recommendations_p1.html'), 1));
      expect(page.items, hasLength(2));
      expect(page.hasNext, isTrue);
      final first = page.items.first;
      expect(first.from.id, 263);
      expect(first.from.title, 'Hajime no Ippo');
      expect(first.to.id, 1559);
      expect(first.to.category, 'anime');
      expect(first.text, startsWith('Hajime no Ippo and Kenichi'));
      expect(first.date, DateTime(2008, 1, 20));
      expect(first.id, 2829);
    });

    test('stacks: title, author, counts, pictures', () {
      final page = parseProfileStacksPage((_fixture('stacks_p1.html'), 1));
      expect(page.items, hasLength(2));
      expect(page.hasNext, isTrue);
      final first = page.items.first;
      expect(first.url, 'https://myanimelist.net/stacks/88582');
      expect(first.title, 'Best Emotional Anime Worth Watching');
      expect(first.username, 'sehola');
      expect(first.entries, 48);
      expect(first.reStacks, 15);
      expect(first.imageUrls, hasLength(2));
    });

    test('stacks and blog: an empty page is an empty list', () {
      expect(parseProfileStacksPage((_fixture('stacks_empty.html'), 1)).items, isEmpty);
      expect(parseProfileBlogPage(_fixture('blog_empty.html')), isEmpty);
    });

    test('blog: title, date, text with line breaks, comment count', () {
      final posts = parseProfileBlogPage(_fixture('blog.html'));
      expect(posts, hasLength(2));
      expect(posts.first.title, 'Pilot 2, Part 1 - Why We Watch Anime');
      expect(posts.first.dateText, 'May 6th, 2008');
      expect(posts.first.id, 9876);
      expect(posts.first.comments, 4);
      expect(posts.first.text, contains('\n'));
      expect(posts.first.text, startsWith('Koreth and I'));
    });

    test('a challenge page is an error, not an empty list', () {
      expect(() => parseProfileReviewsPage((_fixture('challenge.html'), 1)),
          throwsFormatException);
      expect(() => parseProfileBlogPage(_fixture('challenge.html')), throwsFormatException);
    });
  });

  group('source', () {
    setUp(() {
      ProfileTabsSource.reset();
      ProfileTabsSource.parseInline = true;
    });
    tearDown(ProfileTabsSource.reset);

    test('asks the right page and page number', () async {
      final urls = <Uri>[];
      ProfileTabsSource.fetchPage = (url, timeout) async {
        urls.add(url);
        return _fixture('reviews_p1.html');
      };
      await ProfileTabsSource.reviews('Xin il', page: 2);
      expect(urls.single.toString(), 'https://myanimelist.net/profile/Xin%20il/reviews?p=2');
    });
  });

  group('account fields', () {
    test('time_zone and is_supporter are read, the old key still works', () {
      final prof = MalUserProf.fromJson({
        'id': 1,
        'name': 'me',
        'time_zone': 'Africa/Lome',
        'is_supporter': true,
      });
      expect(prof.timezone, 'Africa/Lome');
      expect(prof.isSupporter, isTrue);
      expect(MalUserProf.fromJson({'timezone': 'UTC'}).timezone, 'UTC');
      expect(MalUserProf.fromJson({}).isSupporter, isFalse);
    });

    test('they reach the profile data and survive the cache', () {
      final data = UserProfileRepository.merge(
        'me',
        mal: MalUserProf.fromJson({'id': 1, 'name': 'me', 'time_zone': 'Africa/Lome', 'is_supporter': true}),
      );
      final back = UserProfileData.fromJson(data.toJson());
      expect(back.timezone, 'Africa/Lome');
      expect(back.isSupporter, isTrue);
      expect(UserProfileRepository.merge('x').isSupporter, isFalse);
    });

    test('the new tabs show on every profile', () {
      for (final self in [true, false]) {
        final tabs = profileTabsFor(isSelf: self);
        expect(tabs, containsAll([
          UserProfileTab.reviews,
          UserProfileTab.recommendations,
          UserProfileTab.stacks,
          UserProfileTab.blog,
        ]));
      }
    });
  });
}
