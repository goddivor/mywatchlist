import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/search/search_service.dart';

/// The "user found" shortcut of the search (gap report E3) asks MyAnimeList's
/// profile page instead of Jikan's `users/{name}` (Tenrai has no user
/// endpoints).
void main() {
  group('canonical profile name', () {
    const head = '<html><head>'
        '<meta property="og:title" content=" Xinil&#039;s Profile - MyAnimeList.net ">'
        '<meta property="og:url" content="https://myanimelist.net/profile/Xinil">'
        '</head><body></body></html>';

    test("MAL's casing wins over the typed one", () {
      expect(canonicalProfileName(head, 'xinil'), 'Xinil');
    });

    test('the typed name stays when the page has no og:url', () {
      expect(canonicalProfileName('<html></html>', 'xinil'), 'xinil');
    });

    test('an og:url of another user is ignored', () {
      expect(canonicalProfileName(head, 'someone'), 'someone');
    });
  });
}
