import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_conversations.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_store.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/services/notifications/mal_hub.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mal_web_store'));
  tearDown(() async {
    MalConversationsCache.clear();
    await dir.delete(recursive: true);
  });

  MalWebStore store() => MalWebStore(directory: () async => dir, saveDelay: Duration.zero);

  test('sections survive a restart, per MAL user', () async {
    final a = store();
    await a.load('Goddivor');
    a.write('pm_inbox', [
      {'id': 1}
    ]);
    await a.flush();

    final b = store();
    await b.load('goddivor');
    expect(b.read('pm_inbox'), [
      {'id': 1}
    ]);
    final other = store();
    await other.load('someone_else');
    expect(other.read('pm_inbox'), isNull);
  });

  test('messages, conversations and chats round-trip through JSON', () {
    const row = MalMessage(
      id: 15296258,
      rowId: 30819492,
      counterpart: 'Aiko',
      subject: 'Re: hey',
      preview: 'Third test',
      date: 'Nov 20, 2026 2:01 PM',
      isSent: true,
      threadId: 7,
    );
    final back = MalMessage.fromJson(row.toJson())!;
    expect([back.id, back.rowId, back.counterpart, back.isSent, back.threadId, back.box],
        [15296258, 30819492, 'Aiko', true, 7, 2]);

    final conversation = MalConversation.fromJson(const MalConversation(counterpart: 'Aiko', rows: [row]).toJson())!;
    expect(conversation.rows.single.preview, 'Third test');

    final history = MalChatHistory(
      messages: [
        MalChatMessage(html: '<b>hi</b>', isMine: true, subject: 'Re: hey', at: DateTime(2026, 11, 20, 14), state: MalSendState.sent, row: row),
      ],
      replyTo: const MalMessageThread(subject: 'hey', counterpart: 'Aiko', messages: [], replyId: 3, threadId: 7),
      olderThreads: 2,
    );
    final chat = MalChatHistory.fromJson(history.toJson())!;
    expect(chat.messages.single.html, '<b>hi</b>');
    expect(chat.messages.single.state, MalSendState.sent);
    expect(chat.messages.single.row!.rowId, 30819492);
    expect(chat.replyTo!.canReply, isTrue);
    expect(chat.olderThreads, 2);
  });

  test('the hub shows what it kept before any network read', () async {
    final s = store();
    await s.load('goddivor');
    final item = MalNotificationItem.fromJson({
      'id': 42,
      'typeIdentifier': 'friend_request',
      'createdAt': 1795000000,
      'friendName': 'Hikari_K',
      'friendProfileUrl': 'https://myanimelist.net/profile/Hikari_K',
      'isRead': false,
    })!;
    final friend = FriendActivity(
      friend: 'Ren',
      category: 'anime',
      malId: 1,
      title: 'Frieren',
      link: 'https://myanimelist.net/anime/1',
      status: 'completed',
      progress: 28,
      total: 28,
      date: DateTime(2026, 11, 20),
    );
    s.write('hub_items', [item.toJson()]);
    s.write('friends_activity', [friend.toJson()]);

    final hub = MalNotificationsHub(
      store: s,
      session: MalWebSession(cookies: _NoCookies(), platformSupported: true),
      malSignedIn: () => true,
      malUsername: () => 'goddivor',
    );
    hub.restore();
    expect(hub.items.single.actorName, 'Hikari_K');
    expect(hub.items.single.kind, MalNotificationKind.friendRequest);
    expect(hub.unread.value, 1);
    expect(hub.activity.single.isCompleted, isTrue);
    expect(hub.activityStatus, MalHubStatus.ready);
    hub.dispose();
  });
}

class _NoCookies implements WebViewCookies {
  @override
  Future<String?> read(String url) async => null;

  @override
  Future<void> clear(String url) async {}
}
