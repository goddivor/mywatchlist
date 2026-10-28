import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_view.dart' show UserProfileTab;
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/base_user.dart' show AuthStatus;
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/sidebar_bg_manager.dart';
import 'package:mywatchlist/utils/sidebar_extension.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';

export 'package:mywatchlist/utils/sidebar_extension.dart' show SidebarMenuItem;

/// The app sidebar (DAL `AppSideBar`), shown as the home shell's end drawer.
///
/// Header with the active account (avatar, name, tracker, custom background), then the
/// user's destinations (DailyAL's profile tabs for MyAnimeList, the profile page for the
/// other trackers, then bookmarks and calendar), the app destinations
/// (settings, about) and sign in, or add an account / sign out. Every entry closes the drawer first.
class AppSidebar extends StatefulWidget {
  /// Extra destinations listed after "My space" (see `SidebarBuilder`).
  final List<SidebarMenuItem> extraItems;

  const AppSidebar({super.key, this.extraItems = const []});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  static Future<String?>? _versionFuture;

  final SidebarBackgroundManager _bgManager = SidebarBackgroundManager.instance;
  String? _backgroundImagePath;
  bool _isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    _versionFuture ??= PackageInfo.fromPlatform()
        .then<String?>((info) => info.version)
        .catchError((Object _) => null);
    _loadBackgroundImage();
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final path = await _bgManager.getCurrentBackgroundImagePath();
      if (mounted && path != null) setState(() => _backgroundImagePath = path);
    } catch (e) {
      debugPrint('Sidebar background not loaded: $e');
    }
  }

  Future<void> _pickBackgroundImage() async {
    setState(() => _isLoadingImage = true);
    try {
      final path = await _bgManager.setNewBackgroundImage(context: context);
      if (mounted) {
        setState(() {
          _backgroundImagePath = path ?? _backgroundImagePath;
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      debugPrint('Sidebar background not picked: $e');
      if (mounted) setState(() => _isLoadingImage = false);
    }
  }

  Future<void> _removeBackgroundImage() async {
    try {
      final success = await _bgManager.removeBackgroundImage(context: context);
      if (success && mounted) setState(() => _backgroundImagePath = null);
    } catch (e) {
      debugPrint('Sidebar background not removed: $e');
    }
  }

  /// Context that survives the drawer closing: the hosting scaffold's, else ours.
  BuildContext get _hostContext => Scaffold.maybeOf(context)?.context ?? context;

  /// Closes the drawer (when shown as one) and runs [action] with a stable context.
  void _go(void Function(BuildContext host) action) {
    final host = _hostContext;
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isEndDrawerOpen) {
      scaffold.closeEndDrawer();
    } else if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    }
    action(host);
  }

  Future<void> _confirmLogout(AccountType tracker) async {
    final host = _hostContext;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout),
        title: Text(S.current.Logout_Confirmation),
        content: Text(S.current.Do_you_wish_to_logout),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.current.Cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.current.Logout),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !host.mounted) return;
    final accountBloc = host.read<AccountBloc>();
    _go((_) {});
    await UserManager.instance.signOut(tracker);
    // The home shell sends the user to the login screen once no account is selected.
    accountBloc.add(RemoveAccountEvent(tracker));
  }

  void _showBackgroundOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  S.current.Sidebar_Background_Title,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: Icon(Icons.image_outlined, color: colors.primary),
                title: Text(S.current.Sidebar_Background_Change),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickBackgroundImage();
                },
              ),
              if (_backgroundImagePath != null)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colors.error),
                  title: Text(S.current.Sidebar_Background_Remove),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removeBackgroundImage();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      width: (MediaQuery.sizeOf(context).width * 0.85).clamp(0.0, 360.0),
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      child: ListenableBuilder(
        listenable: Listenable.merge([UserManager.instance, MalApi.sessionExpired]),
        builder: (context, _) {
          final accountState = context.watch<AccountBloc>().state;
          final tracker = accountState is AccountLoaded
              ? accountState.selectedAccountType
              : AccountType.none;
          final user = UserManager.instance.getUserByTracker(tracker);
          final signedIn = user?.status == AuthStatus.AUTHENTICATED;
          final needsReLogin = (user?.needsReLogin ?? false) ||
              (tracker == AccountType.myanimelist && MalApi.sessionExpired.value);
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(theme, accountState, tracker),
              if (needsReLogin)
                _SessionExpiredCard(
                  tracker: tracker,
                  onSignIn: () =>
                      _go((host) => AppRoutes.signInAgain(host, tracker)),
                ),
              _GroupLabel(S.current.Sidebar_Section_Profile),
              if (signedIn && tracker == AccountType.myanimelist)
                // DailyAL's profile shortcuts, each opening the profile on its tab.
                for (final (tab, icon, label) in _profileShortcuts())
                  _SidebarTile(
                    icon: icon,
                    title: label,
                    onTap: () => _go((host) =>
                        AppRoutes.openUserProfile(host, tracker: tracker, tab: tab)),
                  )
              else if (signedIn)
                // Other trackers have a single profile page.
                _SidebarTile(
                  icon: Icons.person_outline,
                  title: S.current.Profile,
                  onTap: () => _go((host) => AppRoutes.openUserProfile(host,
                      tracker: tracker, username: user?.username)),
                ),
              _SidebarTile(
                icon: Icons.bookmark_outline,
                title: S.current.Bookmarks,
                onTap: () => _go(AppRoutes.openBookmarks),
              ),
              _SidebarTile(
                icon: Icons.calendar_month_outlined,
                title: S.current.AnimeCalendar,
                onTap: () => _go(AppRoutes.openCalendar),
              ),
              for (final item in widget.extraItems)
                _SidebarTile(
                  icon: item.icon,
                  title: item.title,
                  selected: item.isActive,
                  trailing: item.trailing,
                  onTap: () => _go((_) => item.onTap()),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: Divider(height: 1),
              ),
              _GroupLabel(S.current.Sidebar_Section_App),
              _SidebarTile(
                icon: Icons.settings_outlined,
                title: S.current.Settings,
                onTap: () => _go(AppRoutes.openSettings),
              ),
              _SidebarTile(
                icon: Icons.info_outline,
                title: S.current.About,
                onTap: () => _go(AppRoutes.openAbout),
              ),
              if (signedIn) ...[
                _SidebarTile(
                  icon: Icons.person_add_alt_1_outlined,
                  title: S.current.Sidebar_Add_Account,
                  // The login page opens in add mode: an account is already active.
                  onTap: () => _go(AppRoutes.openLogin),
                ),
                _SidebarTile(
                  icon: Icons.logout,
                  title: S.current.Logout,
                  destructive: true,
                  onTap: () => _confirmLogout(tracker),
                ),
              ] else
                _SidebarTile(
                  icon: Icons.login,
                  title: S.current.Log_In,
                  onTap: () => _go(AppRoutes.openLogin),
                ),
              _buildFooter(theme),
            ],
          );
        },
      ),
    );
  }

  /// The profile tabs DailyAL's sidebar lists, in its order.
  static List<(UserProfileTab, IconData, String)> _profileShortcuts() {
    final s = S.current;
    return [
      (UserProfileTab.stats, Icons.stacked_bar_chart_rounded, s.Prof_Tab_Stats),
      (UserProfileTab.about, Icons.info_outline, s.Prof_Tab_About),
      (UserProfileTab.friends, Icons.people_alt_outlined, s.Prof_Tab_Friends),
      (UserProfileTab.clubs, Icons.castle_outlined, s.Prof_Tab_Clubs),
      (UserProfileTab.favorites, Icons.favorite_outline, s.Prof_Tab_Favorites),
      (UserProfileTab.history, Icons.history_rounded, s.Prof_Tab_History),
    ];
  }

  Widget _buildFooter(ThemeData theme) {
    final style = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      child: FutureBuilder<String?>(
        future: _versionFuture,
        builder: (context, snapshot) {
          final version = snapshot.data;
          return Text(
            version == null
                ? 'MyWatchList'
                : 'MyWatchList · ${S.current.Sidebar_Version(version)}',
            style: style,
          );
        },
      ),
    );
  }

  Widget _buildHeader(
      ThemeData theme, AccountState state, AccountType tracker) {
    final colors = theme.colorScheme;
    final tokens = AppColors.of(context);
    String? avatarUrl;
    var name = S.current.Sidebar_Guest;
    if (state is AccountLoaded && tracker != AccountType.none) {
      avatarUrl = state.profileImageUrl;
      for (final account in state.availableAccounts) {
        if (account.typeAcc == tracker) name = account.name;
      }
    }
    final trackerLabel = tracker == AccountType.none
        ? S.current.Sidebar_Not_Connected
        : AppRoutes.trackerLabel(tracker);
    final topInset = MediaQuery.paddingOf(context).top;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final bgPath = _backgroundImagePath;

    return SizedBox(
      height: 176 + topInset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bgPath != null)
            Image(
              // Decoded at the drawer's size, never at the photo's full resolution.
              image: ResizeImage(FileImage(File(bgPath)),
                  width: (360 * dpr).round()),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(color: colors.primary),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [colors.primary, colors.tertiary],
                ),
              ),
            ),
          // Scrim so the name stays readable on any picture (alpha gradient, no blur).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tokens.imageScrim.withValues(alpha: 0.08), tokens.imageScrim],
              ),
            ),
          ),
          PositionedDirectional(
            top: topInset + 8,
            end: 8,
            child: IconButton.filledTonal(
              tooltip: S.current.Sidebar_Background_Edit,
              icon: _isLoadingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wallpaper, size: 20),
              onPressed: _isLoadingImage ? null : _showBackgroundOptions,
            ),
          ),
          PositionedDirectional(
            start: 20,
            end: 20,
            bottom: 18,
            child: Row(
              children: [
                AvatarWidget(
                  url: avatarUrl,
                  height: 56,
                  width: 56,
                  borderColor: tokens.onImageScrim,
                  borderWidth: 2,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: tokens.onImageScrim,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trackerLabel,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: tokens.onImageScrim.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(28, 16, 16, 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool selected;
  final bool destructive;

  const _SidebarTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.selected = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive ? colors.error : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: ListTile(
        onTap: onTap,
        selected: selected,
        selectedTileColor: colors.secondaryContainer,
        shape: const StadiumBorder(),
        iconColor: color ?? colors.onSurfaceVariant,
        textColor: color,
        leading: Icon(icon),
        title: Text(title),
        trailing: trailing,
      ),
    );
  }
}

class _SessionExpiredCard extends StatelessWidget {
  final AccountType tracker;
  final VoidCallback onSignIn;
  const _SessionExpiredCard({required this.tracker, required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: colors.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      S.current.Shell_Session_Expired(
                          AppRoutes.trackerLabel(tracker)),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onSignIn,
                  child: Text(S.current.Shell_Sign_In_Again),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
