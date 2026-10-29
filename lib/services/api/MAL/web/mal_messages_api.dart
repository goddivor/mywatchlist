import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tabs_source.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/MAL/web/profile_comments_api.dart' show checkWriteAnswer;
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';

/// One row of the MAL inbox or sent box (`mymessages.php`).
@immutable
class MalMessage {
  final int id;

  /// The other person: the sender in the inbox, the recipient in the sent box.
  final String counterpart;
  final String subject;

  /// The start of the body, as MAL prints it next to the subject.
  final String preview;

  /// MAL's own date text (`Oct 27, 2026 4:12 PM`, `Today, 9:03 AM`, `5 hours ago`).
  final String? date;
  final bool isRead;

  /// A row of the sent box (read with `&f=1`).
  final bool isSent;

  /// The ids of MAL's Reply link (`go=send&replyid=&threadid=&toname=`), when it has one.
  final int? threadId;
  final int? replyId;

  /// The `box` MAL's delete script posts with the id (`data-json.type`, 1 = inbox).
  final int box;

  const MalMessage({
    required this.id,
    required this.counterpart,
    required this.subject,
    this.preview = '',
    this.date,
    this.isRead = true,
    this.isSent = false,
    this.threadId,
    this.replyId,
    int? box,
  }) : box = box ?? (isSent ? 2 : 1);

  MalMessage copyWith({bool? isRead, int? threadId, int? replyId}) => MalMessage(
        id: id,
        counterpart: counterpart,
        subject: subject,
        preview: preview,
        date: date,
        isRead: isRead ?? this.isRead,
        isSent: isSent,
        threadId: threadId ?? this.threadId,
        replyId: replyId ?? this.replyId,
        box: box,
      );

  /// The page of this message on MAL.
  String get url => '${MalWebClient.base}/mymessages.php?go=read&id=$id${isSent ? '&f=1' : ''}';
}

/// One page (20 rows) of the inbox or the sent box.
@immutable
class MalMessagesPage {
  final List<MalMessage> messages;

  /// MAL prints "You have 0 messages" (or an empty box).
  final bool isEmpty;

  const MalMessagesPage(this.messages, {this.isEmpty = false});

  int get unread => messages.where((m) => !m.isRead).length;
}

/// One message of a conversation, oldest first.
@immutable
class MalThreadMessage {
  final String sender;
  final String? date;

  /// The body as MAL renders it (HTML from BBCode).
  final String html;
  final bool isMine;

  const MalThreadMessage({required this.sender, required this.html, this.date, this.isMine = false});
}

/// A message read on MAL, with the earlier messages of its thread.
@immutable
class MalMessageThread {
  final String subject;

  /// The other person of the conversation.
  final String counterpart;
  final String? avatarUrl;
  final List<MalThreadMessage> messages;

  /// Reply ids from the page's Reply button; null when MAL offers no reply.
  final int? threadId;
  final int? replyId;

  const MalMessageThread({
    required this.subject,
    required this.counterpart,
    required this.messages,
    this.avatarUrl,
    this.threadId,
    this.replyId,
  });

  bool get canReply => replyId != null && threadId != null;

  MalMessageThread withMessage(MalThreadMessage message) => MalMessageThread(
        subject: subject,
        counterpart: counterpart,
        avatarUrl: avatarUrl,
        messages: [...messages, message],
        threadId: threadId,
        replyId: replyId,
      );
}

/// A user MAL can address a message to: a friend, or a result of MAL's user search.
@immutable
class MalUserSuggestion {
  final String name;
  final String? imageUrl;
  final bool isFriend;

  const MalUserSuggestion(this.name, {this.imageUrl, this.isFriend = false});

  @override
  bool operator ==(Object other) =>
      other is MalUserSuggestion && other.name.toLowerCase() == name.toLowerCase();

  @override
  int get hashCode => name.toLowerCase().hashCode;

  @override
  String toString() => name;
}

// ---------------------------------------------------------------------------------------------
// Parsers (pure, run on a background isolate).

