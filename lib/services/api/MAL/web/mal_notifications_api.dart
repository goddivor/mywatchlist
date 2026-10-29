import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/screens/user_profile/sections/profile_tabs_source.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_friends.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';

// ---------------------------------------------------------------------------
// MAL's notification hub (https://myanimelist.net/notification)
// ---------------------------------------------------------------------------

/// The notification types MAL's own script knows (`createNotificationItem*` in
/// `static/assets/js/pc/all-e0d71967e4.js`, read 2026-10-28), plus [unknown] for a type MAL
/// adds later (shown with MAL's category name).
enum MalNotificationKind {
  friendRequest('friend_request', MalNotificationGroup.friends),
  friendRequestAccept('friend_request_accept', MalNotificationGroup.friends),
  friendRequestDeny('friend_request_deny', MalNotificationGroup.friends),
  profileComment('profile_comment', MalNotificationGroup.comments),
  blogComment('blog_comment', MalNotificationGroup.comments),
  forumQuote('forum_quote', MalNotificationGroup.forum),
  watchedTopicMessage('watched_topic_message', MalNotificationGroup.forum),
  userMentionInForumMessage('user_mention_in_forum_message', MalNotificationGroup.forum),
  clubMassMessageInForum('club_mass_message_in_forum', MalNotificationGroup.clubs),
  userMentionInClubComment('user_mention_in_club_comment', MalNotificationGroup.clubs),
  relatedAnimeAdd('related_anime_add', MalNotificationGroup.anime),
  onAir('on_air', MalNotificationGroup.anime),
  paymentStripe('payment_stripe', MalNotificationGroup.other),
  unknown('', MalNotificationGroup.other);

  const MalNotificationKind(this.typeIdentifier, this.group);

  /// MAL's `typeIdentifier`.
  final String typeIdentifier;
  final MalNotificationGroup group;

  static MalNotificationKind of(String? typeIdentifier) {
    for (final kind in values) {
      if (kind != unknown && kind.typeIdentifier == typeIdentifier) return kind;
    }
    return unknown;
  }
}

/// The filter chips of the notifications screen.
enum MalNotificationGroup { friends, comments, forum, clubs, anime, other }

/// An anime named by a notification (`related_anime_add`, `on_air`).
@immutable
class MalNotificationAnime {
  const MalNotificationAnime({required this.title, this.mediaType, this.url});

  final String title;
  final String? mediaType;
  final String? url;

  /// The MAL id read from [url] (`/anime/<id>/…`), or null.
  int? get malId => malIdFromUrl(url, 'anime');

  static MalNotificationAnime? fromJson(Object? json) {
    if (json is! Map) return null;
    final title = _str(json['title']);
    if (title == null) return null;
    return MalNotificationAnime(
      title: title,
      mediaType: _str(json['mediaType']) ?? _str(json['media_type']),
      url: absoluteMalUrl(_str(json['url'])),
    );
  }
}

/// One item of MAL's notification hub, with the fields MAL's own script copies for its
/// type. The person who acted (friend, commenter, quoter, poster, sharer, sender) is
/// [actorName] whatever the type.
@immutable
class MalNotificationItem {
  const MalNotificationItem({
    required this.id,
    required this.rawId,
    required this.kind,
    required this.typeIdentifier,
    this.categoryName,
    this.createdAt,
    this.createdAtForDisplay,
    this.isRead = false,
    this.isDeleted = false,
    this.url,
    this.actorName,
    this.actorProfileUrl,
    this.actorImageUrl,
    this.text,
    this.topicTitle,
    this.topicUrl,
    this.clubName,
    this.clubUrl,
    this.pageTitle,
    this.pageUrl,
    this.anime,
    this.animes = const [],
    this.planName,
    this.isApproved,
    this.date,
  });

  /// [rawId] as text (MAL sends a number or a string).
  final String id;

  /// The id exactly as MAL sent it, posted back as is when marking it read.
  final Object rawId;
  final MalNotificationKind kind;
  final String typeIdentifier;
  final String? categoryName;
  final DateTime? createdAt;
  final String? createdAtForDisplay;
  final bool isRead;
  final bool isDeleted;
  final String? url;
  final String? actorName;
  final String? actorProfileUrl;
  final String? actorImageUrl;

