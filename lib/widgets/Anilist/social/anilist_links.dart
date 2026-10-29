import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, showToast;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_activity_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_review_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_thread_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_media_card.dart' show openAnilistMedia;

/// What an `anilist.co` link points to.
enum AnilistLinkKind { anime, manga, character, staff, studio, user, thread, comment, activity, review }

/// An `anilist.co` page the app can open itself.
@immutable
class AnilistLink {
  final AnilistLinkKind kind;

  /// The id, or the user name for [AnilistLinkKind.user] (in [name]).
  final int id;
  final String? name;

  /// For a comment link: its thread.
  final int? threadId;

  const AnilistLink(this.kind, {this.id = 0, this.name, this.threadId});

  @override
  bool operator ==(Object other) =>
      other is AnilistLink &&
      other.kind == kind &&
      other.id == id &&
      other.name == name &&
      other.threadId == threadId;

  @override
  int get hashCode => Object.hash(kind, id, name, threadId);

  @override
  String toString() => 'AnilistLink($kind, $id, $name, $threadId)';
}

/// Reads an `anilist.co` URL (absolute, or a path such as `/anime/1` from AniList's HTML).
/// Null for other sites and for AniList pages the app has no screen for.
AnilistLink? parseAnilistLink(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  if (uri.hasScheme || uri.host.isNotEmpty) {
    final host = uri.host.toLowerCase();
    if (host != 'anilist.co' && host != 'www.anilist.co') return null;
  } else if (!uri.path.startsWith('/')) {
    return null;
  }
  final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
  if (parts.length < 2) return null;
  int? number(int i) => i < parts.length ? int.tryParse(parts[i]) : null;
  final id = number(1);
  switch (parts.first.toLowerCase()) {
    case 'anime':
      return id == null ? null : AnilistLink(AnilistLinkKind.anime, id: id);
    case 'manga':
      return id == null ? null : AnilistLink(AnilistLinkKind.manga, id: id);
    case 'character':
      return id == null ? null : AnilistLink(AnilistLinkKind.character, id: id);
    case 'staff':
      return id == null ? null : AnilistLink(AnilistLinkKind.staff, id: id);
    case 'studio':
      return id == null ? null : AnilistLink(AnilistLinkKind.studio, id: id);
    case 'user':
      final name = Uri.decodeComponent(parts[1]);
      return name.isEmpty ? null : AnilistLink(AnilistLinkKind.user, name: name);
    case 'activity':
      return id == null ? null : AnilistLink(AnilistLinkKind.activity, id: id);
    case 'review':
      return id == null ? null : AnilistLink(AnilistLinkKind.review, id: id);
    case 'forum':
      if (parts.length < 3 || parts[1] != 'thread') return null;
      final thread = number(2);
      if (thread == null) return null;
      final comment = parts.length >= 5 && parts[3] == 'comment' ? number(4) : null;
      return comment != null
          ? AnilistLink(AnilistLinkKind.comment, id: comment, threadId: thread)
          : AnilistLink(AnilistLinkKind.thread, id: thread);
  }
  return null;
}

/// Opens an AniList profile inside the app.
Future<void> openAnilistUser(BuildContext context, String? name) async {
  if (name == null || name.isEmpty) return;
  await AppRoutes.openUserProfile(context, tracker: AccountType.anilist, username: name);
}

/// What a tap on a link of AniList's HTML does: titles, users, threads, comments, activities
/// and reviews open their screen in the app; characters, staff and studios (no in-app page
/// yet) and every other site go through [openLink] (asks, then the in-app browser).
Future<void> openAnilistLink(BuildContext context, String url, {AnilistSocialService? service}) async {
  final link = parseAnilistLink(url);
  final absolute = url.startsWith('/') ? 'https://anilist.co$url' : url;
  if (link == null) return openLink(context, absolute);
  switch (link.kind) {
    case AnilistLinkKind.anime:
    case AnilistLinkKind.manga:
      try {
        final media = await (service ?? AnilistSocialService.instance).media(link.id);
        if (!context.mounted) return;
        if (media != null) return openAnilistMedia(context, media);
      } catch (_) {
        showToast(S.current.Al_Load_Failed);
        return;
      }
      if (!context.mounted) return;
      return openLink(context, absolute, confirm: false);
    case AnilistLinkKind.user:
      return openAnilistUser(context, link.name);
    case AnilistLinkKind.thread:
      return openAnilistThread(context, link.id);
    case AnilistLinkKind.comment:
      return openAnilistThread(context, link.threadId!, commentId: link.id);
    case AnilistLinkKind.activity:
      return openAnilistActivity(context, link.id);
    case AnilistLinkKind.review:
      return openAnilistReview(context, link.id);
    case AnilistLinkKind.character:
    case AnilistLinkKind.staff:
    case AnilistLinkKind.studio:
      return openLink(context, absolute, confirm: false);
  }
}
