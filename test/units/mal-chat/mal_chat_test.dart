import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_conversations.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_outbox.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart' show MalWebFormTimeout;
import 'package:shared_preferences/shared_preferences.dart';

/// Records what would go to MAL; [fail] makes every send throw, [gate] holds them.
class _FakeApi extends MalMessagesApi {
  final List<String> bodies = [];
  final List<String> subjects = [];
  bool fail = false;
  Completer<void>? gate;

  /// MAL takes the message but its answer never comes.
  bool late = false;
  List<MalMessage> sentBox = const [];

  @override
  Future<MalMessagesPage> sent({int offset = 0}) async => MalMessagesPage(sentBox);

  /// Pages read to check a send; the thread holds what was sent.
  final List<MalMessage> threadsRead = [];

  @override
  Future<MalMessageThread> thread(MalMessage message) async {
    threadsRead.add(message);
    return MalMessageThread(
      subject: 'yooooo',
      counterpart: 'LolitaToka',
      messages: [
        for (final b in bodies)
          MalThreadMessage(sender: 'me', html: b.replaceAll(RegExp(r'\[img\][^\[]*\[/img\]'), '<img src="p">'), isMine: true),
      ],
    );
  }

  @override
  Future<void> send({required String to, required String subject, required String body}) async {
    await gate?.future;
    if (fail) throw Exception('offline');
    subjects.add(subject);
    bodies.add(body);
    if (late) throw const MalWebFormTimeout();
  }

  @override
  Future<void> reply(MalMessageThread thread, String body) async {
    await gate?.future;
    if (fail) throw Exception('offline');
    subjects.add(replySubject(thread.subject));
    bodies.add(body);
    if (late) throw const MalWebFormTimeout();
  }
}

MalMessage _row(int id, String who, String date, {bool sent = false, bool read = true, int? thread, bool? seen}) =>
    MalMessage(
      id: id,
      counterpart: who,
      subject: 's$id',
      preview: 'p$id',
      date: date,
      isSent: sent,
      isRead: read,
      threadId: thread,
      recipientRead: sent ? (seen ?? true) : null,
    );

MalChatMessage _chat(bool mine) => MalChatMessage(html: mine ? 'me' : 'them', isMine: mine, subject: '');

