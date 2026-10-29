import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart'
    show AnilistThread, AnilistThreadPage;
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';

export 'package:mywatchlist/services/api/Anilist/anilist_actions.dart'
    show AnilistLikeable, AnilistLikeState;
// The page type of `threads()` (AnilistThreadPage) is not re-exported: the name is also the
// thread page widget.
export 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart' show AnilistThread;

DateTime? _time(Object? seconds) => seconds is num
    ? DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000)
    : null;

int _int(Object? v) => v is num ? v.toInt() : 0;

String _str(Object? v) => v is String ? v : '';

/// Someone on AniList, as social rows show them.
@immutable
class AnilistSocialUser {
  final int id;
  final String name;
  final String? avatarUrl;

  const AnilistSocialUser({required this.id, required this.name, this.avatarUrl});

  static const String fields = 'id name avatar { medium }';

  static AnilistSocialUser? fromJson(Object? json) {
    if (json is! Map) return null;
    final avatar = json['avatar'];
    return AnilistSocialUser(
      id: _int(json['id']),
      name: _str(json['name']),
      avatarUrl: avatar is Map ? avatar['medium'] as String? : null,
    );
  }
}

/// A forum category: AniList has no query listing them, the ids are fixed on anilist.co.
@immutable
class AnilistForumCategory {
  final int id;
  final String name;
  const AnilistForumCategory(this.id, this.name);

  /// Every category of the forum, in anilist.co's order (checked 2026-10-29).
  static const List<AnilistForumCategory> all = [
    AnilistForumCategory(1, 'Anime'),
    AnilistForumCategory(2, 'Manga'),
    AnilistForumCategory(3, 'Light Novels'),
    AnilistForumCategory(4, 'Visual Novels'),
    AnilistForumCategory(5, 'Release Discussion'),
    AnilistForumCategory(7, 'General'),
    AnilistForumCategory(8, 'News'),
    AnilistForumCategory(9, 'Music'),
    AnilistForumCategory(10, 'Gaming'),
    AnilistForumCategory(11, 'Site Feedback'),
    AnilistForumCategory(12, 'Bug Reports'),
    AnilistForumCategory(13, 'Site Announcements'),
    AnilistForumCategory(14, 'List Customisation'),
    AnilistForumCategory(15, 'Recommendations'),
    AnilistForumCategory(16, 'Forum Games'),
    AnilistForumCategory(18, 'AniList Apps'),
    AnilistForumCategory(19, 'Events'),
  ];
}

/// What the forum list shows (`Page.threads` arguments). [subscribed] needs the token.
@immutable
class AnilistThreadFilter {
  /// A `ThreadSort` value.
  final String sort;
  final int? categoryId;

  /// Threads about one title (AniList media id).
  final int? mediaId;
  final bool subscribed;
  final String? search;

  const AnilistThreadFilter({
    this.sort = 'REPLIED_AT_DESC',
    this.categoryId,
    this.mediaId,
    this.subscribed = false,
    this.search,
  });

  AnilistThreadFilter copyWith({
    String? sort,
    int? Function()? categoryId,
    bool? subscribed,
    String? Function()? search,
  }) =>
      AnilistThreadFilter(
        sort: sort ?? this.sort,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        mediaId: mediaId,
        subscribed: subscribed ?? this.subscribed,
        search: search != null ? search() : this.search,
      );

  @override
  bool operator ==(Object other) =>
      other is AnilistThreadFilter &&
      other.sort == sort &&
      other.categoryId == categoryId &&
      other.mediaId == mediaId &&
      other.subscribed == subscribed &&
      other.search == search;

  @override
  int get hashCode => Object.hash(sort, categoryId, mediaId, subscribed, search);
}

/// A title a thread, an activity or a review is about.
@immutable
class AnilistMediaRef {
  final int id;
  final String title;
  final String? coverUrl;
  final String? bannerUrl;

  /// `anime` or `manga`.
  final String category;

  const AnilistMediaRef({
    required this.id,
    required this.title,
    required this.category,
    this.coverUrl,
    this.bannerUrl,
  });

  static const String fields =
      'id type title { userPreferred } coverImage { medium large } bannerImage';

  static AnilistMediaRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final title = json['title'];
    final cover = json['coverImage'];
    return AnilistMediaRef(
      id: _int(json['id']),
      title: title is Map ? _str(title['userPreferred']) : '',
      category: json['type'] == 'MANGA' ? 'manga' : 'anime',
      coverUrl: cover is Map ? (cover['large'] ?? cover['medium']) as String? : null,
      bannerUrl: json['bannerImage'] as String?,
    );
  }
}

/// A whole forum thread (`Thread(id)`): the body is AniList's HTML.
@immutable
class AnilistThreadDetail {
  final int id;
  final String title;
  final String bodyHtml;
  final AnilistSocialUser? user;
  final DateTime? createdAt;
  final int replyCount;
  final int viewCount;
  final int likeCount;
  final bool isLiked;
  final bool isSubscribed;
  final bool isLocked;
  final bool isSticky;
  final List<AnilistForumCategory> categories;
  final List<AnilistMediaRef> media;

  const AnilistThreadDetail({
    required this.id,
    required this.title,
    this.bodyHtml = '',
    this.user,
    this.createdAt,
    this.replyCount = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
    this.isSubscribed = false,
    this.isLocked = false,
    this.isSticky = false,
    this.categories = const [],
    this.media = const [],
  });

