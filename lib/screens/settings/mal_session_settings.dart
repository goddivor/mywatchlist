import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show showConfirmationDialog;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/screens/settings/storage_settings.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/mal_auth_v2.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/user/profile/profile_comments.dart' show showCommentSnack;

/// The MyAnimeList website session: its state, a check, disconnect, and a one-tap connect
/// when it is missing (the MAL sign in captures it).
class MalSessionSettingsPage extends StatefulWidget {
  const MalSessionSettingsPage({super.key, this.session, this.client});

  final MalWebSession? session;
  final MalWebClient? client;

  @override
  State<MalSessionSettingsPage> createState() => _MalSessionSettingsPageState();
}

class _MalSessionSettingsPageState extends State<MalSessionSettingsPage> {
  MalWebSession get _session => widget.session ?? MalWebSession.instance;
  MalWebClient get _client => widget.client ?? MalWebClient.instance;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _session.ensureLoaded();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    String message;
    try {
      final ok = await _client.checkSession(force: true);
      message = ok ? S.current.Ms_Check_Ok : S.current.Ms_Session_Expired;
    } on MalWebNoSession {
      message = S.current.Ms_Session_Expired;
    } catch (_) {
      message = S.current.Ms_Action_Failed;
    }
    if (!mounted) return;
    setState(() => _checking = false);
    showCommentSnack(context, message);
  }

  Future<void> _disconnect() async {
    final ok = await showConfirmationDialog(
      context: context,
      alertTitle: S.current.Ms_Disconnect_Confirm,
    );
    if (!ok) return;
    _client.reset();
    await _session.clear();
    if (mounted) showCommentSnack(context, S.current.Ms_Disconnected);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SettingsScaffold(
      title: s.Ms_Settings_Title,
      children: [
        ListenableBuilder(
          listenable: _session,
          builder: (context, _) => _content(context, s),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, S s) {
    final state = _session.state;
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag().replaceAll('-', '_');
    final (IconData icon, Color tint, String title) = switch (state) {
      MalWebSessionState.connected => (
          Icons.verified_user_outlined,
          colors.success.color,
          _session.username == null
              ? s.Ms_State_Connected
              : s.Ms_State_Connected_As(_session.username!),
        ),
      MalWebSessionState.expired => (Icons.lock_clock_outlined, colors.danger.color, s.Ms_Session_Expired),
      MalWebSessionState.unsupported => (Icons.block, scheme.onSurfaceVariant, s.Ms_State_Unsupported),
      _ => (Icons.link_off, scheme.onSurfaceVariant, s.Ms_State_None),
    };
    String? since;
    final saved = _session.savedAt;
    if (state == MalWebSessionState.connected && saved != null) {
      try {
        since = s.Ms_Connected_Since(DateFormat.yMMMd(locale).format(saved));
      } catch (_) {
        since = null;
      }
    }
    return PrefGroup(
      title: 'MyAnimeList',
      children: [
        ListTile(
          leading: Icon(icon, color: tint),
          title: Text(title),
          subtitle: since == null ? null : Text(since),
        ),
        if (state == MalWebSessionState.none || state == MalWebSessionState.expired)
          SettingsActionTile(
            icon: Icons.login,
            title: s.Ms_Connect,
            onTap: () => MalAuthV2().handleSignIn(context: context),
          ),
        if (state == MalWebSessionState.connected)
          SettingsActionTile(
            icon: Icons.fact_check_outlined,
            title: s.Ms_Check,
            trailing: _checking
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _checking ? null : _check,
          ),
        if (state == MalWebSessionState.connected || state == MalWebSessionState.expired)
          SettingsActionTile(
            icon: Icons.logout,
            title: s.Ms_Disconnect,
            danger: true,
            onTap: _disconnect,
          ),
      ],
    );
  }
}
