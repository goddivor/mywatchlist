import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart'
    show AnilistSocialUser;
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';

DateTime? _time(Object? seconds) => seconds is num
    ? DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000)
    : null;

int? _intOrNull(Object? v) => v is num ? v.toInt() : null;

String? _strOrNull(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// The 20 values of AniList's `NotificationType` (checked against the live schema on
/// 2026-10-29), by `__typename` of the `NotificationUnion` member.
enum AnilistNotificationKind {
  airing('AIRING'),
  following('FOLLOWING'),
  activityMessage('ACTIVITY_MESSAGE'),
  activityMention('ACTIVITY_MENTION'),
  activityReply('ACTIVITY_REPLY'),
  activityReplySubscribed('ACTIVITY_REPLY_SUBSCRIBED'),
  activityLike('ACTIVITY_LIKE'),
  activityReplyLike('ACTIVITY_REPLY_LIKE'),
  threadCommentMention('THREAD_COMMENT_MENTION'),
  threadCommentReply('THREAD_COMMENT_REPLY'),
  threadSubscribed('THREAD_SUBSCRIBED'),
  threadCommentLike('THREAD_COMMENT_LIKE'),
  threadLike('THREAD_LIKE'),
  relatedMediaAddition('RELATED_MEDIA_ADDITION'),
  mediaDataChange('MEDIA_DATA_CHANGE'),
  mediaMerge('MEDIA_MERGE'),
  mediaDeletion('MEDIA_DELETION'),
  mediaSubmissionUpdate('MEDIA_SUBMISSION_UPDATE'),
  staffSubmissionUpdate('STAFF_SUBMISSION_UPDATE'),
  characterSubmissionUpdate('CHARACTER_SUBMISSION_UPDATE');

  const AnilistNotificationKind(this.wire);

  /// The `NotificationType` value.
  final String wire;

  static AnilistNotificationKind? fromWire(Object? value) {
    for (final k in values) {
      if (k.wire == value) return k;
    }
    return null;
  }

  /// A notification made by another user (it shows their avatar and name).
  bool get hasUser => switch (this) {
        airing ||
        relatedMediaAddition ||
        mediaDataChange ||
        mediaMerge ||
        mediaDeletion ||
        mediaSubmissionUpdate ||
        staffSubmissionUpdate ||
        characterSubmissionUpdate =>
          false,
        _ => true,
      };

  bool get isActivity => switch (this) {
        activityMessage ||
        activityMention ||
        activityReply ||
        activityReplySubscribed ||
        activityLike ||
        activityReplyLike =>
          true,
        _ => false,
      };

  bool get isThread => switch (this) {
        threadCommentMention ||
        threadCommentReply ||
        threadSubscribed ||
        threadCommentLike ||
        threadLike =>
          true,
        _ => false,
      };
}

/// The filter chips of the inbox, as anilist.co groups the types.
enum AnilistNotificationGroup {
  all(null),
  airing([AnilistNotificationKind.airing]),
  activity([
    AnilistNotificationKind.activityMessage,
    AnilistNotificationKind.activityMention,
    AnilistNotificationKind.activityReply,
    AnilistNotificationKind.activityReplySubscribed,
    AnilistNotificationKind.activityLike,
    AnilistNotificationKind.activityReplyLike,
  ]),
  forum([
    AnilistNotificationKind.threadCommentMention,
    AnilistNotificationKind.threadCommentReply,
    AnilistNotificationKind.threadSubscribed,
    AnilistNotificationKind.threadCommentLike,
    AnilistNotificationKind.threadLike,
  ]),
  follows([AnilistNotificationKind.following]),
  media([
    AnilistNotificationKind.relatedMediaAddition,
    AnilistNotificationKind.mediaDataChange,
    AnilistNotificationKind.mediaMerge,
    AnilistNotificationKind.mediaDeletion,
    AnilistNotificationKind.mediaSubmissionUpdate,
    AnilistNotificationKind.staffSubmissionUpdate,
    AnilistNotificationKind.characterSubmissionUpdate,
  ]);

  const AnilistNotificationGroup(this.kinds);

  /// The types of the group, null for [all] (no `type_in`).
  final List<AnilistNotificationKind>? kinds;
}

/// The title, staff member or character a notification is about.
@immutable
class AnilistNotificationSubject {
  final int id;

  /// `anime`, `manga`, `staff` or `character`.
  final String type;
  final String? title;
  final String? imageUrl;

  const AnilistNotificationSubject({
    required this.id,
    required this.type,
    this.title,
    this.imageUrl,
  });

  bool get isMedia => type == 'anime' || type == 'manga';

  static const String mediaFields = 'id type title { userPreferred } coverImage { medium }';

  static AnilistNotificationSubject? media(Object? json) {
    if (json is! Map) return null;
    final id = _intOrNull(json['id']);
    if (id == null) return null;
    final title = json['title'];
    final cover = json['coverImage'];
    return AnilistNotificationSubject(
      id: id,
      type: json['type'] == 'MANGA' ? 'manga' : 'anime',
      title: title is Map ? _strOrNull(title['userPreferred']) : null,
      imageUrl: cover is Map ? cover['medium'] as String? : null,
    );
  }

  static AnilistNotificationSubject? person(Object? json, String type) {
    if (json is! Map) return null;
    final id = _intOrNull(json['id']);
    if (id == null) return null;
    final name = json['name'];
    final image = json['image'];
    return AnilistNotificationSubject(
      id: id,
      type: type,
      title: name is Map ? _strOrNull(name['userPreferred']) : null,
      imageUrl: image is Map ? image['medium'] as String? : null,
    );
  }
}

/// One entry of the AniList inbox.
@immutable
class AnilistNotification {
  final int id;
  final AnilistNotificationKind? kind;
  final DateTime? createdAt;

  /// Who did it (follows, likes, replies, mentions, messages).
  final AnilistSocialUser? user;

  /// The title (airing, media changes), staff member or character.
  final AnilistNotificationSubject? subject;

  /// Airing: the episode.
  final int? episode;
  final int? activityId;
  final int? threadId;
  final String? threadTitle;
  final int? commentId;

  /// AniList's own English text (after the user name), used for a type the app has no
  /// sentence for.
  final String? context;

  /// Data change, merge, deletion: why. Submission update: the notes.
  final String? reason;

  /// Submission update: its status.
  final String? status;

  /// Merge: the titles that were merged away. Deletion: the title deleted. Submission: the
  /// submitted title.
  final String? otherTitle;

  const AnilistNotification({
    required this.id,
    required this.kind,
    this.createdAt,
    this.user,
    this.subject,
    this.episode,
    this.activityId,
    this.threadId,
    this.threadTitle,
    this.commentId,
    this.context,
    this.reason,
    this.status,
    this.otherTitle,
  });

  /// `contexts` is a list of strings on AniList's side; its parts around the episode and the
  /// title make the English sentence.
  static String? _joinContexts(Object? contexts) {
    if (contexts is List) {
      final parts = contexts.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty);
      return parts.isEmpty ? null : parts.join(' ');
    }
    return _strOrNull(contexts);
  }

  /// The GraphQL selection of every member of the union.
  static const String fields = '''
__typename
... on AiringNotification { id type episode createdAt media { ${AnilistNotificationSubject.mediaFields} } }
... on FollowingNotification { id type context createdAt user { ${AnilistSocialUser.fields} } }
... on ActivityMessageNotification { id type activityId context createdAt user { ${AnilistSocialUser.fields} } }
... on ActivityMentionNotification { id type activityId context createdAt user { ${AnilistSocialUser.fields} } }
... on ActivityReplyNotification { id type activityId context createdAt user { ${AnilistSocialUser.fields} } }
... on ActivityReplySubscribedNotification { id type activityId context createdAt user { ${AnilistSocialUser.fields} } }
... on ActivityLikeNotification { id type activityId context createdAt user { ${AnilistSocialUser.fields} } }
... on ActivityReplyLikeNotification { id type activityId context createdAt user { ${AnilistSocialUser.fields} } }
... on ThreadCommentMentionNotification { id type commentId context createdAt thread { id title } user { ${AnilistSocialUser.fields} } }
... on ThreadCommentReplyNotification { id type commentId context createdAt thread { id title } user { ${AnilistSocialUser.fields} } }
... on ThreadCommentSubscribedNotification { id type commentId context createdAt thread { id title } user { ${AnilistSocialUser.fields} } }
... on ThreadCommentLikeNotification { id type commentId context createdAt thread { id title } user { ${AnilistSocialUser.fields} } }
... on ThreadLikeNotification { id type threadId context createdAt thread { id title } user { ${AnilistSocialUser.fields} } }
... on RelatedMediaAdditionNotification { id type context createdAt media { ${AnilistNotificationSubject.mediaFields} } }
... on MediaDataChangeNotification { id type context reason createdAt media { ${AnilistNotificationSubject.mediaFields} } }
... on MediaMergeNotification { id type context reason deletedMediaTitles createdAt media { ${AnilistNotificationSubject.mediaFields} } }
... on MediaDeletionNotification { id type context reason deletedMediaTitle createdAt }
... on MediaSubmissionUpdateNotification { id type contexts status notes submittedTitle createdAt media { ${AnilistNotificationSubject.mediaFields} } }
... on StaffSubmissionUpdateNotification { id type contexts status notes createdAt staff { id name { userPreferred } image { medium } } }
... on CharacterSubmissionUpdateNotification { id type contexts status notes createdAt character { id name { userPreferred } image { medium } } }
''';

  static AnilistNotification? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _intOrNull(json['id']);
    if (id == null) return null;
    final kind = AnilistNotificationKind.fromWire(json['type']);
    final thread = json['thread'];
    final isSubmission = kind == AnilistNotificationKind.mediaSubmissionUpdate ||
        kind == AnilistNotificationKind.staffSubmissionUpdate ||
        kind == AnilistNotificationKind.characterSubmissionUpdate;
    return AnilistNotification(
      id: id,
      kind: kind,
      createdAt: _time(json['createdAt']),
      user: AnilistSocialUser.fromJson(json['user']),
      subject: AnilistNotificationSubject.media(json['media']) ??
          AnilistNotificationSubject.person(json['staff'], 'staff') ??
          AnilistNotificationSubject.person(json['character'], 'character'),
      episode: _intOrNull(json['episode']),
      activityId: _intOrNull(json['activityId']),
      threadId: _intOrNull(json['threadId']) ?? (thread is Map ? _intOrNull(thread['id']) : null),
      threadTitle: thread is Map ? _strOrNull(thread['title']) : null,
      commentId: _intOrNull(json['commentId']),
      context: _joinContexts(json['context'] ?? json['contexts']),
      reason: isSubmission ? _strOrNull(json['notes']) : _strOrNull(json['reason']),
      status: _strOrNull(json['status']),
      otherTitle: _strOrNull(json['deletedMediaTitles']) ??
          _strOrNull(json['deletedMediaTitle']) ??
          _strOrNull(json['submittedTitle']),
    );
  }
}