final RegExp _idParam = RegExp(r'[?&](?:amp;)?id=(\d+)');
final RegExp _replyParam = RegExp(r'replyid=(\d+)');
final RegExp _threadParam = RegExp(r'threadid=(\d+)');
final RegExp _tonameParam = RegExp(r'toname=([^&#"' "'" r']+)');
final RegExp _rowId = RegExp(r'^message_(\d+)$');

String _clean(String? s) => (s ?? '').replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String _text(Node? n) => _clean(n?.text);

int? _int(String? s) => s == null ? null : int.tryParse(s);

/// Not a MAL page (challenge, maintenance, the login form).
bool _isMalPage(Document doc) =>
    doc.querySelector('#content') != null || doc.querySelector('#contentWrapper') != null;

bool _isLoginPage(Document doc) =>
    doc.querySelector('form[action*="login.php"]') != null && doc.querySelector('input[name=password]') != null;

/// Reads one `div.message` row of `mymessages.php` (inbox `spot1`, sent `spot2`), with the
/// selectors MAL's own script binds (`.mym_checkboxes`, `.js-pmessage-delete-message`) and the
/// ones MALClient read (`.mym_user`, `.mym_subject a.subject-link` + `span`, `span.mym_date`,
/// the Reply link of `.mym_actions`).
MalMessage? parseMessageRow(Element row, {required bool sent}) {
  final link = row.querySelector('a.subject-link') ??
      row.querySelector('.mym_subject a[href*="go=read"]') ??
      row.querySelector('a[href*="go=read"]');
  final href = (link?.attributes['href'] ?? '').replaceAll('&amp;', '&');
  final id = _int(_idParam.firstMatch(href)?.group(1)) ??
      _int(_rowId.firstMatch(row.id)?.group(1)) ??
      _int(row.querySelector('.mym_checkboxes input')?.attributes['value']);
  if (id == null) return null;

  final userNode = row.querySelector('.mym_user');
  final counterpart = _text(userNode?.querySelector('a') ?? userNode);
  if (counterpart.isEmpty) return null;

  // The subject is the link's own text; the preview its `span` ("- start of the body").
  var subject = '';
  var preview = '';
  final subjectBox = row.querySelector('.mym_subject');
  if (link != null) {
    subject = _clean(link.nodes.where((n) => n.nodeType == Node.TEXT_NODE).map((n) => n.text).join(' '));
    if (subject.isEmpty) subject = _text(link.querySelector('strong') ?? link.querySelector('.subject'));
  }
  final span = subjectBox?.querySelector('span') ?? link?.querySelector('span');
  preview = _text(span);
  if (subject.isEmpty) subject = _text(link);
  subject = subject.replaceFirst(RegExp(r'\s*-\s*$'), '').trim();
  preview = preview.replaceFirst(RegExp(r'^-\s*'), '').trim();

  final dateNode = row.querySelector('span.mym_date') ?? row.querySelector('.mym_date');
  final date = _text(dateNode);

  int? threadId;
  int? replyId;
  for (final a in row.querySelectorAll('a[href*="replyid"]')) {
    final h = (a.attributes['href'] ?? '').replaceAll('&amp;', '&');
    replyId = _int(_replyParam.firstMatch(h)?.group(1));
    threadId = _int(_threadParam.firstMatch(h)?.group(1));
    if (replyId != null) break;
  }

  int? box;
  final delete = row.querySelector('.js-pmessage-delete-message');
  final json = delete?.attributes['data-json'];
  if (json != null) {
    try {
      final data = jsonDecode(json.replaceAll('&quot;', '"'));
      if (data is Map) box = _int('${data['type']}');
    } on FormatException {
      // MAL's script falls back to box 1 too.
    }
  }

  return MalMessage(
    id: id,
    counterpart: counterpart,
    subject: subject,
    preview: preview,
    date: date.isEmpty ? null : date,
    isRead: sent || !row.classes.contains('unread'),
    isSent: sent,
    threadId: threadId,
    replyId: replyId,
    box: box,
  );
}

