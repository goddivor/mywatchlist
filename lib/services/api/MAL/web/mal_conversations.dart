import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything exchanged with one person: the rows of the inbox and of the sent box that name
/// them, newest first. MAL splits a conversation into threads (one per subject) and two boxes;
/// the app shows it as one chat, like a messaging app.
@immutable
class MalConversation {
  /// The other person, as MAL writes the name.
  final String counterpart;

  /// Inbox and sent-box rows with [counterpart], newest first.
  final List<MalMessage> rows;

  const MalConversation({required this.counterpart, required this.rows});

  Map<String, Object?> toJson() => {'counterpart': counterpart, 'rows': [for (final r in rows) r.toJson()]};

  static MalConversation? fromJson(Object? json) {
    if (json is! Map || json['counterpart'] is! String || json['rows'] is! List) return null;
    final rows = [...(json['rows'] as List).map(MalMessage.fromJson).whereType<MalMessage>()];
    if (rows.isEmpty) return null;
    return MalConversation(counterpart: json['counterpart'] as String, rows: rows);
  }

  /// Lower-case name, the key of a conversation.
  String get key => counterpart.toLowerCase();

  /// The newest row (the one the list shows).
  MalMessage get last => rows.first;

  /// Received rows not yet opened.
  int get unread => rows.where((m) => !m.isSent && !m.isRead).length;

  String? get avatarUrl {
    for (final m in rows) {
      if (m.avatarUrl != null) return m.avatarUrl;
    }
    return null;
  }

  /// The newest row of each thread (rows without a thread id stand alone), newest first:
  /// reading one of them gives the whole thread.
  List<MalMessage> get threadHeads {
    final seen = <String>{};
    return [
      for (final m in rows)
        if (seen.add(m.threadId != null ? 't${m.threadId}' : 'm${m.id}')) m,
    ];
  }

  /// The newest sent row has been opened by the other person.
  bool? get lastSentRead {
    for (final m in rows) {
      if (m.isSent) return m.recipientRead;
    }
    return null;
  }
}

/// Groups inbox and sent-box rows by person, each conversation newest first and the
/// conversations ordered by their newest row. Rows whose date MAL gives in a form the app
/// cannot read keep MAL's order (newest first) behind the dated ones of their box.
List<MalConversation> groupConversations(
  Iterable<MalMessage> inbox,
  Iterable<MalMessage> sent, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final byKey = <String, List<_Dated>>{};
  final names = <String, String>{};
  var order = 0;
  void add(MalMessage m) {
    final name = m.counterpart.trim();
    if (name.isEmpty) return;
    final key = name.toLowerCase();
    names.putIfAbsent(key, () => name);
    byKey.putIfAbsent(key, () => []).add(_Dated(m, parseMalMessageDate(m.date, now: at), order++));
  }

  inbox.forEach(add);
  sent.forEach(add);
  final out = <MalConversation>[];
  final newest = <String, DateTime?>{};
  for (final entry in byKey.entries) {
    final rows = entry.value..sort(_Dated.newestFirst);
    final seen = <String>{};
    out.add(MalConversation(
      counterpart: names[entry.key]!,
      rows: [
        for (final d in rows)
          if (seen.add('${d.message.isSent}:${d.message.id}')) d.message,
      ],
    ));
    newest[entry.key] = rows.first.at;
  }
  out.sort((a, b) {
    final x = newest[a.key];
    final y = newest[b.key];
    if (x != null && y != null) return y.compareTo(x);
    if (x != null) return -1;
    if (y != null) return 1;
    return 0;
  });
  return out;
}

class _Dated {
  final MalMessage message;
  final DateTime? at;
  final int order;

  const _Dated(this.message, this.at, this.order);

  static int newestFirst(_Dated a, _Dated b) {
    if (a.at != null && b.at != null) {
      final c = b.at!.compareTo(a.at!);
      if (c != 0) return c;
    }
    if (a.at != null && b.at == null) return -1;
    if (a.at == null && b.at != null) return 1;
    return a.order.compareTo(b.order);
  }
}