/// One page of the inbox.
@immutable
class AnilistNotificationBatch {
  final List<AnilistNotification> items;
  final bool hasNext;

  /// `Viewer.unreadNotificationCount` when the page was read.
  final int unread;

  const AnilistNotificationBatch({
    required this.items,
    required this.hasNext,
    required this.unread,
  });

  /// The date from which the notifications of the first page are unread: the oldest of the
  /// first [unread] items (the whole page when more are unread). Null when none is.
  DateTime? get unreadSince {
    if (unread <= 0 || items.isEmpty) return null;
    final last = items[(unread < items.length ? unread : items.length) - 1];
    return last.createdAt;
  }
}

/// The inbox of the signed-in AniList account (G1 to G3): `Page.notifications` for the 20
/// types, `Viewer.unreadNotificationCount`, and the read mark.
///
/// Reading a page never marks anything: AniList marks the inbox read on a read that passes
/// `resetNotificationCount: true`, which [markRead] does once the page has been shown.
class AnilistNotificationsService {
  AnilistNotificationsService({AnilistGraphql? client, bool? signedIn})
      : _client = client,
        _signedIn = signedIn;

  /// The service every page uses; tests replace it.
  static AnilistNotificationsService instance = AnilistNotificationsService();

  static const int perPage = 30;

