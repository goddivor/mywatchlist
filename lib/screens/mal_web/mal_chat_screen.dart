import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_conversations.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_outbox.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/services/upload/image_upload.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/mal_web/chat_tiles.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/composer_controls.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/message_markup.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/reply_composer.dart';
import 'package:mywatchlist/widgets/mal_web/message_tiles.dart';

/// Opens the chat with [name]. [conversation] is what the list already knows of it; without
/// it the boxes are read to find it (a new conversation when there is none).
Future<void> openMalChat(BuildContext context, String name, {MalConversation? conversation}) =>
    AppRoutes.push<void>(context, MalChatScreen(counterpart: name, conversation: conversation));

/// Everything exchanged with one person, as a messaging app shows it: one chat across MAL's
/// threads and boxes, the newest at the bottom, and a message bar. A message shows at once
/// with a clock, then two ticks once MAL took it, coloured ones once the other person read it;
/// a failed one is tapped to be sent again (the outbox keeps its text).
class MalChatScreen extends StatefulWidget {
  const MalChatScreen({
    super.key,
    required this.counterpart,
    this.conversation,
    this.api,
    this.outbox,
    this.source,
    this.uploader,
    this.pickImage,
  });

  final String counterpart;
  final MalConversation? conversation;
  final MalMessagesApi? api;
  final MalOutbox? outbox;
  final MalConversationsSource? source;
  final ImageUploader? uploader;
  final MalImagePick? pickImage;

  @override
  State<MalChatScreen> createState() => _MalChatScreenState();
}

class _MalChatScreenState extends State<MalChatScreen> {
  final TextEditingController _text = TextEditingController();
  MalConversation? _conversation;
  MalChatHistory? _history;
  Object? _error;
  bool _loading = true;
  int _threads = 4;

