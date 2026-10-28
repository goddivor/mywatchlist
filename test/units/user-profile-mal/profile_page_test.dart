import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_profile_page.dart';
import 'package:mywatchlist/widgets/user/profile/profile_header.dart';

/// Real MAL profile pages, saved with a desktop User-Agent (October 2026).
String fixture(String name) =>
    File('test/units/user-profile-mal/fixtures/$name').readAsStringSync();

void main() {
  group('parseMalProfilePage', () {
    test('reads the owner\'s profile (modern about-me, birthday without a year)', () {
      final page = parseMalProfilePage(fixture('profile_goddivor_2026-10.html'))!;
      expect(page['mal_id'], 14110547);
      expect(page['username'], 'goddivor');
      expect((page['images'] as Map)['jpg']['image_url'], contains('userimages/839ea415'));
      expect(page['last_online'], 'Now');
      expect(page['gender'], 'Male');
      expect(page['birthday'], '--01-01');
      expect(page['location'], 'Animeland');
      expect(page['joined'], '2021-11-26');
      expect(page['about_modern'], isTrue);
      expect(page['about'], isNotEmpty);

      final data = UserProfileRepository.merge('goddivor', jikan: page);
      expect(data.id, 14110547);
      expect(data.anime.totalEntries, 2316);
      expect(data.anime.current, 202);
      expect(data.anime.completed, 885);
      expect(data.anime.onHold, 202);
      expect(data.anime.dropped, 3);
      expect(data.anime.planned, 1024);
      expect(data.anime.progress, 14517);
      expect(data.anime.days, 241.2);
      expect(data.anime.meanScore, 8.9);
      expect(data.manga.totalEntries, 86);
      expect(data.manga.current, 33);
      expect(data.manga.planned, 50);
      expect(data.manga.progress, 1875);
      expect(data.manga.volumes, 22);

      expect(data.favorites.anime.map((f) => f.id), [52991, 4224, isA<int>()]);
      expect(data.favorites.anime.first.title, 'Sousou no Frieren');
      expect(data.favorites.anime.first.imageUrl, contains('/images/anime/1015/138006'));
      expect(data.favorites.manga, isEmpty);
      expect(data.favorites.characters, hasLength(10));
      expect(data.favorites.characters.first.title, 'Yamada, Anna');
      expect(data.favorites.people.first.id, 1901);
      expect(data.favorites.people.first.title, 'Toriyama, Akira');
      expect(data.lastOnline, 'Now');
      expect(data.aboutModern, isTrue);
    });

    test('reads another profile (classic about-me, full birthday, manga favorites)', () {
      final page = parseMalProfilePage(fixture('profile_xinil_2026-10.html'))!;
      expect(page['mal_id'], 1);
      expect(page['username'], 'Xinil');
      expect(page['birthday'], '1985-03-04');
      expect(page['location'], 'California');
      expect(page['joined'], '2004-11-05');
      expect(page['last_online'], 'Jul 3, 2:03 PM');
      expect(page['about_modern'], isFalse);
      expect(page['about'], contains('Founder and creator of MyAnimeList'));

      final data = UserProfileRepository.merge('Xinil', jikan: page);
      expect(data.anime.days, 142.3);
      expect(data.anime.meanScore, 7.37);
      expect(data.anime.totalEntries, greaterThan(0));
      expect(data.favorites.manga, isNotEmpty);
      expect(data.favorites.people, isNotEmpty);
      // The parsed profile survives the disk cache.
      final back = UserProfileData.fromJson(data.toJson());
      expect(back.about, data.about);
      expect(back.lastOnline, data.lastOnline);
    });

    test('a page without the profile column is not a profile', () {
      expect(parseMalProfilePage('<html><body>Just a moment...</body></html>'), isNull);
    });
  });

  test('page dates become ISO days', () {
    expect(malProfileDate('Nov 26, 2021'), '2021-11-26');
    expect(malProfileDate('Jan 1'), '--01-01');
    expect(malProfileDate(''), isNull);
    expect(malProfileDate('sometime'), isNull);
    expect(formatProfileDate('--01-31'), 'Jan 31');
    expect(formatProfileDate('--01-31', withDay: false), isNull);
    expect(formatProfileDate('2021-11-26', withDay: false), 'Nov 2021');
  });
}
