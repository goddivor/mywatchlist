import 'package:html/dom.dart';

/// Helpers to read ids, categories and usernames out of MyAnimeList links.
///
/// MAL links come absolute (`https://myanimelist.net/anime/1/Cowboy_Bebop`),
/// root-relative (`/profile/Xinil`) or bare-relative (`anime/1`); all three
/// are handled.
class MalPath {
  MalPath._();

  static const _idCategories = {
    'anime',
    'manga',
    'news',
    'featured',
    'character',
    'people',
    'stacks',
  };

  static List<String> _segments(String? url) {
    if (url == null || url.isEmpty) return const [];
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return const [];
    return uri.pathSegments.where((s) => s.isNotEmpty).toList();
  }

  /// Numeric id of an anime, manga, character, person, news, featured,
  /// stack or forum topic link; null when the link carries none.
  static int? idFromUrl(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final topic = uri.queryParameters['topicid'];
    if (topic != null) return int.tryParse(topic);
    final club = uri.queryParameters['cid'];
    if (club != null) return int.tryParse(club);
    final segments = _segments(url);
    if (segments.length < 2 || !_idCategories.contains(segments[0])) {
      return null;
    }
    return int.tryParse(segments[1]);
  }

  /// Category (`anime`, `manga`, `character`, `people`, …) of a MAL link.
  static String? categoryFromUrl(String? url) {
    final segments = _segments(url);
    if (segments.isEmpty) return null;
    final first = segments.first;
    if (_idCategories.contains(first) || first == 'forum') return first;
    if (first == 'clubs.php') return 'club';
    return null;
  }

  /// Username of a `/profile/<name>` link.
  static String? usernameFromUrl(String? url) {
    final segments = _segments(url);
    if (segments.length >= 2 && segments[0] == 'profile') {
      return Uri.decodeComponent(segments[1]);
    }
    return null;
  }

  /// The element itself when it is an anchor, else its first anchor.
  static Element? anchorOf(Element? element) {
    if (element == null) return null;
    if (element.localName == 'a') return element;
    return element.querySelector('a');
  }

  /// `href` of [element] (or of its first anchor).
  static String? hrefOf(Element? element) =>
      anchorOf(element)?.attributes['href'];

  static int? idOf(Element? element) => idFromUrl(hrefOf(element));

  static String? usernameOf(Element? element) =>
      usernameFromUrl(hrefOf(element));
}
