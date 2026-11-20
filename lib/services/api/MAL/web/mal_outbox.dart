import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_conversations.dart' show previewMatches;
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart' show MalWebFormTimeout;
import 'package:shared_preferences/shared_preferences.dart';

/// A message the user wrote that MAL has not confirmed yet, or refused.
@immutable
class MalOutboxMessage {
  /// Local id (creation time and a counter), never sent to MAL.
  final String id;

  /// The recipient's MAL name.
  final String to;

  /// The text as typed (BBCode).
  final String body;
  final String subject;

  /// The thread it answers; null for a new message.
  final int? replyId;
  final int? threadId;

  final DateTime createdAt;

  /// False while waiting for MAL, true once MAL refused it or could not be reached.
  final bool failed;

  /// True once MAL accepted it, until the conversation is read again from MAL.
  final bool sent;

  const MalOutboxMessage({
    required this.id,
    required this.to,
    required this.body,
    required this.subject,
    required this.createdAt,
    this.replyId,
    this.threadId,
    this.failed = false,
    this.sent = false,
  });

  bool get isReply => replyId != null && threadId != null;

  MalOutboxMessage copyWith({bool? failed, bool? sent}) => MalOutboxMessage(
        id: id,
        to: to,
        body: body,
        subject: subject,
        createdAt: createdAt,
        replyId: replyId,
        threadId: threadId,
        failed: failed ?? this.failed,
        sent: sent ?? this.sent,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'to': to,
        'body': body,
        'subject': subject,
        'replyId': replyId,
        'threadId': threadId,
        'at': createdAt.millisecondsSinceEpoch,
      };

  /// A message read back after the app was closed: it can no longer be waiting, so it shows
  /// as failed and the user decides to send it again.
  static MalOutboxMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final to = json['to'];
    final body = json['body'];
    final at = json['at'];
    if (id is! String || to is! String || body is! String || at is! int) return null;
    return MalOutboxMessage(
      id: id,
      to: to,
      body: body,
      subject: json['subject'] is String ? json['subject'] as String : '',
      replyId: json['replyId'] is int ? json['replyId'] as int : null,
      threadId: json['threadId'] is int ? json['threadId'] as int : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(at),
      failed: true,
    );
  }
}

/// The subject of a new conversation: the start of the first line of [body], as MAL needs
/// one and a chat has none.
String subjectFromBody(String body, {int max = 60}) {
  final line = body
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  if (line.length <= max) return line.isEmpty ? '…' : line;
  return '${line.substring(0, max - 1).trimRight()}…';
}

/// Messages being sent to MAL, one after the other, in the background: the chat shows them at
/// once and follows their state. What is not confirmed is saved on the device, so a text is
/// never lost (a failed one waits for the user to send it again or drop it).
class MalOutbox extends ChangeNotifier {
  MalOutbox({MalMessagesApi? api, Future<SharedPreferences> Function()? storage, DateTime Function()? clock})
      : _api = api,
        _storage = storage ?? SharedPreferences.getInstance,
        _clock = clock ?? DateTime.now;

  static MalOutbox instance = MalOutbox();

  static const String storageKey = 'mal_pm_outbox_v1';

  /// Pause before reading MAL again after a send without an answer.
  static Duration verifyDelay = const Duration(seconds: 3);

  /// The comparison key of a typed body (BBCode tags dropped), as [messageTextKey] gives it
  /// for MAL's rendering of the same text.
  static String textKey(String body) =>
      messageTextKey(messageBody(body).replaceAll(RegExp(r'\[/?[a-zA-Z*]+(=[^\]]*)?\]'), ''));

  final MalMessagesApi? _api;
  final Future<SharedPreferences> Function() _storage;
  final DateTime Function() _clock;

  MalMessagesApi get api => _api ?? MalMessagesApi.instance;

  final List<MalOutboxMessage> _messages = [];
  Future<void>? _loading;
  Future<void> _queue = Future.value();
  int _counter = 0;

  List<MalOutboxMessage> get messages => List.unmodifiable(_messages);

  /// The messages to [name], oldest first.
  List<MalOutboxMessage> to(String name) {
    final key = name.toLowerCase();
    return [for (final m in _messages) if (m.to.toLowerCase() == key) m];
  }

