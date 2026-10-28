import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/MAL/web/profile_comments_api.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';

final DateFormat _malDate = DateFormat('MMM d, yyyy h:mm a', 'en_US');

/// MAL's absolute comment date (`Oct 30, 2023 8:44 PM`) in the app's locale; relative
/// dates (`5 hours ago`, `Yesterday, 1:47 PM`) stay as MAL wrote them.
String formatCommentDate(String raw, String locale) {
  try {
    final date = _malDate.parseStrict(raw);
    return DateFormat.yMMMd(locale).add_jm().format(date);
  } catch (_) {
    return raw;
  }
}

/// The message for a failed comment action.
String commentErrorText(Object error) {
  final s = S.current;
  if (error is MalWebActionFailed && (error.message?.trim().isNotEmpty ?? false)) {
    return s.Ms_Comment_Refused(error.message!.trim());
  }
  if (error is MalWebSessionExpired || error is MalWebNoSession) return s.Ms_Session_Expired;
  return s.Ms_Action_Failed;
}

void showCommentSnack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
}

/// One profile comment: avatar, author, date, body, and the actions MAL offers the viewer
/// (conversation, reply, delete) in a menu.
class ProfileCommentTile extends StatelessWidget {
  const ProfileCommentTile({
    super.key,
    required this.comment,
    this.onConversation,
    this.onReply,
    this.onDelete,
  });

  final ProfileComment comment;
  final VoidCallback? onConversation;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag().replaceAll('-', '_');
    final hasMenu = onConversation != null || onReply != null || onDelete != null;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      padding: EdgeInsetsDirectional.fromSTEB(16, 12, hasMenu ? 4 : 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ForumAvatar(username: comment.author, url: comment.avatarUrl, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => openForumUser(context, comment.author),
                  child: Text(
                    comment.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (comment.date != null)
                  Text(
                    formatCommentDate(comment.date!, locale),
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                if (comment.html.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  MalHtmlBody(
                    comment.html,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
                  ),
                ],
              ],
            ),
          ),
          if (hasMenu)
            PopupMenuButton<VoidCallback>(
              icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant, size: 20),
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                if (onConversation != null)
                  PopupMenuItem(
                    value: onConversation,
                    child: ListTile(
                      leading: const Icon(Icons.forum_outlined),
                      title: Text(s.Ms_Comment_Conversation),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onReply != null)
                  PopupMenuItem(
                    value: onReply,
                    child: ListTile(
                      leading: const Icon(Icons.reply_outlined),
                      title: Text(s.Ms_Comment_Reply),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: onDelete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: scheme.error),
                      title: Text(s.Ms_Comment_Delete, style: TextStyle(color: scheme.error)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A text field with a send button. [onSend] returns true when the text was accepted (the
/// field is then emptied); the button shows a spinner while it runs.
class ProfileCommentComposer extends StatefulWidget {
  const ProfileCommentComposer({
    super.key,
    required this.onSend,
    this.hint,
    this.autofocus = false,
  });

  final Future<bool> Function(String text) onSend;
  final String? hint;
  final bool autofocus;

  @override
  State<ProfileCommentComposer> createState() => _ProfileCommentComposerState();
}

class _ProfileCommentComposerState extends State<ProfileCommentComposer> {
  final TextEditingController _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _text.text.trim();
    if (value.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.onSend(value);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _text,
            autofocus: widget.autofocus,
            enabled: !_sending,
            minLines: 1,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: widget.hint ?? s.Ms_Comment_Hint,
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _text,
          builder: (context, value, _) => IconButton.filled(
            tooltip: s.Ms_Comment_Send,
            onPressed: _sending || value.text.trim().isEmpty ? null : _send,
            icon: _sending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ),
      ],
    );
  }
}

/// A one-line row inviting a signed-in MAL user without a website session to connect it.
class CommentConnectRow extends StatelessWidget {
  const CommentConnectRow({super.key, required this.label, required this.onConnect});

  final String label;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
        child: Row(
          children: [
            Icon(Icons.chat_bubble_outline, size: 20, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer),
              ),
            ),
            TextButton(
              onPressed: onConnect,
              style: TextButton.styleFrom(foregroundColor: scheme.onSecondaryContainer),
              child: Text(S.of(context).Ms_Connect),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with a composer, for a reply. Returns when the reply was sent or the sheet
/// closed; [onSend] does the work and reports errors itself.
Future<void> showCommentReplySheet(
  BuildContext context, {
  required String to,
  required Future<bool> Function(String text) onSend,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(sheetContext).Ms_Comment_Reply_To(to),
            style: Theme.of(sheetContext).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ProfileCommentComposer(
            autofocus: true,
            onSend: (text) async {
              final ok = await onSend(text);
              if (ok && sheetContext.mounted) Navigator.of(sheetContext).pop();
              return ok;
            },
          ),
        ],
      ),
    ),
  );
}
