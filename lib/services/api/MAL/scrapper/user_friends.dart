/// One friend of a MyAnimeList user.
class ProfileFriend {
  final String username;
  final String? imageUrl;

  /// MAL's own wording ("2 hours ago", "Oct 5, 3:12 PM"), shown as is.
  final String? lastOnline;
  final String? friendsSince;

  const ProfileFriend({
    required this.username,
    this.imageUrl,
    this.lastOnline,
    this.friendsSince,
  });
}

/// A page of friends. MAL (through Jikan) returns 100 per page.
class ProfileFriendsPage {
  final List<ProfileFriend> friends;
  final bool hasNextPage;

  const ProfileFriendsPage(this.friends, {this.hasNextPage = false});

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
    ));
  }
  if (!hasNext && friends.length >= ProfileFriendsPage.pageSize && payload is! Map) {
    hasNext = true;
  }
  return ProfileFriendsPage(friends, hasNextPage: hasNext);
}

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
