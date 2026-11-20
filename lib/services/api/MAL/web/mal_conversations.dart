import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';

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

  const MalChatMessage({
    required this.html,
    required this.isMine,
    required this.subject,
    this.at,
    this.dateText,
    this.state,
    this.outboxId,
  });
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
}

/// Reads the threads of [conversation] (the [maxThreads] newest ones), merges their messages
/// into one chat ordered by date and works out which of the user's messages were read.
Future<MalChatHistory> loadChatHistory(
  MalMessagesApi api,
  MalConversation conversation, {
  int maxThreads = 4,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final heads = conversation.threadHeads;
  final read = heads.take(maxThreads).toList();
  final threads = <(MalMessage, MalMessageThread)>[];
  Object? firstError;
  for (final head in read) {
    try {
      threads.add((head, await api.thread(head)));
    } catch (e) {
      firstError ??= e;
    }
  }
  if (threads.isEmpty && firstError != null) throw firstError;

  final items = <_ChatItem>[];
  final seen = <String>{};
  var order = 0;
  for (final (head, thread) in threads.reversed) {
    final subject = thread.subject.isNotEmpty ? thread.subject : head.subject;
    final headAt = parseMalMessageDate(head.date, now: at);
    for (final m in thread.messages) {
      final time = parseMalMessageDate(m.date, now: at);
      final key = '${m.isMine}|${messageTextKey(m.html)}|${m.date ?? ''}';
      if (!seen.add(key)) continue;
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
  MalMessageThread? replyTo;
  for (final (_, thread) in threads) {
    if (thread.canReply) {
      replyTo = thread;
      break;
    }
  }
  String? avatar = conversation.avatarUrl;
  for (final (_, thread) in threads) {
    avatar ??= thread.avatarUrl;
  }
  return MalChatHistory(
    messages: [
      for (var i = 0; i < messages.length; i++)
        messages[i].isMine
            ? MalChatMessage(
                html: messages[i].html,
                isMine: true,
                subject: messages[i].subject,
                at: messages[i].at,
                dateText: messages[i].dateText,
                state: states[i],
              )
            : messages[i],
    ],
    replyTo: replyTo,
    avatarUrl: avatar,
    olderThreads: heads.length - read.length,
  );
}

/// [html] without the blank end MAL adds to some messages (spaces, `&nbsp;`, line breaks).
String trimMessageHtml(String html) =>
    html.replaceFirst(RegExp(r'(\s|&nbsp;|&#160;|\u00a0|<br\s*/?>)+$', caseSensitive: false), '');

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
  Future<({List<MalConversation> conversations, bool hasMore})> load({int pages = 2}) async {
    final inbox = <MalMessage>[];
    final sent = <MalMessage>[];
    var more = false;
    for (var p = 0; p < pages; p++) {
      final page = await api.inbox(offset: p * MalMessagesApi.pageSize);
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
    return (conversations: groupConversations(inbox, sent), hasMore: more);
  }
}