  /// Profile comment text, or the message attached to a friend request.
  final String? text;
  final String? topicTitle;
  final String? topicUrl;
  final String? clubName;
  final String? clubUrl;
  final String? pageTitle;
  final String? pageUrl;
  final MalNotificationAnime? anime;
  final List<MalNotificationAnime> animes;
  final String? planName;

  /// Friend requests only: null when not answered yet.
  final bool? isApproved;

  /// `on_air`: MAL's airing date text.
  final String? date;

  /// An unanswered friend request (Accept / Deny are offered).
  bool get isPendingFriendRequest => kind == MalNotificationKind.friendRequest && isApproved != true;

  /// The page a tap opens: the anime for airing and related-anime items, the post or topic
  /// for forum items, the profile for comments and friends, MAL's own url otherwise.
  String? get targetUrl {
    switch (kind) {
      case MalNotificationKind.onAir:
        return animes.isNotEmpty ? animes.first.url ?? url : url;
      case MalNotificationKind.relatedAnimeAdd:
        return anime?.url ?? url;
      case MalNotificationKind.friendRequest:
        return actorProfileUrl ?? url;
      case MalNotificationKind.friendRequestAccept:
      case MalNotificationKind.friendRequestDeny:
        return actorProfileUrl ?? url;
      case MalNotificationKind.forumQuote:
      case MalNotificationKind.watchedTopicMessage:
      case MalNotificationKind.clubMassMessageInForum:
        return topicUrl ?? url;
      case MalNotificationKind.userMentionInForumMessage:
      case MalNotificationKind.userMentionInClubComment:
        return pageUrl ?? url;
      case MalNotificationKind.profileComment:
      case MalNotificationKind.blogComment:
      case MalNotificationKind.paymentStripe:
      case MalNotificationKind.unknown:
        return url;
    }
  }

  /// The anime or manga a tap opens directly (`anime:<id>` payloads), when there is one.
  int? get animeId => malIdFromUrl(targetUrl, 'anime');

  MalNotificationItem copyWith({bool? isRead, bool? isApproved}) => MalNotificationItem(
        id: id,
        rawId: rawId,
        kind: kind,
        typeIdentifier: typeIdentifier,
        categoryName: categoryName,
        createdAt: createdAt,
        createdAtForDisplay: createdAtForDisplay,
        isRead: isRead ?? this.isRead,
        isDeleted: isDeleted,
        url: url,
        actorName: actorName,
        actorProfileUrl: actorProfileUrl,
        actorImageUrl: actorImageUrl,
        text: text,
        topicTitle: topicTitle,
        topicUrl: topicUrl,
        clubName: clubName,
        clubUrl: clubUrl,
        pageTitle: pageTitle,
        pageUrl: pageUrl,
        anime: anime,
        animes: animes,
        planName: planName,
        isApproved: isApproved ?? this.isApproved,
        date: date,
      );

