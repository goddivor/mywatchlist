import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/main.dart' show appNavigatorKey;
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart' show MalWebFormHost;
import 'package:mywatchlist/services/auth/mal_auth_v2.dart';
import 'package:mywatchlist/services/notifications/mal_hub.dart';
import 'package:mywatchlist/services/notifications/mal_hub_poller.dart';
import 'package:mywatchlist/services/notifications/mal_hub_texts.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/mal_web/notification_tiles.dart';

/// Opens a tapped hub notification (`malhub:<id>|<url>`): marks the item read, then opens its
/// target in the app (or the screen for a group summary). Waits for the navigator on a cold
/// start (at most 10 s).
Future<void> openMalHubPayload(String payload) async {
  final parsed = MalHubPayload.parse(payload);
  if (parsed == null) return;
  BuildContext? context;
  for (var i = 0; i < 34; i++) {
    final c = appNavigatorKey.currentContext;
    if (c != null && c.mounted) {
      context = c;
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  if (context == null || !context.mounted) return;
  final hub = MalNotificationsHub.instance;
  final id = parsed.id;
  if (id != null) {
    unawaited(() async {
      if (!hub.items.any((i) => i.id == id)) await hub.refresh(quiet: true);
      final matches = hub.items.where((i) => i.id == id && !i.isRead).toList();
      if (matches.isNotEmpty) await hub.markRead(matches);
    }());
  }
  final url = parsed.url;
  if (url == null) {
    await MalNotificationsScreen.open(context, tab: id == null && payload != MalHubPayload.screen ? 1 : 0);
    return;
  }
  await openLink(context, url, confirm: false);
}

/// MAL's notification hub (all its types, mark read, friend requests) and the friends'
/// activity (their list updates, from MAL's RSS feeds), in two tabs.
class MalNotificationsScreen extends StatefulWidget {
  const MalNotificationsScreen({super.key, this.initialTab = 0, this.hub, this.poller});

  /// 0 = notifications, 1 = friends' activity.
  final int initialTab;
  final MalNotificationsHub? hub;
  final MalHubPoller? poller;

  static Future<void> open(BuildContext context, {int tab = 0}) =>
      AppRoutes.push<void>(context, MalNotificationsScreen(initialTab: tab));

  @override
  State<MalNotificationsScreen> createState() => _MalNotificationsScreenState();
}

class _MalNotificationsScreenState extends State<MalNotificationsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
  MalNotificationsHub get _hub => widget.hub ?? MalNotificationsHub.instance;
  MalHubPoller get _poller => widget.poller ?? MalHubPoller.instance;

  @override
  void initState() {
    super.initState();
    _hub.bindSession();
    unawaited(_hub.refresh(quiet: _hub.status == MalHubStatus.ready));
    if (_tabs.index == 1) unawaited(_hub.loadActivity());
    _tabs.addListener(_onTab);
  }

  void _onTab() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index == 1) unawaited(_hub.loadActivity());
    setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTab);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _markAll() async {
    final ok = await _hub.markAllRead();
    if (!ok && mounted) _snack(S.current.Ms_Action_Failed);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.Mn_Title),
        actions: [
          if (_tabs.index == 0)
            ValueListenableBuilder<int>(
              valueListenable: _hub.unread,
              builder: (context, count, _) => count == 0
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: s.Mn_Mark_All_Read,
                      icon: const Icon(Icons.done_all_rounded),
                      onPressed: _markAll,
                    ),
            ),
          _Menu(poller: _poller),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(child: MalNotificationsBadge(hub: _hub, child: Text(s.Mn_Title))),
            Tab(text: s.Mn_Tab_Friends),
          ],
        ),
      ),
      // Mark read and friend requests are sent from MAL's page in an invisible WebView.
      body: MalWebFormHost(
        child: TabBarView(
          controller: _tabs,
          children: [
            _HubTab(hub: _hub, onFailed: () => _snack(S.current.Ms_Action_Failed)),
            _FriendsTab(hub: _hub),
          ],
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.poller});

  final MalHubPoller poller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopupMenuButton<int>(
      onSelected: (value) {
        switch (value) {
          case 0:
            poller.setPushHub(!poller.pushHub.value);
          case 1:
            poller.setPushFriends(!poller.pushFriends.value);
          case 2:
            launchWebView('https://myanimelist.net/notification', context: context);
        }
      },
      itemBuilder: (context) => [
        if (poller.notifier.isSupported) ...[
          CheckedPopupMenuItem(value: 0, checked: poller.pushHub.value, child: Text(s.Mn_Push_Hub)),
          CheckedPopupMenuItem(value: 1, checked: poller.pushFriends.value, child: Text(s.Mn_Push_Friends)),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(value: 2, child: Text(s.Mn_Open_Web)),
      ],
    );
  }
}