/// How far a message of the user has gone.
enum MalSendState {
  /// Waiting for MAL's answer.
  sending,

  /// MAL accepted it.
  sent,

  /// The other person has opened it (MAL's sent box says so).
  read,

  /// MAL refused it or could not be reached; the text is kept for another try.
  failed,
}

/// One bubble of a conversation.
@immutable
class MalChatMessage {
  /// The body as HTML (MAL's rendering, or the local rendering of a message being sent).
  final String html;
  final bool isMine;
  final DateTime? at;

  /// MAL's own date text, when [at] could not be read from it.
  final String? dateText;

  /// The subject of the MAL thread it belongs to.
  final String subject;

  /// Only for the user's messages.
  final MalSendState? state;

  /// The id of a local message still in the outbox (sending or failed).
  final String? outboxId;

  /// The row of MAL's inbox or sent box this message is (matched by the start of its text);
  /// null when none was found. Deleting goes through it.
  final MalMessage? row;

  const MalChatMessage({
    required this.html,
    required this.isMine,
    required this.subject,
    this.at,
    this.dateText,
    this.state,
    this.outboxId,
    this.row,
  });

  Map<String, Object?> toJson() => {
        'html': html,
        'isMine': isMine,
        'subject': subject,
        'at': at?.millisecondsSinceEpoch,
        'dateText': dateText,
        'state': state?.name,
        'row': row?.toJson(),
      };

  /// A message saved by [toJson]; never an outbox message (the outbox keeps its own).
  static MalChatMessage? fromJson(Object? json) {
    if (json is! Map || json['html'] is! String) return null;
    final at = json['at'];
    final state = json['state'];
    return MalChatMessage(
      html: json['html'] as String,
      isMine: json['isMine'] == true,
      subject: json['subject'] is String ? json['subject'] as String : '',
      at: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : null,
      dateText: json['dateText'] is String ? json['dateText'] as String : null,
      state: MalSendState.values.where((v) => v.name == state).firstOrNull,
      row: MalMessage.fromJson(json['row']),
    );
  }

  MalChatMessage copyWith({MalSendState? state, MalMessage? row}) => MalChatMessage(
        html: html,
        isMine: isMine,
        subject: subject,
        at: at,
        dateText: dateText,
        state: state ?? this.state,
        outboxId: outboxId,
        row: row ?? this.row,
      );
}

/// A whole conversation read from MAL: the bubbles, oldest first, and the thread a reply goes
/// to.
@immutable
class MalChatHistory {
  final List<MalChatMessage> messages;

  /// The newest thread MAL lets the user answer; null when there is none (a new message is
  /// sent then).
  final MalMessageThread? replyTo;

  final String? avatarUrl;

  /// Threads left out because only the newest ones are read at first.
  final int olderThreads;

  const MalChatHistory({
    required this.messages,
    this.replyTo,
    this.avatarUrl,
    this.olderThreads = 0,
  });

  Map<String, Object?> toJson() => {
        'messages': [for (final m in messages) m.toJson()],
        'replyTo': replyTo == null
            ? null
            : {
                'subject': replyTo!.subject,
                'counterpart': replyTo!.counterpart,
                'replyId': replyTo!.replyId,
                'threadId': replyTo!.threadId,
                'pageId': replyTo!.pageId,
              },
        'avatarUrl': avatarUrl,
        'olderThreads': olderThreads,
      };

  static MalChatHistory? fromJson(Object? json) {
    if (json is! Map || json['messages'] is! List) return null;
    final reply = json['replyTo'];
    return MalChatHistory(
      messages: [...(json['messages'] as List).map(MalChatMessage.fromJson).whereType<MalChatMessage>()],
      replyTo: reply is Map && reply['replyId'] is int && reply['threadId'] is int
          ? MalMessageThread(
              subject: reply['subject'] is String ? reply['subject'] as String : '',
              counterpart: reply['counterpart'] is String ? reply['counterpart'] as String : '',
              messages: const [],
              replyId: reply['replyId'] as int,
              threadId: reply['threadId'] as int,
              pageId: reply['pageId'] is int ? reply['pageId'] as int : null,
            )
          : null,
      avatarUrl: json['avatarUrl'] is String ? json['avatarUrl'] as String : null,
      olderThreads: json['olderThreads'] is int ? json['olderThreads'] as int : 0,
    );
  }
}

