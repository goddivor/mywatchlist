import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';

/// One user in a follower list or a user search.
@immutable
class AnilistUserRow {
  final int id;
  final String name;
  final String? avatarUrl;

  /// The signed-in user follows this user (false when signed out).
  final bool isFollowing;

  /// This user follows the signed-in user.
  final bool isFollower;

  const AnilistUserRow({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isFollowing = false,
    this.isFollower = false,
  });

  AnilistUserRow copyWith({bool? isFollowing, bool? isFollower}) => AnilistUserRow(
        id: id,
        name: name,
        avatarUrl: avatarUrl,
        isFollowing: isFollowing ?? this.isFollowing,
        isFollower: isFollower ?? this.isFollower,
      );

  static AnilistUserRow? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! num || raw['name'] is! String) return null;
    final avatar = raw['avatar'];
    return AnilistUserRow(
      id: (raw['id'] as num).toInt(),
      name: raw['name'] as String,
      avatarUrl: avatar is Map ? avatar['large'] as String? : null,
      isFollowing: raw['isFollowing'] == true,
      isFollower: raw['isFollower'] == true,
    );
  }
}

/// A page of users.
@immutable
class AnilistUserPageResult {
  final List<AnilistUserRow> users;
  final bool hasNext;

  /// `pageInfo.total` when AniList gives it.
  final int? total;
  const AnilistUserPageResult(this.users, {required this.hasNext, this.total});
}

/// How a social list is read: who follows the user, whom they follow, or the users both
/// sides have in common with the signed-in user.
enum AnilistSocialList { followers, following, mutual }

/// Followers, following, mutuals, follow and unfollow, and profile messages.
///
/// Reads need no account (the follow flags need one); every write is one mutation sent once,
/// run only from a tap of the signed-in user ([AnilistGraphql.mutate]).
class AnilistFollowService {
  AnilistFollowService({AnilistGraphql? client, AnilistActions? actions, bool? signedIn})
      : _client = client,
        _actions = actions,
        _signedIn = signedIn;

  static AnilistFollowService instance = AnilistFollowService();

  final AnilistGraphql? _client;
  final AnilistActions? _actions;
  final bool? _signedIn;

  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;
  AnilistActions get _act => _actions ?? AnilistActions.instance;

  bool get signedIn =>
      _signedIn ?? UserAnilistV2.instance.status == AuthStatus.AUTHENTICATED;

  static const String _userFields = 'id name avatar { large } isFollowing isFollower';

  /// Followers and following totals of [userId], null for a count AniList did not give.
  Future<({int? followers, int? following})> counts(int userId) async {
    final data = await _gql.query('''
      query (\$id: Int!) {
        followers: Page(perPage: 1) { pageInfo { total } followers(userId: \$id) { id } }
        following: Page(perPage: 1) { pageInfo { total } following(userId: \$id) { id } }
      }
    ''', variables: {'id': userId}, auth: signedIn);
    int? total(Object? page) {
      final info = page is Map ? page['pageInfo'] : null;
      return info is Map ? (info['total'] as num?)?.toInt() : null;
    }

    return (followers: total(data['followers']), following: total(data['following']));
  }

  /// One page of [list] of [userId]. AniList has no mutual query: on the own profile
  /// ([self]) the mutuals are the users you follow who follow you back, on another profile
  /// the followers you also follow. They are cut from a plain page, so a page may hold fewer
  /// users than [perPage] (or none) while [AnilistUserPageResult.hasNext].
  Future<AnilistUserPageResult> users(
    int userId,
    AnilistSocialList list, {
    int page = 1,
    int perPage = 30,
    bool self = false,
  }) async {
    final root = list == AnilistSocialList.following || (list == AnilistSocialList.mutual && self)
        ? 'following'
        : 'followers';
    final data = await _gql.query('''
      query (\$id: Int!, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { hasNextPage total }
          $root(userId: \$id, sort: USERNAME) { $_userFields }
        }
      }
    ''', variables: {'id': userId, 'page': page, 'perPage': perPage}, auth: signedIn);
    final result = parsePage(data['Page'], root);
    if (list != AnilistSocialList.mutual) return result;
    // Own profile: a mutual follows you back; another profile: a follower you also follow.
    final keep = <AnilistUserRow>[
      for (final u in result.users)
        if (self ? u.isFollower : u.isFollowing) u,
    ];
    return AnilistUserPageResult(keep, hasNext: result.hasNext, total: null);
  }

  @visibleForTesting
  static AnilistUserPageResult parsePage(Object? page, String root) {
    if (page is! Map) return const AnilistUserPageResult([], hasNext: false);
    final info = page['pageInfo'];
    final rows = page[root];
    return AnilistUserPageResult(
      [
        if (rows is List)
          for (final r in rows)
            if (AnilistUserRow.fromJson(r) case final u?) u,
      ],
      hasNext: info is Map && info['hasNextPage'] == true,
      total: info is Map ? (info['total'] as num?)?.toInt() : null,
    );
  }

  /// Follows or unfollows [userId]; the follow as AniList stores it afterwards.
  Future<AnilistFollowState> toggleFollow(int userId) => _act.toggleFollow(userId);

  /// Sends [message] to [recipientId] on their profile (`SaveMessageActivity`); [private]
  /// makes it visible to the two of you only. Returns the new activity's id.
  Future<int> sendMessage(int recipientId, String message, {bool private = false}) async {
    final text = message.trim();
    if (text.isEmpty) throw ArgumentError('empty message');
    final data = await _gql.mutate('''
      mutation (\$to: Int, \$message: String, \$private: Boolean) {
        SaveMessageActivity(recipientId: \$to, message: \$message, private: \$private) { id }
      }
    ''', variables: {'to': recipientId, 'message': text, 'private': private});
    final saved = data['SaveMessageActivity'];
    if (saved is! Map) throw const AnilistError(404, 'SaveMessageActivity answered nothing');
    return (saved['id'] as num?)?.toInt() ?? 0;
  }

  /// Users matching [search], best match first (`Page.users`).
  Future<AnilistUserPageResult> searchUsers(String search,
      {int page = 1, int perPage = 30}) async {
    final text = search.trim();
    if (text.isEmpty) return const AnilistUserPageResult([], hasNext: false);
    final data = await _gql.query('''
      query (\$q: String, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { hasNextPage total }
          users(search: \$q, sort: SEARCH_MATCH) { $_userFields }
        }
      }
    ''', variables: {'q': text, 'page': page, 'perPage': perPage}, auth: signedIn);
    return parsePage(data['Page'], 'users');
  }
}
