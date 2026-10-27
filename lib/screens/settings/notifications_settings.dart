import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

/// Settings page "Notifications" (DailyAL `NotificationSettingsPage`): airing reminders for
/// the Watching and Plan to watch lists, with the permission state, what is scheduled, a
/// test notification and a full reschedule. Values live in `PreferencesBloc`; the schedule
/// itself is `NotificationService`.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, this.service});

  /// Replaced by a fake in tests.
  final NotificationService? service;

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  NotificationPermissions? _permissions;
  bool _busy = false;

  NotificationService get _service => widget.service ?? NotificationService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPermissions();
    // The page shows what is scheduled right away, even when no run is due.
    if (Preferences.notifications.enabled) _service.scheduleAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the system settings: read the permissions again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final permissions = await _service.permissions();
    if (mounted) setState(() => _permissions = permissions);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setEnabled(bool on) async {
    final bloc = context.read<PreferencesBloc>();
    if (!on) {
      bloc.add(NotificationPreferencesChanged((p) => p.unsubscribed()));
      return;
    }
    final granted = await _service.requestPermissions();
    if (!mounted) return;
    setState(() => _permissions = granted);
    if (!granted.notifications) {
      _toast(S.current.Notif_Denied);
      return;
    }
    bloc.add(NotificationPreferencesChanged((p) => p.copyWith(subscribedAt: DateTime.now())));
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    final sent = await _service.sendTest();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(sent ? S.current.Notif_Test_Sent : S.current.Notif_Test_Failed);
  }

  Future<void> _reschedule() async {
    setState(() => _busy = true);
    await _service.clearAndReschedule();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(S.current.Notif_Reschedule_Done);
  }

  static void _reset(PreferencesBloc bloc) =>
      bloc.add(NotificationPreferencesChanged((p) => const NotificationPreferences().copyWith(
            subscribedAt: p.subscribedAt,
          )));

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final supported = _service.isSupported;
    return PrefsPage(
      title: SettingsSection.notifications.title,
      onReset: _reset,
      children: [
        if (!supported)
          _Notice(icon: Icons.info_outline, message: s.Notif_Unsupported)
        else ...[
          _MasterCard(onChanged: _setEnabled),
          _Status(service: _service, permissions: _permissions, onPermissions: _loadPermissions),
        ],
        PrefGroup(
          title: s.Notif_Sec_Notify,
          children: [
            PrefSwitchTile(
              icon: Icons.play_circle_outline,
              title: s.Notif_Watching_Title,
              subtitle: s.Notif_Watching_Desc,
              read: (p) => p.notifications.watchingList,
              toEvent: (v) => NotificationPreferencesChanged((p) => p.copyWith(watchingList: v)),
            ),
            PrefSwitchTile(
              icon: Icons.bookmark_border,
              title: s.Notif_Plan_Title,
              subtitle: s.Notif_Plan_Desc,
              read: (p) => p.notifications.planToWatchList,
              toEvent: (v) => NotificationPreferencesChanged((p) => p.copyWith(planToWatchList: v)),
            ),
          ],
        ),
        PrefGroup(
          title: s.Notif_Sec_Look,
          children: [
            PrefSwitchTile(
              icon: Icons.image_outlined,
              title: s.Notif_Large_Image_Title,
              subtitle: s.Notif_Large_Image_Desc,
              read: (p) => p.notifications.largeImage,
              toEvent: (v) => NotificationPreferencesChanged((p) => p.copyWith(largeImage: v)),
            ),
          ],
        ),
        if (supported)
          PrefGroup(
            title: s.Notif_Sec_Tools,
            children: [
              ListTile(
                contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
                leading: const PrefIcon(Icons.notifications_active_outlined),
                title: Text(s.Notif_Test_Title_Action),
                subtitle: Text(s.Notif_Test_Action_Desc),
                enabled: !_busy,
                onTap: _test,
              ),
              ListTile(
                contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
                leading: const PrefIcon(Icons.refresh_rounded),
                title: Text(s.Notif_Reschedule_Title),
                subtitle: Text(s.Notif_Reschedule_Desc),
                enabled: !_busy && context.select((PreferencesBloc b) => b.state.notifications.enabled),
                onTap: _reschedule,
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(28, 20, 28, 0),
          child: Text(
            s.Notif_Footer,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// The master switch, as a prominent card at the top of the page.
class _MasterCard extends StatelessWidget {
  const _MasterCard({required this.onChanged});

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = context.select((PreferencesBloc b) => b.state.notifications.enabled);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: enabled ? colors.primaryContainer : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile(
          contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 8, 16, 8),
          secondary: Icon(
            enabled ? Icons.notifications_active : Icons.notifications_off_outlined,
            color: enabled ? colors.onPrimaryContainer : colors.onSurfaceVariant,
            size: 28,
          ),
          title: Text(
            S.current.Notif_Master_Title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: enabled ? colors.onPrimaryContainer : colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: Text(
            S.current.Notif_Master_Desc,
            style: TextStyle(color: enabled ? colors.onPrimaryContainer : colors.onSurfaceVariant),
          ),
          value: enabled,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// What the reminders are doing: permission problems, MAL needed, progress, count and next.
class _Status extends StatelessWidget {
  const _Status({required this.service, required this.permissions, required this.onPermissions});

  final NotificationService service;
  final NotificationPermissions? permissions;
  final VoidCallback onPermissions;

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final enabled = context.select((PreferencesBloc b) => b.state.notifications.enabled);
    if (!enabled) return const SizedBox.shrink();
    final malConnected = context.select<UserManager, bool>(
        (m) => m.isAuthenticated(AccountType.myanimelist));
    final permissions = this.permissions;

    return ValueListenableBuilder<NotificationSummary>(
      valueListenable: service.summary,
      builder: (context, summary, _) {
        final children = <Widget>[];
        if (permissions != null && !permissions.notifications) {
          children.add(_Notice(
            icon: Icons.block,
            message: s.Notif_Blocked,
            action: s.Notif_Blocked_Action,
            onAction: openAppSettings,
            error: true,
          ));
        } else if (permissions != null && !permissions.exactAlarms) {
          children.add(_Notice(
            icon: Icons.alarm,
            message: s.Notif_Exact_Alarm,
            action: s.Notif_Exact_Alarm_Action,
            onAction: () async {
              await service.requestPermissions();
              onPermissions();
            },
          ));
        }
        if (!malConnected || summary.needsMal) {
          children.add(_Notice(
            icon: Icons.link_off,
            message: s.Notif_Needs_Mal,
            action: s.Notif_Needs_Mal_Action,
            onAction: () => AppRoutes.openSettingsPage(context, SettingsSection.accounts),
          ));
        } else if (summary.running) {
          children.add(_Notice(icon: Icons.sync, message: s.Notif_Status_Working, busy: true));
        } else if (summary.failed) {
          children.add(_Notice(icon: Icons.cloud_off, message: s.Notif_Status_Failed));
        } else if (summary.scheduled == 0) {
          if (summary.updatedAt != null) {
            children.add(_Notice(icon: Icons.inbox_outlined, message: s.Notif_Status_Empty));
          }
        } else {
          final next = summary.next;
          final locale = Localizations.localeOf(context).toString();
          final date = next == null ? null : DateFormat.MMMEd(locale).add_Hm().format(next.toLocal());
          children.add(_Notice(
            icon: Icons.schedule,
            message: date == null
                ? s.Notif_Status_Scheduled(summary.scheduled)
                : '${s.Notif_Status_Scheduled(summary.scheduled)}\n${s.Notif_Status_Next(date)}',
          ));
        }
        return Column(children: children);
      },
    );
  }
}

/// A rounded line of information with an optional action.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
    this.error = false,
    this.busy = false,
  });

  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final bool error;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = error ? colors.onErrorContainer : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: error ? colors.errorContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
          child: Row(
            children: [
              busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: foreground),
                    )
                  : Icon(icon, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground)),
              ),
              if (action != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(action!)),
            ],
          ),
        ),
      ),
    );
  }
}
