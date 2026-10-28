import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';

/// One comment of a MAL profile (or of a comment-to-comment conversation).
@immutable
class ProfileComment {
  final int id;
  final String author;
  final String? avatarUrl;

  /// MAL's own date text (`Oct 30, 2023 8:44 PM`, `Yesterday, 1:47 PM`, `5 hours ago`).
  final String? date;

  /// The comment body as MAL renders it (HTML from BBCode).
  final String html;

  /// `https://myanimelist.net/comtocom.php?id1=…&id2=…`, shown to a signed-in viewer.
  final String? conversationUrl;

  /// MAL offers to delete it (your own profile, or a comment you wrote).
  final bool canDelete;

  /// MAL offers to reply: the reply is a comment on the author's profile (member id).
  final int? replyToMemberId;

  const ProfileComment({
    required this.id,
    required this.author,
    required this.html,
    this.avatarUrl,
    this.date,
    this.conversationUrl,
    this.canDelete = false,
    this.replyToMemberId,
  });
}

/// The comments block of a profile, or one page of `comments.php`.
@immutable
class ProfileCommentsPage {
  final List<ProfileComment> comments;

  /// The numeric MAL member id (needed to post and to page through `comments.php`).
  final int? memberId;

  /// "All Comments (N)" / "N Comments", when MAL prints it.
  final int? total;

  /// The page has MAL's comment form: the viewer is signed in and may comment.
  final bool canPost;

  /// The profile user name as MAL spells it (from the form), when known.
  final String? profileUsername;

  const ProfileCommentsPage({
    required this.comments,
    this.memberId,
    this.total,
    this.canPost = false,
    this.profileUsername,
  });
}

/// A comment-to-comment conversation between two members.
@immutable
class CommentConversation {
  final List<ProfileComment> comments;

  /// The two user names of the header, in MAL's order (id1, id2).
  final List<String> usernames;

  /// The two member ids of the URL (id1, id2).
  final List<int> memberIds;

  const CommentConversation({
    required this.comments,
    required this.usernames,
    required this.memberIds,
  });

  /// The member id of the other participant than [me], for a reply.
  int? otherMemberId(String? me) {
    if (memberIds.length != 2 || usernames.length != 2 || me == null) return null;
    final mine = usernames.indexWhere((u) => u.toLowerCase() == me.toLowerCase());
    if (mine < 0) return null;
    return memberIds[1 - mine];
  }
}

final RegExp _memIdInComments = RegExp(r'comments\.php\?id=(\d+)');
final RegExp _memIdInReport = RegExp(r'go=report&(?:amp;)?type=profile&(?:amp;)?id=(\d+)');
final RegExp _memIdInGa = RegExp(r'uid:(\d+)');
final RegExp _allCount = RegExp(r'All Comments \((\d[\d,]*)\)');
final RegExp _listCount = RegExp(r'(\d[\d,]*)\s+Comments', caseSensitive: false);

int? _int(String? s) => s == null ? null : int.tryParse(s.replaceAll(',', ''));