/// The inbox (`?go=&show=`) or the sent box (`?go=sent`). Null when the page is not MAL's
/// messages page (login form, challenge, maintenance).
MalMessagesPage? parseMessagesPage(String raw, {bool sent = false}) {
  final doc = html.parse(raw);
  if (!_isMalPage(doc) || _isLoginPage(doc)) return null;
  final rows = doc.querySelectorAll('div.message');
  final seen = <int>{};
  final out = <MalMessage>[];
  for (final row in rows) {
    if (!row.classes.contains('read') && !row.classes.contains('unread')) continue;
    final m = parseMessageRow(row, sent: sent);
    if (m != null && seen.add(m.id)) out.add(m);
  }
  final empty = out.isEmpty && (raw.contains('You have 0 messages') || rows.isEmpty);
  return MalMessagesPage(out, isEmpty: empty);
}

final DateFormat _malDate = DateFormat('MMM d, yyyy h:mm a', 'en_US');
final DateFormat _malShortDate = DateFormat('MMM d, h:mm a', 'en_US');
final DateFormat _malTime = DateFormat('h:mm a', 'en_US');
final RegExp _ago = RegExp(r'^(\d+)\s+(second|minute|hour|day)s?\s+ago$', caseSensitive: false);

/// MAL's date text as a time, when it can be read (absolute, `Today`/`Yesterday, h:mm a`,
/// `N hours ago`); null otherwise.
DateTime? parseMalMessageDate(String? raw, {DateTime? now}) {
  final s = _clean(raw);
  if (s.isEmpty) return null;
  final at = now ?? DateTime.now();
  for (final f in [_malDate, _malShortDate]) {
    try {
      final d = f.parseStrict(s);
      return f == _malShortDate ? DateTime(at.year, d.month, d.day, d.hour, d.minute) : d;
    } on FormatException {
      // next format
    }
  }
  final rel = RegExp(r'^(Today|Yesterday),\s*(.+)$', caseSensitive: false).firstMatch(s);
  if (rel != null) {
    try {
      final t = _malTime.parseStrict(rel.group(2)!.trim());
      final day = rel.group(1)!.toLowerCase() == 'today' ? at : at.subtract(const Duration(days: 1));
      return DateTime(day.year, day.month, day.day, t.hour, t.minute);
    } on FormatException {
      return null;
    }
  }
  final ago = _ago.firstMatch(s);
  if (ago != null) {
    final n = int.parse(ago.group(1)!);
    final unit = ago.group(2)!.toLowerCase();
    final d = switch (unit) {
      'second' => Duration(seconds: n),
      'minute' => Duration(minutes: n),
      'hour' => Duration(hours: n),
      _ => Duration(days: n),
    };
    return at.subtract(d);
  }
  return null;
}

String _bodyHtml(Element td) {
  // The cell starts with MAL's header blocks (sender, date, subject); the body follows them.
  final nodes = td.nodes.toList();
  var start = 0;
  while (start < nodes.length) {
    final n = nodes[start];
    final blank = n.nodeType == Node.TEXT_NODE && _clean(n.text).isEmpty;
    final header = n is Element && (n.localName == 'div' || n.localName == 'h2' || n.localName == 'h3');
    if (!blank && !header) break;
    start++;
  }
  if (start >= nodes.length) {
    // Everything is in blocks: the last one is the body.
    final blocks = td.children;
    return blocks.isEmpty ? td.innerHtml.trim() : blocks.last.innerHtml.trim();
  }
  final out = StringBuffer();
  for (final n in nodes.skip(start)) {
    out.write(n is Element ? n.outerHtml : (n is Text ? const HtmlEscape(HtmlEscapeMode.element).convert(n.text) : ''));
  }
  return out.toString().trim();
}

String _norm(String htmlBody) => _clean(html.parseFragment(htmlBody).text).toLowerCase();

