import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, showToast;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/user/profile/profile_background.dart';
import 'package:mywatchlist/widgets/user/profile/profile_header.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';
import 'package:mywatchlist/widgets/user/profile/report_user.dart';

/// Opens the quick profile sheet of [username] (null = the signed-in user): header, the main
/// numbers, and the actions that make sense for that user (open the full profile, open in
/// the browser, set or remove the profile background for yourself, report for others).
Future<void> showUserPopSheet(BuildContext context, {String? username}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => UserPopSheet(username: username),
  );
}

class UserPopSheet extends StatefulWidget {
  final String? username;

  const UserPopSheet({super.key, this.username});

  @override
  State<UserPopSheet> createState() => _UserPopSheetState();
}

class _UserPopSheetState extends State<UserPopSheet> {
  late Future<UserProfileData> _future;
  bool _busy = false;

  bool get _isSelf => widget.username == null;

  @override
  void initState() {
    super.initState();
    _future = UserProfileRepository.instance.load(widget.username);
  }

  void _retry() => setState(() {
        _future = UserProfileRepository.instance.load(widget.username, forceRefresh: true);
      });

  Future<void> _setBackground(UserProfileData data) async {
    setState(() => _busy = true);
    final ok = await ProfileBackgroundStore.instance.pick(data.username);
    if (!mounted) return;
    setState(() => _busy = false);
    // Cancelling the picker is not an error; the store returns false for it too, so only a
    // saved picture is announced.
    if (ok) showToast(S.current.Prof_Bg_Set_Done);
  }

  Future<void> _removeBackground(UserProfileData data) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(s.Prof_Bg_Remove_Confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.Prof_Cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.Prof_Bg_Remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final ok = await ProfileBackgroundStore.instance.remove(data.username);
    if (!mounted) return;
    setState(() => _busy = false);
    showToast(ok ? S.current.Prof_Bg_Removed : S.current.Prof_Bg_Error);
  }

  void _openFull(UserProfileData data) {
    Navigator.of(context).pop();
    AppRoutes.openUserProfile(
      context,
      tracker: AccountType.myanimelist,
      username: _isSelf ? null : data.username,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfileData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            height: 260,
            child: ProfileLoading(label: S.of(context).Prof_Loading),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 300,
            child: ProfileErrorView(error: snapshot.error!, onRetry: _retry),
          );
        }
        return _content(context, snapshot.data!);
      },
    );
  }

  Widget _content(BuildContext context, UserProfileData data) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern();
    final hasBackground = _isSelf && ProfileBackgroundStore.instance.cached(data.username) != null;

    final tiles = <(String, String)>[
      (
        s.Prof_Mean_Score,
        (data.anime.meanScore ?? 0) > 0 ? data.anime.meanScore!.toStringAsFixed(2) : '—',
      ),
      ('${s.Prof_Anime} · ${s.Prof_Entries_Label}', number.format(data.anime.totalEntries)),
      ('${s.Prof_Manga} · ${s.Prof_Entries_Label}', number.format(data.manga.totalEntries)),
    ];

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 168,
            child: ProfileHeader(data: data, isSelf: _isSelf),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tiles[i].$1,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tiles[i].$2,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => _openFull(data),
                  icon: const Icon(Icons.person_outline),
                  label: Text(s.Prof_Open_Full),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => openLink(context, data.profileUrl),
                  icon: const Icon(Icons.open_in_browser),
                  label: Text(s.Open_In_Browser),
                ),
                if (_isSelf) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => hasBackground ? _removeBackground(data) : _setBackground(data),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(hasBackground ? Icons.hide_image_outlined : Icons.image_outlined),
                    label: Text(hasBackground ? s.Prof_Bg_Remove : s.Prof_Bg_Set),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      s.Prof_Bg_Local_Note,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ] else if (data.id != 0) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => reportUser(
                      context,
                      userId: data.id,
                      username: data.username,
                      pictureUrl: data.pictureUrl,
                    ),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(s.Prof_Report_Action),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