  String get url => 'https://anilist.co/forum/thread/$id';

  static const String fields = '''
    id title body(asHtml: true) createdAt replyCount viewCount likeCount isLiked isSubscribed
    isLocked isSticky user { ${AnilistSocialUser.fields} } categories { id name }
    mediaCategories { ${AnilistMediaRef.fields} }
  ''';

  factory AnilistThreadDetail.fromJson(Map<String, dynamic> json) => AnilistThreadDetail(
        id: _int(json['id']),
        title: _str(json['title']).trim(),
        bodyHtml: _str(json['body']),
        user: AnilistSocialUser.fromJson(json['user']),
        createdAt: _time(json['createdAt']),
        replyCount: _int(json['replyCount']),
        viewCount: _int(json['viewCount']),
        likeCount: _int(json['likeCount']),
        isLiked: json['isLiked'] == true,
        isSubscribed: json['isSubscribed'] == true,
        isLocked: json['isLocked'] == true,
        isSticky: json['isSticky'] == true,
        categories: [
          for (final c in (json['categories'] as List? ?? const []))
            if (c is Map && c['id'] is num) AnilistForumCategory(_int(c['id']), _str(c['name'])),
        ],
        media: [
          for (final m in (json['mediaCategories'] as List? ?? const []))
            if (AnilistMediaRef.fromJson(m) case final ref?) ref,
        ],
      );

  AnilistThreadDetail copyWith({
    int? likeCount,
    bool? isLiked,
    bool? isSubscribed,
    int? replyCount,
  }) =>
      AnilistThreadDetail(
        id: id,
        title: title,
        bodyHtml: bodyHtml,
        user: user,
        createdAt: createdAt,
        replyCount: replyCount ?? this.replyCount,
        viewCount: viewCount,
        likeCount: likeCount ?? this.likeCount,
        isLiked: isLiked ?? this.isLiked,
        isSubscribed: isSubscribed ?? this.isSubscribed,
        isLocked: isLocked,
        isSticky: isSticky,
        categories: categories,
        media: media,
      );
}

/// A forum comment and its replies (AniList gives the whole tree under each top comment).
@immutable
class AnilistComment {
  final int id;
  final String html;
  final AnilistSocialUser? user;
  final DateTime? createdAt;
  final int likeCount;
  final bool isLiked;
  final bool isLocked;
  final List<AnilistComment> children;

  const AnilistComment({
    required this.id,
    this.html = '',
    this.user,
    this.createdAt,
    this.likeCount = 0,
    this.isLiked = false,
    this.isLocked = false,
    this.children = const [],
  });

  static const String fields = '''
    id comment(asHtml: true) likeCount isLiked isLocked createdAt
    user { ${AnilistSocialUser.fields} } childComments
  ''';

  /// Reads a comment; `childComments` is a JSON scalar of the same shape (with HTML too).
  factory AnilistComment.fromJson(Map json) => AnilistComment(
        id: _int(json['id']),
        html: _str(json['comment']),
        user: AnilistSocialUser.fromJson(json['user']),
        createdAt: _time(json['createdAt']),
        likeCount: _int(json['likeCount']),
        isLiked: json['isLiked'] == true,
        isLocked: json['isLocked'] == true,
        children: [
          for (final c in (json['childComments'] is List ? json['childComments'] as List : const []))
            if (c is Map && c['id'] is num) AnilistComment.fromJson(c),
        ],
      );

  AnilistComment copyWith({
    String? html,
    int? likeCount,
    bool? isLiked,
    List<AnilistComment>? children,
  }) =>
      AnilistComment(
        id: id,
        html: html ?? this.html,
        user: user,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        isLiked: isLiked ?? this.isLiked,
        isLocked: isLocked,
        children: children ?? this.children,
      );

  /// [comments] with the comment [id] (at any depth) replaced by [update]'s result, or
  /// removed when it returns null.
  static List<AnilistComment> updateTree(
    List<AnilistComment> comments,
    int id,
    AnilistComment? Function(AnilistComment comment) update,
  ) {
    final out = <AnilistComment>[];
    for (final c in comments) {
      if (c.id == id) {
        final updated = update(c);
        if (updated != null) out.add(updated);
      } else if (c.children.isEmpty) {
        out.add(c);
      } else {
        out.add(c.copyWith(children: updateTree(c.children, id, update)));
      }
    }
    return out;
  }

  /// Every comment of the tree, this one first, depth first.
  Iterable<AnilistComment> get flattened sync* {
    yield this;
    for (final c in children) {
      yield* c.flattened;
    }
  }
}

/// A page of rows and whether AniList has more (`pageInfo.hasNextPage`: never trust `total`).
@immutable
class AnilistSocialPage<T> {
  final List<T> items;
  final bool hasNext;
  const AnilistSocialPage(this.items, {required this.hasNext});
}

/// AniList's activity kinds (`ActivityType`).
enum AnilistActivityKind { text, list, message }

/// Which activities the feed shows.
enum AnilistFeedScope {
  /// The people the signed-in user follows (and their own), needs the token.
  following,

  /// Everyone: status posts and list updates that have replies, like anilist.co's Global.
  global,
}

/// Activity kinds the feed can be narrowed to.
enum AnilistFeedKind { all, text, list, message }