  /// Reads the saved messages once.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = (await _storage()).getString(storageKey);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      final known = {for (final m in _messages) m.id};
      for (final item in list) {
        final m = MalOutboxMessage.fromJson(item);
        if (m != null && known.add(m.id)) _messages.add(m);
      }
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('MAL outbox: $e');
    }
  }

  Future<void> _save() async {
    try {
      final pending = [for (final m in _messages) if (!m.sent) m.toJson()];
      final prefs = await _storage();
      if (pending.isEmpty) {
        await prefs.remove(storageKey);
      } else {
        await prefs.setString(storageKey, jsonEncode(pending));
      }
    } catch (e) {
      debugPrint('MAL outbox save: $e');
    }
  }

  /// Queues [body] for [to]: an answer in [thread] when given, a new message otherwise.
  /// Returns at once with the queued message.
  MalOutboxMessage send({required String to, required String body, MalMessageThread? thread}) {
    final now = _clock();
    final reply = thread != null && thread.canReply ? thread : null;
    final message = MalOutboxMessage(
      id: '${now.microsecondsSinceEpoch}-${_counter++}',
      to: to,
      body: body,
      subject: reply != null ? replySubject(reply.subject) : subjectFromBody(body),
      replyId: reply?.replyId,
      threadId: reply?.threadId,
      createdAt: now,
    );
    _messages.add(message);
    notifyListeners();
    unawaited(_save());
    _enqueue(message.id);
    return message;
  }

  /// Sends a failed message again.
  void retry(String id) {
    final i = _messages.indexWhere((m) => m.id == id);
    if (i < 0 || !_messages[i].failed) return;
    _messages[i] = _messages[i].copyWith(failed: false);
    notifyListeners();
    _enqueue(id);
  }

  /// Drops a failed message (the user gave up on it).
  void discard(String id) {
    _messages.removeWhere((m) => m.id == id);
    notifyListeners();
    unawaited(_save());
  }

  /// Forgets the messages to [name] that MAL now shows ([isOnMal]): the conversation was read
  /// again and has them. A failed one found there went through after all (MAL answered too
  /// late). The ones still waiting stay, and so do sent ones MAL does not list yet.
  void reconcile(String name, bool Function(MalOutboxMessage m) isOnMal) {
    final key = name.toLowerCase();
    final before = _messages.length;
    _messages.removeWhere((m) => m.to.toLowerCase() == key && (m.sent || m.failed) && isOnMal(m));
    if (_messages.length != before) {
      notifyListeners();
      unawaited(_save());
    }
  }

  /// MAL did not answer in time, or with a page the app cannot read: the message may have
  /// gone all the same. MAL is read once more (the thread of a reply, the sent box for a new
  /// message) and the message counts as sent when its text is there, so a "send again" never
  /// writes it twice.
  Future<bool> _landed(MalOutboxMessage m, Object error) async {
    try {
      await Future<void>.delayed(verifyDelay);
      final key = textKey(m.body);
      if (m.isReply) {
        final thread = await api.thread(MalMessage(
          id: m.replyId!,
          counterpart: m.to,
          subject: m.subject,
          threadId: m.threadId,
        ));
        if (thread.messages.any((x) => x.isMine && messageTextKey(x.html) == key)) return true;
      }
      final page = await api.sent();
      final name = m.to.toLowerCase();
      final found = page.messages.any((r) => r.counterpart.toLowerCase() == name && previewMatches(r.preview, key));
      if (!found) debugPrint('MAL message to ${m.to} not sent: $error');
      return found;
    } catch (e) {
      debugPrint('MAL message to ${m.to} not sent: $error (check failed: $e)');
      return false;
    }
  }

  void _enqueue(String id) {
    _queue = _queue.then((_) => _deliver(id));
  }

  Future<void> _deliver(String id) async {
    final i = _messages.indexWhere((m) => m.id == id);
    if (i < 0) return;
    final m = _messages[i];
    var ok = false;
    try {
      if (m.isReply) {
        await api.reply(
          MalMessageThread(
            subject: m.subject.replaceFirst(RegExp(r'^Re:\s*', caseSensitive: false), ''),
            counterpart: m.to,
            messages: const [],
            replyId: m.replyId,
            threadId: m.threadId,
          ),
          m.body,
        );
      } else {
        await api.send(to: m.to, subject: m.subject, body: m.body);
      }
      ok = true;
    } on MalWebSendUnconfirmed catch (e) {
      ok = await _landed(m, e);
    } on MalWebFormTimeout catch (e) {
      ok = await _landed(m, e);
    } catch (e) {
      debugPrint('MAL message to ${m.to} not sent: $e');
    }
    final j = _messages.indexWhere((x) => x.id == id);
    if (j < 0) return;
    _messages[j] = _messages[j].copyWith(failed: !ok, sent: ok);
    notifyListeners();
    await _save();
  }
}