/// A `mymessages.php?go=read&id=…[&threadid=…]` page: the message in `td.dialog-text`, the
/// Reply button's ids (`replyid`, `threadid`, `toname` in its `onclick`, as MALClient read
/// them) and the thread in `table.pmessage-message-history` (`td` date, sender, text). [me] is
/// the signed-in user name (own messages are drawn on the other side).
MalMessageThread? parseMessageThread(String raw, {String? subject, String? counterpart, String? me}) {
  final doc = html.parse(raw);
  if (!_isMalPage(doc) || _isLoginPage(doc)) return null;
  final mine = me?.toLowerCase();
  bool isMine(String name) => mine != null && name.toLowerCase() == mine;

  final td = doc.querySelector('td.dialog-text');
  String? sender;
  String? date;
  String? body;
  if (td != null) {
    sender = _text(td.querySelector('a[href*="/profile/"]'));
    if (sender.isEmpty) sender = _text(doc.querySelector('td.dialog-avatar a[href*="/profile/"]'));
    final dateNode = td.querySelector('.lightLink') ?? td.querySelector('small') ?? td.querySelector('.date');
    date = _text(dateNode);
    body = _bodyHtml(td);
  }

  int? threadId;
  int? replyId;
  String? toname;
  for (final e in doc.querySelectorAll('[onclick*="replyid"], a[href*="replyid"]')) {
    final s = (e.attributes['onclick'] ?? e.attributes['href'] ?? '').replaceAll('&amp;', '&');
    replyId = _int(_replyParam.firstMatch(s)?.group(1));
    threadId = _int(_threadParam.firstMatch(s)?.group(1));
    final t = _tonameParam.firstMatch(s)?.group(1);
    if (t != null) toname = Uri.decodeQueryComponent(t);
    if (replyId != null) break;
  }

  final history = <MalThreadMessage>[];
  final table = doc.querySelector('table.pmessage-message-history');
  for (final tr in table?.querySelectorAll('tr') ?? const <Element>[]) {
    final tds = tr.querySelectorAll('td');
    if (tds.length < 3) continue;
    final text = tds[2].innerHtml.trim();
    if (_clean(tds[2].text).isEmpty && tds[2].querySelector('img') == null) continue;
    final who = _text(tds[1]);
    history.add(MalThreadMessage(sender: who, date: _text(tds[0]), html: text, isMine: isMine(who)));
  }

  final messages = <MalThreadMessage>[...history];
  if (body != null && body.isNotEmpty) {
    final key = _norm(body);
    final known = history.any((m) => _norm(m.html) == key);
    if (!known) {
      final who = (sender == null || sender.isEmpty) ? (counterpart ?? '') : sender;
      messages.add(MalThreadMessage(
        sender: who,
        date: (date == null || date.isEmpty) ? null : date,
        html: body,
        isMine: isMine(who),
      ));
    }
  }
  if (messages.isEmpty) return null;

  // Oldest first: by date when MAL's texts can all be read, page order otherwise.
  final now = DateTime.now();
  final times = messages.map((m) => parseMalMessageDate(m.date, now: now)).toList();
  if (times.every((t) => t != null)) {
    final indexed = List.generate(messages.length, (i) => i)
      ..sort((a, b) {
        final c = times[a]!.compareTo(times[b]!);
        return c != 0 ? c : a.compareTo(b);
      });
    final sorted = [for (final i in indexed) messages[i]];
    messages
      ..clear()
      ..addAll(sorted);
  }

  final other = toname ??
      counterpart ??
      messages.map((m) => m.sender).firstWhere((s) => s.isNotEmpty && !isMine(s), orElse: () => '');
  final avatar = doc.querySelector('td.dialog-avatar img');
  final src = avatar?.attributes['data-src'] ?? avatar?.attributes['src'];
  final pageSubject = _text(doc.querySelector('.dialog-subject') ?? doc.querySelector('td.dialog-text .fw-b'));
  return MalMessageThread(
    subject: (subject != null && subject.isNotEmpty) ? subject : pageSubject,
    counterpart: other,
    avatarUrl: (src == null || src.isEmpty || src.startsWith('data:')) ? null : src,
    messages: List.unmodifiable(messages),
    threadId: threadId,
    replyId: replyId,
  );
}

/// The answer of `POST mymessages.php?go=send`: a redirect or MAL's `goodresult` is a sent
/// message; its `badresult` box (or the form shown again) a refusal, with MAL's text.
void checkSendAnswer(http.Response response) {
  final code = response.statusCode;
  if (code >= 400) throw MalWebActionFailed(statusCode: code);
  if (code >= 300) return;
  final doc = html.parse(response.body);
  final bad = doc.querySelector('.badresult') ?? doc.querySelector('.badresult-text');
  if (bad != null) {
    final text = _text(bad);
    throw MalWebActionFailed(statusCode: code, message: text.isEmpty ? null : text);
  }
  if (doc.querySelector('.goodresult') != null) return;
  if (doc.querySelector('textarea[name=message]') != null) {
    throw MalWebActionFailed(statusCode: code);
  }
}