void main() {
  final now = DateTime(2026, 11, 20, 12);

  group('conversations', () {
    test('one per person (any case), newest first, rows of both boxes', () {
      final list = groupConversations(
        [
          _row(1, 'Kineta', 'Nov 19, 2026 9:00 AM', read: false, thread: 7),
          _row(2, 'Xinil', 'Nov 20, 2026 8:00 AM'),
        ],
        [_row(3, 'kineta', 'Nov 20, 2026 10:00 AM', sent: true, thread: 7)],
        now: now,
      );
      expect(list.map((c) => c.counterpart), ['Kineta', 'Xinil']);
      final kineta = list.first;
      expect(kineta.rows.map((m) => m.id), [3, 1]);
      expect(kineta.last.isSent, isTrue);
      expect(kineta.unread, 1);
      // Both rows are in thread 7: reading one gives the thread.
      expect(kineta.threadHeads.map((m) => m.id), [3]);
      expect(kineta.lastSentRead, isTrue);
    });

    test('rows without a readable date keep MAL\'s order behind the dated ones', () {
      final list = groupConversations(
        [_row(1, 'A', 'sometime'), _row(2, 'B', 'Nov 20, 2026 8:00 AM')],
        const [],
        now: now,
      );
      expect(list.map((c) => c.counterpart), ['B', 'A']);
    });

    test('ticks: answered messages are read, the last ones follow MAL\'s sent box', () {
      final messages = [_chat(true), _chat(false), _chat(true), _chat(true)];
      expect(readStates(messages, lastSentRead: false),
          [MalSendState.read, null, MalSendState.sent, MalSendState.sent]);
      expect(readStates(messages, lastSentRead: true),
          [MalSendState.read, null, MalSendState.read, MalSendState.read]);
    });
  });

  test('a message of pictures only is recognised in MAL\'s copy', () {
    final typed = MalOutbox.textKey('[img]https://iili.io/oF8Tc2S.png[/img]');
    expect(typed, '[img1]');
    expect(messageTextKey('<img class="userimg" src="https://image.myanimelist.net/ui/abc">'), typed);
    expect(MalOutbox.textKey('Look [b]this[/b] [img]https://x/y.png[/img]'),
        messageTextKey('Look <b>this</b> <img class="userimg" src="z">'));
    expect(messageTextKey('hey'), 'hey');
  });

  test('relative MAL dates are known as such', () {
    expect(isRelativeMalDate('2 hours ago'), isTrue);
    expect(isRelativeMalDate('Nov 20, 2026 1:31 PM'), isFalse);
    expect(isRelativeMalDate(null), isFalse);
  });

  group('hidden messages', () {
    test('a message deleted in the app stays hidden, on that day only', () async {
      SharedPreferences.setMockInitialValues({});
      final hidden = MalHiddenMessages();
      await hidden.load();
      final hey = MalChatMessage(html: 'hey', isMine: true, subject: '', at: DateTime(2026, 11, 20, 14, 1));
      await hidden.hide('LolitaToka', hey);
      // The same message read again from another page, dated a minute later.
      expect(hidden.hides('lolitatoka', MalChatMessage(html: 'hey', isMine: true, subject: '', at: DateTime(2026, 11, 20, 14, 2))), isTrue);
      expect(hidden.hides('lolitatoka', MalChatMessage(html: 'hey', isMine: true, subject: '', at: DateTime(2026, 11, 21))), isFalse);
      expect(hidden.hides('lolitatoka', MalChatMessage(html: 'hey', isMine: false, subject: '', at: DateTime(2026, 11, 20))), isFalse);
      final again = MalHiddenMessages();
      await again.load();
      expect(again.hides('LolitaToka', hey), isTrue);
    });
  });

  group('bubbles and box rows', () {
    test('each bubble gets the newest matching row of its own box, once', () {
      const messages = [
        MalChatMessage(html: 'hey', isMine: true, subject: ''),
        MalChatMessage(html: 'hello you', isMine: false, subject: ''),
        MalChatMessage(html: 'hey', isMine: true, subject: ''),
      ];
      const rows = [
        MalMessage(id: 3, counterpart: 'A', subject: '', preview: 'hey', isSent: true),
        MalMessage(id: 2, counterpart: 'A', subject: '', preview: 'hello you'),
        MalMessage(id: 1, counterpart: 'A', subject: '', preview: 'hey', isSent: true),
      ];
      final matched = matchRows(messages, rows);
      expect(matched.map((r) => r?.id), [1, 2, 3]);
      expect(matchRows(const [MalChatMessage(html: 'other', isMine: true, subject: '')], rows), [null]);
    });
  });

  group('outbox', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MalOutbox.verifyDelay = Duration.zero;
    });

    test('no answer from MAL: the sent box decides, so nothing is sent twice', () async {
      final api = _FakeApi()..late = true;
      final outbox = MalOutbox(api: api);
      api.sentBox = [
        const MalMessage(id: 5, counterpart: 'Xinil', subject: 'Hello', preview: 'Hello there friend...', isSent: true),
      ];
      outbox.send(to: 'Xinil', body: 'Hello [b]there[/b] friend, how are you?');
      await pumpEventQueue();
      expect(outbox.to('Xinil').single.sent, isTrue);

      // Not in the sent box: it failed, the text stays.
      api.sentBox = const [];
      outbox.send(to: 'Archaeon', body: 'Are you there?');
      await pumpEventQueue();
      expect(outbox.to('Archaeon').single.failed, isTrue);
    });

    test('a picture answer MAL took without confirming is checked on the answered page', () async {
      final api = _FakeApi()..late = true;
      final outbox = MalOutbox(api: api);
      const thread = MalMessageThread(
        subject: 'yooooo',
        counterpart: 'LolitaToka',
        messages: [],
        replyId: 30819527,
        threadId: 19830857,
        pageId: 15296290,
      );
      outbox.send(to: 'LolitaToka', body: '[img]https://iili.io/oF8Tc2S.png[/img]', thread: thread);
      await pumpEventQueue(times: 100);
      // The page id, not the row id MAL answers 404 to.
      expect(api.threadsRead.single.id, 15296290);
      expect(api.threadsRead.single.threadId, 19830857);
      expect(outbox.to('LolitaToka').single.sent, isTrue);
    });

    test('a failed message MAL shows after all leaves the outbox', () async {
      final api = _FakeApi()..fail = true;
      final outbox = MalOutbox(api: api);
      outbox.send(to: 'Xinil', body: 'Hello there');
      outbox.send(to: 'Xinil', body: 'Second');
      await pumpEventQueue();
      outbox.reconcile('xinil', (m) => m.body == 'Hello there');
      expect(outbox.to('Xinil').map((m) => m.body), ['Second']);
    });

    test('ticks follow each message\'s own row of the sent box', () {
      const messages = [
        MalChatMessage(html: 'them', isMine: false, subject: ''),
        MalChatMessage(html: 'hey', isMine: true, subject: ''),
        MalChatMessage(html: 'Test du chat', isMine: true, subject: ''),
      ];
      final states = readStates(messages, lastSentRead: false, sentRows: const [
        MalMessage(id: 2, counterpart: 'A', subject: '', preview: 'Test du chat', isSent: true, recipientRead: false),
        MalMessage(id: 1, counterpart: 'A', subject: '', preview: 'hey', isSent: true, recipientRead: true),
      ]);
      expect(states, [null, MalSendState.read, MalSendState.sent]);
    });

    test('the blank end MAL adds to a message is dropped', () {
      expect(trimMessageHtml('Hello<br>\u00a0\u00a0 &nbsp;<br />\n'), 'Hello');
      expect(trimMessageHtml('a<br>b'), 'a<br>b');
      expect(trimMessageHtml('Test<br>\n<span>\u00a0\u00a0</span>\n'), 'Test');
      expect(trimMessageHtml('Look<br><img src="x.png">'), 'Look<br><img src="x.png">');
    });

    test('a subject for a new conversation comes from the first line', () {
      expect(subjectFromBody('\n  Hello [b]there[/b]\nSecond line'), 'Hello there');
      expect(subjectFromBody('a' * 80).length, 60);
      expect(subjectFromBody('   '), '…');
    });

    test('shows the message at once, then sent; replies keep the thread subject', () async {
      final api = _FakeApi()..gate = Completer<void>();
      final outbox = MalOutbox(api: api);
      const thread = MalMessageThread(
        subject: 'Frieren rewatch',
        counterpart: 'Kineta',
        messages: [],
        replyId: 9,
        threadId: 7,
      );
      final m = outbox.send(to: 'Kineta', body: 'Count me in', thread: thread);
      expect(outbox.to('kineta').single.id, m.id);
      expect(outbox.to('Kineta').single.sent, isFalse);
      expect(outbox.to('Kineta').single.failed, isFalse);
      // Waiting for MAL: the text is already saved on the device.
      await pumpEventQueue();
      final saved = (await SharedPreferences.getInstance()).getString(MalOutbox.storageKey);
      expect(jsonDecode(saved!), hasLength(1));

      api.gate!.complete();
      await pumpEventQueue();
      expect(api.bodies, ['Count me in']);
      expect(api.subjects, ['Re: Frieren rewatch']);
      expect(outbox.to('Kineta').single.sent, isTrue);
      expect((await SharedPreferences.getInstance()).getString(MalOutbox.storageKey), isNull);

      outbox.reconcile('kineta', (m) => true);
      expect(outbox.to('Kineta'), isEmpty);
    });

    test('a failed message keeps its text, survives a restart and is sent again', () async {
      final api = _FakeApi()..fail = true;
      final outbox = MalOutbox(api: api);
      final m = outbox.send(to: 'Xinil', body: 'Hello there');
      await pumpEventQueue();
      expect(outbox.to('Xinil').single.failed, isTrue);
      expect(api.bodies, isEmpty);

      // The app restarts: the message is still there, as failed.
      final again = MalOutbox(api: api);
      await again.load();
      final back = again.to('Xinil').single;
      expect(back.body, 'Hello there');
      expect(back.subject, 'Hello there');
      expect(back.failed, isTrue);

      api.fail = false;
      again.retry(back.id);
      expect(again.to('Xinil').single.failed, isFalse);
      await pumpEventQueue();
      expect(api.bodies, ['Hello there']);
      expect(again.to('Xinil').single.sent, isTrue);

      outbox.discard(m.id);
      expect(outbox.to('Xinil'), isEmpty);
    });
  });
}