  /// Reads one entry of `items` / `historyItems`; null when it has no id.
  static MalNotificationItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final rawId = json['id'];
    if (rawId == null || (rawId is! String && rawId is! num)) return null;
    final id = '$rawId';
    if (id.isEmpty) return null;
    final type = _str(json['typeIdentifier']) ?? '';
    final created = json['createdAt'];
    DateTime? createdAt;
    if (created is num && created > 0) {
      createdAt = DateTime.fromMillisecondsSinceEpoch((created * 1000).round(), isUtc: true);
    } else if (created is String) {
      final seconds = int.tryParse(created);
      if (seconds != null && seconds > 0) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
      }
    }
    final animes = json['animes'];
    final approved = json['isApproved'];
    return MalNotificationItem(
      id: id,
      rawId: rawId,
      kind: MalNotificationKind.of(type),
      typeIdentifier: type,
      categoryName: _str(json['categoryName']),
      createdAt: createdAt,
      createdAtForDisplay: _str(json['createdAtForDisplay']),
      isRead: json['isRead'] == true || json['isRead'] == 1,
      isDeleted: json['isDeleted'] == true || json['isDeleted'] == 1,
      url: absoluteMalUrl(_str(json['url'])),
      actorName: _str(json['friendName']) ??
          _str(json['commentUserName']) ??
          _str(json['quoteUserName']) ??
          _str(json['postedUserName']) ??
          _str(json['sharedUserName']) ??
          _str(json['senderName']),
      actorProfileUrl: absoluteMalUrl(_str(json['friendProfileUrl']) ??
          _str(json['commentUserProfileUrl']) ??
          _str(json['quoteUserProfileUrl']) ??
          _str(json['postedUserProfileUrl']) ??
          _str(json['sharedUserProfileUrl']) ??
          _str(json['senderProfileUrl'])),
      actorImageUrl: _str(json['friendImageUrl']) ?? _str(json['commentUserImageUrl']),
      text: _str(json['text']) ?? _str(json['message']),
      topicTitle: _str(json['topicTitle']),
      topicUrl: absoluteMalUrl(_str(json['topicUrl'])),
      clubName: _str(json['clubName']),
      clubUrl: absoluteMalUrl(_str(json['clubUrl'])),
      pageTitle: _str(json['pageTitle']),
      pageUrl: absoluteMalUrl(_str(json['pageUrl'])),
      anime: MalNotificationAnime.fromJson(json['anime']),
      animes: animes is List
          ? [...animes.map(MalNotificationAnime.fromJson).whereType<MalNotificationAnime>()]
          : const [],
      planName: _str(json['plan_name']) ?? _str(json['planName']),
      isApproved: approved is bool ? approved : (approved is num ? approved != 0 : null),
      date: _str(json['date']),
    );
  }
}

/// What the notification page holds: the newest [items] and the older [history].
@immutable
class MalNotificationFeed {
  const MalNotificationFeed({this.items = const [], this.history = const [], this.unreadDigest});

  final List<MalNotificationItem> items;
  final List<MalNotificationItem> history;

  /// MAL's own unread counter (`headerNotification.countDigest`) when the page carries it.
  final int? unreadDigest;

  /// Every item once, newest first, deleted ones left out.
  List<MalNotificationItem> get all {
    final seen = <String>{};
    final out = <MalNotificationItem>[
      for (final item in [...items, ...history])
        if (!item.isDeleted && seen.add(item.id)) item,
    ];
    out.sort((a, b) {
      final ta = a.createdAt, tb = b.createdAt;
      if (ta == null || tb == null) return 0;
      return tb.compareTo(ta);
    });
    return out;
  }

  int get unreadCount => all.where((i) => !i.isRead).length;
}

/// The page carries neither the notification data nor a login form: MAL changed it.
class MalNotificationsUnreadable implements Exception {
  const MalNotificationsUnreadable();
  @override
  String toString() => 'MalNotificationsUnreadable';
}

/// Cuts the object or array literal that starts at [start] (a `{` or `[`), skipping
/// brackets inside JSON strings. Null when it never closes.
String? _balancedLiteral(String source, int start) {
  if (start < 0 || start >= source.length) return null;
  final open = source[start];
  if (open != '{' && open != '[') return null;
  var depth = 0;
  var inString = false;
  String? quote;
  for (var i = start; i < source.length; i++) {
    final c = source[i];
    if (inString) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        inString = false;
      }
      continue;
    }
    if (c == '"' || c == "'") {
      inString = true;
      quote = c;
    } else if (c == '{' || c == '[') {
      depth++;
    } else if (c == '}' || c == ']') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  return null;
}

final RegExp _notificationAssign = RegExp(r'window\.MAL\.notification\s*=\s*([\{])');
final RegExp _itemsAssign = RegExp(r'window\.MAL\.notification\.(items|historyItems)\s*=\s*(\[)');
final RegExp _headerAssign = RegExp(r'window\.MAL\.headerNotification\s*=\s*(\{)');
final RegExp _countDigest = RegExp(r'''["']?countDigest["']?\s*[:=]\s*(\d+)''');

