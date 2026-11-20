import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/mal_chat_screen.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_conversations.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_outbox.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/mal_web/chat_tiles.dart';
import 'package:mywatchlist/widgets/mal_web/message_tiles.dart';

export 'package:mywatchlist/screens/mal_web/mal_chat_screen.dart' show openMalChat;

/// Opens the MAL conversations.
Future<void> openMalMessages(BuildContext context) =>
    AppRoutes.push<void>(context, const MalMessagesScreen());

/// Opens the chat with [to], or the screen that picks a person when [to] is empty. Completes
/// with true (kept for the callers of the former compose screen).
Future<bool> openComposeMalMessage(BuildContext context, {String? to}) async {
  final name = (to ?? '').trim();
  if (name.isEmpty) {
    await AppRoutes.push<void>(context, const NewMalChatScreen());
  } else {
    await openMalChat(context, name);
  }
  return true;
}

/// The MAL private messages as a messaging app lists them: one row per person (inbox and
/// sent box together), the newest conversation first, with the start of its last message, its
/// time and the unread count. A button starts a new conversation.
class MalMessagesScreen extends StatefulWidget {
  const MalMessagesScreen({super.key, this.api, this.source, this.outbox, this.initialTab = 0});

  final MalMessagesApi? api;
  final MalConversationsSource? source;
  final MalOutbox? outbox;

  /// Kept for the routes that opened the former Inbox / Sent tabs; the list has both.
  final int initialTab;

  @override
  State<MalMessagesScreen> createState() => _MalMessagesScreenState();
}

class _MalMessagesScreenState extends State<MalMessagesScreen> {
  List<MalConversation> _items = const [];
  bool _loading = true;
  bool _hasMore = false;
  int _pages = 2;
  Object? _error;
  int _generation = 0;

  MalMessagesApi get _api => widget.api ?? MalMessagesApi.instance;
  MalOutbox get _outbox => widget.outbox ?? MalOutbox.instance;
  MalConversationsSource get _source => widget.source ?? MalConversationsSource(api: _api);
  MalWebSession get _session => _api.client.session;

  @override
  void initState() {
    super.initState();
    _outbox.addListener(_onOutbox);
    unawaited(_outbox.load());
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _outbox.removeListener(_onOutbox);
    super.dispose();
  }

  void _onOutbox() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _source.load(pages: _pages);
      if (!mounted || generation != _generation) return;
      for (final c in result.conversations) {
        final sent = [for (final r in c.rows) if (r.isSent) r];
        _outbox.reconcile(
          c.counterpart,
          (m) => sent.any((r) => previewMatches(r.preview, MalOutbox.textKey(m.body))),
        );
      }
      setState(() {
        _items = result.conversations;
        _hasMore = result.hasMore;
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

  Future<void> _open(MalConversation conversation) async {
    await openMalChat(context, conversation.counterpart, conversation: conversation);
    if (mounted) unawaited(_refresh());
  }

  Future<void> _newChat() async {
    await AppRoutes.push<void>(context, NewMalChatScreen(api: widget.api));
    if (mounted) unawaited(_refresh());
  }

  /// The state of the newest outbox message to [conversation]'s person, when it is newer
  /// than what MAL listed.
  MalSendState? _pending(MalConversation conversation) {
    final mine = _outbox.to(conversation.counterpart);
    if (mine.isEmpty) return null;
    final last = mine.last;
    if (last.failed) return MalSendState.failed;
    return last.sent ? MalSendState.sent : MalSendState.sending;
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
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _session,
        builder: (context, _) => _session.isConnected
            ? FloatingActionButton(
                tooltip: s.Pc_New,
                onPressed: _newChat,
                child: const Icon(Icons.chat_outlined),
              )
            : const SizedBox.shrink(),
      ),
      body: MalSessionGate(session: _session, connected: _list),
    );
  }

  Widget _list(BuildContext context) {
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
            : MalMessagesStateView(icon: Icons.forum_outlined, text: s.Pc_Empty),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, i) =>
            Divider(height: 1, indent: 78, color: scheme.outlineVariant.withValues(alpha: 0.4)),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(
                        onPressed: () {
                          _pages += 2;
                          _refresh();
                        },
                        child: Text(s.Pc_Earlier),
                      ),
              ),
            );
          }
          final c = _items[i];
          return MalConversationTile(conversation: c, pending: _pending(c), onTap: () => _open(c));
        },
      ),
    );
  }
}

/// Picks the person of a new conversation: the user's friends, and MAL's user search once
/// three letters are typed. Tapping a person opens the chat with them.
class NewMalChatScreen extends StatefulWidget {
  const NewMalChatScreen({super.key, this.api});

  final MalMessagesApi? api;

  @override
  State<NewMalChatScreen> createState() => _NewMalChatScreenState();
}

class _NewMalChatScreenState extends State<NewMalChatScreen> {
  final TextEditingController _query = TextEditingController();
  List<MalUserSuggestion> _friends = const [];
  List<MalUserSuggestion> _found = const [];
  bool _searching = false;
  int _search = 0;
  Timer? _debounce;

  MalMessagesApi get _api => widget.api ?? MalMessagesApi.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFriends());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      await _api.client.session.ensureLoaded();
      final friends = await _api.friends();
      if (mounted) setState(() => _friends = friends);
    } catch (_) {
      // The search still answers.
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 3) {
      setState(() {
        _found = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final generation = ++_search;
      List<MalUserSuggestion> found;
      try {
        found = await _api.searchUsers(q);
      } catch (_) {
        found = const [];
      }
      if (!mounted || generation != _search) return;
      setState(() {
        _found = found;
        _searching = false;
      });
    });
  }

  void _pick(String name) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => MalChatScreen(counterpart: name, api: widget.api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final q = _query.text.trim().toLowerCase();
    final friends = q.isEmpty ? _friends : _friends.where((f) => f.name.toLowerCase().contains(q)).toList();
    final friendNames = {for (final f in friends) f.name.toLowerCase()};
    final others = [for (final u in _found) if (!friendNames.contains(u.name.toLowerCase())) u];
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        );
    Widget tile(MalUserSuggestion u) => ListTile(
          leading: ForumAvatar(username: u.name, url: u.imageUrl, size: 40, tappable: false),
          title: Text(u.name),
          onTap: () => _pick(u.name),
        );
    final typed = _query.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.go,
          decoration: InputDecoration(hintText: s.Pc_Search_Hint, border: InputBorder.none),
          onChanged: _onChanged,
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) _pick(v.trim());
          },
        ),
      ),
      body: ListView(
        children: [
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          if (friends.isNotEmpty) ...[header(s.Pc_Friends), ...friends.map(tile)],
          if (others.isNotEmpty) ...[header(s.Pc_Users), ...others.map(tile)],
          if (typed.length >= 3 && !_searching && friends.isEmpty && others.isEmpty)
            ListTile(
              leading: const Icon(Icons.person_search_outlined),
              title: Text(s.Pc_No_User),
            ),
        ],
      ),
    );
  }
}
