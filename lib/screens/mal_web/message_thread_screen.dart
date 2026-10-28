import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/mal_web/message_tiles.dart';

/// What the thread screen did, for the list that opened it.
enum MessageThreadResult { deleted }

/// A message and its thread as chat bubbles (oldest at the top), with a reply box at the
/// bottom when MAL offers a reply.
class MalMessageThreadScreen extends StatefulWidget {
  const MalMessageThreadScreen({super.key, required this.message, this.api, this.session});

  final MalMessage message;
  final MalMessagesApi? api;
  final MalWebSession? session;

  @override
  State<MalMessageThreadScreen> createState() => _MalMessageThreadScreenState();
}

class _MalMessageThreadScreenState extends State<MalMessageThreadScreen> {
  final TextEditingController _reply = TextEditingController();
  MalMessageThread? _thread;
  Object? _error;
  bool _loading = true;
  bool _sending = false;

  MalMessagesApi get _api => widget.api ?? MalMessagesApi.instance;
  MalWebSession get _session => widget.session ?? _api.client.session;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final thread = await _api.thread(widget.message);
      if (!mounted) return;
      setState(() {
        _thread = thread;
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

  Future<void> _send() async {
    final thread = _thread;
    final text = _reply.text;
    if (thread == null || _sending || text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.reply(thread, text);
      if (!mounted) return;
      _reply.clear();
      setState(() {
        _sending = false;
        _thread = thread.withMessage(MalThreadMessage(
          sender: _api.me ?? '',
          html: const HtmlEscape().convert(messageBody(text)).replaceAll('\n', '<br>'),
          isMine: true,
        ));
      });
      showMessageSnack(context, S.current.Pm_Sent);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showMessageSnack(context, messageErrorText(e));
    }
  }

  Future<void> _delete() async {
    if (!await confirmDeleteMessage(context)) return;
    try {
      await _api.delete(widget.message);
      if (!mounted) return;
      showMessageSnack(context, S.current.Pm_Deleted);
      Navigator.of(context).pop(MessageThreadResult.deleted);
    } catch (e) {
      if (mounted) showMessageSnack(context, messageErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final thread = _thread;
    final subject = thread?.subject.isNotEmpty ?? false ? thread!.subject : widget.message.subject;
    final other = thread?.counterpart.isNotEmpty ?? false ? thread!.counterpart : widget.message.counterpart;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ForumAvatar(username: other, url: thread?.avatarUrl, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                  Text(
                    other,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<int>(
            onSelected: (v) {
              if (v == 0) _delete();
              if (v == 1) launchWebView(widget.message.url, context: context);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: scheme.error),
                  title: Text(s.Delete, style: TextStyle(color: scheme.error)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: Text(s.Mn_Open_Web),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: MalSessionGate(session: _session, connected: _content),
    );
  }

  Widget _content(BuildContext context) {
    final s = S.of(context);
    final thread = _thread;
    if (thread == null) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return MalMessagesStateView(
        icon: Icons.error_outline_rounded,
        text: _error is MalWebActionFailed ? messageErrorText(_error!) : s.Pm_Thread_Error,
        action: s.Ms_Retry,
        onAction: _load,
      );
    }
    final items = thread.messages.reversed.toList();
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              reverse: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, i) => MalMessageBubble(message: items[i]),
            ),
          ),
        ),
        if (thread.canReply) _ReplyBar(controller: _reply, sending: _sending, name: thread.counterpart, onSend: _send),
      ],
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.controller, required this.sending, required this.name, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final String name;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
                  decoration: InputDecoration(
                    hintText: s.Pm_Reply_Hint(name),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton.filled(
                        tooltip: s.Pm_Send,
                        onPressed: controller.text.trim().isEmpty ? null : onSend,
                        icon: const Icon(Icons.send_rounded),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
