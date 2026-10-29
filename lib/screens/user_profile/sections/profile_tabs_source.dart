import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:mwl_commons/mwl_commons.dart' show UserFriendsList;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart' show InterestStack;
import 'package:mywatchlist/services/api/MAL/scrapper/html_parsers.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_friends.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_history.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';

/// Where the Friends, Clubs and History tabs of a profile get their data.
///
/// MyAnimeList's own profile pages answer where Jikan does not (it is unreachable on some
/// networks), so each tab reads the MAL page first and falls back to the mwl-api route. One
/// call never outlasts [budget]: the tab ends in data, an empty list or an error to retry.
/// Pages are parsed on a background isolate. Sources are fields so tests can replace them.
class ProfileTabsSource {
  ProfileTabsSource._();

  /// Longest wait for one tab, both sources included.
  static Duration budget = const Duration(seconds: 12);

  /// The MAL page gets this part of the [budget]; the fallback gets the rest.
  static Duration get _primaryShare =>
      Duration(milliseconds: budget.inMilliseconds * 7 ~/ 12);

  static const Duration _minFallback = Duration(milliseconds: 500);

  /// GET of one MAL page, body as text; throws on a non-200 status or after the timeout.
  static Future<String> Function(Uri url, Duration timeout) fetchPage = _fetchPage;

  /// mwl-api routes (Jikan for friends, MAL pages parsed by the backend for the others).
  static Future<Map<String, dynamic>?> Function(String username, int page) apiFriends =
      (username, page) =>
          MwlApi.i.getUserFriends(username, page: page, timeout: budget);
  static Future<Map<String, dynamic>?> Function(String username, String type) apiHistory =
      (username, type) => MwlApi.i.getUserHistory(username, type: type, timeout: budget);
  static Future<Map<String, dynamic>?> Function(String username) apiClubs =
      (username) => MwlApi.i.getUserClubs(username, timeout: budget);

  /// Tests parse on the calling isolate (`compute` needs a real event loop).
  @visibleForTesting
  static bool parseInline = false;

  /// Restores the real sources and timings (tests).
  @visibleForTesting
  static void reset() {
    budget = const Duration(seconds: 12);
    fetchPage = _fetchPage;
    apiFriends = (username, page) =>
        MwlApi.i.getUserFriends(username, page: page, timeout: budget);
    apiHistory = (username, type) =>
        MwlApi.i.getUserHistory(username, type: type, timeout: budget);
    apiClubs = (username) => MwlApi.i.getUserClubs(username, timeout: budget);
    parseInline = false;
  }

  // ---------------------------------------------------------------------------
  // The three tabs
  // ---------------------------------------------------------------------------

  /// One page of friends. [page] starts at 1. [after] is the [ProfileFriendsPage.cursor] of
  /// the previous page when it came from MAL's new friends page: the next one then comes from
  /// MAL's own "load more" endpoint, with no fallback (Jikan pages by 100 and would skip or
  /// repeat friends).
  static Future<ProfileFriendsPage> friends(String username,
      {int page = 1, FriendsCursor? after}) {
    if (after != null) {
      return () async {
        final body = await fetchPage(
          Uri.parse('https://myanimelist.net/friends/api/list/${after.userId}.json').replace(
            queryParameters: {
              'last_friend_id': '${after.lastFriendId}',
              'last_time_added': '${after.lastTimeAdded}',
            },
          ),
          budget,
        );
        return _parse(parseFriendsJson, (body, after.userId));
      }()
          .timeout(budget + _minFallback);
    }
    return _withFallback<ProfileFriendsPage>(
      (timeout) async {
        final offset = (page - 1) * ProfileFriendsPage.pageSize;
        final body = await fetchPage(
          _profileUrl(username, 'friends', query: offset == 0 ? null : 'offset=$offset'),
          timeout,
        );
        return _parse(parseFriendsPage, body);
      },
      (timeout) async {
        final envelope = await apiFriends(username, page).timeout(timeout);
        if (envelope == null) throw StateError('No answer for the friends of $username');
        return parseFriendsEnvelope(envelope);
      },
    );
  }