/// A post of the activity feed: a status (text), a list update or a message.
@immutable
class AnilistActivity {
  final int id;
  final AnilistActivityKind kind;

  /// The author (the messenger for a message).
  final AnilistSocialUser? user;

  /// The receiver of a message.
  final AnilistSocialUser? recipient;

  /// Text or message HTML; empty for a list update.
  final String html;

  /// List update: AniList's English verb ("watched episode", "completed"…) and progress.
  final String? status;
  final String? progress;
  final AnilistMediaRef? media;

  final DateTime? createdAt;
  final int likeCount;
  final int replyCount;
  final bool isLiked;
  final bool isSubscribed;
  final bool isPinned;
  final bool isPrivate;

  /// Filled by [AnilistSocialService.activity] only.
  final List<AnilistActivityReply> replies;

  const AnilistActivity({
    required this.id,
    required this.kind,
    this.user,
    this.recipient,
    this.html = '',
    this.status,
    this.progress,
    this.media,
    this.createdAt,
    this.likeCount = 0,
    this.replyCount = 0,
    this.isLiked = false,
    this.isSubscribed = false,
    this.isPinned = false,
    this.isPrivate = false,
    this.replies = const [],
  });

  String get url => 'https://anilist.co/activity/$id';

  static const _common =
      'id likeCount replyCount isLiked isSubscribed createdAt';

  /// The fields of `ActivityUnion` rows; [replies] adds the replies.
  static String fields({bool replies = false}) {
    final r = replies ? ' replies { ${AnilistActivityReply.fields} }' : '';
    return '''
      __typename
      ... on TextActivity { $_common isPinned text(asHtml: true) user { ${AnilistSocialUser.fields} }$r }
      ... on ListActivity { $_common isPinned status progress user { ${AnilistSocialUser.fields} }
        media { ${AnilistMediaRef.fields} }$r }
      ... on MessageActivity { $_common isPrivate message(asHtml: true)
        messenger { ${AnilistSocialUser.fields} } recipient { ${AnilistSocialUser.fields} }$r }
    ''';
  }

  static AnilistActivity? fromJson(Object? json) {
    if (json is! Map || json['id'] is! num) return null;
    final kind = switch (json['__typename']) {
      'TextActivity' => AnilistActivityKind.text,
      'ListActivity' => AnilistActivityKind.list,
      'MessageActivity' => AnilistActivityKind.message,
      _ => null,
    };
    if (kind == null) return null;
    final message = kind == AnilistActivityKind.message;
    return AnilistActivity(
      id: _int(json['id']),
      kind: kind,
      user: AnilistSocialUser.fromJson(message ? json['messenger'] : json['user']),
      recipient: message ? AnilistSocialUser.fromJson(json['recipient']) : null,
      html: _str(message ? json['message'] : json['text']),
      status: json['status'] as String?,
      progress: json['progress'] as String?,
      media: AnilistMediaRef.fromJson(json['media']),
      createdAt: _time(json['createdAt']),
      likeCount: _int(json['likeCount']),
      replyCount: _int(json['replyCount']),
      isLiked: json['isLiked'] == true,
      isSubscribed: json['isSubscribed'] == true,
      isPinned: json['isPinned'] == true,
      isPrivate: json['isPrivate'] == true,
      replies: [
        for (final r in (json['replies'] as List? ?? const []))
          if (AnilistActivityReply.fromJson(r) case final reply?) reply,
      ],
    );
  }

  AnilistActivity copyWith({
    int? likeCount,
    bool? isLiked,
    bool? isSubscribed,
    bool? isPinned,
    String? html,
    int? replyCount,
    List<AnilistActivityReply>? replies,
  }) =>
      AnilistActivity(
        id: id,
        kind: kind,
        user: user,
        recipient: recipient,
        html: html ?? this.html,
        status: status,
        progress: progress,
        media: media,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        replyCount: replyCount ?? this.replyCount,
        isLiked: isLiked ?? this.isLiked,
        isSubscribed: isSubscribed ?? this.isSubscribed,
        isPinned: isPinned ?? this.isPinned,
        isPrivate: isPrivate,
        replies: replies ?? this.replies,
      );
}

/// A reply under an activity.
@immutable
class AnilistActivityReply {
  final int id;
  final String html;
  final AnilistSocialUser? user;
  final DateTime? createdAt;
  final int likeCount;
  final bool isLiked;

  const AnilistActivityReply({
    required this.id,
    this.html = '',
    this.user,
    this.createdAt,
    this.likeCount = 0,
    this.isLiked = false,
  });

  static const String fields =
      'id text(asHtml: true) likeCount isLiked createdAt user { ${AnilistSocialUser.fields} }';

  static AnilistActivityReply? fromJson(Object? json) {
    if (json is! Map || json['id'] is! num) return null;
    return AnilistActivityReply(
      id: _int(json['id']),
      html: _str(json['text']),
      user: AnilistSocialUser.fromJson(json['user']),
      createdAt: _time(json['createdAt']),
      likeCount: _int(json['likeCount']),
      isLiked: json['isLiked'] == true,
    );
  }

  AnilistActivityReply copyWith({int? likeCount, bool? isLiked, String? html}) =>
      AnilistActivityReply(
        id: id,
        html: html ?? this.html,
        user: user,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        isLiked: isLiked ?? this.isLiked,
      );
}

