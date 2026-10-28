import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_notifications_api.dart';

/// The words of one hub item: a [headline] sentence and an optional [detail] line (comment
/// text, friend request message). Shared by the tiles and the system notifications.
typedef MalNotificationWords = ({String headline, String? detail});

/// Describes [item] in the current language.
MalNotificationWords describeMalNotification(MalNotificationItem item, [S? strings]) {
  final s = strings ?? S.current;
  final who = item.actorName ?? s.Mn_Someone;
  String topic() => item.topicTitle ?? item.pageTitle ?? '';
  switch (item.kind) {
    case MalNotificationKind.friendRequest:
      return (headline: s.Mn_Friend_Request(who), detail: item.text);
    case MalNotificationKind.friendRequestAccept:
      return (headline: s.Mn_Friend_Accepted(who), detail: null);
    case MalNotificationKind.friendRequestDeny:
      return (headline: s.Mn_Friend_Denied(who), detail: null);
    case MalNotificationKind.profileComment:
      return (headline: s.Mn_Profile_Comment(who), detail: item.text);
    case MalNotificationKind.blogComment:
      return (headline: s.Mn_Blog_Comment(who), detail: item.text);
    case MalNotificationKind.forumQuote:
      return (headline: s.Mn_Forum_Quote(who, topic()), detail: null);
    case MalNotificationKind.watchedTopicMessage:
      return (headline: s.Mn_Watched_Topic(who, topic()), detail: null);
    case MalNotificationKind.clubMassMessageInForum:
      return (
        headline: s.Mn_Club_Message(item.clubName ?? who, topic()),
        detail: item.actorName,
      );
    case MalNotificationKind.userMentionInForumMessage:
      return (headline: s.Mn_Forum_Mention(who, topic()), detail: null);
    case MalNotificationKind.userMentionInClubComment:
      return (headline: s.Mn_Club_Mention(who, item.pageTitle ?? item.clubName ?? ''), detail: null);
    case MalNotificationKind.relatedAnimeAdd:
      final anime = item.anime;
      final title = anime == null
          ? (item.categoryName ?? '')
          : (anime.mediaType == null ? anime.title : '${anime.title} (${anime.mediaType})');
      return (headline: s.Mn_Related_Anime(title), detail: null);
    case MalNotificationKind.onAir:
      final titles = item.animes.map((a) => a.title).join(', ');
      return (headline: s.Mn_On_Air(titles.isEmpty ? (item.categoryName ?? '') : titles), detail: null);
    case MalNotificationKind.paymentStripe:
      return (headline: s.Mn_Payment(item.planName ?? item.categoryName ?? ''), detail: null);
    case MalNotificationKind.unknown:
      return (headline: item.categoryName ?? s.Mn_Generic, detail: item.text);
  }
}

/// The filter chip label of [group].
String malNotificationGroupLabel(MalNotificationGroup group, [S? strings]) {
  final s = strings ?? S.current;
  return switch (group) {
    MalNotificationGroup.friends => s.Mn_Group_Friends,
    MalNotificationGroup.comments => s.Mn_Group_Comments,
    MalNotificationGroup.forum => s.Mn_Group_Forum,
    MalNotificationGroup.clubs => s.Mn_Group_Clubs,
    MalNotificationGroup.anime => s.Mn_Group_Anime,
    MalNotificationGroup.other => s.Mn_Group_Other,
  };
}

/// The list status of a friend's update in the current language (MAL's own text when the
/// status is unknown).
String friendStatusLabel(FriendActivity a, [S? strings]) {
  final s = strings ?? S.current;
  return switch (a.status) {
    'watching' => s.Watching,
    'reading' => s.Reading,
    'completed' => s.Completed,
    'on_hold' => s.On_Hold,
    'dropped' => s.Dropped,
    'plan_to_watch' => s.Plan_To_Watch,
    'plan_to_read' => s.Plan_To_Read,
    _ => a.statusText ?? '',
  };
}

/// `Ep. 3/12`, `Ch. 40/?`; null when MAL gave no progress.
String? friendProgressLabel(FriendActivity a, [S? strings]) {
  final s = strings ?? S.current;
  final progress = a.progress;
  if (progress == null) return null;
  final total = a.total?.toString() ?? '?';
  return a.category == 'manga'
      ? s.Mn_Progress_Chapters('$progress', total)
      : s.Mn_Progress_Episodes('$progress', total);
}
