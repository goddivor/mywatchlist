import 'package:flutter/foundation.dart';
import 'package:mwl_commons/mwl_commons.dart'
    show ClubCommentHtml, ClubPageHtml, ClubStaffHtml, ForumTopicHtml, MalNodeRef, MalUserRef;
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';

/// MyAnimeList clubs, read through the MWL backend (`MwlApi`), which parses MAL's HTML pages.
/// The app keeps its own light models ([ClubData], [ClubMember]…): this class only maps the
/// backend ones, nothing is scraped on the device any more.
///
/// A method that fails answers null (page, list of clubs) or throws (the "see all" pages), so
/// a screen can tell "could not load" from "nothing there" and offer Retry.
class MalClubsApi {
  MalClubsApi({MwlApi? api}) : _api = api ?? MwlApi.i;

  final MwlApi _api;

  /// One page of MAL's club list (page starts at 1). Null when the request failed.
  Future<ClubListHtml?> getClubs({int page = 1}) async {
    try {
      final result = await _api.getClubs(page: page);
      final data = result?['data'];
      if (data is Map) {
        return ClubListHtml.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MalClubsApi: getClubs error: $e');
    }
    return null;
  }

  /// The club page (description, members, topics, comments, staff, relations).
  /// Null when it could not be loaded.
  Future<ClubData?> getClubData(int clubId) async {
    try {
      final page = await _api.getClubPage(clubId);
      return page == null ? null : _toClubData(page);
    } catch (e) {
      if (kDebugMode) debugPrint('MalClubsApi: getClubData error: $e');
    }
    return null;
  }

  /// A "see all" page of a club: [type] is `members`, `forum` or `comments`, [offset] MAL's
  /// `show` offset (36, 50 and 20 items per page). Throws when the request fails; an empty
  /// list means MAL had nothing at that offset.
  Future<List<Object>> getClubViewAll(int clubId, String type, int offset) async {
    switch (type) {
      case 'members':
        final members = await _api.getClubMembers(clubId, offset: offset);
        return members.map(_toMember).where((m) => m.username?.isNotEmpty ?? false).toList();
      case 'forum':
        final topics = await _api.getClubForumTopics(clubId, offset: offset);
        return topics.map(_toTopic).toList();
      case 'comments':
        final comments = await _api.getClubComments(clubId, offset: offset);
        return comments.map(_toComment).toList();
      default:
        return const [];
    }
  }

  static ClubData _toClubData(ClubPageHtml page) {
    final details = page.details;
    return ClubData(
      title: page.title,
      information: page.information,
      members: page.members.map(_toMember).where((m) => m.username?.isNotEmpty ?? false).toList(),
      forumTopics: page.forumTopics.map(_toTopic).toList(),
      comments: page.comments.map(_toComment).toList(),
      details: ClubExtra(
        pictureUrl: details.picture?.best,
        members: details.members,
        category: details.category,
        pictures: details.pictures,
        created: details.created,
        staffs: details.staff.map(_toStaff).toList(),
        clubRelations: ClubRelations(
          anime: details.animeRelations.map(_toRelation).toList(),
          manga: details.mangaRelations.map(_toRelation).toList(),
          character: details.characterRelations.map(_toRelation).toList(),
        ),
      ),
    );
  }

  static ClubMember _toMember(MalUserRef user) => ClubMember(
        username: user.username,
        imageUrl: user.image?.best,
      );

  static ClubStaff _toStaff(ClubStaffHtml staff) => ClubStaff(
        user: _toMember(staff.user),
        position: staff.position,
      );

  static ClubRelation _toRelation(MalNodeRef node) =>
      ClubRelation(id: node.id, title: node.title);

  static ClubForumTopic _toTopic(ForumTopicHtml topic) => ClubForumTopic(
        id: topic.id,
        title: topic.title,
        createdBy: topic.createdBy,
        replies: topic.replies?.toString(),
        lastPostBy: topic.lastPostBy,
        lastPostTime: topic.lastPostTime,
      );

  static ClubComment _toComment(ClubCommentHtml comment) => ClubComment(
        id: comment.id,
        by: comment.by == null ? null : _toMember(comment.by!),
        longAgo: comment.longAgo,
        content: comment.content,
      );
}