String _text(Element? e) => (e?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

String? _src(Element? img) {
  if (img == null) return null;
  final src = img.attributes['data-src'] ?? img.attributes['src'];
  return (src == null || src.isEmpty || src.startsWith('data:')) ? null : src;
}

/// Reads one `div.comment[data-id]` of either layout: the profile block
/// (`a.fw-b`, `span.fn-grey1`, `div.comment-text`) or `comments.php` / `comtocom.php`
/// (`div.dark_text a`, `small`, `div.comment-text`). Action links are those MAL's own
/// scripts bind (`js-profile-comment-delete`, `js-profile-comment-reply[data-user-id]`).
ProfileComment? parseCommentElement(Element node) {
  final id = int.tryParse(node.attributes['data-id'] ?? '');
  if (id == null) return null;
  final authorLink = node.querySelector('a.fw-b') ??
      node.querySelector('.dark_text a') ??
      node.querySelector('.spaceit strong a') ??
      node.querySelector('.text a');
  final author = _text(authorLink);
  if (author.isEmpty) return null;
  final dateNode = node.querySelector('span.fn-grey1') ?? node.querySelector('.dark_text small') ?? node.querySelector('small');
  var date = _text(dateNode);
  if (date.startsWith('|')) date = date.substring(1).trim();
  final body = node.querySelector('div.comment-text');
  final conversation = node.querySelectorAll('a').map((a) => a.attributes['href'] ?? '').firstWhere(
        (href) => href.contains('comtocom.php'),
        orElse: () => '',
      );
  final reply = node.querySelector('.js-profile-comment-reply');
  return ProfileComment(
    id: id,
    author: author,
    avatarUrl: _src(node.querySelector('img')),
    date: date.isEmpty ? null : date,
    html: (body?.innerHtml ?? '').trim(),
    conversationUrl: conversation.isEmpty
        ? null
        : Uri.parse(MalWebClient.base).resolve(conversation.replaceAll('&amp;', '&')).toString(),
    canDelete: node.querySelector('.js-profile-comment-delete') != null,
    replyToMemberId: _int(reply?.attributes['data-user-id']),
  );
}

List<ProfileComment> _comments(Iterable<Element> nodes) {
  final seen = <int>{};
  final out = <ProfileComment>[];
  for (final node in nodes) {
    final c = parseCommentElement(node);
    if (c != null && seen.add(c.id)) out.add(c);
  }
  return out;
}

int? _memberId(Document doc, String raw) {
  final input = doc.querySelector('input[name=profileMemId]')?.attributes['value'];
  return _int(input) ??
      _int(_memIdInComments.firstMatch(raw)?.group(1)) ??
      _int(_memIdInReport.firstMatch(raw)?.group(1)) ??
      _int(_memIdInGa.firstMatch(raw)?.group(1));
}

/// The comments block of a `/profile/<name>` page (desktop layout). Null when the page is
/// not a MAL page (challenge, maintenance).
ProfileCommentsPage? parseProfileComments(String raw) {
  final doc = html.parse(raw);
  if (doc.querySelector('#contentWrapper') == null && doc.querySelector('#content') == null) {
    return null;
  }
  final block = doc.querySelector('div.user-comments');
  final nodes = block?.querySelectorAll('div.comment[data-id]') ?? const <Element>[];
  final form = block?.querySelector('.comment-form');
  final canPost = form?.querySelector('textarea[name=commentText]') != null;
  return ProfileCommentsPage(
    comments: _comments(nodes),
    memberId: _memberId(doc, raw),
    total: _int(_allCount.firstMatch(block?.outerHtml ?? '')?.group(1)),
    canPost: canPost,
    profileUsername: doc.querySelector('input[name=profileUsername]')?.attributes['value'],
  );
}

/// One page of `comments.php?id=<member>&show=<offset>` (20 comments, newest first).
ProfileCommentsPage? parseCommentsListPage(String raw) {
  final doc = html.parse(raw);
  final content = doc.querySelector('#content');
  if (content == null) return null;
  final header = content.querySelector('.borderClass');
  return ProfileCommentsPage(
    comments: _comments(content.querySelectorAll('div.comment[data-id]')),
    memberId: _memberId(doc, raw),
    total: _int(_listCount.firstMatch(_text(header))?.group(1)),
  );
}

/// A `comtocom.php?id1=…&id2=…` page, oldest last as MAL prints it.
CommentConversation? parseConversation(String raw, {String? url}) {
  final doc = html.parse(raw);
  final content = doc.querySelector('#content');
  if (content == null) return null;
  final names = <String>[];
  for (final a in content.querySelectorAll('.com-box-header a, .borderClass a')) {
    final href = a.attributes['href'] ?? '';
    final m = RegExp(r'/profile/([^/?#]+)').firstMatch(href);
    if (m != null && !names.contains(m.group(1))) names.add(Uri.decodeComponent(m.group(1)!));
    if (names.length == 2) break;
  }
  final ids = <int>[];
  if (url != null) {
    final q = Uri.parse(url).queryParameters;
    for (final key in const ['id1', 'id2']) {
      final v = int.tryParse(q[key] ?? '');
      if (v != null) ids.add(v);
    }
  }
  return CommentConversation(
    comments: _comments(content.querySelectorAll('div.comment[data-id]')),
    usernames: names,
    memberIds: ids,
  );
}

/// Throws [MalWebActionFailed] unless MAL accepted the write. `addcomment.php` answers JSON
/// (`{"error": …, "message": …}` on failure); older endpoints answer 2xx or a 303.
void checkWriteAnswer(http.Response response) {
  final code = response.statusCode;
  if (code >= 400) throw MalWebActionFailed(statusCode: code);
  final body = response.body.trim();
  if (body.startsWith('{')) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] != null && json['error'] != false && json['error'] != '') {
        final message = json['message'];
        throw MalWebActionFailed(statusCode: code, message: message is String ? message : null);
      }
    } on FormatException {
      // Not JSON after all: the status decides.
    }
  } else if (body.contains('badresult')) {
    throw MalWebActionFailed(statusCode: code);
  }
}

