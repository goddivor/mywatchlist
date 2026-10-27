import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/MAL/featured_screen.dart';
import 'package:mywatchlist/screens/forum/club_screen.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/screens/forum/forum_topics_screen.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_screen.dart';
import 'package:mywatchlist/utils/deep_links.dart';
import 'package:mywatchlist/utils/web_launcher.dart';

Object? screen(String url) {
  final link = parseMalLink(Uri.parse(url));
  return link == null ? null : DeepLinks.screenForLink(link);
}

void main() {
  test('anime and manga links open the detail screen', () {
    final anime = screen('https://myanimelist.net/anime/1/Cowboy_Bebop') as ContentDetailedScreen;
    expect(anime.id, 1);
    expect(anime.category, 'anime');
    final manga = screen('https://myanimelist.net/manga/2') as ContentDetailedScreen;
    expect(manga.id, 2);
    expect(manga.category, 'manga');
    expect(screen('https://myanimelist.net/anime/5114/Fullmetal/reviews'), isA<ContentDetailedScreen>());
  });

  test('character, people, profile, forum, club and article links', () {
    expect((screen('https://myanimelist.net/character/7/Spike') as CharacterScreen).category, 'character');
    expect((screen('https://myanimelist.net/people/9') as CharacterScreen).category, 'people');
    expect((screen('https://myanimelist.net/profile/Xinil') as UserProfileScreen).username, 'Xinil');
    expect(screen('https://myanimelist.net/forum/?topicid=12'), isA<ForumPostsScreen>());
    expect((screen('https://myanimelist.net/forum/?board=4') as ForumTopicsScreen).boardId, 4);
    expect((screen('https://myanimelist.net/forum/?subboard=3') as ForumTopicsScreen).subBoardId, 3);
    expect(screen('https://myanimelist.net/clubs.php?cid=5'), isA<ClubScreen>());
    expect((screen('https://myanimelist.net/featured/55/x') as FeaturedScreen).id, 55);
  });

  test('genre, studio, magazine, season and search links open a search', () {
    expect(screen('https://myanimelist.net/anime/genre/1/Action'), isA<GeneralSearchScreen>());
    expect(screen('https://myanimelist.net/manga/genre/1/Action'), isA<GeneralSearchScreen>());
    expect(screen('https://myanimelist.net/anime/producer/11/Madhouse'), isA<GeneralSearchScreen>());
    expect(screen('https://myanimelist.net/manga/magazine/83/Shounen_Jump'), isA<GeneralSearchScreen>());
    expect(screen('https://myanimelist.net/anime/season/2024/spring'), isA<GeneralSearchScreen>());
    expect(screen('https://myanimelist.net/anime.php?q=bebop'), isA<GeneralSearchScreen>());
  });

  test('links without a screen return null', () {
    expect(screen('https://myanimelist.net/'), isNull);
    expect(screen('https://myanimelist.net/anime/abc'), isNull);
    expect(screen('https://myanimelist.net/forum/'), isNull);
    expect(screen('https://myanimelist.net/profile/'), isNull);
    expect(screen('https://myanimelist.net/anime/season/2024/nope'), isNull);
    expect(screen('https://example.com/anime/1'), isNull);
  });

  test('register installs the handler, stop removes it', () async {
    DeepLinks.register();
    expect(WebLauncher.internalLinkHandler, isNotNull);
    await DeepLinks.stop();
    expect(WebLauncher.internalLinkHandler, isNull);
  });
}
