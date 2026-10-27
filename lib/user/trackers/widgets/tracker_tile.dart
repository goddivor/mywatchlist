import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/account_status.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/widgets/common/acc_widget.dart';

/// One tracker in every account screen (settings, switcher, first sign in, intro).
///
/// What the tile shows and does follows [status]:
/// * connected: a radio mark (filled = active account); tapping the tile makes it active;
///   the overflow menu signs out;
/// * needs sign in: error tint, "Sign in again" button;
/// * connecting: spinner and "Cancel" (a sign in that never came back cannot block);
/// * disconnected: the service pitch and a "Connect" button.
class TrackerTile extends StatelessWidget {
  final TrackerInfo info;
  final TrackerStatus status;
  final String? username;
  final String? imageUrl;
  final bool isActive;

  /// Tap on a connected account that is not active. Null = not selectable.
  final VoidCallback? onSelect;
  final VoidCallback? onConnect;
  final VoidCallback? onCancel;

  /// Adds the "Sign out" entry of the overflow menu (connected and expired accounts).
  final VoidCallback? onSignOut;

  const TrackerTile({
    super.key,
    required this.info,
    required this.status,
    this.username,
    this.imageUrl,
    this.isActive = false,
    this.onSelect,
    this.onConnect,
    this.onCancel,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final expired = status == TrackerStatus.needsSignIn;
    final connected = status == TrackerStatus.connected;
    final hasAccount = connected || expired;

    final Color border;
    final Color fill;
    if (expired) {
      border = colors.error.withValues(alpha: 0.5);
      fill = colors.errorContainer.withValues(alpha: 0.35);
    } else if (connected && isActive) {
      border = info.color.withValues(alpha: 0.7);
      fill = info.color.withValues(alpha: 0.10);
    } else {
      border = colors.outlineVariant.withValues(alpha: 0.6);
      fill = colors.surfaceContainerLow;
    }

    final title = hasAccount && (username?.isNotEmpty ?? false)
        ? username!
        : info.name;
    final onTap = connected ? (isActive ? null : onSelect) : null;

    final tile = Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border, width: isActive && connected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              hasAccount
                  ? AccountAvatar(info: info, imageUrl: imageUrl, size: 48)
                  : TrackerLogo(info: info, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    _subtitle(context),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ..._trailing(context),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      selected: connected && isActive,
      child: tile,
    );
  }

  Widget _subtitle(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final base = theme.textTheme.bodySmall;
    switch (status) {
      case TrackerStatus.connected:
        return Text.rich(
          TextSpan(children: [
            TextSpan(text: info.name),
            TextSpan(
              text: ' · ${isActive ? S.current.Acc_Active : S.current.Acc_Connected}',
              style: isActive
                  ? TextStyle(color: colors.primary, fontWeight: FontWeight.w600)
                  : null,
            ),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base?.copyWith(color: colors.onSurfaceVariant),
        );
      case TrackerStatus.needsSignIn:
        return Text(
          '${info.name} · ${S.current.Acc_Session_Expired}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base?.copyWith(color: colors.error, fontWeight: FontWeight.w600),
        );
      case TrackerStatus.connecting:
        return Text(
          S.current.Acc_Connecting,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base?.copyWith(color: colors.onSurfaceVariant),
        );
      case TrackerStatus.disconnected:
        return Text(
          info.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: base?.copyWith(color: colors.onSurfaceVariant),
        );
    }
  }

  List<Widget> _trailing(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    switch (status) {
      case TrackerStatus.connected:
        return [
          Icon(
            isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: isActive ? colors.primary : colors.outline,
          ),
          if (onSignOut != null) _menu(context) else const SizedBox(width: 8),
        ];
      case TrackerStatus.needsSignIn:
        return [
          FilledButton.tonal(
            onPressed: onConnect,
            style: FilledButton.styleFrom(
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(S.current.Acc_Sign_In_Again),
          ),
          if (onSignOut != null) _menu(context) else const SizedBox(width: 8),
        ];
      case TrackerStatus.connecting:
        return [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 4),
          TextButton(onPressed: onCancel, child: Text(S.current.Cancel)),
        ];
      case TrackerStatus.disconnected:
        return [
          FilledButton.tonal(
            onPressed: onConnect,
            style: FilledButton.styleFrom(
              backgroundColor: info.color.withValues(alpha: 0.18),
              foregroundColor: colors.onSurface,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(S.current.Acc_Connect),
          ),
          const SizedBox(width: 8),
        ];
    }
  }

  Widget _menu(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      tooltip: S.current.Acc_Menu_Tooltip,
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        PopupMenuItem<VoidCallback>(
          value: onSignOut!,
          child: Row(
            children: [
              Icon(Icons.logout_rounded,
                  size: 20, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              Text(S.current.Acc_Sign_Out),
            ],
          ),
        ),
      ],
    );
  }
}