/// Profile comments through the MAL website. Reading needs no session (anonymous desktop
/// page); posting, replying and deleting need the website session.
class ProfileCommentsApi {
  ProfileCommentsApi({MalWebClient? client}) : _clientOverride = client;

  final MalWebClient? _clientOverride;
  MalWebClient get client => _clientOverride ?? MalWebClient.instance;

  /// Tests parse on the calling isolate (`compute` needs a real event loop).
  @visibleForTesting
  static bool parseInline = false;

  static const int pageSize = 20;

  Future<R> _parse<R>(R Function(String) parser, String body) =>
      parseInline ? Future.value(parser(body)) : compute(parser, body);

  String _ok(http.Response response, Uri uri) {
    if (response.statusCode != 200) {
      throw http.ClientException('MAL answered ${response.statusCode}', uri);
    }
    return response.body;
  }

  /// The comments shown on [username]'s profile, with the member id and whether the viewer
  /// may post.
  Future<ProfileCommentsPage> profile(String username) async {
    final path = '/profile/${Uri.encodeComponent(username)}';
    final response = await client.get(path);
    final page = await _parse(parseProfileComments, _ok(response, Uri.parse(path)));
    if (page == null) throw FormatException('Not a MAL profile page for $username');
    return page;
  }

  /// One page of all comments of [memberId], starting at [offset].
  Future<ProfileCommentsPage> page(int memberId, int offset) async {
    final path = '/comments.php?id=$memberId&show=$offset';
    final response = await client.get(path);
    final page = await _parse(parseCommentsListPage, _ok(response, Uri.parse(path)));
    if (page == null) throw const FormatException('Not a MAL comments page');
    return page;
  }

  /// The comment-to-comment conversation at [url].
  Future<CommentConversation> conversation(String url) async {
    final response = await client.get(url);
    final body = _ok(response, Uri.parse(url));
    final parsed = await _parse((String b) => parseConversation(b, url: url), body);
    if (parsed == null) throw const FormatException('Not a MAL conversation page');
    return parsed;
  }

  /// Posts [text] on the profile of [memberId] / [username] (same form as MAL's page).
  Future<void> post({required int memberId, required String username, required String text}) async {
    final response = await client.postForm(
      '/addcomment.php',
      {
        'commentSubmit': '1',
        'profileMemId': '$memberId',
        'profileUsername': username,
        'commentText': text,
        'area': '2',
      },
      referer: '${MalWebClient.base}/profile/${Uri.encodeComponent(username)}',
    );
    checkWriteAnswer(response);
  }

  /// Replies to a comment: MAL writes it on the profile of [memberId] (the author).
  Future<void> reply({required int memberId, required String text, String? referer}) async {
    final response = await client.postForm(
      '/addcomment.php',
      {
        'commentSubmit': '1',
        'profileMemId': '$memberId',
        'commentText': text,
        'area': '2',
      },
      referer: referer,
    );
    checkWriteAnswer(response);
  }

  /// Deletes comment [commentId] (MAL allows it on your profile and for your own comments).
  Future<void> delete(int commentId, {String? referer}) async {
    final response = await client.postForm(
      '/includes/ajax.inc.php?t=78',
      {'id': '$commentId'},
      referer: referer,
    );
    checkWriteAnswer(response);
  }
}
