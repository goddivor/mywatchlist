import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_notifications_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/notifications/anilist_notification_tile.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart'
    show AnilistPageFooter, anilistErrorText;
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumMessage, ForumSkeleton;

/// Opens the AniList inbox.
Future<void> openAnilistNotifications(BuildContext context) =>
    AppRoutes.push<void>(context, const AnilistNotificationsPage());

class _GroupState {
  final List<AnilistNotification> items = [];
  int page = 0;
  bool hasNext = true;
  bool loading = false;
  Object? error;
  bool loaded = false;
}

/// The AniList notifications: filter chips by group (All, Airing, Activity, Forum, Follows,
/// Media), the entries with a dot while unread, and a tap that opens what they are about.
/// The inbox is marked read once the first page of "All" is on screen; the dots stay until
/// the page closes.
class AnilistNotificationsPage extends StatefulWidget {
  const AnilistNotificationsPage({super.key, this.service, this.unread});

  final AnilistNotificationsService? service;
  final AnilistUnreadCount? unread;

  @override
  State<AnilistNotificationsPage> createState() => _AnilistNotificationsPageState();
}

class _AnilistNotificationsPageState extends State<AnilistNotificationsPage> {
  final Map<AnilistNotificationGroup, _GroupState> _groups = {
    for (final g in AnilistNotificationGroup.values) g: _GroupState(),
  };
  final ScrollController _scroll = ScrollController();
  AnilistNotificationGroup _group = AnilistNotificationGroup.all;
  DateTime? _unreadSince;
  bool _markedRead = false;

  AnilistNotificationsService get _service =>
      widget.service ?? AnilistNotificationsService.instance;
  AnilistUnreadCount get _unread => widget.unread ?? AnilistUnreadCount.instance;
  _GroupState get _state => _groups[_group]!;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (_service.signedIn) _load(_group);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels > p.maxScrollExtent - 600) _load(_group);
  }

  Future<void> _load(AnilistNotificationGroup group, {bool refresh = false}) async {
    final st = _groups[group]!;
    if (st.loading || (!refresh && st.loaded && !st.hasNext)) return;
    st.loading = true;
    st.error = null;
    if (mounted) setState(() {});
    try {
      final page = await _service.page(group: group, page: refresh ? 1 : st.page + 1);
      if (!mounted) return;
      setState(() {
        if (refresh) st.items.clear();
        st.items.addAll(page.items);
        st.page = refresh ? 1 : st.page + 1;
        st.hasNext = page.hasNext;
        st.loaded = true;
        if (group == AnilistNotificationGroup.all && st.page == 1 && !_markedRead) {
          _unreadSince = page.unreadSince;
        }
      });
      if (group == AnilistNotificationGroup.all && !_markedRead) _markRead();
    } catch (e) {
      if (mounted) setState(() => st.error = e);
    } finally {
      st.loading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _markRead() async {
    _markedRead = true;
    try {
      await _service.markRead();
      _unread.markedRead();
    } catch (_) {
      _markedRead = false;
    }
  }

  Future<void> _refresh() async {
    _groups[_group]!.hasNext = true;
    await _load(_group, refresh: true);
  }

  void _select(AnilistNotificationGroup group) {
    if (group == _group) return;
    setState(() => _group = group);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (!_state.loaded) _load(group);
  }

  String _label(S s, AnilistNotificationGroup g) => switch (g) {
        AnilistNotificationGroup.all => s.Aln_Group_All,
        AnilistNotificationGroup.airing => s.Aln_Group_Airing,
        AnilistNotificationGroup.activity => s.Aln_Group_Activity,
        AnilistNotificationGroup.forum => s.Aln_Group_Forum,
        AnilistNotificationGroup.follows => s.Aln_Group_Follows,
        AnilistNotificationGroup.media => s.Aln_Group_Media,
      };

  bool _isUnread(AnilistNotification n) {
    final since = _unreadSince;
    final at = n.createdAt;
    return since != null && at != null && !at.isBefore(since);
  }

  Widget _signIn(BuildContext context, {required bool expired}) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              expired ? s.Al_Session_Expired : s.Aln_Sign_In_Title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => AppRoutes.signInAgain(context, AccountType.anilist),
              child: Text(expired ? s.Al_Sign_In_Again : s.Al_Sign_In),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final s = S.of(context);
    if (!_service.signedIn) return _signIn(context, expired: false);
    final st = _state;
    if (st.error is AnilistSessionExpired) return _signIn(context, expired: true);
    if (!st.loaded) {
      return st.error != null
          ? ForumMessage(
              icon: Icons.cloud_off_outlined,
              title: anilistErrorText(st.error!),
              onRetry: () => _load(_group),
            )
          : const ForumSkeleton(count: 6, round: true, rowHeight: 64);
    }
    if (st.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ForumMessage(icon: Icons.notifications_none, title: s.Aln_Empty),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: st.items.length + 1,
        itemBuilder: (context, i) {
          if (i == st.items.length) {
            return AnilistPageFooter(
              loading: st.loading,
              failed: st.error != null,
              onRetry: () => _load(_group),
            );
          }
          final n = st.items[i];
          return AnilistNotificationTile(
              key: ValueKey(n.id), notification: n, unread: _isUnread(n));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.Aln_Title)),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: AnilistNotificationGroup.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final g = AnilistNotificationGroup.values[i];
                return ChoiceChip(
                  label: Text(_label(s, g)),
                  selected: g == _group,
                  onSelected: (_) => _select(g),
                );
              },
            ),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }
}
