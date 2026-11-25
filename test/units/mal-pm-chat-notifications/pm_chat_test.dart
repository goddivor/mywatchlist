import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/notifications/mal_hub_poller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Notifier implements MalHubNotifier {
  final shown = <(MalHubChannel, HubSystemNotification)>[];
  final cancelled = <int>[];
  @override
  bool get isSupported => true;
  @override
  Future<bool> allowed() async => true;
  @override
  Future<void> show(MalHubChannel channel, List<HubSystemNotification> notifications) async =>
      shown.addAll([for (final n in notifications) (channel, n)]);
  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

/// The inbox from memory: no request is ever sent to MAL.
class _Inbox extends MalMessagesApi {
  MalMessagesPage page = const MalMessagesPage([]);
  @override
  Future<MalMessagesPage> inbox({int offset = 0}) async => page;
  @override
  Future<MalMessagesPage> sent({int offset = 0}) async => const MalMessagesPage([]);
}

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  Future<(_Notifier, _Inbox, MalMessagesWatcher)> primed({bool gate = true}) async {
    final notifier = _Notifier();
    final inbox = _Inbox();
    final watcher = MalMessagesWatcher(api: inbox, notifier: notifier, mayNotify: () => gate, canRead: () => true);
    await watcher.check(); // the first look only remembers what is there
    return (notifier, inbox, watcher);
  }

  test('messages go to their own chat channel, one notification per conversation (#352)', () async {
    final (notifier, inbox, watcher) = await primed();
    inbox.page = const MalMessagesPage([
      MalMessage(id: 9, counterpart: 'Ren_99', subject: 'Re: Club night', preview: 'See you', threadId: 70, avatarUrl: 'https://x/ren.jpg', isRead: false),
      MalMessage(id: 8, counterpart: 'Ren_99', subject: 'Club night', threadId: 70, isRead: false),
      MalMessage(id: 5, counterpart: 'Aki', subject: 'Hi', isRead: false),
    ]);
    expect(await watcher.check(), 2);
    expect(notifier.shown.map((e) => e.$1).toSet(), {MalHubChannel.messages});
    final ren = notifier.shown.first.$2;
    expect(ren.sender, 'Ren_99');
    expect(ren.avatarUrl, 'https://x/ren.jpg');
    expect(ren.body, 'Re: Club night\nSee you', reason: 'the newest message of the thread');
    expect(ren.id, MalMessagesWatcher.idFor(messageId: 8, threadId: 70), reason: 'same id for the whole thread');
  });

  test('the messages follow the notification gate, not the episode reminders', () async {
    final (notifier, inbox, watcher) = await primed(gate: false);
    inbox.page = const MalMessagesPage([MalMessage(id: 3, counterpart: 'a', subject: 's', isRead: false)]);
    expect(await watcher.check(), 0);
    expect(notifier.shown, isEmpty);
  });

  test('opening a conversation removes its notification', () async {
    final (notifier, _, watcher) = await primed();
    await watcher.cancelThread(messageId: 8, threadId: 70);
    expect(notifier.cancelled, [MalMessagesWatcher.idFor(messageId: 1, threadId: 70)]);
  });
}