/// No MAL account, no website session or a dead one: one tap to connect.
class _ConnectState extends StatelessWidget {
  const _ConnectState({required this.expired});

  final bool expired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              expired ? s.Ms_Session_Expired : s.Mn_Connect_Title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => MalAuthV2().handleSignIn(context: context),
              icon: const Icon(Icons.login_rounded),
              label: Text(s.Ms_Connect),
            ),
          ],
        ),
      ),
    );
  }
}

/// An icon and one line, with an optional Retry, inside a scroll view so pull to refresh works.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(onPressed: onRetry, child: Text(S.of(context).Ms_Retry)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The filter chips: All, Unread, then the groups the items have.
enum _HubFilterKind { all, unread, group }

class _HubFilter {
  const _HubFilter(this.kind, [this.group]);
  final _HubFilterKind kind;
  final MalNotificationGroup? group;

  bool accepts(MalNotificationItem i) => switch (kind) {
        _HubFilterKind.all => true,
        _HubFilterKind.unread => !i.isRead,
        _HubFilterKind.group => i.kind.group == group,
      };

  @override
  bool operator ==(Object other) => other is _HubFilter && other.kind == kind && other.group == group;

  @override
  int get hashCode => Object.hash(kind, group);
}

class _HubTab extends StatefulWidget {
  const _HubTab({required this.hub, required this.onFailed});

  final MalNotificationsHub hub;
  final VoidCallback onFailed;

  @override
  State<_HubTab> createState() => _HubTabState();
}

class _HubTabState extends State<_HubTab> with AutomaticKeepAliveClientMixin {
  _HubFilter _filter = const _HubFilter(_HubFilterKind.all);

  @override
  bool get wantKeepAlive => true;

  Future<void> _open(MalNotificationItem item) async {
    if (!item.isRead) unawaited(widget.hub.markRead([item]));
    final url = item.targetUrl;
    if (url == null) return;
    await openLink(context, url, confirm: false);
  }

