import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_notifications_page.dart' show openAnilistNotifications;
import 'package:mywatchlist/services/api/Anilist/anilist_notifications_service.dart';

/// The AniList bell with its unread badge, for the app bar of the AniList home. It asks
/// AniList for the count when it appears and when the app comes back to the foreground
/// (never on a timer), and opens the inbox.
class AnilistNotificationBell extends StatefulWidget {
  const AnilistNotificationBell({super.key, this.unread, this.onOpen});

  /// The count holder; tests pass their own.
  final AnilistUnreadCount? unread;

  /// Replaces opening the inbox (tests).
  final VoidCallback? onOpen;

  @override
  State<AnilistNotificationBell> createState() => _AnilistNotificationBellState();
}

class _AnilistNotificationBellState extends State<AnilistNotificationBell>
    with WidgetsBindingObserver {
  AnilistUnreadCount get _unread => widget.unread ?? AnilistUnreadCount.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unread.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _unread.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _open() async {
    if (widget.onOpen != null) return widget.onOpen!();
    await openAnilistNotifications(context);
    if (mounted) _unread.refresh(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: _unread,
      builder: (context, _) {
        final count = _unread.count;
        return IconButton(
          tooltip: count > 0 ? s.Aln_Unread_Badge(count) : s.Aln_Title,
          onPressed: _open,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}