/// The users of MAL's `/search/prefix.json?type=user` answer.
List<MalUserSuggestion> parseUserPrefix(String raw) {
  final out = <MalUserSuggestion>[];
  try {
    final json = jsonDecode(raw);
    final categories = json is Map ? json['categories'] : null;
    if (categories is! List) return out;
    for (final c in categories) {
      if (c is! Map || c['type'] != 'user' || c['items'] is! List) continue;
      for (final item in c['items'] as List) {
        if (item is! Map) continue;
        final name = item['name'];
        if (name is! String || name.isEmpty) continue;
        final image = item['image_url'];
        out.add(MalUserSuggestion(
          name,
          imageUrl: image is String && !image.contains('kaomoji') ? image : null,
        ));
      }
    }
  } on FormatException {
    // Not JSON: no suggestion.
  }
  return out;
}

/// `Re: ` once, as MAL's reply form writes it.
String replySubject(String subject) {
  final s = subject.trim();
  return RegExp(r'^re\s*:', caseSensitive: false).hasMatch(s) ? s : 'Re: $s';
}

/// The body as typed: BBCode and line breaks go to MAL unchanged (it renders them); only the
/// line ends are made uniform and the outer blank lines dropped.
String messageBody(String text) => text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

// ---------------------------------------------------------------------------------------------

/// MAL private messages through the website (`mymessages.php`), with the website session of
/// `mal-session`. Every call needs the session; a login redirect marks it expired
/// ([MalWebSessionExpired]).
class MalMessagesApi {
  MalMessagesApi({MalWebClient? client, Future<List<MalUserSuggestion>> Function(String me)? friends})
      : _clientOverride = client,
        _friendsOverride = friends;

  static MalMessagesApi instance = MalMessagesApi();

  final MalWebClient? _clientOverride;
  final Future<List<MalUserSuggestion>> Function(String me)? _friendsOverride;
  MalWebClient get client => _clientOverride ?? MalWebClient.instance;

  static const int pageSize = 20;

  /// Unread messages of the inbox's first page (MAL lists unread first), for a badge.
  static final ValueNotifier<int> unread = ValueNotifier<int>(0);

  /// Tests parse on the calling isolate (`compute` needs a real event loop).
  @visibleForTesting
  static bool parseInline = false;

  Future<R> _parse<R>(R Function(String) parser, String body) =>
      parseInline ? Future.value(parser(body)) : compute(parser, body);

  MalWebSession get _session => client.session;

  /// The signed-in MAL user name.
  String? get me => _session.username ?? UserMalV2.instance.username;

  Future<void> _requireSession() async {
    await _session.ensureLoaded();
    if (!_session.isConnected) throw const MalWebNoSession();
  }

  String _ok(http.Response response, String path) {
    if (response.statusCode != 200) {
      throw http.ClientException('MAL answered ${response.statusCode}', Uri.parse(path));
    }
    return response.body;
  }

  Future<MalMessagesPage> _box(String path, {required bool sent}) async {
    await _requireSession();
    final response = await client.get(path);
    final body = _ok(response, path);
    final page = await _parse(sent ? _parseSent : _parseInbox, body);
    if (page == null) throw const FormatException('Not the MAL messages page');
    return page;
  }

  /// One inbox page from [offset] (`?go=&show=`, 20 rows).
  Future<MalMessagesPage> inbox({int offset = 0}) async {
    final page = await _box('/mymessages.php?go=&show=$offset', sent: false);
    if (offset == 0) unread.value = page.unread;
    return page;
  }

  /// One sent-box page from [offset].
  Future<MalMessagesPage> sent({int offset = 0}) =>
      _box('/mymessages.php?go=sent${offset > 0 ? '&show=$offset' : ''}', sent: true);

