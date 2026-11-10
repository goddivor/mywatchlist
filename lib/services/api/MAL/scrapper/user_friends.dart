/// One friend of a MyAnimeList user.
class ProfileFriend {
  final String username;
  final String? imageUrl;

  /// MAL's own wording ("2 hours ago", "Oct 5, 3:12 PM"), shown as is.
  final String? lastOnline;
  final String? friendsSince;

  /// Exact times when MAL gives them (its new friends page); the tile then formats them in
  /// the app's language instead of showing MAL's English wording.
  final DateTime? lastSeenAt;
  final DateTime? friendsSinceAt;

  const ProfileFriend({
    required this.username,
    this.imageUrl,
    this.lastOnline,
    this.friendsSince,
    this.lastSeenAt,
    this.friendsSinceAt,
  });
}

/// Where the next page of MAL's new friends page starts: its "load more" endpoint
/// `/friends/api/list/<userId>.json?last_friend_id=&last_time_added=` pages by the last
/// friend shown, not by number.
class FriendsCursor {
  final int userId;
  final int lastFriendId;
  final int lastTimeAdded;

  const FriendsCursor({
    required this.userId,
    required this.lastFriendId,
    required this.lastTimeAdded,
  });
}

/// A page of friends. MAL's classic page and Jikan return 100 per page; MAL's new page 30.
class ProfileFriendsPage {
  final List<ProfileFriend> friends;
  final bool hasNextPage;

  /// Set when the page came from MAL's new friends page: the next page must be asked with it.
  final FriendsCursor? cursor;

  const ProfileFriendsPage(this.friends, {this.hasNextPage = false, this.cursor});

  static const int pageSize = 100;
}

/// Reads the `data` of a `users/friends` envelope. The backend forwards Jikan's body
/// (`{pagination, data: [...]}`) or, for the HTML parser, `{friends: [...]}`; both are
/// accepted so a backend change cannot blank the tab.
ProfileFriendsPage parseFriendsEnvelope(Map<String, dynamic>? envelope) {
  final payload = envelope?['data'];
  List<dynamic> rows = const [];
  var hasNext = false;
  if (payload is Map) {
    final inner = payload['data'] ?? payload['friends'];
    if (inner is List) rows = inner;
    final pagination = payload['pagination'];
    if (pagination is Map) hasNext = pagination['has_next_page'] == true;
  } else if (payload is List) {
    rows = payload;
  }
  final friends = <ProfileFriend>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final user = row['user'];
    if (user is! Map) continue;
    final name = (user['username'] as String?)?.trim() ?? '';
    if (name.isEmpty) continue;
    final jpg = (user['images'] is Map) ? (user['images'] as Map)['jpg'] : null;
    final image = (jpg is Map ? jpg['image_url'] : null) ?? user['imageUrl'];
    friends.add(ProfileFriend(
      username: name,
      imageUrl: image is String && image.isNotEmpty ? image : null,
      lastOnline: _text(row['last_online'] ?? row['lastOnline']),
      friendsSince: _friendsSinceDate(_text(row['friends_since'] ?? row['friendSince'])),
      lastSeenAt: _unixSeconds(row['lastActivity']),
      friendsSinceAt: _unixSeconds(row['timeAdded']),
    ));
  }
  if (!hasNext && friends.length >= ProfileFriendsPage.pageSize && payload is! Map) {
    hasNext = true;
  }
  return ProfileFriendsPage(friends, hasNextPage: hasNext);
}

DateTime? _unixSeconds(Object? v) =>
    v is int && v > 0 ? DateTime.fromMillisecondsSinceEpoch(v * 1000) : null;

String? _text(Object? v) {
  final s = v is String ? v.trim() : null;
  return (s == null || s.isEmpty) ? null : s;
}

/// MAL's page prints "Friends since May 4, 2008 9:29 PM" while Jikan gives the bare date; the
/// tile adds its own "Friends since", so the prefix goes.
String? _friendsSinceDate(String? v) {
  if (v == null) return null;
  final date = v.replaceFirst(RegExp(r'^Friends since\s*', caseSensitive: false), '').trim();
  return date.isEmpty ? null : date;
}