  MalMessagesApi get _api => widget.api ?? MalMessagesApi.instance;
  MalOutbox get _outbox => widget.outbox ?? MalOutbox.instance;
  MalWebSession get _session => _api.client.session;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _outbox.addListener(_onOutbox);
    unawaited(_outbox.load());
    unawaited(_load());
  }

  @override
  void dispose() {
    _outbox.removeListener(_onOutbox);
    _text.dispose();
    super.dispose();
  }

  void _onOutbox() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool findAgain = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var conversation = findAgain ? null : _conversation;
      if (conversation == null) {
        final found = await (widget.source ?? MalConversationsSource(api: _api)).load();
        final key = widget.counterpart.toLowerCase();
        for (final c in found.conversations) {
          if (c.key == key) conversation = c;
        }
      }
      final history = conversation == null
          ? const MalChatHistory(messages: [])
          : await loadChatHistory(_api, conversation, maxThreads: _threads);
      if (!mounted) return;
      final onMal = {for (final m in history.messages) if (m.isMine) messageTextKey(m.html)};
      _outbox.reconcile(widget.counterpart, (m) => onMal.contains(MalOutbox.textKey(m.body)));
      setState(() {
        _conversation = conversation;
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _send() {
    final body = _text.text;
    if (body.trim().isEmpty) return;
    _text.clear();
    _outbox.send(to: _conversation?.counterpart ?? widget.counterpart, body: body, thread: _history?.replyTo);
  }

  /// The chat: MAL's messages, then the outbox's (the sent ones not yet read back from MAL).
  List<MalChatMessage> _messages() {
    final history = _history?.messages ?? const <MalChatMessage>[];
    final known = {for (final m in history) if (m.isMine) messageTextKey(m.html)};
    return [
      ...history,
      for (final m in _outbox.to(widget.counterpart))
        // A copy MAL already shows is not drawn twice (only a message still waiting is).
        if ((!m.sent && !m.failed) || !known.contains(MalOutbox.textKey(m.body)))
          MalChatMessage(
            html: bbcodeToHtml(messageBody(m.body)),
            isMine: true,
            subject: m.subject,
            at: m.createdAt,
            outboxId: m.id,
            state: m.sent
                ? MalSendState.sent
                : (m.failed ? MalSendState.failed : MalSendState.sending),
          ),
    ];
  }

  Future<void> _actions(MalChatMessage message) async {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final failed = message.state == MalSendState.failed && message.outboxId != null;
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failed)
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: Text(s.Pc_Retry),
                onTap: () => Navigator.pop(context, 0),
              ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(s.Pc_Copy),
              onTap: () => Navigator.pop(context, 1),
            ),
            if (failed)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
                title: Text(s.Pc_Discard, style: TextStyle(color: scheme.error)),
                onTap: () => Navigator.pop(context, 2),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 0:
        _outbox.retry(message.outboxId!);
      case 1:
        final text = message.outboxId != null
            ? _outbox.messages.firstWhere((m) => m.id == message.outboxId).body
            : html_parser.parseFragment(message.html).text ?? '';
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) showMessageSnack(context, s.Pc_Copied);
      case 2:
        _outbox.discard(message.outboxId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = _conversation?.counterpart ?? widget.counterpart;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => AppRoutes.openUserProfile(context, tracker: AccountType.myanimelist, username: name),
          child: Row(
            children: [
              ForumAvatar(username: name, url: _history?.avatarUrl ?? _conversation?.avatarUrl, size: 38, tappable: false),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<int>(
            onSelected: (_) => launchWebView('${MalWebClient.base}/mymessages.php', context: context),
            itemBuilder: (context) => [PopupMenuItem(value: 0, child: Text(S.of(context).Mn_Open_Web))],
          ),
        ],
      ),
      backgroundColor: scheme.surface,
      body: MalWebFormHost(child: MalSessionGate(session: _session, connected: _content)),
    );
  }

  Widget _content(BuildContext context) {
    final s = S.of(context);
    final history = _history;
    if (history == null) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return MalMessagesStateView(
        icon: Icons.error_outline_rounded,
        text: _error is MalWebActionFailed ? messageErrorText(_error!) : s.Pm_Thread_Error,
        action: s.Ms_Retry,
        onAction: _load,
      );
    }
    final messages = _messages();
    final rows = _rows(context, messages, history);
    final name = _conversation?.counterpart ?? widget.counterpart;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(findAgain: true),
            child: messages.isEmpty
                ? MalMessagesStateView(icon: Icons.chat_bubble_outline_rounded, text: s.Pc_Start(name))
                : ListView.builder(
                    reverse: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => rows[rows.length - 1 - i],
                  ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        MalReplyComposer(
          controller: _text,
          sending: false,
          hint: s.Pc_Hint,
          onSend: _send,
          uploader: widget.uploader,
          pickImage: widget.pickImage,
        ),
      ],
    );
  }

  /// Bubbles in reading order, with a day chip when the day changes and a subject chip when
  /// the MAL thread does.
  List<Widget> _rows(BuildContext context, List<MalChatMessage> messages, MalChatHistory history) {
    final s = S.of(context);
    final rows = <Widget>[];
    if (history.olderThreads > 0) {
      rows.add(Center(
        child: TextButton.icon(
          onPressed: _loading
              ? null
              : () {
                  _threads += 4;
                  _load();
                },
          icon: const Icon(Icons.history_rounded, size: 18),
          label: Text(s.Pc_Earlier),
        ),
      ));
    }
    DateTime? day;
    String? subject;
    for (final m in messages) {
      final at = m.at;
      if (at != null && (day == null || at.year != day.year || at.month != day.month || at.day != day.day)) {
        day = at;
        rows.add(MalChatChip(text: chatDayLabel(context, at)));
      }
      final topic = m.subject.replaceFirst(RegExp(r'^(Re:\s*)+', caseSensitive: false), '').trim();
      if (topic.isNotEmpty && topic != subject && m.outboxId == null) {
        subject = topic;
        rows.add(MalChatChip(text: s.Pc_Subject(topic), subtle: true));
      }
      rows.add(MalChatBubble(
        message: m,
        onTap: m.state == MalSendState.failed && m.outboxId != null ? () => _outbox.retry(m.outboxId!) : null,
        onLongPress: () => _actions(m),
      ));
    }
    return rows;
  }
}