/// MAL's "N minutes / hours / days ago": a time rounded to its unit.
bool isRelativeMalDate(String? raw) => RegExp(r'\bago$', caseSensitive: false).hasMatch((raw ?? '').trim());

/// The time [previous] gave the same message (side and text), when it is close to [time]
/// (within the rounding of a relative date).
DateTime? _earlierTime(MalChatHistory? previous, bool mine, String key, DateTime time) {
  for (final m in previous?.messages ?? const <MalChatMessage>[]) {
    final at = m.at;
    if (at == null || m.isMine != mine || messageTextKey(m.html) != key) continue;
    if (at.difference(time).abs() <= const Duration(hours: 24)) return at;
  }
  return null;
}

/// How far apart two copies of one message may be dated by different MAL pages.
const Duration duplicateWindow = Duration(minutes: 10);

/// Reads the threads of [conversation] (the [maxThreads] newest ones), merges their messages
/// into one chat ordered by date and works out which of the user's messages were read.
///
/// [previous] is the chat read before: MAL writes recent times as "2 hours ago", so a message
/// it gave an exact time to then keeps that time.
Future<MalChatHistory> loadChatHistory(
  MalMessagesApi api,
  MalConversation conversation, {
  int maxThreads = 4,
  DateTime? now,
  MalChatHistory? previous,
}) async {
  final at = now ?? DateTime.now();
  final heads = conversation.threadHeads;
  final read = heads.take(maxThreads).toList();
  // All the threads at once (the client spaces the requests to MAL).
  Object? firstError;
  final loaded = await Future.wait([
    for (final head in read)
      api.thread(head).then<MalMessageThread?>((t) => t, onError: (Object e) {
        firstError ??= e;
        return null;
      }),
  ]);
  final threads = <(MalMessage, MalMessageThread)>[
    for (var i = 0; i < read.length; i++)
      if (loaded[i] != null) (read[i], loaded[i]!),
  ];
  if (threads.isEmpty && firstError != null) throw firstError!;

  final items = <_ChatItem>[];
  // One message read from two pages: same side, same text, times a few minutes apart (MAL
  // writes "4 minutes ago" on one page and the clock time on another).
  final seen = <String, List<DateTime?>>{};
  bool known(String key, DateTime? time) {
    final times = seen[key];
    if (times == null) return false;
    return times.any((t) => t == null || time == null || t.difference(time).abs() <= duplicateWindow);
  }

  var order = 0;
  for (final (head, thread) in threads.reversed) {
    final subject = thread.subject.isNotEmpty ? thread.subject : head.subject;
    final headAt = parseMalMessageDate(head.date, now: at);
    for (final m in thread.messages) {
      var time = parseMalMessageDate(m.date, now: at);
      if (time != null && isRelativeMalDate(m.date)) {
        time = _earlierTime(previous, m.isMine, messageTextKey(m.html), time) ?? time;
      }
      final key = '${m.isMine}|${messageTextKey(m.html)}';
      if (known(key, time)) continue;
      seen.putIfAbsent(key, () => []).add(time);
      items.add(_ChatItem(
        MalChatMessage(
          html: trimMessageHtml(m.html),
          isMine: m.isMine,
          subject: subject,
          at: time,
          dateText: time == null ? m.date : null,
        ),
        time ?? headAt,
        order++,
      ));
    }
  }
  items.sort((a, b) {
    if (a.at != null && b.at != null) {
      final c = a.at!.compareTo(b.at!);
      if (c != 0) return c;
    }
    return a.order.compareTo(b.order);
  });

  final messages = [for (final i in items) i.message];
  final states = readStates(
    messages,
    lastSentRead: conversation.lastSentRead,
    sentRows: [for (final r in conversation.rows) if (r.isSent) r],
  );
  // The answer goes to the newest thread the other person wrote in: their newest inbox row
  // carries MAL's Reply ids (a page of the user's own message has no Reply button).
  MalMessageThread? replyTo;
  for (final r in conversation.rows) {
    if (!r.isSent && r.replyId != null && r.threadId != null) {
      replyTo = MalMessageThread(
        subject: r.subject.replaceFirst(RegExp(r'^(Re:\s*)+', caseSensitive: false), ''),
        counterpart: conversation.counterpart,
        messages: const [],
        replyId: r.replyId,
        threadId: r.threadId,
        pageId: r.id,
      );
      break;
    }
  }
  if (replyTo == null) {
    for (final (_, thread) in threads) {
      if (thread.canReply) {
        replyTo = thread;
        break;
      }
    }
  }
  String? avatar = conversation.avatarUrl;
  for (final (_, thread) in threads) {
    avatar ??= thread.avatarUrl;
  }
  final rows = matchRows(messages, conversation.rows);
  return MalChatHistory(
    messages: [
      for (var i = 0; i < messages.length; i++)
        messages[i].copyWith(state: messages[i].isMine ? states[i] : null, row: rows[i]),
    ],
    replyTo: replyTo,
    avatarUrl: avatar,
    olderThreads: heads.length - read.length,
  );
}