/// The signed-in user's vote on a review (`ReviewRating`).
enum AnilistReviewVote {
  none('NO_VOTE'),
  up('UP_VOTE'),
  down('DOWN_VOTE');

  const AnilistReviewVote(this.value);
  final String value;

  static AnilistReviewVote of(Object? value) =>
      values.firstWhere((v) => v.value == value, orElse: () => none);
}

/// How the reviews feed is sorted (`ReviewSort`).
enum AnilistReviewSort {
  newest('ID_DESC'),
  helpful('RATING_DESC'),
  highestScore('SCORE_DESC'),
  lowestScore('SCORE'),
  updated('UPDATED_AT_DESC');

  const AnilistReviewSort(this.value);
  final String value;
}

/// An AniList review: [bodyHtml] is only read by [AnilistSocialService.review].
@immutable
class AnilistReview {
  final int id;
  final String summary;
  final String bodyHtml;

  /// The reviewer's score, 0-100.
  final int score;

  /// Users who found it helpful ([rating]) out of all who voted ([ratingAmount]).
  final int rating;
  final int ratingAmount;
  final AnilistReviewVote userRating;
  final bool isPrivate;
  final AnilistSocialUser? user;
  final AnilistMediaRef? media;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AnilistReview({
    required this.id,
    this.summary = '',
    this.bodyHtml = '',
    this.score = 0,
    this.rating = 0,
    this.ratingAmount = 0,
    this.userRating = AnilistReviewVote.none,
    this.isPrivate = false,
    this.user,
    this.media,
    this.createdAt,
    this.updatedAt,
  });

  String get url => 'https://anilist.co/review/$id';

  static const String listFields = '''
    id summary score rating ratingAmount private createdAt updatedAt
    user { ${AnilistSocialUser.fields} } media { ${AnilistMediaRef.fields} }
  ''';

  static const String detailFields = '$listFields body(asHtml: true) userRating';

  static AnilistReview? fromJson(Object? json) {
    if (json is! Map || json['id'] is! num) return null;
    return AnilistReview(
      id: _int(json['id']),
      summary: _str(json['summary']).trim(),
      bodyHtml: _str(json['body']),
      score: _int(json['score']),
      rating: _int(json['rating']),
      ratingAmount: _int(json['ratingAmount']),
      userRating: AnilistReviewVote.of(json['userRating']),
      isPrivate: json['private'] == true,
      user: AnilistSocialUser.fromJson(json['user']),
      media: AnilistMediaRef.fromJson(json['media']),
      createdAt: _time(json['createdAt']),
      updatedAt: _time(json['updatedAt']),
    );
  }