  /// The recent activity of one kind (`anime` or `manga`).
  static Future<List<ProfileHistoryEntry>> history(String username, String type) {
    return _withFallback<List<ProfileHistoryEntry>>(
      (timeout) async {
        final body = await fetchPage(
          Uri.parse(
              '${Constants.maluserHistoryUrl}/${Uri.encodeComponent(username)}/$type'),
          timeout,
        );
        return _parse(parseHistoryPage, (body, type));
      },
      (timeout) async {
        final envelope = await apiHistory(username, type).timeout(timeout);
        if (envelope == null) throw StateError('No answer for the history of $username');
        return parseHistoryEnvelope(envelope, category: type);
      },
    );
  }

  /// Anime and manga activity together. One kind failing does not hide the other; both
  /// failing throws.
  static Future<List<ProfileHistoryEntry>> historyAll(String username) async {
    Future<List<ProfileHistoryEntry>?> one(String type) async {
      try {
        return await history(username, type);
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([one('anime'), one('manga')]);
    if (results.every((r) => r == null)) {
      throw TimeoutException('History unavailable for $username');
    }
    return [...?results[0], ...?results[1]];
  }

  /// The clubs a user belongs to.
  static Future<List<ClubHtml>> clubs(String username) {
    return _withFallback<List<ClubHtml>>(
      (timeout) async {
        final body = await fetchPage(_profileUrl(username, 'clubs'), timeout);
        return _parse(parseClubsPage, body);
      },
      (timeout) async {
        final envelope = await apiClubs(username).timeout(timeout);
        if (envelope == null) throw StateError('No answer for the clubs of $username');
        return clubsFromRows((envelope['data'] as Map?)?['clubs']);
      },
    );
  }

  /// One page of the reviews a user wrote (`/profile/<name>/reviews?p=N`), newest first.
  static Future<ProfilePage<ProfileReview>> reviews(String username, {int page = 1}) =>
      _single(parseProfileReviewsPage, _profileUrl(username, 'reviews', query: _pageQuery(page)), page);

  /// One page of the recommendations a user made (`/profile/<name>/recommendations?p=N`).
  static Future<ProfilePage<ProfileRecommendation>> recommendations(String username,
          {int page = 1}) =>
      _single(parseProfileRecommendationsPage,
          _profileUrl(username, 'recommendations', query: _pageQuery(page)), page);

  /// One page of the interest stacks a user made or restacked (`/profile/<name>/stacks?p=N`).
  static Future<ProfilePage<InterestStack>> stacks(String username, {int page = 1}) =>
      _single(parseProfileStacksPage, _profileUrl(username, 'stacks', query: _pageQuery(page)), page);

  /// The blog entries of a user (`/blog/<name>`), newest first. MAL shows them on one page.
  static Future<List<ProfileBlogPost>> blog(String username) async {
    final body = await fetchPage(
      Uri.parse('https://myanimelist.net/blog/${Uri.encodeComponent(username)}'),
      budget,
    ).timeout(budget + _minFallback);
    return _parse(parseProfileBlogPage, body);
  }

  // ---------------------------------------------------------------------------
  // Plumbing
  // ---------------------------------------------------------------------------

  static String? _pageQuery(int page) => page > 1 ? 'p=$page' : null;

  /// A page of one of MAL's paged profile lists, no fallback: the data exists only there.
  static Future<ProfilePage<T>> _single<T>(
    ProfilePage<T> Function((String, int)) parser,
    Uri url,
    int page,
  ) async {
    final body = await fetchPage(url, budget).timeout(budget + _minFallback);
    return _parse(parser, (body, page));
  }

  static Uri _profileUrl(String username, String tab, {String? query}) => Uri.parse(
      '${Constants.maluserProfileUrl}/${Uri.encodeComponent(username)}/$tab'
      '${query == null ? '' : '?$query'}');

  /// Runs [primary], then [fallback] with what is left of the [budget]; the whole call is
  /// bounded by the budget. When both fail the fallback's error is thrown.
  static Future<T> _withFallback<T>(
    Future<T> Function(Duration timeout) primary,
    Future<T> Function(Duration timeout) fallback,
  ) {
    Future<T> run() async {
      final clock = Stopwatch()..start();
      try {
        return await primary(_primaryShare);
      } catch (_) {
        final left = budget - clock.elapsed;
        return fallback(left < _minFallback ? _minFallback : left);
      }
    }

    return run().timeout(budget + _minFallback);
  }

  static Future<R> _parse<M, R>(R Function(M) fn, M message) =>
      parseInline ? Future.value(fn(message)) : compute<M, R>(fn, message);

  /// A desktop browser. MAL picks the page layout from the User-Agent: a phone gets the Vue
  /// friends page (JSON in `#vm-friendlist`, no `#contentWrapper`), a desktop the classic HTML
  /// rows the parsers read. Both are parsed; this keeps the classic one the normal case.
  @visibleForTesting
  static const String userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Safari/537.36';

  static Future<String> _fetchPage(Uri url, Duration timeout) async {
    final response = await http.get(url, headers: const {
      'User-Agent': userAgent,
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('MAL answered ${response.statusCode}', url);
    }
    return response.body;
  }
}

// -----------------------------------------------------------------------------
// Parsers (top level so `compute` can run them)
// -----------------------------------------------------------------------------

/// A classic MAL page has `#contentWrapper`, the new friends page `#vm-friendlist`; a
/// challenge or maintenance page has neither, and must not read as "no friends".
Document _malDocument(String body) {
  final doc = html.parse(body);
  if (doc.querySelector('#contentWrapper, #vm-friendlist') == null) {
    throw const FormatException('Not a MyAnimeList profile page');
  }
  return doc;
}

/// The friends of `/profile/<name>/friends`: the classic rows (100 per page, next page by
/// `?offset=`) or the new page's JSON (30, next page by [FriendsCursor]).
ProfileFriendsPage parseFriendsPage(String body) {
  final doc = _malDocument(body);
  return _friendsPage(HtmlParsers.parseUserFriends(doc));
}

/// A body of MAL's "load more" endpoint; [args] = (body, id of the list's owner).
ProfileFriendsPage parseFriendsJson((String, int) args) {
  final Object? data;
  try {
    data = jsonDecode(args.$1);
  } on FormatException {
    throw const FormatException('Not a MyAnimeList friends answer');
  }
  if (data is! Map || data['items'] is! List) {
    throw const FormatException('Not a MyAnimeList friends answer');
  }
  final list = HtmlParsers.parseUserFriendsJson(data);
  return _friendsPage(UserFriendsList(
    friends: list.friends,
    hasMore: list.hasMore,
    userId: args.$2,
  ));
}

ProfileFriendsPage _friendsPage(UserFriendsList list) {
  final page = parseFriendsEnvelope({'data': list.toJson()});
  if (list.hasMore == null) {
    return ProfileFriendsPage(
      page.friends,
      hasNextPage: page.friends.length >= ProfileFriendsPage.pageSize,
    );
  }
  final last = list.friends.isEmpty ? null : list.friends.last;
  final cursor = (list.hasMore == true &&
          list.userId != null &&
          last?.id != null &&
          last?.timeAdded != null)
      ? FriendsCursor(
          userId: list.userId!,
          lastFriendId: last!.id!,
          lastTimeAdded: last.timeAdded!,
        )
      : null;
  // Without a cursor there is no way to ask for more: no "load more" button.
  return ProfileFriendsPage(page.friends, hasNextPage: cursor != null, cursor: cursor);
}

/// The rows of `/history/<name>/<type>`; [args] = (page body, `anime` or `manga`).
List<ProfileHistoryEntry> parseHistoryPage((String, String) args) {
  final doc = _malDocument(args.$1);
  return parseHistoryEnvelope(
    {'data': HtmlParsers.parseUserHistory(doc).toJson()},
    category: args.$2,
  );
}

/// The clubs of `/profile/<name>/clubs`.
List<ClubHtml> parseClubsPage(String body) {
  final doc = _malDocument(body);
  return clubsFromRows(HtmlParsers.parseUserClubs(doc)['clubs']);
}

/// `[{id, name}]` rows to clubs, without rows lacking an id and without duplicates.
List<ClubHtml> clubsFromRows(Object? rows) {
  if (rows is! List) return const [];
  final seen = <int>{};
  return [
    for (final row in rows)
      if (row is Map && row['id'] is int && seen.add(row['id'] as int))
        ClubHtml(id: row['id'] as int, name: row['name'] as String?),
  ];
}


// -----------------------------------------------------------------------------
// Reviews, recommendations, interest stacks and blog entries of a profile
// -----------------------------------------------------------------------------

/// One page of a paged profile list; [hasNext] when the page links to the following one.
class ProfilePage<T> {
  final List<T> items;
  final bool hasNext;

  const ProfilePage(this.items, {this.hasNext = false});
}

/// An anime or manga as a profile tab refers to it.
class ProfileMediaRef {
  final int id;
  final String category;
  final String title;
  final String? imageUrl;

  const ProfileMediaRef({
    required this.id,
    required this.category,
    required this.title,
    this.imageUrl,
  });
}

/// A review written by the profile's owner.
class ProfileReview {
  /// MAL's review id (`reviews.php?id=`), null when the page gives none.
  final int? id;
  final ProfileMediaRef media;

  /// MAL's label: `Anime`, `Manga`, `Light Novel`...
  final String? kind;
  final DateTime? date;

  /// The date as MAL wrote it when it is not a plain day ("Today, 2:03 PM").
  final String? dateText;
  final List<String> tags;
  final String text;
  final int? score;
  final int reactions;

  const ProfileReview({
    this.id,
    required this.media,
    this.kind,
    this.date,
    this.dateText,
    this.tags = const [],
    this.text = '',
    this.score,
    this.reactions = 0,
  });

  String? get url => id == null ? null : 'https://myanimelist.net/reviews.php?id=$id';
}

/// A recommendation made by the profile's owner: "if you liked [from], you might like [to]".
class ProfileRecommendation {
  final int? id;
  final ProfileMediaRef from;
  final ProfileMediaRef to;
  final String text;
  final DateTime? date;
  final String? dateText;

  const ProfileRecommendation({
    this.id,
    required this.from,
    required this.to,
    this.text = '',
    this.date,
    this.dateText,
  });
}

/// A blog entry; its text keeps line breaks, links and formatting are dropped.
class ProfileBlogPost {
  final int? id;
  final String title;
  final String text;
  final String? dateText;
  final int comments;

  const ProfileBlogPost({
    this.id,
    required this.title,
    this.text = '',
    this.dateText,
    this.comments = 0,
  });

  String get url =>
      id == null ? 'https://myanimelist.net/blog.php' : 'https://myanimelist.net/blog.php?eid=$id';
}

/// A page of a profile list is a MAL page that has the content wrapper; a challenge or
/// maintenance page throws instead of reading as "nothing here".
Document _profileDocument(String body) {
  final doc = html.parse(body);
  if (doc.querySelector('#contentWrapper') == null) {
    throw const FormatException('Not a MyAnimeList profile page');
  }
  return doc;
}

bool _linksToPage(Document doc, int page) => doc
    .querySelectorAll('a[href*="p="]')
    .any((a) => RegExp('[?&]p=${page + 1}(?!\\d)').hasMatch(a.attributes['href'] ?? ''));

/// Entities MAL escapes twice in review and blog text (`&amp;quot;`), decoded once more.
String _unescape(String text) {
  if (!text.contains('&')) return text;
  return html.parseFragment(text).text ?? text;
}

String _cleanText(String text) => _unescape(text)
    .replaceAll(' ', ' ')
    .replaceAll(RegExp(r'[ \t]+\n'), '\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// The text of [element] with `<br>` as line breaks and the nodes matching [drop] removed.
String _textWithBreaks(Element element, {String? drop}) {
  final copy = element.clone(true);
  if (drop != null) {
    for (final node in copy.querySelectorAll(drop)) {
      node.remove();
    }
  }
  for (final br in copy.querySelectorAll('br')) {
    br.replaceWith(Text('\n'));
  }
  return _cleanText(copy.text);
}

const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

/// "Sep 9, 2007" to a date; null for MAL's relative wording ("Today, 2:03 PM").
DateTime? _malDay(String? raw) {
  final m = RegExp(r'([A-Za-z]{3})[a-z]*\.? (\d{1,2}), (\d{4})').firstMatch(raw ?? '');
  if (m == null) return null;
  final month = _months.indexOf(m.group(1)!.toLowerCase()) + 1;
  if (month == 0) return null;
  return DateTime(int.parse(m.group(3)!), month, int.parse(m.group(2)!));
}

String? _imageOf(Element? img) {
  if (img == null) return null;
  final srcset = img.attributes['data-srcset'];
  if (srcset != null && srcset.isNotEmpty) {
    // The last candidate is the sharpest ("url 1x, url 2x").
    final last = srcset.split(',').last.trim().split(' ').first;
    if (last.startsWith('http')) return last;
  }
  for (final key in ['data-src', 'src']) {
    final url = img.attributes[key];
    if (url != null && url.startsWith('http') && !url.endsWith('spacer.gif')) return url;
  }
  return null;
}

ProfileMediaRef? _mediaRef(Element? root, {String? titleSelector}) {
  if (root == null) return null;
  for (final a in root.querySelectorAll('a[href]')) {
    final m = RegExp(r'/(anime|manga)/(\d+)').firstMatch(a.attributes['href'] ?? '');
    if (m == null) continue;
    final title = (titleSelector == null ? null : root.querySelector(titleSelector)?.text) ??
        a.attributes['title'] ??
        a.text;
    return ProfileMediaRef(
      id: int.parse(m.group(2)!),
      category: m.group(1)!,
      title: _cleanText(title),
      imageUrl: _imageOf(root.querySelector('img')),
    );
  }
  return null;
}

/// The reviews of `/profile/<name>/reviews`; [args] = (page body, page number).
ProfilePage<ProfileReview> parseProfileReviewsPage((String, int) args) {
  final doc = _profileDocument(args.$1);
  final reviews = <ProfileReview>[];
  for (final row in doc.querySelectorAll('.review-element')) {
    final media = _mediaRef(row.querySelector('.thumb'), titleSelector: '.titleblock .title');
    if (media == null) continue;
    final titleblock = row.querySelector('.titleblock');
    final title = _cleanText(titleblock?.querySelector('a.title')?.text ?? media.title);
    final dateText = row.querySelector('.update_at')?.text.trim();
    int? id;
    final open = row.querySelector('.open a')?.attributes['href'];
    if (open != null) id = int.tryParse(RegExp(r'[?&]id=(\d+)').firstMatch(open)?.group(1) ?? '');
    var reactions = 0;
    try {
      final data = jsonDecode(row.attributes['data-reactions'] ?? '{}');
      if (data is Map) reactions = (data['num'] as num?)?.toInt() ?? 0;
    } on FormatException {
      // No reaction count: left at 0.
    }
    final day = _malDay(dateText);
    reviews.add(ProfileReview(
      id: id,
      media: ProfileMediaRef(
        id: media.id,
        category: media.category,
        title: title,
        imageUrl: media.imageUrl,
      ),
      kind: titleblock?.querySelector('small')?.text.replaceAll(RegExp(r'[()]'), '').trim(),
      date: day,
      dateText: day == null ? dateText : null,
      tags: [
        for (final tag in row.querySelectorAll('.tags .tag')) _cleanText(tag.text),
      ],
      // The long text is cut by a "..." that a tap on "Read more" removes; both halves are
      // in the page.
      text: row.querySelector('.text') == null
          ? ''
          : _textWithBreaks(row.querySelector('.text')!, drop: '.js-visible'),
      score: int.tryParse(row.querySelector('.rating .num')?.text.trim() ?? ''),
      reactions: reactions,
    ));
  }
  return ProfilePage(reviews, hasNext: _linksToPage(doc, args.$2));
}

/// The recommendations of `/profile/<name>/recommendations`.
ProfilePage<ProfileRecommendation> parseProfileRecommendationsPage((String, int) args) {
  final doc = _profileDocument(args.$1);
  final recs = <ProfileRecommendation>[];
  for (final row in doc.querySelectorAll('.borderClass')) {
    final cells = row.querySelectorAll('table td');
    final textNode = row.querySelector('.profile-user-recs-text');
    if (cells.length < 2 || textNode == null) continue;
    final from = _mediaRef(cells[0], titleSelector: 'strong');
    final to = _mediaRef(cells[1], titleSelector: 'strong');
    if (from == null || to == null) continue;
    final footer = row.querySelector('div.lightLink')?.text ?? '';
    final dateText = RegExp(r' - ([^-]+)$').firstMatch(footer.trim())?.group(1)?.trim();
    final report = row.querySelector('a[href*="reportanimerecommendation"], a[href*="reportmangarecommendation"]');
    final day = _malDay(dateText);
    recs.add(ProfileRecommendation(
      id: int.tryParse(
          RegExp(r'[?&]id=(\d+)').firstMatch(report?.attributes['href'] ?? '')?.group(1) ?? ''),
      from: from,
      to: to,
      text: _cleanText(textNode.text),
      date: day,
      dateText: day == null ? dateText : null,
    ));
  }
  return ProfilePage(recs, hasNext: _linksToPage(doc, args.$2));
}

/// The stacks of `/profile/<name>/stacks`.
ProfilePage<InterestStack> parseProfileStacksPage((String, int) args) {
  final doc = _profileDocument(args.$1);
  final stacks = <InterestStack>[];
  for (final row in doc.querySelectorAll('.stacks-list .column-item')) {
    final href = row.querySelector('a')?.attributes['href'];
    if (href == null || !RegExp(r'/stacks/\d+').hasMatch(href)) continue;
    final statText = row.querySelector('.stat .text')?.text ?? '';
    stacks.add(InterestStack(
      url: href,
      title: _cleanText(row.querySelector('.detail .title')?.text ?? ''),
      imageUrls: [
        for (final img in row.querySelectorAll('.img img'))
          if (_imageOf(img) != null) _imageOf(img)!,
      ],
      username: row.querySelector('.detail .tag a')?.text.trim(),
      entries: int.tryParse(RegExp(r'(\d+)\s*Entr').firstMatch(statText)?.group(1) ?? ''),
      reStacks: int.tryParse(row.querySelector('.js-num-stack')?.text.trim() ?? ''),
      updatedAt: row.querySelector('.detail .update')?.text.trim(),
    ));
  }
  return ProfilePage(stacks, hasNext: _linksToPage(doc, args.$2));
}

/// The entries of `/blog/<name>`: a date header, a bold title, the text and a footer with
/// the comment count, as siblings. The categories sidebar is not a post.
List<ProfileBlogPost> parseProfileBlogPage(String body) {
  final doc = _profileDocument(body);
  final posts = <ProfileBlogPost>[];
  for (final header in doc.querySelectorAll('#content .normal_header')) {
    String title = '';
    Element? text;
    Element? footer;
    for (var node = header.nextElementSibling;
        node != null && !node.classes.contains('normal_header');
        node = node.nextElementSibling) {
      if (node.classes.contains('borderClass')) {
        footer = node;
        break;
      }
      if (node.classes.contains('lightLink') && title.isEmpty) {
        title = _cleanText(node.text);
      } else if (!RegExp(r'^(Anime|Manga) Relations').hasMatch(node.text.trim())) {
        text = node;
      }
    }
    // A post has a bold title or a "Posted by" footer; the sidebar's "Categories" block is a
    // normal_header too, followed only by its links.
    if (title.isEmpty && footer == null) continue;
    final comments = footer?.querySelector('a[href*="eid="]');
    final href = comments?.attributes['href'] ?? '';
    posts.add(ProfileBlogPost(
      id: int.tryParse(RegExp(r'eid=(\d+)').firstMatch(href)?.group(1) ?? ''),
      title: title,
      text: text == null ? '' : _textWithBreaks(text),
      dateText: header.text.trim(),
      comments: int.tryParse(RegExp(r'(\d+)\s*comment').firstMatch(comments?.text ?? '')?.group(1) ?? '') ?? 0,
    ));
  }
  return posts;
}