/// The box row of each message of [messages] (oldest first): the newest messages take the
/// newest rows, a row of the sent box for the user's messages, of the inbox for the others,
/// matched by the start of the text. A row is given once.
List<MalMessage?> matchRows(List<MalChatMessage> messages, List<MalMessage> rows) {
  final used = <String>{};
  final out = List<MalMessage?>.filled(messages.length, null);
  for (var i = messages.length - 1; i >= 0; i--) {
    final m = messages[i];
    final key = messageTextKey(m.html);
    for (final r in rows) {
      final id = '${r.isSent}:${r.id}';
      if (r.isSent != m.isMine || used.contains(id)) continue;
      if (previewMatches(r.preview, key)) {
        used.add(id);
        out[i] = r;
        break;
      }
    }
  }
  return out;
}

/// [html] without the blank end MAL adds to some messages: trailing spaces, `&nbsp;`, line
/// breaks, and elements holding nothing else.
String trimMessageHtml(String html) {
  final fragment = html_parser.parseFragment(html);
  bool blank(dom.Node n) {
    if (n is dom.Text) return n.text.replaceAll('\u00a0', ' ').trim().isEmpty;
    if (n is dom.Element) {
      if (n.localName == 'br') return true;
      if (n.localName == 'img' || n.querySelector('img') != null) return false;
      return n.nodes.every(blank);
    }
    return true;
  }

  final nodes = fragment.nodes;
  var changed = false;
  while (nodes.isNotEmpty && blank(nodes.last)) {
    nodes.removeLast();
    changed = true;
  }
  if (!changed) return html;
  return fragment.outerHtml.trim();
}

class _ChatItem {
  final MalChatMessage message;
  final DateTime? at;
  final int order;

  const _ChatItem(this.message, this.at, this.order);
}

/// Whether the start of a message that MAL prints in a box row ([preview]) is the start of
/// the message whose text key ([messageTextKey]) is [textKey]. MAL cuts long previews and may
/// end them with dots.
bool previewMatches(String preview, String textKey) {
  final start = messageTextKey(preview).replaceFirst(RegExp(r'(\.\.\.|…)$'), '').trim();
  if (start.isEmpty || textKey.isEmpty) return false;
  return textKey.startsWith(start) || start.startsWith(textKey);
}