  AnilistReview copyWith({int? rating, int? ratingAmount, AnilistReviewVote? userRating}) =>
      AnilistReview(
        id: id,
        summary: summary,
        bodyHtml: bodyHtml,
        score: score,
        rating: rating ?? this.rating,
        ratingAmount: ratingAmount ?? this.ratingAmount,
        userRating: userRating ?? this.userRating,
        isPrivate: isPrivate,
        user: user,
        media: media,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// AniList's limits for a review (`SaveReview` refuses anything outside them).
abstract final class AnilistReviewRules {
  static const int summaryMin = 20;
  static const int summaryMax = 120;
  static const int bodyMin = 2200;
}

/// The signed-in user's vote on a recommendation (`RecommendationRating`).
enum AnilistRecommendationVote {
  none('NO_RATING'),
  up('RATE_UP'),
  down('RATE_DOWN');

  const AnilistRecommendationVote(this.value);
  final String value;
}

/// Everything social on AniList: forum threads and comments, the activity feed and its
/// replies, reviews, likes, markdown previews, and the writes behind them.
///
/// Reads are public unless noted (`auth: true` when signed in, so `isLiked`,
/// `isSubscribed` and `userRating` are the user's). Writes go through
/// [AnilistGraphql.mutate] (never replayed) and throw its errors ([AnilistSessionExpired],
/// [AnilistRateLimited], [AnilistError]). Likes are [AnilistActions.toggleLike].
class AnilistSocialService {
  AnilistSocialService({AnilistGraphql? client, AnilistActions? actions, bool? signedIn})
      : _client = client,
        _actions = actions,
        _signedIn = signedIn;

  /// The service every page uses; tests replace it.
  static AnilistSocialService instance = AnilistSocialService();

  final AnilistGraphql? _client;
  final AnilistActions? _actions;
  final bool? _signedIn;
  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;
  AnilistActions get _likes => _actions ?? AnilistActions.instance;

  /// True when an AniList account is signed in (reads then carry the token).
  bool get signedIn =>
      _signedIn ?? UserAnilistV2.instance.status == AuthStatus.AUTHENTICATED;

  int? _viewerId;
  String? _viewerName;
  Future<int?>? _viewerLoad;

  /// The signed-in user's AniList id (to tell their own posts apart), null when signed out.
  Future<int?> viewerId() {
    if (!signedIn) return Future.value(null);
    final name = _signedIn == null ? UserAnilistV2.instance.username : null;
    if (_viewerId != null && name == _viewerName) return Future.value(_viewerId);
    return _viewerLoad ??= () async {
      try {
        final data = await _gql.query('query { Viewer { id } }', auth: true);
        final viewer = data['Viewer'];
        _viewerId = viewer is Map ? (viewer['id'] as num?)?.toInt() : null;
        _viewerName = name;
        return _viewerId;
      } catch (_) {
        return null;
      } finally {
        _viewerLoad = null;
      }
    }();
  }

  Future<Map<String, dynamic>> _read(String query, Map<String, dynamic> variables) =>
      _gql.query(query, variables: variables, auth: signedIn);

  static bool _hasNext(Object? page) {
    if (page is! Map) return false;
    final info = page['pageInfo'];
    return info is Map && info['hasNextPage'] == true;
  }

  // ---------------------------------------------------------------- forum

  static const String _threadRow = '''
    id title replyCount viewCount likeCount isSticky isLocked repliedAt createdAt
    user { name avatar { medium } } categories { id name }
  ''';

  /// One page of forum threads matching [filter]; a sticky-first sort puts pinned threads on
  /// top. [AnilistThreadFilter.subscribed] needs the token.
  Future<AnilistThreadPage> threads(AnilistThreadFilter filter,
      {int page = 1, int perPage = 25}) async {
    final search = filter.search?.trim();
    final data = await _read(r'''
      query ($page: Int, $perPage: Int, $sort: [ThreadSort], $categoryId: Int,
          $mediaCategoryId: Int, $subscribed: Boolean, $search: String) {
        Page(page: $page, perPage: $perPage) {
          pageInfo { hasNextPage }
          threads(sort: $sort, categoryId: $categoryId, mediaCategoryId: $mediaCategoryId,
              subscribed: $subscribed, search: $search) { ''' '$_threadRow' r''' }
        }
      }
    ''', {
      'page': page,
      'perPage': perPage,
      'sort': [if (search != null && search.isNotEmpty) 'SEARCH_MATCH', filter.sort],
      if (filter.categoryId != null) 'categoryId': filter.categoryId,
      if (filter.mediaId != null) 'mediaCategoryId': filter.mediaId,
      if (filter.subscribed) 'subscribed': true,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final pageData = data['Page'];
    final rows = pageData is Map ? pageData['threads'] : null;
    return AnilistThreadPage(
      [
        for (final t in (rows is List ? rows : const []))
          if (t is Map<String, dynamic> && t['id'] is num) AnilistThread.fromJson(t),
      ],
      hasNext: _hasNext(pageData),
    );
  }

  /// The thread [id] and the first page of its comments, in one request.
  Future<(AnilistThreadDetail, AnilistSocialPage<AnilistComment>)> thread(int id,
      {int perPage = 25}) async {
    final result = await _gql.batch({
      'thread': 'Thread(id: \$id) { ${AnilistThreadDetail.fields} }',
      'comments': 'Page(page: 1, perPage: \$perPage) { pageInfo { hasNextPage } '
          'threadComments(threadId: \$id, sort: ID) { ${AnilistComment.fields} } }',
    }, variables: {
      'id': GqlVar('Int', id),
      'perPage': GqlVar('Int', perPage),
    }, auth: signedIn);
    return (
      AnilistThreadDetail.fromJson(result.require('thread')),
      _commentsOf(result['comments']),
    );
  }

  /// Page [page] (from 1) of the comments of thread [threadId], oldest first like anilist.co.
  Future<AnilistSocialPage<AnilistComment>> comments(int threadId,
      {int page = 1, int perPage = 25}) async {
    final data = await _read('''
      query (\$id: Int, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { hasNextPage }
          threadComments(threadId: \$id, sort: ID) { ${AnilistComment.fields} }
        }
      }
    ''', {'id': threadId, 'page': page, 'perPage': perPage});
    return _commentsOf(data['Page']);
  }

  static AnilistSocialPage<AnilistComment> _commentsOf(Object? page) {
    final rows = page is Map ? page['threadComments'] : null;
    return AnilistSocialPage(
      [
        for (final c in (rows is List ? rows : const []))
          if (c is Map && c['id'] is num) AnilistComment.fromJson(c),
      ],
      hasNext: _hasNext(page),
    );
  }

  /// Posts a comment on thread [threadId] (a reply to [parentId] when given), or edits the
  /// comment [id]. [markdown] is AniList markdown. Returns the comment as stored.
  Future<AnilistComment> saveComment({
    required int threadId,
    required String markdown,
    int? parentId,
    int? id,
  }) async {
    final data = await _gql.mutate('''
      mutation (\$id: Int, \$threadId: Int, \$parentCommentId: Int, \$comment: String) {
        SaveThreadComment(id: \$id, threadId: \$threadId, parentCommentId: \$parentCommentId,
            comment: \$comment) { ${AnilistComment.fields} }
      }
    ''', variables: {
      if (id != null) 'id': id,
      'threadId': threadId,
      if (parentId != null) 'parentCommentId': parentId,
      'comment': markdown,
    });
    final saved = data['SaveThreadComment'];
    if (saved is! Map) throw const AnilistError(404, 'SaveThreadComment answered nothing');
    return AnilistComment.fromJson(saved);
  }

  Future<void> deleteComment(int id) =>
      _delete('DeleteThreadComment', id);

  /// Subscribes to thread [threadId] (notifications for new comments), or unsubscribes.
  /// Returns the new state.
  Future<bool> setThreadSubscription(int threadId, bool subscribe) async {
    final data = await _gql.mutate(r'''
      mutation ($threadId: Int, $subscribe: Boolean) {
        ToggleThreadSubscription(threadId: $threadId, subscribe: $subscribe) { id isSubscribed }
      }
    ''', variables: {'threadId': threadId, 'subscribe': subscribe});
    final thread = data['ToggleThreadSubscription'];
    return thread is Map ? thread['isSubscribed'] == true : subscribe;
  }

  /// Creates a thread (or edits thread [id]); returns its id.
  Future<int> saveThread({
    required String title,
    required String markdown,
    List<int> categories = const [],
    List<int> mediaIds = const [],
    int? id,
  }) async {
    final data = await _gql.mutate(r'''
      mutation ($id: Int, $title: String, $body: String, $categories: [Int], $media: [Int]) {
        SaveThread(id: $id, title: $title, body: $body, categories: $categories,
            mediaCategories: $media) { id }
      }
    ''', variables: {
      if (id != null) 'id': id,
      'title': title,
      'body': markdown,
      'categories': categories,
      'media': mediaIds,
    });
    final thread = data['SaveThread'];
    final saved = thread is Map ? (thread['id'] as num?)?.toInt() : null;
    if (saved == null) throw const AnilistError(404, 'SaveThread answered nothing');
    return saved;
  }

  // ------------------------------------------------------------- activity

  /// One page of the activity feed. [AnilistFeedScope.following] needs the token; messages
  /// only exist in it (the Global feed has status posts and list updates).
  Future<AnilistSocialPage<AnilistActivity>> activities({
    AnilistFeedScope scope = AnilistFeedScope.global,
    AnilistFeedKind kind = AnilistFeedKind.all,
    int? userId,
    int? mediaId,
    int page = 1,
    int perPage = 25,
  }) async {
    final types = switch (kind) {
      AnilistFeedKind.all => null,
      AnilistFeedKind.text => ['TEXT'],
      AnilistFeedKind.list => ['ANIME_LIST', 'MANGA_LIST'],
      AnilistFeedKind.message => ['MESSAGE'],
    };
    final following = scope == AnilistFeedScope.following && userId == null;
    final data = await _read('''
      query (\$page: Int, \$perPage: Int, \$following: Boolean, \$hasReplies: Boolean,
          \$types: [ActivityType], \$userId: Int, \$mediaId: Int) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { hasNextPage }
          activities(sort: [PINNED, ID_DESC], isFollowing: \$following, type_in: \$types,
              hasRepliesOrTypeText: \$hasReplies, userId: \$userId, mediaId: \$mediaId) {
            ${AnilistActivity.fields()}
          }
        }
      }
    ''', {
      'page': page,
      'perPage': perPage,
      if (following) 'following': true,
      // anilist.co's Global feed: status posts, and list updates people replied to.
      if (!following && userId == null && mediaId == null && kind != AnilistFeedKind.list)
        'hasReplies': true,
      if (types != null) 'types': types,
      if (userId != null) 'userId': userId,
      if (mediaId != null) 'mediaId': mediaId,
    });
    final pageData = data['Page'];
    final rows = pageData is Map ? pageData['activities'] : null;
    return AnilistSocialPage(
      [
        for (final a in (rows is List ? rows : const []))
          if (AnilistActivity.fromJson(a) case final activity?) activity,
      ],
      hasNext: _hasNext(pageData),
    );
  }

  /// The activity [id] with all its replies.
  Future<AnilistActivity> activity(int id) async {
    final data = await _read('''
      query (\$id: Int) { Activity(id: \$id) { ${AnilistActivity.fields(replies: true)} } }
    ''', {'id': id});
    return AnilistActivity.fromJson(data['Activity']) ??
        (throw const AnilistError(404, 'No activity'));
  }

  /// Posts a status (or edits the status [id]); returns it as stored.
  Future<AnilistActivity> saveStatus(String markdown, {int? id}) async {
    final data = await _gql.mutate('''
      mutation (\$id: Int, \$text: String) {
        SaveTextActivity(id: \$id, text: \$text) {
          __typename id likeCount replyCount isLiked isSubscribed isPinned createdAt
          text(asHtml: true) user { ${AnilistSocialUser.fields} }
        }
      }
    ''', variables: {if (id != null) 'id': id, 'text': markdown});
    return AnilistActivity.fromJson(data['SaveTextActivity']) ??
        (throw const AnilistError(404, 'SaveTextActivity answered nothing'));
  }

  Future<void> deleteActivity(int id) => _delete('DeleteActivity', id);

  /// Replies to activity [activityId] (or edits the reply [id]); returns it as stored.
  Future<AnilistActivityReply> saveReply({
    required int activityId,
    required String markdown,
    int? id,
  }) async {
    final data = await _gql.mutate('''
      mutation (\$id: Int, \$activityId: Int, \$text: String) {
        SaveActivityReply(id: \$id, activityId: \$activityId, text: \$text) {
          ${AnilistActivityReply.fields}
        }
      }
    ''', variables: {if (id != null) 'id': id, 'activityId': activityId, 'text': markdown});
    return AnilistActivityReply.fromJson(data['SaveActivityReply']) ??
        (throw const AnilistError(404, 'SaveActivityReply answered nothing'));
  }

  Future<void> deleteReply(int id) => _delete('DeleteActivityReply', id);

  /// Pins the activity [id] on the user's profile, or unpins it. Returns the new state.
  Future<bool> setActivityPinned(int id, bool pinned) async {
    final data = await _gql.mutate(r'''
      mutation ($id: Int, $pinned: Boolean) {
        ToggleActivityPin(id: $id, pinned: $pinned) {
          ... on TextActivity { isPinned } ... on ListActivity { isPinned }
        }
      }
    ''', variables: {'id': id, 'pinned': pinned});
    final a = data['ToggleActivityPin'];
    return a is Map && a.containsKey('isPinned') ? a['isPinned'] == true : pinned;
  }

  /// Subscribes to the activity [id] (notified of replies), or unsubscribes.
  Future<bool> setActivitySubscription(int id, bool subscribe) async {
    final data = await _gql.mutate(r'''
      mutation ($id: Int, $subscribe: Boolean) {
        ToggleActivitySubscription(activityId: $id, subscribe: $subscribe) {
          ... on TextActivity { isSubscribed } ... on ListActivity { isSubscribed }
          ... on MessageActivity { isSubscribed }
        }
      }
    ''', variables: {'id': id, 'subscribe': subscribe});
    final a = data['ToggleActivitySubscription'];
    return a is Map && a.containsKey('isSubscribed') ? a['isSubscribed'] == true : subscribe;
  }

  // -------------------------------------------------------------- reviews

  /// One page of reviews: of title [mediaId], by user [userId], of one [mediaType]
  /// (`ANIME` | `MANGA`) or all of them.
  Future<AnilistSocialPage<AnilistReview>> reviews({
    int? mediaId,
    int? userId,
    String? mediaType,
    AnilistReviewSort sort = AnilistReviewSort.newest,
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _read('''
      query (\$page: Int, \$perPage: Int, \$mediaId: Int, \$userId: Int, \$type: MediaType,
          \$sort: [ReviewSort]) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { hasNextPage }
          reviews(mediaId: \$mediaId, userId: \$userId, mediaType: \$type, sort: \$sort) {
            ${AnilistReview.listFields}
          }
        }
      }
    ''', {
      'page': page,
      'perPage': perPage,
      if (mediaId != null) 'mediaId': mediaId,
      if (userId != null) 'userId': userId,
      if (mediaType != null) 'type': mediaType,
      'sort': [sort.value],
    });
    final pageData = data['Page'];
    final rows = pageData is Map ? pageData['reviews'] : null;
    return AnilistSocialPage(
      [
        for (final r in (rows is List ? rows : const []))
          if (AnilistReview.fromJson(r) case final review?) review,
      ],
      hasNext: _hasNext(pageData),
    );
  }

  /// The whole review [id] (body as HTML, the user's vote when signed in).
  Future<AnilistReview> review(int id) async {
    final data = await _read('''
      query (\$id: Int) { Review(id: \$id) { ${AnilistReview.detailFields} } }
    ''', {'id': id});
    return AnilistReview.fromJson(data['Review']) ??
        (throw const AnilistError(404, 'No review'));
  }

  /// The signed-in user's review of title [mediaId] with its markdown source (to edit it),
  /// null when they have none.
  Future<({AnilistReview review, String markdown})?> myReview(int mediaId) async {
    final viewer = await viewerId();
    if (viewer == null) return null;
    final data = await _gql.query('''
      query (\$mediaId: Int, \$userId: Int) {
        Page(perPage: 1) {
          reviews(mediaId: \$mediaId, userId: \$userId) { ${AnilistReview.listFields} source: body }
        }
      }
    ''', variables: {'mediaId': mediaId, 'userId': viewer}, auth: true);
    final page = data['Page'];
    final rows = page is Map ? page['reviews'] : null;
    if (rows is! List || rows.isEmpty || rows.first is! Map) return null;
    final review = AnilistReview.fromJson(rows.first);
    if (review == null) return null;
    return (review: review, markdown: _str((rows.first as Map)['source']));
  }

  /// Votes on review [id]; returns the review's new helpful counts and vote.
  Future<AnilistReview> rateReview(int id, AnilistReviewVote vote) async {
    final data = await _gql.mutate(r'''
      mutation ($id: Int, $rating: ReviewRating) {
        RateReview(reviewId: $id, rating: $rating) { id rating ratingAmount userRating }
      }
    ''', variables: {'id': id, 'rating': vote.value});
    final r = data['RateReview'];
    if (r is! Map) throw const AnilistError(404, 'RateReview answered nothing');
    return AnilistReview(
      id: id,
      rating: _int(r['rating']),
      ratingAmount: _int(r['ratingAmount']),
      userRating: AnilistReviewVote.of(r['userRating']),
    );
  }

  /// Writes the user's review of title [mediaId] (or edits review [id]); [score] is 0-100.
  /// Returns the review id. See [AnilistReviewRules] for the lengths AniList accepts.
  Future<int> saveReview({
    required int mediaId,
    required String summary,
    required String markdown,
    required int score,
    bool isPrivate = false,
    int? id,
  }) async {
    final data = await _gql.mutate(r'''
      mutation ($id: Int, $mediaId: Int, $body: String, $summary: String, $score: Int,
          $private: Boolean) {
        SaveReview(id: $id, mediaId: $mediaId, body: $body, summary: $summary, score: $score,
            private: $private) { id }
      }
    ''', variables: {
      if (id != null) 'id': id,
      'mediaId': mediaId,
      'body': markdown,
      'summary': summary,
      'score': score,
      'private': isPrivate,
    });
    final r = data['SaveReview'];
    final saved = r is Map ? (r['id'] as num?)?.toInt() : null;
    if (saved == null) throw const AnilistError(404, 'SaveReview answered nothing');
    return saved;
  }

  Future<void> deleteReview(int id) => _delete('DeleteReview', id);

  // --------------------------------------------------------------- shared

  /// Likes or unlikes; see [AnilistActions.toggleLike].
  Future<AnilistLikeState> toggleLike(AnilistLikeable type, int id) => _likes.toggleLike(type, id);

  /// Who liked a thread, comment, activity or reply.
  Future<AnilistSocialPage<AnilistSocialUser>> likes(AnilistLikeable type, int id,
      {int page = 1, int perPage = 50}) async {
    final data = await _read('''
      query (\$id: Int, \$type: LikeableType, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { hasNextPage }
          likes(likeableId: \$id, type: \$type) { ${AnilistSocialUser.fields} }
        }
      }
    ''', {'id': id, 'type': type.value, 'page': page, 'perPage': perPage});
    final pageData = data['Page'];
    final rows = pageData is Map ? pageData['likes'] : null;
    return AnilistSocialPage(
      [
        for (final u in (rows is List ? rows : const []))
          if (AnilistSocialUser.fromJson(u) case final user?) user,
      ],
      hasNext: _hasNext(pageData),
    );
  }

  /// The markdown of the user's own status [id] (to edit it).
  Future<String> statusSource(int id) async {
    final data = await _gql.query(
      r'query ($id: Int) { Activity(id: $id) { ... on TextActivity { text(asHtml: false) } } }',
      variables: {'id': id},
      auth: true,
    );
    final a = data['Activity'];
    return a is Map ? _str(a['text']) : '';
  }

  /// The markdown of the user's own forum comment [id] of thread [threadId], null when it
  /// cannot be found.
  ///
  /// AniList ignores `id` in `threadComments` and `ThreadComment` (checked 2026-10-29: any id
  /// answers the thread's first comment), so this walks the user's own comments of the thread,
  /// newest first (with the replies under them), at most [maxPages] pages of 50.
  Future<String?> commentSource(int threadId, int id, {int maxPages = 4}) async {
    final viewer = await viewerId();
    if (viewer == null) return null;
    for (var page = 1; page <= maxPages; page++) {
      final data = await _gql.query(r'''
        query ($threadId: Int, $userId: Int, $page: Int) {
          Page(page: $page, perPage: 50) {
            pageInfo { hasNextPage }
            threadComments(threadId: $threadId, userId: $userId, sort: ID_DESC) {
              id comment(asHtml: false) childComments
            }
          }
        }
      ''', variables: {'threadId': threadId, 'userId': viewer, 'page': page}, auth: true);
      final pageData = data['Page'];
      final rows = pageData is Map ? pageData['threadComments'] : null;
      for (final row in (rows is List ? rows : const [])) {
        if (row is! Map) continue;
        for (final c in AnilistComment.fromJson(row).flattened) {
          if (c.id == id) return c.html;
        }
      }
      if (!_hasNext(pageData)) break;
    }
    return null;
  }

  /// The markdown of the user's own activity reply [id].
  Future<String> replySource(int id) async {
    final data = await _gql.query(
      r'query ($id: Int) { ActivityReply(id: $id) { text(asHtml: false) } }',
      variables: {'id': id},
      auth: true,
    );
    final r = data['ActivityReply'];
    return r is Map ? _str(r['text']) : '';
  }

  /// AniList's own rendering of a [markdown] draft (the preview before posting).
  Future<String> preview(String markdown) async {
    if (markdown.trim().isEmpty) return '';
    final data = await _gql.query(
      r'query ($m: String) { Markdown(markdown: $m) { html } }',
      variables: {'m': markdown},
    );
    final md = data['Markdown'];
    return md is Map ? _str(md['html']) : '';
  }

  /// A title for an in-app link (`anilist.co/anime/<id>`), null when AniList has none.
  Future<AnilistMedia?> media(int id) async {
    final data = await _gql.query(
      'query (\$id: Int) { Media(id: \$id) { ${AnilistMedia.fields} } }',
      variables: {'id': id},
    );
    final m = data['Media'];
    return m is Map<String, dynamic> ? AnilistMedia.fromJson(m) : null;
  }

  /// Votes on recommending [recommendationId] to fans of [mediaId] (also creates the
  /// recommendation when nobody made it yet). For the title page.
  Future<void> rateRecommendation(
      int mediaId, int recommendationId, AnilistRecommendationVote vote) async {
    await _gql.mutate(r'''
      mutation ($mediaId: Int, $recId: Int, $rating: RecommendationRating) {
        SaveRecommendation(mediaId: $mediaId, mediaRecommendationId: $recId, rating: $rating) {
          id rating userRating
        }
      }
    ''', variables: {'mediaId': mediaId, 'recId': recommendationId, 'rating': vote.value});
  }

  Future<void> _delete(String mutation, int id) async {
    final data = await _gql.mutate(
      'mutation (\$id: Int) { $mutation(id: \$id) { deleted } }',
      variables: {'id': id},
    );
    final d = data[mutation];
    if (d is! Map || d['deleted'] != true) {
      throw AnilistError(400, '$mutation did not delete');
    }
  }
}