  /// Reads [message] (MAL marks it read) with the earlier messages of its thread.
  Future<MalMessageThread> thread(MalMessage message) async {
    await _requireSession();
    final thread = message.threadId;
    final path = '/mymessages.php?go=read&id=${message.id}'
        '${message.isSent ? '&f=1' : ''}${thread != null ? '&threadid=$thread' : ''}';
    final response = await client.get(path);
    final body = _ok(response, path);
    final me = this.me;
    final parsed = await _parse(
      (String b) => parseMessageThread(b, subject: message.subject, counterpart: message.counterpart, me: me),
      body,
    );
    if (parsed == null) throw const FormatException('Not a MAL message page');
    if (!message.isRead && unread.value > 0) unread.value = unread.value - 1;
    return parsed;
  }

  /// Sends a new message to [to] (MAL's compose form: `subject`, `message`, `sendmessage`,
  /// plus the session's `csrf_token`).
  Future<void> send({required String to, required String subject, required String body}) async {
    await _requireSession();
    final name = to.trim();
    final response = await client.postForm(
      '/mymessages.php?go=send&toname=${Uri.encodeQueryComponent(name)}',
      {'subject': subject.trim(), 'message': messageBody(body), 'sendmessage': 'Send Message'},
      referer: '${MalWebClient.base}/mymessages.php?go=send&toname=${Uri.encodeQueryComponent(name)}',
    );
    checkSendAnswer(response);
  }

  /// Replies in [thread] (same form, with MAL's `replyid` and `threadid`).
  Future<void> reply(MalMessageThread thread, String body) async {
    final replyId = thread.replyId;
    final threadId = thread.threadId;
    if (replyId == null || threadId == null) throw const MalWebActionFailed();
    await _requireSession();
    final to = Uri.encodeQueryComponent(thread.counterpart);
    final path = '/mymessages.php?go=send&replyid=$replyId&threadid=$threadId&toname=$to';
    final response = await client.postForm(
      path,
      {'subject': replySubject(thread.subject), 'message': messageBody(body), 'sendmessage': 'Send Message'},
      referer: '${MalWebClient.base}$path',
    );
    checkSendAnswer(response);
  }

  /// Deletes [message] from its box, as MAL's Delete link does
  /// (`includes/ajax.inc.php?t=75`, `id` + `box`).
  Future<void> delete(MalMessage message) async {
    await _requireSession();
    final response = await client.postForm(
      '/includes/ajax.inc.php?t=75',
      {'id': '${message.id}', 'box': '${message.box}'},
      referer: '${MalWebClient.base}/mymessages.php${message.isSent ? '?go=sent' : ''}',
    );
    checkWriteAnswer(response);
    if (!message.isRead && unread.value > 0) unread.value = unread.value - 1;
  }

  List<MalUserSuggestion>? _friends;
  String? _friendsOf;

  /// The signed-in user's friends (first page of MAL's friends list), kept for the session.
  Future<List<MalUserSuggestion>> friends() async {
    final me = this.me;
    if (me == null || me.isEmpty) return const [];
    if (_friendsOf == me && _friends != null) return _friends!;
    final List<MalUserSuggestion> list;
    final override = _friendsOverride;
    if (override != null) {
      list = await override(me);
    } else {
      final page = await ProfileTabsSource.friends(me);
      list = [
        for (final f in page.friends) MalUserSuggestion(f.username, imageUrl: f.imageUrl, isFriend: true),
      ];
    }
    _friends = list;
    _friendsOf = me;
    return list;
  }

  /// MAL's user search (`/search/prefix.json?type=user`, the one its compose field uses).
  Future<List<MalUserSuggestion>> searchUsers(String keyword) async {
    final q = keyword.trim();
    if (q.length < 3) return const [];
    final path = '/search/prefix.json?type=user&keyword=${Uri.encodeQueryComponent(q)}&v=1';
    final response = await client.get(path, withSession: false);
    if (response.statusCode != 200) return const [];
    return _parse(parseUserPrefix, response.body);
  }
}

MalMessagesPage? _parseInbox(String raw) => parseMessagesPage(raw);
MalMessagesPage? _parseSent(String raw) => parseMessagesPage(raw, sent: true);