/// The state of each of the user's messages in [messages] (oldest first; null for the other
/// person's). A message followed by an answer of the other person was read. The others take
/// the state of their own row in MAL's sent box ([sentRows], matched by the start of the
/// text; `unread` there means not opened yet); without a row, the newest sent row decides
/// ([lastSentRead]).
List<MalSendState?> readStates(
  List<MalChatMessage> messages, {
  bool? lastSentRead,
  List<MalMessage> sentRows = const [],
}) {
  var lastTheirs = -1;
  for (var i = 0; i < messages.length; i++) {
    if (!messages[i].isMine) lastTheirs = i;
  }
  MalSendState? fromRow(MalChatMessage m) {
    final key = messageTextKey(m.html);
    for (final row in sentRows) {
      if (row.recipientRead != null && previewMatches(row.preview, key)) {
        return row.recipientRead! ? MalSendState.read : MalSendState.sent;
      }
    }
    return null;
  }

  return [
    for (var i = 0; i < messages.length; i++)
      if (!messages[i].isMine)
        null
      else if (i < lastTheirs)
        MalSendState.read
      else
        fromRow(messages[i]) ?? (lastSentRead == true ? MalSendState.read : MalSendState.sent),
  ];
}

/// Inbox and sent-box pages read together and grouped by person.
class MalConversationsSource {
  MalConversationsSource({MalMessagesApi? api}) : _api = api;

  final MalMessagesApi? _api;

  MalMessagesApi get api => _api ?? MalMessagesApi.instance;

  /// Reads [pages] pages of each box (20 rows a page) and groups them. A failing sent box
  /// still gives the inbox's conversations; a failing inbox throws.
  ///
  /// With [merge], the rows read are added to the conversations kept from before (the
  /// background job reads one page, the list may hold more).
  /// [firstInbox] is the inbox's first page when the caller has just read it.
  Future<({List<MalConversation> conversations, bool hasMore})> load({
    int pages = 2,
    bool merge = false,
    MalMessagesPage? firstInbox,
  }) async {
    final inbox = <MalMessage>[];
    final sent = <MalMessage>[];
    var more = false;
    for (var p = 0; p < pages; p++) {
      final page = p == 0 && firstInbox != null ? firstInbox : await api.inbox(offset: p * MalMessagesApi.pageSize);
      inbox.addAll(page.messages);
      if (page.messages.length < MalMessagesApi.pageSize) break;
      if (p == pages - 1) more = true;
    }
    try {
      for (var p = 0; p < pages; p++) {
        final page = await api.sent(offset: p * MalMessagesApi.pageSize);
        sent.addAll(page.messages);
        if (page.messages.length < MalMessagesApi.pageSize) break;
        if (p == pages - 1) more = true;
      }
    } catch (e) {
      if (sent.isEmpty) debugPrint('MAL sent box: $e');
    }
    api.prefetchPictures([...inbox, ...sent]);
    if (merge) {
      final known = {for (final m in [...inbox, ...sent]) '${m.isSent}:${m.id}'};
      for (final c in MalConversationsCache.list ?? const <MalConversation>[]) {
        for (final r in c.rows) {
          if (!known.add('${r.isSent}:${r.id}')) continue;
          (r.isSent ? sent : inbox).add(r);
        }
      }
    }
    final conversations = groupConversations(inbox, sent);
    MalConversationsCache.put(conversations);
    return (conversations: conversations, hasMore: more);
  }

  /// The conversation with [name], or the one holding message [messageId] (a notification
  /// knows only the id). Reads the first pages of the boxes; when the message is not there,
  /// its own page gives the person.
  Future<MalConversation?> find({String? name, int? messageId, int? threadId, bool sent = false}) async {
    final key = name?.trim().toLowerCase();
    final found = await load(pages: 1);
    for (final c in found.conversations) {
      if (key != null && key.isNotEmpty && c.key == key) return c;
      if (messageId != null && c.rows.any((r) => r.id == messageId)) return c;
    }
    if (messageId == null) return null;
    final row = MalMessage(
      id: messageId,
      counterpart: name ?? '',
      subject: '',
      isSent: sent,
      isRead: sent,
      threadId: threadId,
    );
    final thread = await api.thread(row);
    if (thread.counterpart.isEmpty) return null;
    return MalConversation(
      counterpart: thread.counterpart,
      rows: [
        MalMessage(
          id: messageId,
          counterpart: thread.counterpart,
          subject: thread.subject,
          isSent: sent,
          threadId: thread.threadId ?? threadId,
          replyId: thread.replyId,
          avatarUrl: thread.avatarUrl,
        ),
      ],
    );
  }
}

