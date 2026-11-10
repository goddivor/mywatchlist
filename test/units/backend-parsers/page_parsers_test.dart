import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:mwl_api/client/http_connect.dart';
import 'package:mwl_api/handlers/handler_core.dart';
import 'package:mwl_commons/mwl_commons.dart';

import '../../helpers/html_fixtures.dart';

/// Saved MAL / LiveChart pages (trimmed copies of real pages fetched on
/// 2026-10-27), parsed offline.
Document fixture(String name) =>
    htmlFixture(File('mwl-api/test/fixtures/$name').readAsStringSync());

/// Round-trips [value] through the backend's JSON conversion and back into
/// the model with [fromJson], as the app client receives it.
T roundTrip<T>(Object value, T Function(Map<String, dynamic>) fromJson) =>
    fromJson(HttpConnect.toJsonReady(value) as Map<String, dynamic>);

void main() {
  group('content characters page', () {
    test('anime: characters with roles, favorites and voice actors', () {
      final page =
          PageParsers.parseCharacterAllPage(fixture('anime_characters.html'), 'anime');
      expect(page.characters, hasLength(3));
      final jet = page.characters.first;
      expect(jet.id, 3);
      expect(jet.name, 'Black, Jet');
      expect(jet.role, 'Main');
      expect(jet.favorites, 2319);
      expect(jet.image?.large, contains('/r/84x124/images/characters/11/253723.jpg'));
      expect(jet.voiceActors.first.id, 357);
      expect(jet.voiceActors.first.name, 'Ishizuka, Unshou');
      expect(jet.voiceActors.first.language, 'Japanese');
      expect(jet.voiceActors.map((e) => e.language), contains('English'));
    });

    test('anime: staff list follows the Staff header', () {
      final page =
          PageParsers.parseCharacterAllPage(fixture('anime_characters.html'), 'anime');
      expect(page.staff, hasLength(3));
      expect(page.staff.first.id, 77978);
      expect(page.staff.first.name, 'Ikeguchi, Kazuhiko');
      expect(page.staff.first.role, 'Producer');
    });

    test('manga: characters without voice actors nor staff', () {
      final page =
          PageParsers.parseCharacterAllPage(fixture('manga_characters.html'), 'manga');
      expect(page.characters, hasLength(2));
      expect(page.characters.first.id, 423);
      expect(page.characters.first.name, 'Casca');
      expect(page.characters.first.voiceActors, isEmpty);
      expect(page.staff, isEmpty);
    });

    test('survives the JSON round trip', () {
      final page =
          PageParsers.parseCharacterAllPage(fixture('anime_characters.html'), 'anime');
      final back = roundTrip(page, ContentCharactersHtml.fromJson);
      expect(back.characters.first.voiceActors.first.name, 'Ishizuka, Unshou');
      expect(back.staff.last.name, page.staff.last.name);
    });

    test('a page without the container gives an empty result', () {
      final page = PageParsers.parseCharacterAllPage(
          htmlFixture('<p>maintenance</p>'), 'anime');
      expect(page.characters, isEmpty);
      expect(page.staff, isEmpty);
    });
  });

  group('top characters and people', () {
    test('characters ranking with animeography and mangaography', () {
      final list = PageParsers.parseCharacterPeopleHome(
          fixture('top_characters.html'), 'character');
      expect(list, hasLength(3));
      final lelouch = list.first;
      expect(lelouch.id, 417);
      expect(lelouch.rank, 1);
      expect(lelouch.name, 'Lamperouge, Lelouch');
      expect(lelouch.otherName, 'ルルーシュ・ランペルージ');
      expect(lelouch.favorites, 181686);
      expect(lelouch.animeography.first.id, 1575);
      expect(lelouch.animeography.first.category, 'anime');
      expect(lelouch.mangaography.first.id, 1528);
      expect(lelouch.birthday, isNull);
    });

    test('people ranking with birthday', () {
      final list =
          PageParsers.parseCharacterPeopleHome(fixture('top_people.html'), 'people');
      expect(list, hasLength(3));
      expect(list.first.id, 118);
      expect(list.first.name, 'Kamiya, Hiroshi');
      expect(list.first.otherName, '神谷 浩史');
      expect(list.first.birthday, 'Jan 28, 1975');
      expect(list.first.favorites, 108692);
      expect(list.first.animeography, isEmpty);
    });
  });

  group('pictures pages', () {
    test('character pictures are full-size image links', () {
      final pics = PageParsers.parsePicturesPage(fixture('character_pics.html'));
      expect(pics, hasLength(3));
      expect(pics.first,
          'https://cdn.myanimelist.net/images/characters/9/55741.jpg');
    });

    test('people pictures', () {
      final pics = PageParsers.parsePicturesPage(fixture('people_pics.html'));
      expect(pics, isNotEmpty);
      expect(pics.every((e) => e.contains('/images/voiceactors/')), isTrue);
    });
  });

  group('magazines and studios', () {
    test('magazines come from the magazine block only', () {
      final mags = PageParsers.parseMagazines(fixture('manga_php.html'), 'manga');
      expect(mags[1439], 'KakaoPage');
      expect(mags[1209], 'Shounen Jump+');
      expect(mags.keys.first, 1439);
    });

    test('studios come from the producer block only', () {
      final studios = PageParsers.parseMagazines(fixture('anime_php.html'), 'anime');
      expect(studios[18], 'Toei Animation');
      expect(studios[14], 'Sunrise');
    });

    test('JSON keys become strings for the wire', () {
      final studios = PageParsers.parseMagazines(fixture('anime_php.html'), 'anime');
      final json = HttpConnect.toJsonReady(studios) as Map<String, dynamic>;
      expect(json['18'], 'Toei Animation');
    });
  });

  group('reviews', () {
    test('latest reviews carry the reviewed content', () {
      final reviews = PageParsers.getReviews(fixture('reviews_all.html'));
      expect(reviews, hasLength(2));
      final first = reviews.first;
      expect(first.id, 624268);
      expect(first.username, 'whyyyyyyyyyy');
      expect(first.timeAdded, 'Oct 27, 2026');
      expect(first.overallRating, '7');
      expect(first.tags, ['Mixed Feelings']);
      expect(first.relatedNode?.id, 61839);
      expect(first.relatedNode?.category, 'anime');
      expect(first.relatedNode?.title, 'Aishiteru Game wo Owarasetai');
      expect(first.reactions.keys, contains('Nice'));
    });

    test('review text is whole, unescaped and keeps paragraphs', () {
      final text = PageParsers.getReviews(fixture('reviews_all.html')).first.reviewText!;
      expect(text, contains("you're stuck"));
      expect(text, contains('the worst mistake'));
      expect(text, contains('\n\n'));
      expect(text, isNot(contains('...')));
    });

    test('content reviews decode named entities', () {
      final reviews = PageParsers.getReviews(fixture('reviews_anime.html'));
      expect(reviews, hasLength(2));
      expect(reviews.first.username, 'TheLlama');
      expect(reviews.first.overallRating, '10');
      expect(reviews.first.reviewText, contains('Ed’s a girl'));
    });

    test('survives the JSON round trip', () {
      final review = PageParsers.getReviews(fixture('reviews_all.html')).first;
      final back = roundTrip(review, ReviewHtml.fromJson);
      expect(back.reactions, review.reactions);
      expect(back.relatedNode?.id, 61839);
    });
  });

  group('user about', () {
    test('classic profile', () {
      final about = PageParsers.parseUserAboutPage(fixture('profile_about.html'));
      expect(about.modern, isFalse);
      expect(about.about, startsWith('Founder and creator of MyAnimeList.'));
    });

    test('modern profile', () {
      final about = PageParsers.parseUserAboutPage(fixture('profile_modern.html'));
      expect(about.modern, isTrue);
      expect(about.about, contains('<b>there</b>'));
    });

    test('no about block', () {
      final about = PageParsers.parseUserAboutPage(htmlFixture('<div></div>'));
      expect(about.about, isNull);
    });
  });

  group('clubs', () {
    test('club page: title, members, pictures, topics, comments', () {
      final club = PageParsers.parseClubPage(fixture('club.html'))!;
      expect(club.title, 'Cowboy Bebop');
      expect(club.information, isNotEmpty);
      expect(club.members.first.username, 'spiegel21221');
      expect(club.pictures.first.medium,
          'https://cdn.myanimelist.net/images/clubs/5/837_thumb.jpg');
      expect(club.forumTopics.first.id, 6129);
      expect(club.forumTopics.first.title, 'Favorite Track');
      expect(club.forumTopics.first.replies, 54);
      expect(club.comments.first.id, 16308002);
      expect(club.comments.first.by?.username, 'Abdur-Rauf');
      expect(club.comments.first.longAgo, 'Oct 8, 8:34 AM');
      expect(club.comments.first.content, 'damn.... what did i stumble upon....');
    });

    test('club details: stats, staff and relations', () {
      final details = PageParsers.parseClubPage(fixture('club.html'))!.details;
      expect(details.members, 1402);
      expect(details.pictures, 25);
      expect(details.category, 'Anime');
      expect(details.created, 'Mar 29, 2007');
      expect(details.picture?.medium,
          'https://cdn.myanimelist.net/images/clubs/16/222057.jpg');
      expect(details.staff.map((e) => e.user.username), ['Xinil', 'daya']);
      expect(details.staff.first.position, 'President');
      expect(details.animeRelations.map((e) => e.id), [1, 5, 4037]);
      expect(details.mangaRelations.map((e) => e.id), [173, 174]);
      expect(details.characterRelations, isNotEmpty);
    });

    test('a page that is not a club gives null', () {
      expect(PageParsers.parseClubPage(htmlFixture('<p>nothing</p>')), isNull);
    });

    test('see all: members', () {
      final list =
          PageParsers.parseClubPageViewAll(fixture('club_members.html'), 'members');
      expect(list, hasLength(3));
      expect((list.first as MalUserRef).username, '-alquimista-');
    });

    test('see all: forum skips the header row', () {
      final list =
          PageParsers.parseClubPageViewAll(fixture('club_forum.html'), 'forum');
      expect(list, hasLength(2));
      final topic = list.first as ForumTopicHtml;
      expect(topic.id, 6129);
      expect(topic.createdBy, 'daya');
      expect(topic.createdTime, 'Oct 16, 2007');
      expect(topic.lastPostBy, 'Itzmespooky');
      expect(topic.lastPostTime, 'Jun 12, 2023 10:36 PM');
    });

    test('see all: comments newest first', () {
      final list = PageParsers.parseClubPageViewAll(
          fixture('club_comments.html'), 'comments');
      expect(list, hasLength(2));
      final ids = list.cast<ClubCommentHtml>().map((e) => e.id).toList();
      expect(ids, [16308002, 16133069]);
    });

    test('club page survives the JSON round trip', () {
      final club = PageParsers.parseClubPage(fixture('club.html'))!;
      final back = roundTrip(club, ClubPageHtml.fromJson);
      expect(back.details.staff.first.user.username, 'Xinil');
      expect(back.forumTopics.first.id, 6129);
    });
  });

  group('all search', () {
    test('groups results by category with ids from data attributes', () {
      final result = PageParsers.allSearchResultFromHtml(fixture('search_all.html'));
      expect(result.results.keys, containsAll(SearchAllResult.categories));
      final naruto = result.of('anime').first;
      expect(naruto.id, 20);
      expect(naruto.title, 'Naruto');
      expect(naruto.mediaType, 'TV');
      expect(naruto.numEpisodes, 220);
      expect(naruto.mean, 8.03);
      expect(naruto.numListUsers, 3173615);
      expect(naruto.image?.medium,
          'https://cdn.myanimelist.net/images/anime/1141/142503.jpg');
      expect(result.of('character').first.id, 17);
      expect(result.of('person').first.id, 33563);
      expect(result.of('forum').first.id, 2074262);
      expect(result.of('club').first.id, 1503);
      expect(result.of('news').first.id, 74809610);
      expect(result.of('featured').first.id, 1751);
    });

    test('other categories keep the text under the title', () {
      final result = PageParsers.allSearchResultFromHtml(fixture('search_all.html'));
      expect(result.of('character').first.additional, contains('Favorites'));
      expect(result.of('club').first.additional, contains('28 Members'));
    });

    test('an empty page still has every category', () {
      final result = PageParsers.allSearchResultFromHtml(htmlFixture('<p></p>'));
      for (final c in SearchAllResult.categories) {
        expect(result.of(c), isEmpty);
      }
      expect(SearchAllResult.fromJson(null).results.keys,
          SearchAllResult.categories);
    });
  });

  group('LiveChart schedule', () {
    test('episodes with timestamp, number and MAL id', () {
      final list = PageParsers.parseLiveChartSchedule(fixture('livechart.html'));
      expect(list, hasLength(3));
      final first = list.first;
      expect(first.timestamp, 1793371200);
      expect(first.episode, 5);
      expect(first.title, 'Kusuriya no Hitorigoto 3rd Season Cour 1');
      expect(first.malId, 61987);
      expect(first.relatedLinks['anilist'], 'https://anilist.co/anime/195516');
      expect(first.airingAt.isUtc, isTrue);
    });

    test('survives the JSON round trip', () {
      final first = PageParsers.parseLiveChartSchedule(fixture('livechart.html')).first;
      final back = roundTrip(first, LiveChartEpisode.fromJson);
      expect(back.malId, 61987);
      expect(back.relatedLinks, first.relatedLinks);
    });
  });

  group('MalPath', () {
    test('ids, categories and usernames from absolute and relative links', () {
      expect(MalPath.idFromUrl('https://myanimelist.net/anime/1/Cowboy_Bebop'), 1);
      expect(MalPath.idFromUrl('character/19119'), 19119);
      expect(MalPath.idFromUrl('/forum/?topicid=6129'), 6129);
      expect(MalPath.idFromUrl('https://myanimelist.net/clubs.php?cid=1503'), 1503);
      expect(MalPath.idFromUrl('/profile/Xinil'), isNull);
      expect(MalPath.categoryFromUrl('https://myanimelist.net/people/118/x'), 'people');
      expect(MalPath.usernameFromUrl('/profile/Xinil'), 'Xinil');
    });
  });

  group('backend helpers', () {
    test('HTML is parsed into JSON-ready data', () {
      final json = HttpConnect.parseHtml(
        File('mwl-api/test/fixtures/livechart.html').readAsStringSync(),
        PageParsers.parseLiveChartSchedule,
      );
      expect(json, isA<List>());
      expect((json as List).first, isA<Map<String, dynamic>>());
    });

    test('current LiveChart season switches on the 28th', () {
      expect(currentSeason(DateTime(2026, 10, 27)), (season: 'fall', year: 2026));
      expect(currentSeason(DateTime(2026, 12, 28)), (season: 'winter', year: 2027));
      expect(currentSeason(DateTime(2026, 3, 27)), (season: 'winter', year: 2026));
      expect(currentSeason(DateTime(2026, 3, 28)), (season: 'spring', year: 2026));
      expect(currentSeason(DateTime(2026, 6, 28)), (season: 'summer', year: 2026));
      expect(currentSeason(DateTime(2026, 9, 28)), (season: 'fall', year: 2026));
    });
  });
}
