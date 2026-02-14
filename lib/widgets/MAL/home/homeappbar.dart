import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/account_switcher_page.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/utils/page_transitions.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

class AppBarHome extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback? onUiChange;
  final Widget? titleWidget;
  final String? title;
  final bool showAvatar;
  final bool showSearch;
  final bool showBookmarks;
  final bool showCalendar;
  final bool showSettings;
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
    this.transparent = false,
    this.backgroundColor,
    this.onSearchTap,
    this.onBookmarksTap,
    this.onCalendarTap,
    this.onSettingsTap,
  });

  @override
  State<AppBarHome> createState() => _AppBarHomeState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);
}

class _AppBarHomeState extends State<AppBarHome> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Get color based on account type
  Color _getAccountColor(AccountType type) {
    switch (type) {
      case AccountType.myanimelist:
        return const Color(0xFF2E51A2); // MyAnimeList blue
      case AccountType.anilist:
        return const Color(0xFF02A9FF); // Anilist blue
      case AccountType.kitsu:
        return const Color(0xFFEF5D5D); // Kitsu red
      case AccountType.simkl:
        return const Color(0xFF343C42); // Simkl dark gray
      default:
        return Colors.grey; // Default color for no account
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        String? profileImageUrl;
        AccountType currentAccountType = AccountType.none;
        List<Account> accounts = [];

        if (state is AccountLoaded) {
          currentAccountType = state.selectedAccountType;
          profileImageUrl = state.profileImageUrl;
          accounts = state.availableAccounts;
        }

        return _buildAppBar(
            context, profileImageUrl, currentAccountType, accounts);
      },
    );
  }

  Widget _buildAppBar(BuildContext context, String? profileImageUrl,
      AccountType currentAccountType, List<Account> accounts) {
    final theme = Theme.of(context);
    final effectiveColor = _getAccountColor(currentAccountType);

    return Container(
      decoration: BoxDecoration(
        color: widget.transparent
            ? Colors.transparent
            : widget.backgroundColor ?? theme.scaffoldBackgroundColor,
        boxShadow: widget.transparent
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            height: kToolbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // App logo or title
                _buildTitle(theme),

                // Actions
                Row(
                  children: [
                    // Action buttons
                    _buildActionButtons(theme),

                    // Space between actions and avatar
                    const SizedBox(width: 12),

                    // User avatar
                    if (widget.showAvatar)
                      _buildAvatar(profileImageUrl, currentAccountType,
                          accounts, effectiveColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    if (widget.titleWidget != null) {
      return widget.titleWidget!;
    }

    return CircleAvatar(
      radius: 18,
      backgroundImage: const AssetImage('assets/images/mwl-black-bg.png'),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final iconColor = theme.colorScheme.onSurface;
    final hasAnyButton = widget.showSearch ||
        widget.showBookmarks ||
        widget.showCalendar ||
        widget.showSettings;

    if (!hasAnyButton) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          if (widget.showSearch)
            _buildIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Search',
              onTap: widget.onSearchTap ?? () {},
              iconColor: iconColor,
              theme: theme,
            ),
          if (widget.showBookmarks)
            _buildIconButton(
              icon: Icons.bookmark_outline_rounded,
              tooltip: 'Bookmarks',
              onTap: widget.onBookmarksTap ?? () {},
              iconColor: iconColor,
              theme: theme,
            ),
          if (widget.showCalendar)
            _buildIconButton(
              icon: Icons.calendar_today_outlined,
              tooltip: 'Calendar',
              onTap: widget.onCalendarTap ?? () {},
              iconColor: iconColor,
              theme: theme,
            ),
          if (widget.showSettings)
            _buildIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onTap: widget.onSettingsTap ?? () {},
              iconColor: iconColor,
              theme: theme,
            ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color iconColor,
    required ThemeData theme,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    String? profileImageUrl,
    AccountType currentAccountType,
    List<Account> accounts,
    Color effectiveColor,
  ) {
    // Generate a placeholder URL if profileImageUrl is null
    final imageUrl = profileImageUrl ??
        'https://cdn-icons-png.flaticon.com/512/4140/4140037.png';

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: effectiveColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AvatarWidget(
        url: imageUrl,
        height: 36,
        width: 36,
        borderColor: effectiveColor,
        borderWidth: 2,
        onTap: () => _showAccountSelectionModal(
          context,
          currentAccountType,
          accounts,
        ),
      ),
    );
  }

  void _showAccountSelectionModal(BuildContext context,
      AccountType currentAccountType, List<Account> accounts) {
    Navigator.push(
      context,
      SlidePageRoute(
        direction: SlideDirection.left,
        page: AccountSwitcherPage(
          onUiChange: widget.onUiChange,
        ),
      ),
    );
  }
}