/// The JSON blob of `window.MAL.notification = {…};` in a notification page, or null.
String? extractNotificationJson(String html) {
  final match = _notificationAssign.firstMatch(html);
  if (match == null) return null;
  return _balancedLiteral(html, match.end - 1);
}

List<MalNotificationItem> _items(Object? list) => list is List
    ? [...list.map(MalNotificationItem.fromJson).whereType<MalNotificationItem>()]
    : const [];

/// Reads a notification page: the `window.MAL.notification` object (MALClient's source),
/// or `window.MAL.notification.items = […]` assignments, plus MAL's unread counter. Null
/// when the page has none of them.
MalNotificationFeed? parseNotificationPage(String html) {
  int? digest;
  final header = _headerAssign.firstMatch(html);
  if (header != null) {
    final literal = _balancedLiteral(html, header.end - 1);
    if (literal != null) {
      final m = _countDigest.firstMatch(literal);
      if (m != null) digest = int.tryParse(m.group(1)!);
    }
  }
  final json = extractNotificationJson(html);
  if (json != null) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return MalNotificationFeed(
          items: _items(decoded['items']),
          history: _items(decoded['historyItems']),
          unreadDigest: digest,
        );
      }
    } on FormatException {
      // Not strict JSON: try the separate assignments below.
    }
  }
  List<MalNotificationItem>? items;
  List<MalNotificationItem>? history;
  for (final m in _itemsAssign.allMatches(html)) {
    final literal = _balancedLiteral(html, m.end - 1);
    if (literal == null) continue;
    try {
      final list = _items(jsonDecode(literal));
      if (m.group(1) == 'items') {
        items = list;
      } else {
        history = list;
      }
    } on FormatException {
      continue;
    }
  }
  if (items == null && history == null) return null;
  return MalNotificationFeed(items: items ?? const [], history: history ?? const [], unreadDigest: digest);
}

/// Reads the answer of `/notification/api/request-items.json` (`{items: […]}`).
MalNotificationFeed? parseRequestItems(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['items'] is! List) return null;
    return MalNotificationFeed(items: _items(decoded['items']));
  } on FormatException {
    return null;
  }
}

/// MAL's notification hub through the website session ([MalWebClient]): read the page, mark
/// items read, answer friend requests. Endpoints and bodies follow MAL's own script
/// (`NotificationContainerMixin`): JSON `{notification_ids: [...]}` with the page's
/// `csrf_token` added to the JSON, as MAL's `ajaxPrefilter` does.
class MalNotificationsApi {
  /// [httpClient] is no longer used (every request goes through [client]); kept so the
  /// existing callers still compile.
  MalNotificationsApi({MalWebClient? client, http.Client Function()? httpClient})
      : _clientOverride = client;

  static MalNotificationsApi instance = MalNotificationsApi();

  static const String pagePath = '/notification';
  static const String requestItemsPath = '/notification/api/request-items.json';
  static const String markReadPath = '/notification/api/check-items-as-read.json';
  static const String acceptPath = '/notification/api/accept-friend-request.json';
  static const String denyPath = '/notification/api/deny-friend-request.json';

  /// Tests parse on the calling isolate.
  @visibleForTesting
  static bool parseInline = false;

  final MalWebClient? _clientOverride;

  MalWebClient get client => _clientOverride ?? MalWebClient.instance;

  /// The hub, newest first. Throws [MalWebNoSession] without a website session,
  /// [MalWebSessionExpired] when MAL sends the request to its login page, and
  /// [MalNotificationsUnreadable] when the page has changed beyond recognition.
  Future<MalNotificationFeed> fetch() async {
    await client.session.ensureLoaded();
    if (!client.session.isConnected) throw const MalWebNoSession();
    final response = await client.get(pagePath);
    if (response.statusCode != 200) {
      throw MalWebActionFailed(statusCode: response.statusCode);
    }
    final body = response.body;
    final feed = parseInline ? parseNotificationPage(body) : await compute(parseNotificationPage, body);
    if (feed != null) return feed;
    if (_looksLoggedOut(body)) {
      await client.session.markExpired();
      client.reset();
      throw const MalWebSessionExpired();
    }
    // The page no longer embeds the data: MAL's header dropdown asks this endpoint.
    final answer = await client.postForm(requestItemsPath, const {}, referer: '${MalWebClient.base}$pagePath');
    final fallback = answer.statusCode == 200 ? parseRequestItems(answer.body) : null;
    if (fallback == null) throw const MalNotificationsUnreadable();
    return fallback;
  }

