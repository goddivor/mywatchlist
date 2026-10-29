import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';

/// What [AnilistActions.toggleFavourite] can mark: each is one argument of AniList's
/// `ToggleFavourite` mutation.
enum AnilistFavouriteKind {
  anime('animeId'),
  manga('mangaId'),
  character('characterId'),
  staff('staffId'),
  studio('studioId');

  const AnilistFavouriteKind(this.argument);

  /// The `ToggleFavourite` argument carrying the id.
  final String argument;
}

/// What [AnilistActions.toggleLike] can like: AniList's `LikeableType`.
enum AnilistLikeable {
  thread('THREAD'),
  threadComment('THREAD_COMMENT'),
  activity('ACTIVITY'),
  activityReply('ACTIVITY_REPLY');

  const AnilistLikeable(this.value);

  /// The `LikeableType` enum value sent to AniList.
  final String value;
}

/// A like after [AnilistActions.toggleLike], as AniList now stores it.
@immutable
class AnilistLikeState {
  final bool isLiked;
  final int likeCount;
  const AnilistLikeState({required this.isLiked, required this.likeCount});

  @override
  bool operator ==(Object other) =>
      other is AnilistLikeState && other.isLiked == isLiked && other.likeCount == likeCount;

  @override
  int get hashCode => Object.hash(isLiked, likeCount);

  @override
  String toString() => 'AnilistLikeState($isLiked, $likeCount)';
}

/// A follow after [AnilistActions.toggleFollow]: whether the signed-in user follows that user,
/// and whether that user follows them back.
@immutable
class AnilistFollowState {
  final bool isFollowing;
  final bool isFollower;
  const AnilistFollowState({required this.isFollowing, required this.isFollower});

  @override
  bool operator ==(Object other) =>
      other is AnilistFollowState &&
      other.isFollowing == isFollowing &&
      other.isFollower == isFollower;

  @override
  int get hashCode => Object.hash(isFollowing, isFollower);

  @override
  String toString() => 'AnilistFollowState($isFollowing, $isFollower)';
}

/// The AniList writes shared by every screen (title, character, staff, studio pages, threads,
/// activities, profiles): favourite, like and follow toggles. Each is one mutation through
/// [AnilistGraphql.mutate] (signed-in user, never replayed); errors are those of `mutate`
/// ([AnilistSessionExpired], [AnilistRateLimited], [AnilistError]).
class AnilistActions {
  AnilistActions({AnilistGraphql? client}) : _client = client;

  /// The actions every screen uses; tests replace it (or pass a fake client).
  static AnilistActions instance = AnilistActions();

  final AnilistGraphql? _client;
  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

  /// Adds the item to the user's favourites, or removes it when it already is one.
  ///
  /// AniList answers with the user's whole favourite lists, not the new state of this item:
  /// the caller flips the `isFavourite` it showed (read from `Media.isFavourite`,
  /// `Character.isFavourite`… with the token).
  Future<void> toggleFavourite(AnilistFavouriteKind kind, int id) async {
    await _gql.mutate(
      'mutation (\$id: Int) { ToggleFavourite(${kind.argument}: \$id) { __typename } }',
      variables: {'id': id},
    );
  }

  /// Likes the item, or removes the like; returns the like as AniList now stores it
  /// (`ToggleLikeV2`: the old `ToggleLike` is deprecated).
  Future<AnilistLikeState> toggleLike(AnilistLikeable type, int id) async {
    const fields = 'isLiked likeCount';
    final data = await _gql.mutate('''
      mutation (\$id: Int, \$type: LikeableType) {
        ToggleLikeV2(id: \$id, type: \$type) {
          ... on ListActivity { $fields }
          ... on TextActivity { $fields }
          ... on MessageActivity { $fields }
          ... on ActivityReply { $fields }
          ... on Thread { $fields }
          ... on ThreadComment { $fields }
        }
      }
    ''', variables: {'id': id, 'type': type.value});
    final liked = data['ToggleLikeV2'];
    if (liked is! Map) throw const AnilistError(404, 'ToggleLikeV2 answered nothing');
    return AnilistLikeState(
      isLiked: liked['isLiked'] == true,
      likeCount: (liked['likeCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Follows the user [userId], or unfollows them; returns the follow as AniList now stores it.
  Future<AnilistFollowState> toggleFollow(int userId) async {
    final data = await _gql.mutate(
      'mutation (\$id: Int) { ToggleFollow(userId: \$id) { id isFollowing isFollower } }',
      variables: {'id': userId},
    );
    final user = data['ToggleFollow'];
    if (user is! Map) throw const AnilistError(404, 'ToggleFollow answered nothing');
    return AnilistFollowState(
      isFollowing: user['isFollowing'] == true,
      isFollower: user['isFollower'] == true,
    );
  }
}
