import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/home/account_switcher_sheet.dart';
import 'package:mywatchlist/widgets/mal_web/notification_tiles.dart' show MalNotificationsBell;

/// The header of the home tabs: logo (or [titleWidget]), the shortcut buttons and the account
/// avatar.
///
/// Every button works without a callback: search, bookmarks, calendar and settings open their
/// screen through [AppRoutes]; pass an `on…Tap` only to do something else. The avatar opens the
/// sidebar of the home shell; a long press (or the small switch badge) opens the account
/// switcher as a bottom sheet.
class AppBarHome extends StatelessWidget implements PreferredSizeWidget {
  /// Called after another account became active from the switcher sheet.
  final VoidCallback? onUiChange;
  final Widget? titleWidget;
  final String? title;
  final bool showAvatar;
  final bool showSearch;
  final bool showBookmarks;
  final bool showCalendar;
  final bool showSettings;

  /// The MyAnimeList notification bell (hidden for the other trackers).
  final bool showNotifications;
  final bool transparent;
  final Color? backgroundColor;
  final VoidCallback? onSearchTap;
  final VoidCallback? onBookmarksTap;
  final VoidCallback? onCalendarTap;
  final VoidCallback? onSettingsTap;

  const AppBarHome({
    super.key,
    this.onUiChange,
    this.titleWidget,
    this.title,
    this.showAvatar = true,
    this.showSearch = true,
    this.showBookmarks = true,
    this.showCalendar = true,
    this.showSettings = false,
    this.showNotifications = true,
    this.transparent = false,
    this.backgroundColor,
    this.onSearchTap,
    this.onBookmarksTap,
    this.onCalendarTap,
    this.onSettingsTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: transparent
            ? Colors.transparent
            : backgroundColor ?? theme.scaffoldBackgroundColor,
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _buildTitle(context, theme),
                  ),
                ),
                _buildActionButtons(context, theme),
                if (showAvatar) ...[
                  const SizedBox(width: 12),
                  _AccountAvatar(onUiChange: onUiChange),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, ThemeData theme) {
    if (titleWidget != null) return titleWidget!;
    if (title != null) {
      return Text(title!, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return CircleAvatar(
      radius: 18,
      backgroundImage: const AssetImage('assets/images/mwl-black-bg.png'),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    if (!(showSearch || showBookmarks || showCalendar || showSettings || showNotifications)) {
      return const SizedBox.shrink();
    }
    final s = S.current;
    // Plain icons like DailyAL's header (no container behind them).
    return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSearch)
              _BarButton(
                icon: Icons.search_rounded,
                tooltip: s.Hw_Search,
                onTap: onSearchTap ?? () => AppRoutes.openSearch(context),
              ),
            if (showBookmarks)
              _BarButton(
                icon: Icons.bookmark_outline_rounded,
                tooltip: s.Hw_Bookmarks,
                onTap: onBookmarksTap ?? () => AppRoutes.openBookmarks(context),
              ),
            if (showCalendar)
              _BarButton(
                icon: Icons.calendar_today_outlined,
                tooltip: s.Hw_Calendar,
                onTap: onCalendarTap ?? () => AppRoutes.openCalendar(context),
              ),
            // The MyAnimeList hub: only when the active account is MyAnimeList.
            if (showNotifications)
              BlocSelector<AccountBloc, AccountState, bool>(
                selector: (state) =>
                    state is AccountLoaded && state.selectedAccountType == AccountType.myanimelist,
                builder: (context, isMal) =>
                    isMal ? const MalNotificationsBell() : const SizedBox.shrink(),
              ),
            if (showSettings)
              _BarButton(
                icon: Icons.settings_outlined,
                tooltip: s.Hw_Settings,
                onTap: onSettingsTap ?? () => AppRoutes.openSettings(context),
              ),
          ],
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _BarButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onTap,
      color: Theme.of(context).colorScheme.onSurface,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 44, height: 40),
      padding: EdgeInsets.zero,
    );
  }
}

/// The account avatar: a tap opens the sidebar, a long press the account switcher sheet. The
/// ring takes the colour of the active tracker; the badge shows that the account can be switched.
class _AccountAvatar extends StatelessWidget {
  final VoidCallback? onUiChange;

  const _AccountAvatar({this.onUiChange});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocSelector<AccountBloc, AccountState, ({AccountType type, String? image})>(
      selector: (state) => state is AccountLoaded
          ? (type: state.selectedAccountType, image: state.profileImageUrl)
          : (type: AccountType.none, image: null),
      builder: (context, account) {
        final ring = TrackerInfo.of(account.type)?.color ?? scheme.outline;
        void openSwitcher() => showAccountSwitcherSheet(context, onSwitched: onUiChange);
        return Semantics(
          button: true,
          label: S.current.Hw_Menu_Tooltip,
          onTap: () => AppRoutes.openSidebar(context),
          onLongPress: openSwitcher,
          customSemanticsActions: {
            CustomSemanticsAction(label: S.current.Hw_Switch_Account): openSwitcher,
          },
          child: Tooltip(
            message: S.current.Hw_Account_Tooltip,
            excludeFromSemantics: true,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  ExcludeSemantics(
                    child: AvatarWidget(
                      url: account.image,
                      isNetworkImage: account.image != null,
                      height: 36,
                      width: 36,
                      borderColor: ring,
                      borderWidth: 2,
                      onTap: () => AppRoutes.openSidebar(context),
                      onLongPress: openSwitcher,
                    ),
                  ),
                  PositionedDirectional(
                    end: -2,
                    bottom: -2,
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        onTap: openSwitcher,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.surface, width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Icons.swap_horiz_rounded,
                                size: 12, color: scheme.onSurface),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