/// What was last read of the conversations and chats: in memory, and on the device through
/// [MalWebStore] (the background job fills it too), so a screen opened shows it at once and
/// refreshes it quietly.
abstract final class MalConversationsCache {
  static const String listSection = 'pm_list';
  static const String chatPrefix = 'pm_chat:';

  static List<MalConversation>? _list;
  static final Map<String, MalChatHistory> _chats = {};
  static String? _user;

  static MalWebStore get _store => MalWebStore.instance;

  /// Forgets what belongs to another MAL user.
  static void _sync() {
    final user = _store.user?.toLowerCase();
    if (user == _user) return;
    _user = user;
    _list = null;
    _chats.clear();
  }

  /// The conversations last read (from the device when the app has just started).
  static List<MalConversation>? get list {
    _sync();
    if (_list != null) return _list;
    final saved = _store.read(listSection);
    if (saved is! List) return null;
    return _list = [...saved.map(MalConversation.fromJson).whereType<MalConversation>()];
  }

  static void put(List<MalConversation> conversations) {
    _sync();
    _list = conversations;
    _store.write(listSection, [for (final c in conversations) c.toJson()]);
  }

  static MalConversation? conversation(String name) {
    final key = name.toLowerCase();
    for (final c in list ?? const <MalConversation>[]) {
      if (c.key == key) return c;
    }
    return null;
  }

  /// The chat with [name] last read, or null.
  static MalChatHistory? chat(String name) {
    _sync();
    final key = name.toLowerCase();
    final known = _chats[key];
    if (known != null) return known;
    final saved = MalChatHistory.fromJson(_store.read('$chatPrefix$key'));
    if (saved != null) _chats[key] = saved;
    return saved;
  }

  static void putChat(String name, MalChatHistory history) {
    _sync();
    final key = name.toLowerCase();
    _chats[key] = history;
    _store.write('$chatPrefix$key', history.toJson());
  }

  static void removeChat(String name) {
    _sync();
    final key = name.toLowerCase();
    _chats.remove(key);
    _store.write('$chatPrefix$key', null);
  }

  @visibleForTesting
  static void clear() {
    _list = null;
    _chats.clear();
    _user = null;
  }
}

/// Messages the user deleted in the app. MAL removes a deleted message from the user's box,
/// but the thread history it shares with the other person still shows it: the app hides it,
/// as messaging apps do for "delete for me". Kept on the device.
class MalHiddenMessages {
  MalHiddenMessages({Future<SharedPreferences> Function()? storage})
      : _storage = storage ?? SharedPreferences.getInstance;

  static MalHiddenMessages instance = MalHiddenMessages();

  static const String storageKey = 'mal_pm_hidden_v1';

  final Future<SharedPreferences> Function() _storage;
  Set<String> _keys = {};
  Future<void>? _loading;

  /// Person, side, text and day: a "hey" deleted once does not hide every other "hey".
  static String keyOf(String person, MalChatMessage m) {
    final at = m.at;
    final day = at == null ? '' : '${at.year}-${at.month}-${at.day}';
    return '${person.toLowerCase()}|${m.isMine}|${messageTextKey(m.html)}|$day';
  }

  Future<void> load() => _loading ??= () async {
        try {
          _keys = {...?(await _storage()).getStringList(storageKey), ..._keys};
        } catch (_) {}
      }();

  bool hides(String person, MalChatMessage m) => _keys.contains(keyOf(person, m));

  Future<void> hide(String person, MalChatMessage m) async {
    _keys.add(keyOf(person, m));
    try {
      final list = _keys.toList();
      await (await _storage()).setStringList(storageKey, list.length > 500 ? list.sublist(list.length - 500) : list);
    } catch (_) {}
  }
}