  static bool _looksLoggedOut(String html) =>
      html.contains('name="user_name"') || html.contains("name='user_name'") || html.contains('login.php?from=');

  /// Marks [ids] read on MAL. True when MAL accepted it.
  Future<bool> markRead(Iterable<MalNotificationItem> items) =>
      _postIds(markReadPath, [for (final i in items) if (!i.isRead) i.rawId]);

  /// Accepts the friend requests [items].
  Future<bool> acceptFriendRequests(Iterable<MalNotificationItem> items) =>
      _postIds(acceptPath, [for (final i in items) i.rawId]);

  /// Denies the friend requests [items].
  Future<bool> denyFriendRequests(Iterable<MalNotificationItem> items) =>
      _postIds(denyPath, [for (final i in items) i.rawId]);

  /// One JSON POST through [MalWebClient.postJson], which adds the page's `csrf_token`,
  /// fetches it again once when MAL refuses it and turns a login redirect into
  /// [MalWebSessionExpired]. Any other redirect is a refusal.
  Future<bool> _postIds(String path, List<Object> ids) async {
    if (ids.isEmpty) return true;
    final response = await client.postJson(
      path,
      {'notification_ids': ids},
      referer: '${MalWebClient.base}$pagePath',
    );
    final status = response.statusCode;
    if (status >= 300 && status < 400) return false;
    if (status != 200) throw MalWebActionFailed(statusCode: status);
    return _accepted(response.body);
  }

  /// MAL answers `true`, or an object; an `errors` / `error` key is a refusal.
  static bool _accepted(String body) {
    final text = body.trim();
    if (text.isEmpty) return true;
    try {
      final decoded = jsonDecode(text);
      if (decoded is bool) return decoded;
      if (decoded is Map) {
        if (decoded['errors'] != null || decoded['error'] != null) return false;
        return true;
      }
      return true;
    } on FormatException {
      return text.contains('true');
    }
  }
}

// ---------------------------------------------------------------------------
// Friends' list updates (rss.php?type=rw / rm), not part of MAL's notifications
// ---------------------------------------------------------------------------

/// One list update of a friend, from MAL's RSS feed of their list (`rss.php?type=rw` for
/// anime, `type=rm` for manga). MAL's notification hub has no such item type.
@immutable
class FriendActivity {
  const FriendActivity({
    required this.friend,
    required this.category,
    required this.malId,
    required this.title,
    required this.link,
    this.friendImageUrl,
    this.mediaType,
    this.statusText,
    this.status,
    this.progress,
    this.total,
    this.date,
  });

  final String friend;
  final String? friendImageUrl;

  /// `anime` or `manga`.
  final String category;
  final int malId;
  final String title;
  final String link;

  /// `TV`, `Movie`, `Manga`… (the part after the last ` - ` of the RSS title).
  final String? mediaType;

  /// MAL's English status text (`Dropped`, `Plan to Watch`).
  final String? statusText;

  /// [statusText] as a MAL list status: `watching`, `reading`, `completed`, `on_hold`,
  /// `dropped`, `plan_to_watch`, `plan_to_read`; null when unknown.
  final String? status;
  final int? progress;

  /// Episodes or chapters in all; null when MAL writes `?`.
  final int? total;
  final DateTime? date;

  bool get isDropped => status == 'dropped';
  bool get isCompleted => status == 'completed';

  /// Same friend, title and state: the same update seen twice.
  String get key => '$friend|$category|$malId|${status ?? statusText}|${progress ?? ''}';

