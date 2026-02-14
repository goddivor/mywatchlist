import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:mywatchlist/pages/login_page.dart';
import 'package:mywatchlist/screens/manage_accounts_page.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/user/trackers/provider/trackers_list.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/utils/page_transitions.dart';

class AccountSwitcherPage extends StatefulWidget {
  final VoidCallback? onUiChange;

  const AccountSwitcherPage({super.key, this.onUiChange});

  @override
  State<AccountSwitcherPage> createState() => _AccountSwitcherPageState();
}

class _AccountSwitcherPageState extends State<AccountSwitcherPage> {
  @override
  void initState() {
    super.initState();
    UserManager.instance.addListener(_onUserManagerChanged);
    _updateTrackerStates();
  }

  @override
  void dispose() {
    UserManager.instance.removeListener(_onUserManagerChanged);
    super.dispose();
  }

  void _onUserManagerChanged() {
    if (mounted) {
      setState(() {
        _updateTrackerStates();
      });
      context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
    }
  }

  void _updateTrackerStates() {
    final userManager = UserManager.instance;
    for (int i = 0; i < trackers.length; i++) {
      switch (trackers[i].name) {
        case 'MyAnimeList':
          trackers[i].isActive =
              userManager.isAuthenticated(AccountType.myanimelist);
          if (trackers[i].isActive) {
            trackers[i].username = userManager.mal.username;
            trackers[i].profileImage = userManager.mal.profileImage;
          }
          break;
        case 'Anilist':
          trackers[i].isActive =
              userManager.isAuthenticated(AccountType.anilist);
          if (trackers[i].isActive) {
            trackers[i].username = userManager.anilist.username;
            trackers[i].profileImage = userManager.anilist.profileImage;
          }
          break;
        case 'Kitsu':
          trackers[i].isActive =
              userManager.isAuthenticated(AccountType.kitsu);
          if (trackers[i].isActive) {
            trackers[i].username = userManager.kitsu.username;
            trackers[i].profileImage = userManager.kitsu.profileImage;
          }
          break;
        case 'Simkl':
          trackers[i].isActive =
              userManager.isAuthenticated(AccountType.simkl);
          if (trackers[i].isActive) {
            trackers[i].username = userManager.simkl.username;
            trackers[i].profileImage = userManager.simkl.profileImage;
          }
          break;
      }
    }
  }

  Color _getAccountColor(AccountType type) {
    switch (type) {
      case AccountType.myanimelist:
        return const Color(0xFF2E51A2);
      case AccountType.anilist:
        return const Color(0xFF02A9FF);
      case AccountType.kitsu:
        return const Color(0xFFEF5D5D);
      case AccountType.simkl:
        return const Color(0xFF343C42);
      default:
        return Colors.grey;
    }
  }

  String _getAccountImage(AccountType type) {
    switch (type) {
      case AccountType.myanimelist:
        return 'assets/images/mal-icon.png';
      case AccountType.anilist:
        return 'assets/images/anilist-icon.png';
      case AccountType.kitsu:
        return 'assets/images/kitsu-icon.png';
      case AccountType.simkl:
        return 'assets/images/simkl-icon.png';
      default:
        return 'assets/images/mwl-black-bg.png';
    }
  }

  String _accountTypeToDisplayName(AccountType type) {
    switch (type) {
      case AccountType.myanimelist:
        return 'MyAnimeList';
      case AccountType.anilist:
        return 'Anilist';
      case AccountType.kitsu:
        return 'Kitsu';
      case AccountType.simkl:
        return 'Simkl';
      default:
        return '';
    }
  }

  void _switchToAccount(AccountType accountType) {
    context.read<AccountBloc>().add(ChangeAccountEvent(accountType));
    widget.onUiChange?.call();
    Navigator.pop(context);
  }