  final AnilistGraphql? _client;
  final bool? _signedIn;
  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

  bool get signedIn =>
      _signedIn ?? UserAnilistV2.instance.status == AuthStatus.AUTHENTICATED;

  /// `Viewer.unreadNotificationCount`; 0 when signed out.
  Future<int> unreadCount() async {
    if (!signedIn) return 0;
    final data = await _gql.query('query { Viewer { unreadNotificationCount } }', auth: true);
    final viewer = data['Viewer'];
    return viewer is Map ? _intOrNull(viewer['unreadNotificationCount']) ?? 0 : 0;
  }

  /// One page of [group] (1-based [page]), with the unread count.
  Future<AnilistNotificationBatch> page({
    AnilistNotificationGroup group = AnilistNotificationGroup.all,
    int page = 1,
  }) async {
    final data = await _gql.query(
      '''
query (\$page: Int, \$types: [NotificationType]) {
  Viewer { unreadNotificationCount }
  Page(page: \$page, perPage: $perPage) {
    pageInfo { hasNextPage }
    notifications(type_in: \$types, resetNotificationCount: false) { ${AnilistNotification.fields} }
  }
}''',
      variables: {
        'page': page,
        'types': group.kinds?.map((k) => k.wire).toList(),
      },
      auth: true,
    );
    final viewer = data['Viewer'];
    final result = data['Page'];
    final list = result is Map ? result['notifications'] : null;
    final info = result is Map ? result['pageInfo'] : null;
    return AnilistNotificationBatch(
      items: [
        if (list is List)
          for (final e in list)
            if (AnilistNotification.fromJson(e) case final n?) n,
      ],
      hasNext: info is Map && info['hasNextPage'] == true,
      unread: viewer is Map ? _intOrNull(viewer['unreadNotificationCount']) ?? 0 : 0,
    );
  }