  FriendActivity withFriendImage(String? url) => FriendActivity(
        friend: friend,
        friendImageUrl: url,
        category: category,
        malId: malId,
        title: title,
        link: link,
        mediaType: mediaType,
        statusText: statusText,
        status: status,
        progress: progress,
        total: total,
        date: date,
      );
}

final RegExp _rssItem = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false);
final RegExp _rssDescription =
    RegExp(r'^\s*(.+?)\s+-\s+(\d+|\?)\s+of\s+(\d+|\?)\s+\w+', caseSensitive: false);
final RegExp _rfc822 = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|GMT|UTC|UT|Z)?');
const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
final HtmlUnescape _unescape = HtmlUnescape();

String? _rssTag(String item, String tag) {
  final m = RegExp('<$tag(?:\\s[^>]*)?>([\\s\\S]*?)</$tag>', caseSensitive: false).firstMatch(item);
  if (m == null) return null;
  var value = m.group(1)!.trim();
  final cdata = RegExp(r'^<!\[CDATA\[([\s\S]*)\]\]>$').firstMatch(value);
  value = cdata != null ? cdata.group(1)!.trim() : _unescape.convert(value);
  return value.isEmpty ? null : value;
}

/// `Wed, 28 Oct 2026 16:03:53 -0700` as a UTC instant; null when unreadable.
DateTime? parseRssDate(String? text) {
  if (text == null) return null;
  final m = _rfc822.firstMatch(text);
  if (m == null) return null;
  final month = _months.indexOf(m.group(2)!.toLowerCase());
  if (month < 0) return null;
  var at = DateTime.utc(
    int.parse(m.group(3)!),
    month + 1,
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.tryParse(m.group(6) ?? '') ?? 0,
  );
  final zone = m.group(7);
  if (zone != null && (zone.startsWith('+') || zone.startsWith('-'))) {
    final sign = zone.startsWith('-') ? -1 : 1;
    final offset = Duration(hours: int.parse(zone.substring(1, 3)), minutes: int.parse(zone.substring(3, 5)));
    at = sign > 0 ? at.subtract(offset) : at.add(offset);
  }
  return at;
}

/// `Plan to Watch` → `plan_to_watch`, `On-Hold` → `on_hold`; null when unknown.
String? malStatusOf(String? text) {
  final s = text?.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  return switch (s) {
    'watching' => 'watching',
    'reading' => 'reading',
    'completed' => 'completed',
    'onhold' => 'on_hold',
    'dropped' => 'dropped',
    'plantowatch' => 'plan_to_watch',
    'plantoread' => 'plan_to_read',
    'rewatching' => 'watching',
    'rereading' => 'reading',
    _ => null,
  };
}

