import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/messages_screen.dart' show openMalMessages;
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/mal_auth_v2.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/utils/sidebar_extension.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/user/profile/profile_comments.dart' show formatCommentDate;

/// The app's locale as `intl` wants it (`fr_FR`).
String messageLocale(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag().replaceAll('-', '_');

/// The text for a failed message action (MAL's own refusal when it gave one).
String messageErrorText(Object error) {
  final s = S.current;
  if (error is MalWebActionFailed && (error.message?.trim().isNotEmpty ?? false)) {
    return s.Ms_Comment_Refused(error.message!.trim());
  }
  if (error is MalWebSessionExpired || error is MalWebNoSession) return s.Ms_Session_Expired;
  return s.Ms_Action_Failed;
}

void showMessageSnack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
}

/// Asks before deleting a message.
Future<bool> confirmDeleteMessage(BuildContext context) async {
  final s = S.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(s.Pm_Delete_Confirm),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.Cancel)),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: Text(s.Delete),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// One row of the inbox or the sent box, like a mail list: initials, name and date on the
/// first line, subject, then the start of the body. Unread rows are bold with a dot.
class MalMessageTile extends StatelessWidget {
  const MalMessageTile({super.key, required this.message, this.onTap, this.onLongPress});

  final MalMessage message;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = !message.isRead;
    final strong = unread ? FontWeight.w700 : FontWeight.w500;
    final date = message.date;
    final hasSubject = message.subject.trim().isNotEmpty;
    final subject = hasSubject ? message.subject : message.preview;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ForumAvatar(username: message.counterpart, size: 40, tappable: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.counterpart,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: strong, color: scheme.onSurface),
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          formatCommentDate(date, messageLocale(context)),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: unread ? scheme.primary : scheme.onSurfaceVariant,
                            fontWeight: unread ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // No subject: the start of the body takes its line (no blank line).
                  if (subject.isNotEmpty || unread) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: unread ? FontWeight.w600 : null,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (unread)
                          Semantics(
                            label: S.of(context).Pm_Unread,
                            child: Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsetsDirectional.only(start: 8),
                              decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (hasSubject && message.preview.isNotEmpty)
                    Text(
                      message.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One message of a conversation as a chat bubble (MALClient's thread view): yours on the end
/// side in the accent container, theirs on the start side.
class MalMessageBubble extends StatelessWidget {
  const MalMessageBubble({super.key, required this.message});

  final MalThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = message.isMine;
    final background = mine ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final foreground = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    final date = message.date;
    final name = mine ? S.of(context).Pm_You : message.sender;
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(16),
              topEnd: const Radius.circular(16),
              bottomStart: Radius.circular(mine ? 16 : 4),
              bottomEnd: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date == null ? name : '$name · ${formatCommentDate(date, messageLocale(context))}',
                style: theme.textTheme.labelSmall?.copyWith(color: foreground.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 4),
              MalHtmlBody(message.html, style: theme.textTheme.bodyMedium?.copyWith(color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

/// An icon and one line, with an optional button, inside a scroll view so pull to refresh
/// still works over it.
class MalMessagesStateView extends StatelessWidget {
  const MalMessagesStateView({super.key, required this.icon, required this.text, this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface),
                  ),
                  if (action != null && onAction != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.tonal(onPressed: onAction, child: Text(action!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// No website session (or a dead one): one tap to connect, the MAL sign in capturing it.
class MalMessagesConnect extends StatelessWidget {
  const MalMessagesConnect({super.key, required this.state});

  final MalWebSessionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final unsupported = state == MalWebSessionState.unsupported;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline_rounded, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              switch (state) {
                MalWebSessionState.expired => s.Ms_Session_Expired,
                MalWebSessionState.unsupported => s.Ms_State_Unsupported,
                _ => s.Pm_Connect_Title,
              },
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface),
            ),
            if (!unsupported) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => MalAuthV2().handleSignIn(context: context),
                icon: const Icon(Icons.login_rounded),
                label: Text(s.Ms_Connect),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Builds [connected] when the MAL website session is connected, a spinner while it loads
/// and [MalMessagesConnect] otherwise; follows the session as it changes.
class MalSessionGate extends StatelessWidget {
  const MalSessionGate({super.key, required this.session, required this.connected});

  final MalWebSession session;
  final WidgetBuilder connected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final state = session.state;
        if (state == MalWebSessionState.loading) {
          session.ensureLoaded();
          return const Center(child: CircularProgressIndicator());
        }
        if (state != MalWebSessionState.connected) return MalMessagesConnect(state: state);
        return connected(context);
      },
    );
  }
}

/// The unread count as a small badge (nothing when zero).
class MalMessagesUnreadBadge extends StatelessWidget {
  const MalMessagesUnreadBadge({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: MalMessagesApi.unread,
      builder: (context, count, child) {
        if (count == 0) return child ?? const SizedBox.shrink();
        return Badge(
          backgroundColor: scheme.error,
          textColor: scheme.onError,
          label: Text(count > 99 ? '99+' : '$count'),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// A sidebar destination for the messages (`AppSidebar.extraItems`), with the unread count.
SidebarMenuItem malMessagesSidebarItem(BuildContext context, {VoidCallback? onTap}) {
  return SidebarMenuItem(
    icon: Icons.mail_outline_rounded,
    title: S.of(context).Pm_Title,
    onTap: onTap ?? () => openMalMessages(context),
    trailing: const MalMessagesUnreadBadge(),
  );
}