  void _disconnectCurrentAccount() {
    context.read<AccountBloc>().add(ChangeAccountEvent(AccountType.none));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _connectTracker(int index) {
    trackerFunctions[trackers[index].name]!(context, index, () {
      if (mounted) {
        setState(() {
          _updateTrackerStates();
        });
        context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: BlocBuilder<AccountBloc, AccountState>(
          builder: (context, state) {
            AccountType currentAccountType = AccountType.none;
            List<Account> allAccounts = [];

            if (state is AccountLoaded) {
              currentAccountType = state.selectedAccountType;
              allAccounts = state.availableAccounts;
            }

            final connectedAccounts = allAccounts
                .where((a) =>
                    a.typeAcc != AccountType.none &&
                    a.typeAcc != currentAccountType)
                .toList();

            final currentAccount = allAccounts
                .where((a) => a.typeAcc == currentAccountType)
                .toList();

            final unconnectedTrackers =
                trackers.where((t) => !t.isActive).toList();

            return Column(
              children: [
                _buildTopBar(colorScheme),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCurrentAccountSection(
                          theme,
                          colorScheme,
                          currentAccountType,
                          currentAccount.isNotEmpty
                              ? currentAccount.first
                              : null,
                        ),
                        if (connectedAccounts.isNotEmpty) ...[
                          _buildSectionDivider(colorScheme),
                          _buildConnectedAccountsSection(
                            theme,
                            colorScheme,
                            connectedAccounts,
                          ),
                        ],
                        _buildSectionDivider(colorScheme),
                        _buildManageAccountsTile(theme, colorScheme),
                        if (currentAccountType != AccountType.none) ...[
                          _buildDisconnectTile(theme, colorScheme),
                        ],
                        if (unconnectedTrackers.isNotEmpty) ...[
                          _buildSectionDivider(colorScheme),
                          _buildConnectNewSection(
                            theme,
                            colorScheme,
                            unconnectedTrackers,
                          ),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'MyWatchList',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          Material(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.close,
                  color: colorScheme.onSurface,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentAccountSection(
    ThemeData theme,
    ColorScheme colorScheme,
    AccountType currentAccountType,
    Account? currentAccount,
  ) {
    final accountColor = _getAccountColor(currentAccountType);
    final hasAccount =
        currentAccount != null && currentAccountType != AccountType.none;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: Column(
          children: [
            // Large avatar with tracker badge
            Stack(
              children: [
                Container(
                  height: 96,
                  width: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasAccount ? accountColor : colorScheme.outline,
                      width: 3,
                    ),
                    boxShadow: hasAccount
                        ? [
                            BoxShadow(
                              color: accountColor.withAlpha(60),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(48),
                    child: hasAccount
                        ? CachedNetworkImage(
                            imageUrl: currentAccount.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => ShimmerColor(
                              Container(
                                color: Colors.white,
                              ),
                            ),
                            errorWidget: (context, url, error) => Image.asset(
                              'assets/images/user_dal_old.png',
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
                            'assets/images/user_dal_old.png',
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                // Tracker badge
                if (hasAccount)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset(
                          _getAccountImage(currentAccountType),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Username
            Text(
              hasAccount ? currentAccount.name : 'No Account Selected',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 4),

            // Tracker name
            if (hasAccount)
              Text(
                _accountTypeToDisplayName(currentAccountType),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionDivider(ColorScheme colorScheme) {
    return Divider(
      color: colorScheme.outlineVariant.withAlpha(80),
      height: 1,
      indent: 24,
      endIndent: 24,
    );
  }

  Widget _buildConnectedAccountsSection(
    ThemeData theme,
    ColorScheme colorScheme,
    List<Account> connectedAccounts,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Switch account',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...connectedAccounts
              .map((account) => _buildAccountTile(theme, colorScheme, account)),
        ],
      ),
    );
  }

  Widget _buildAccountTile(
    ThemeData theme,
    ColorScheme colorScheme,
    Account account,
  ) {
    final accountColor = _getAccountColor(account.typeAcc);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _switchToAccount(account.typeAcc),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                // Avatar with service badge
                Stack(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accountColor.withAlpha(120),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CachedNetworkImage(
                          imageUrl: account.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (context, url, error) => Image.asset(
                            'assets/images/user_dal_old.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        height: 22,
                        width: 22,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.asset(
                            _getAccountImage(account.typeAcc),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // Account info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _accountTypeToDisplayName(account.typeAcc),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManageAccountsTile(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              SlidePageRoute(
                direction: SlideDirection.left,
                page: const ManageAccountsPage(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer.withAlpha(80),
                  ),
                  child: Icon(
                    Icons.manage_accounts_rounded,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage accounts',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add or remove connected services',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.onSurfaceVariant.withAlpha(120),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectTile(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _disconnectCurrentAccount,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.errorContainer.withAlpha(80),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: colorScheme.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Disconnect',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectNewSection(
    ThemeData theme,
    ColorScheme colorScheme,
    List unconnectedTrackers,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect another account',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...unconnectedTrackers.map((tracker) {
            final index = trackers.indexOf(tracker);
            return _buildUnconnectedTrackerTile(
                theme, colorScheme, tracker, index);
          }),
        ],
      ),
    );
  }

  Widget _buildUnconnectedTrackerTile(
    ThemeData theme,
    ColorScheme colorScheme,
    dynamic tracker,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _connectTracker(index),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tracker.primaryColor.withAlpha(25),
                    border: Border.all(
                      color: tracker.primaryColor.withAlpha(60),
                    ),
                  ),
                  child: Image.asset(
                    tracker.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tracker.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to connect',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.onSurfaceVariant.withAlpha(120),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