/// The id in a MAL url of [category] (`https://myanimelist.net/anime/5114/…` → 5114).
int? malIdFromUrl(String? url, String category) {
  if (url == null) return null;
  final m = RegExp('/$category/(\\d+)').firstMatch(url);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// [url] made absolute on myanimelist.net (MAL sends both forms); null stays null.
String? absoluteMalUrl(String? url) {
  if (url == null) return null;
  final value = url.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  if (value.startsWith('//')) return 'https:$value';
  return '${MalWebClient.base}${value.startsWith('/') ? '' : '/'}$value';
}

/// Reads one friend's RSS feed of [category] (`anime` for `type=rw`, `manga` for `rm`).
List<FriendActivity> parseFriendFeed(String xml, {required String friend, required String category}) {
  final out = <FriendActivity>[];
  for (final m in _rssItem.allMatches(xml)) {
    final item = m.group(1)!;
    final link = _rssTag(item, 'link');
    final id = malIdFromUrl(link, category);
    final header = _rssTag(item, 'title');
    if (link == null || id == null || header == null) continue;
    final dash = header.lastIndexOf(' - ');
    final title = dash > 0 ? header.substring(0, dash).trim() : header;
    final mediaType = dash > 0 ? header.substring(dash + 3).trim() : null;
    final description = _rssTag(item, 'description');
    final d = description == null ? null : _rssDescription.firstMatch(description);
    final statusText = d?.group(1) ?? description;
    out.add(FriendActivity(
      friend: friend,
      category: category,
      malId: id,
      title: title,
      link: link,
      mediaType: (mediaType?.isEmpty ?? true) ? null : mediaType,
      statusText: statusText,
      status: malStatusOf(statusText),
      progress: int.tryParse(d?.group(2) ?? ''),
      total: int.tryParse(d?.group(3) ?? ''),
      date: parseRssDate(_rssTag(item, 'pubDate')),
    ));
  }
  return out;
}

List<FriendActivity> _parseFeedArgs((String, String, String) args) =>
    parseFriendFeed(args.$1, friend: args.$2, category: args.$3);

/// The friends' list updates: the signed-in user's friends (MAL's own friends page, see
/// [ProfileTabsSource.friends]), then each one's anime and manga RSS feed, two at a time
/// (MALClient's limit), merged newest first. Anonymous pages: no website session needed.
class FriendsActivityApi {
  FriendsActivityApi({
    Future<List<ProfileFriend>> Function(String username)? loadFriends,
    Future<String?> Function(Uri url)? fetchFeed,
    this.maxFriends = 20,
    this.parallel = 2,
    this.maxEntries = 300,
  })  : _loadFriends = loadFriends ?? _defaultFriends,
        _fetchFeed = fetchFeed ?? _defaultFetch;

  static FriendsActivityApi instance = FriendsActivityApi();

  /// Tests parse on the calling isolate.
  @visibleForTesting
  static bool parseInline = false;

  final Future<List<ProfileFriend>> Function(String username) _loadFriends;
  final Future<String?> Function(Uri url) _fetchFeed;

  /// Friends read, the most recently online first (MAL's order otherwise).
  final int maxFriends;
  final int parallel;
  final int maxEntries;

  static Future<List<ProfileFriend>> _defaultFriends(String username) async =>
      (await ProfileTabsSource.friends(username)).friends;

  static Future<String?> _defaultFetch(Uri url) async {
    final response = await http.get(url, headers: {
      'User-Agent': MalWebClient.userAgent,
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 12));
    return response.statusCode == 200 ? response.body : null;
  }

  static Uri feedUrl(String friend, String category) => Uri.parse(
      '${MalWebClient.base}/rss.php?type=${category == 'manga' ? 'rm' : 'rw'}&u=${Uri.encodeQueryComponent(friend)}');

  /// The updates of [username]'s friends, newest first. [onProgress] receives the merged
  /// list after each friend so a screen can show the first rows early. Throws when the
  /// friends list itself cannot be read; a friend whose feed fails is skipped.
  Future<List<FriendActivity>> load(String username,
      {void Function(List<FriendActivity> partial)? onProgress}) async {
    final friends = [...await _loadFriends(username)];
    friends.sort((a, b) {
      final ta = a.lastSeenAt, tb = b.lastSeenAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    final picked = friends.take(maxFriends).toList();
    final merged = <String, FriendActivity>{};
    final queue = [
      for (final f in picked)
        for (final c in const ['anime', 'manga']) (f, c),
    ];
    List<FriendActivity> sorted() {
      final list = merged.values.toList()
        ..sort((a, b) {
          final ta = a.date, tb = b.date;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
      return list.length > maxEntries ? list.sublist(0, maxEntries) : list;
    }

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final (friend, category) = queue.removeAt(0);
        try {
          final xml = await _fetchFeed(feedUrl(friend.username, category));
          if (xml == null) continue;
          final args = (xml, friend.username, category);
          final rows = parseInline ? _parseFeedArgs(args) : await compute(_parseFeedArgs, args);
          for (final row in rows) {
            merged.putIfAbsent(row.key, () => row.withFriendImage(friend.imageUrl));
          }
          onProgress?.call(sorted());
        } catch (e) {
          debugPrint('Friends activity: ${friend.username} $category ($e)');
        }
      }
    }

    await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
    return sorted();
  }
}

String? _str(Object? value) {
  if (value is String) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
  if (value is num) return '$value';
  return null;
}