  Future<void> _answer(MalNotificationItem item, bool accept) async {
    final ok = await widget.hub.answerFriendRequest(item, accept: accept);
    if (!mounted) return;
    if (!ok) {
      widget.onFailed();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(accept ? S.current.Mn_Accepted : S.current.Mn_Denied)));
  }

  Future<void> _markRead(MalNotificationItem item) async {
    final ok = await widget.hub.markRead([item]);
    if (!ok && mounted) widget.onFailed();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: widget.hub,
      builder: (context, _) {
        final hub = widget.hub;
        final s = S.of(context);
        final status = hub.status;
        final items = hub.items;
        if (status == MalHubStatus.noAccount || status == MalHubStatus.noSession) {
          return const _ConnectState(expired: false);
        }
        if (status == MalHubStatus.expired) return const _ConnectState(expired: true);
        if (items.isEmpty && (status == MalHubStatus.loading || status == MalHubStatus.idle)) {
          return const Center(child: CircularProgressIndicator());
        }
        Widget body;
        if (items.isEmpty && status == MalHubStatus.error) {
          body = _Message(icon: Icons.cloud_off_rounded, text: s.Mn_Error, onRetry: hub.refresh);
        } else if (items.isEmpty) {
          body = _Message(icon: Icons.notifications_none_rounded, text: s.Mn_Empty);
        } else {
          final groups = <MalNotificationGroup>{for (final i in items) i.kind.group};
          final filters = [
            const _HubFilter(_HubFilterKind.all),
            if (items.any((i) => !i.isRead)) const _HubFilter(_HubFilterKind.unread),
            if (groups.length > 1)
              for (final g in MalNotificationGroup.values)
                if (groups.contains(g)) _HubFilter(_HubFilterKind.group, g),
          ];
          final filter = filters.contains(_filter) ? _filter : filters.first;
          final shown = items.where(filter.accepts).toList();
          body = CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (filters.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final f = filters[index];
                        final label = switch (f.kind) {
                          _HubFilterKind.all => s.Mn_Filter_All,
                          _HubFilterKind.unread => s.Mn_Filter_Unread,
                          _HubFilterKind.group => malNotificationGroupLabel(f.group!, s),
                        };
                        return ChoiceChip(
                          label: Text(label),
                          selected: f == filter,
                          onSelected: (_) => setState(() => _filter = f),
                        );
                      },
                    ),
                  ),
                ),
              if (shown.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Message(icon: Icons.notifications_none_rounded, text: s.Mn_Empty),
                )
              else
                SliverList.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = shown[index];
                    return MalNotificationTile(
                      key: ValueKey(item.id),
                      item: item,
                      onTap: () => _open(item),
                      onMarkRead: () => _markRead(item),
                      onAccept: () => _answer(item, true),
                      onDeny: () => _answer(item, false),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        }
        return RefreshIndicator(onRefresh: hub.refresh, child: body);
      },
    );
  }
}

class _FriendsTab extends StatefulWidget {
  const _FriendsTab({required this.hub});

  final MalNotificationsHub hub;

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> with AutomaticKeepAliveClientMixin {
  /// A list status (`dropped`…) or null for all.
  String? _status;

  @override
  bool get wantKeepAlive => true;

  static const _order = ['watching', 'reading', 'completed', 'on_hold', 'dropped', 'plan_to_watch', 'plan_to_read'];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: widget.hub,
      builder: (context, _) {
        final hub = widget.hub;
        final s = S.of(context);
        final status = hub.activityStatus;
        final rows = hub.activity;
        if (status == MalHubStatus.noAccount) return const _ConnectState(expired: false);
        if (rows.isEmpty && (status == MalHubStatus.loading || status == MalHubStatus.idle)) {
          return const Center(child: CircularProgressIndicator());
        }
        Future<void> reload() async => hub.loadActivity(force: true);
        Widget body;
        if (rows.isEmpty && status == MalHubStatus.error) {
          body = _Message(icon: Icons.cloud_off_rounded, text: s.Mn_Friends_Error, onRetry: reload);
        } else if (rows.isEmpty) {
          body = _Message(icon: Icons.people_alt_outlined, text: s.Mn_Friends_Empty);
        } else {
          final present = rows.map((r) => r.status).whereType<String>().toSet();
          final statuses = [for (final st in _order) if (present.contains(st)) st];
          final selected = statuses.contains(_status) ? _status : null;
          final shown = selected == null ? rows : rows.where((r) => r.status == selected).toList();
          body = CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (statuses.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: statuses.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final st = index == 0 ? null : statuses[index - 1];
                        final label = st == null
                            ? s.Mn_Filter_All
                            : friendStatusLabel(
                                FriendActivity(friend: '', category: '', malId: 0, title: '', link: '', status: st),
                                s);
                        return ChoiceChip(
                          label: Text(label),
                          selected: st == selected,
                          onSelected: (_) => setState(() => _status = st),
                        );
                      },
                    ),
                  ),
                ),
              SliverList.builder(
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final row = shown[index];
                  return FriendActivityTile(
                    key: ValueKey(row.key),
                    activity: row,
                    onTap: () => openLink(context, row.link, confirm: false),
                    onFriendTap: () => openLink(
                      context,
                      'https://myanimelist.net/profile/${Uri.encodeComponent(row.friend)}',
                      confirm: false,
                    ),
                  );
                },
              ),
              if (status == MalHubStatus.loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        }
        return RefreshIndicator(onRefresh: reload, child: body);
      },
    );
  }
}
