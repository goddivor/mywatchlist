import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/trackers/provider/trackers_list.dart';
import 'package:mywatchlist/user/user_manager.dart';

class ManageAccountsPage extends StatefulWidget {
  const ManageAccountsPage({super.key});

  @override
  State<ManageAccountsPage> createState() => _ManageAccountsPageState();
}

class _ManageAccountsPageState extends State<ManageAccountsPage> {
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

  Color _getTrackerColor(String name) {
    switch (name) {
      case 'MyAnimeList':
        return const Color(0xFF2E51A2);
      case 'Anilist':
        return const Color(0xFF02A9FF);
      case 'Kitsu':
        return const Color(0xFFEF5D5D);
      case 'Simkl':
        return const Color(0xFF343C42);
      default:
        return Colors.grey;
    }
  }

  void _handleTrackerTap(int index) {
    // The existing handlers check isActive:
    // if active -> show logout dialog, if not -> start auth flow
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
        child: Column(
          children: [
            _buildTopBar(theme, colorScheme),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: trackers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _buildTrackerTile(theme, colorScheme, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Material(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: colorScheme.onSurface,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Manage accounts',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerTile(
    ThemeData theme,
    ColorScheme colorScheme,
    int index,
  ) {
    final tracker = trackers[index];
    final trackerColor = _getTrackerColor(tracker.name);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: tracker.isActive
              ? trackerColor.withAlpha(80)
              : colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      color: tracker.isActive
          ? trackerColor.withAlpha(12)
          : colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => _handleTrackerTap(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar or tracker icon
              Stack(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tracker.isActive
                          ? trackerColor.withAlpha(30)
                          : colorScheme.surfaceContainerHighest,
                    ),
                    child: tracker.isActive && tracker.profileImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: CachedNetworkImage(
                              imageUrl: tracker.profileImage!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: colorScheme.surfaceContainerHighest,
                              ),
                              errorWidget: (context, url, error) =>
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Image.asset(
                                      tracker.imageUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              tracker.imageUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                  if (tracker.isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 20,
                        width: 20,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tracker.isActive && tracker.username != null
                          ? tracker.username!
                          : tracker.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tracker.isActive
                          ? tracker.name
                          : 'Not connected',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Action
              if (tracker.isActive)
                FilledButton.tonal(
                  onPressed: () => _handleTrackerTap(index),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Remove'),
                )
              else
                FilledButton.tonal(
                  onPressed: () => _handleTrackerTap(index),
                  style: FilledButton.styleFrom(
                    backgroundColor: trackerColor.withAlpha(30),
                    foregroundColor: trackerColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Connect'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
