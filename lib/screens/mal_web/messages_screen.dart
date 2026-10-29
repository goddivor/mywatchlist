import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/compose_message_screen.dart';
import 'package:mywatchlist/screens/mal_web/message_thread_screen.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/mal_web/message_tiles.dart';

export 'package:mywatchlist/screens/mal_web/compose_message_screen.dart' show openComposeMalMessage;

/// Opens the MAL messages (Inbox / Sent).
Future<void> openMalMessages(BuildContext context) =>
    AppRoutes.push<void>(context, const MalMessagesScreen());

/// MAL private messages: Inbox (unread count in the tab) and Sent, a compose button.
class MalMessagesScreen extends StatefulWidget {
  const MalMessagesScreen({super.key, this.api, this.session, this.initialTab = 0});

  final MalMessagesApi? api;
  final MalWebSession? session;

  /// 0 = inbox, 1 = sent.
  final int initialTab;

  @override
  State<MalMessagesScreen> createState() => _MalMessagesScreenState();
}

class _MalMessagesScreenState extends State<MalMessagesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));

  /// Bumped after a message was sent: the boxes read their first page again.
  final ValueNotifier<int> _reload = ValueNotifier<int>(0);

  MalMessagesApi get _api => widget.api ?? MalMessagesApi.instance;
  MalWebSession get _session => widget.session ?? _api.client.session;

  @override
  void dispose() {
    _tabs.dispose();
    _reload.dispose();
    super.dispose();
  }

  Future<void> _compose() async {
    final sent = await AppRoutes.push<bool>(context, ComposeMalMessageScreen(api: widget.api, session: widget.session));
    if (sent ?? false) _reload.value++;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.Pm_Title),
        actions: [
          PopupMenuButton<int>(
            onSelected: (_) => launchWebView('${MalWebClient.base}/mymessages.php', context: context),
            itemBuilder: (context) => [PopupMenuItem(value: 0, child: Text(s.Mn_Open_Web))],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.Pm_Inbox),
                  const SizedBox(width: 6),
                  const MalMessagesUnreadBadge(),
                ],
              ),
            ),
            Tab(text: s.Pm_Sent_Box),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _session,
        builder: (context, _) => _session.isConnected
            ? FloatingActionButton(
                tooltip: s.Pm_Compose,
                onPressed: _compose,
                child: const Icon(Icons.edit_outlined),
              )
            : const SizedBox.shrink(),
      ),
      body: MalSessionGate(
        session: _session,
        connected: (context) => TabBarView(
          controller: _tabs,
          children: [
            _MessageBox(api: _api, session: widget.session, sent: false, reload: _reload),
            _MessageBox(api: _api, session: widget.session, sent: true, reload: _reload),
          ],
        ),
      ),
    );
  }
}

/// One box, a page of 20 at a time, the next page loaded when the end comes into view.
class _MessageBox extends StatefulWidget {
  const _MessageBox({required this.api, required this.sent, required this.reload, this.session});

  final MalMessagesApi api;
  final MalWebSession? session;
  final bool sent;
  final ValueListenable<int> reload;

  @override
  State<_MessageBox> createState() => _MessageBoxState();
}

class _MessageBoxState extends State<_MessageBox> with AutomaticKeepAliveClientMixin {
  List<MalMessage> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _moreFailed = false;
  bool _hasMore = false;
  Object? _error;
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.reload.addListener(_refresh);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    widget.reload.removeListener(_refresh);
    super.dispose();
  }

  Future<MalMessagesPage> _fetch(int offset) =>
      widget.sent ? widget.api.sent(offset: offset) : widget.api.inbox(offset: offset);

  Future<void> _refresh() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _fetch(0);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = page.messages;
        _hasMore = page.messages.length >= MalMessagesApi.pageSize;
        _moreFailed = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final page = await _fetch(_items.length);
      if (!mounted || generation != _generation) return;
      final known = {for (final m in _items) m.id};
      final fresh = page.messages.where((m) => known.add(m.id)).toList();
      setState(() {
        _items = [..._items, ...fresh];
        _hasMore = fresh.isNotEmpty && page.messages.length >= MalMessagesApi.pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  Future<void> _open(MalMessage message) async {
    final index = _items.indexWhere((m) => m.id == message.id);
    if (!message.isRead && index >= 0) {
      setState(() => _items = [..._items]..[index] = message.copyWith(isRead: true));
    }
    final result = await AppRoutes.push<MessageThreadResult>(
      context,
      MalMessageThreadScreen(message: message, api: widget.api, session: widget.session),
    );
    if (result == MessageThreadResult.deleted && mounted) {
      setState(() => _items = _items.where((m) => m.id != message.id).toList());
    }
  }

  Future<bool> _delete(MalMessage message) async {
    if (!await confirmDeleteMessage(context)) return false;
    try {
      await widget.api.delete(message);
      if (!mounted) return true;
      showMessageSnack(context, S.current.Pm_Deleted);
      return true;
    } catch (e) {
      if (mounted) showMessageSnack(context, messageErrorText(e));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return RefreshIndicator(
        onRefresh: _refresh,
        child: _error != null
            ? MalMessagesStateView(
                icon: Icons.error_outline_rounded,
                text: _error is MalWebActionFailed ? messageErrorText(_error!) : s.Pm_Load_Error,
                action: s.Ms_Retry,
                onAction: _refresh,
              )
            : MalMessagesStateView(
                icon: widget.sent ? Icons.outbox_outlined : Icons.inbox_outlined,
                text: widget.sent ? s.Pm_Sent_Empty : s.Pm_Inbox_Empty,
              ),
      );
    }
    final footer = _hasMore ? 1 : 0;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: _items.length + footer,
        separatorBuilder: (context, i) => Divider(height: 1, indent: 68, color: scheme.outlineVariant.withValues(alpha: 0.5)),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            if (!_loadingMore && !_moreFailed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _loadMore();
              });
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _moreFailed
                    ? TextButton(onPressed: _loadMore, child: Text(s.Ms_Retry))
                    : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          }
          final m = _items[i];
          return Dismissible(
            key: ValueKey('pm_${widget.sent}_${m.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _delete(m),
            onDismissed: (_) => setState(() => _items = _items.where((x) => x.id != m.id).toList()),
            background: ColoredBox(
              color: scheme.errorContainer,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 24),
                  child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
                ),
              ),
            ),
            child: MalMessageTile(message: m, onTap: () => _open(m)),
          );
        },
      ),
    );
  }
}