  /// Marks the inbox read (a read with `resetNotificationCount: true`).
  Future<void> markRead() async {
    if (!signedIn) return;
    await _gql.query(
      'query { Page(perPage: 1) { notifications(resetNotificationCount: true) { __typename } } }',
      auth: true,
    );
  }
}

/// The unread count of the AniList badge. Refreshed when the home opens and when the app
/// comes back to the foreground (one cheap request, at most once a minute), never polled.
class AnilistUnreadCount extends ChangeNotifier {
  AnilistUnreadCount({AnilistNotificationsService? service, DateTime Function()? clock})
      : _service = service,
        _clock = clock ?? DateTime.now;

  static AnilistUnreadCount instance = AnilistUnreadCount();

  /// Shortest time between two requests unless a refresh is forced.
  static const Duration minInterval = Duration(minutes: 1);

  final AnilistNotificationsService? _service;
  final DateTime Function() _clock;
  AnilistNotificationsService get _svc => _service ?? AnilistNotificationsService.instance;

  int _count = 0;
  DateTime? _last;
  bool _loading = false;

  int get count => _count;

  void _set(int value) {
    if (value == _count) return;
    _count = value;
    notifyListeners();
  }

  /// Asks AniList for the count. A failure keeps the number on screen.
  Future<void> refresh({bool force = false}) async {
    if (!_svc.signedIn) {
      _last = null;
      _set(0);
      return;
    }
    if (_loading) return;
    final last = _last;
    if (!force && last != null && _clock().difference(last) < minInterval) return;
    _loading = true;
    try {
      final value = await _svc.unreadCount();
      _last = _clock();
      _set(value);
    } catch (_) {
      // Keep the last count: a badge never reports an error.
    } finally {
      _loading = false;
    }
  }

  /// The inbox was read: the badge goes to zero.
  void markedRead() {
    _last = _clock();
    _set(0);
  }
}
