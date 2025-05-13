import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/settings/settings_page.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/user/user_preference.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/utils/sidebar_bg_manager.dart';

class AppSidebar extends StatefulWidget {
  final VoidCallback? onClose;

  const AppSidebar({
    super.key,
    this.onClose,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  String? _backgroundImagePath;
  bool _isLoadingImage = false;
  final UserPreference userPref = UserPreference();
  final SidebarBackgroundManager _bgManager = SidebarBackgroundManager.instance;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _animationController.forward();

    // Load background image path from preferences
    _loadBackgroundImage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final path = await _bgManager.getCurrentBackgroundImagePath();
      if (mounted && path != null) {
        setState(() {
          _backgroundImagePath = path;
        });
      }
    } catch (e) {
      debugPrint('Error loading background image: $e');
    }
  }

  Future<void> _pickAndSaveBackgroundImage() async {
    setState(() {
      _isLoadingImage = true;
    });

    try {
      final path = await _bgManager.setNewBackgroundImage(context: context);

      if (mounted) {
        setState(() {
          _backgroundImagePath = path;
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    }
  }

  Future<void> _removeBackgroundImage() async {
    try {
      final success = await _bgManager.removeBackgroundImage(context: context);

      if (success && mounted) {
        setState(() {
          _backgroundImagePath = null;
        });
      }
    } catch (e) {
      debugPrint('Error removing background image: $e');
    }
  }

  void _showBackgroundImageOptions() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Sidebar Background',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),

            // Change background option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.image,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: const Text('Change background image'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSaveBackgroundImage();
              },
            ),

            // Remove background option (only if there's a background)
            if (_backgroundImagePath != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete,
                    color: theme.colorScheme.error,
                  ),
                ),
                title: const Text('Remove background image'),
                onTap: () {
                  Navigator.pop(context);
                  _removeBackgroundImage();
                },
              ),

            const SizedBox(height: 10),

            // Cancel button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final sidebarWidth = size.width * 0.85;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset((1 - _slideAnimation.value) * sidebarWidth, 0),
          child: child,
        );
      },
      child: Container(
        width: sidebarWidth,
        height: size.height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(0),
            bottomLeft: Radius.circular(0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // User header with background image
            _buildSidebarHeader(theme),

            // Menu items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Settings
                  _buildMenuItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      // Close sidebar
                      if (widget.onClose != null) {
                        widget.onClose!();
                      }
                      // Navigator.pop(context);

                      // Navigate to settings
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                  ),

                  // About
                  _buildMenuItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {
                      // Navigate to about
                      if (widget.onClose != null) {
                        widget.onClose!();
                      }
                      Navigator.pop(context);
                      // Add your navigation logic here
                    },
                  ),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Divider(
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                  ),

                  // Add more menu items here
                ],
              ),
            ),

            // Bottom section with app version
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '© 2025 MyWatchList',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(ThemeData theme) {
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        String? profileImageUrl;
        String username = 'Guest';
        AccountType currentAccountType = AccountType.none;

        if (state is AccountLoaded) {
          currentAccountType = state.selectedAccountType;
          profileImageUrl = state.profileImageUrl;

          // Get username from accounts list
          final selectedAccount = state.availableAccounts.firstWhere(
            (account) => account.typeAcc == currentAccountType,
            orElse: () => Account(
              name: 'Guest',
              typeAcc: AccountType.none,
              imageUrl:
                  'https://cdn-icons-png.flaticon.com/512/4140/4140037.png',
            ),
          );

          username = selectedAccount.name;
        }

        return Stack(
          children: [
            // Background image or gradient
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                image: _backgroundImagePath != null
                    ? DecorationImage(
                        image: FileImage(File(_backgroundImagePath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _backgroundImagePath == null
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.7),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),

            // Overlay for better text visibility
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),

            // User info
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  // Avatar
                  Hero(
                    tag: 'sidebar_avatar',
                    child: AvatarWidget(
                      url: profileImageUrl,
                      height: 60,
                      width: 60,
                      borderColor: Colors.white,
                      borderWidth: 2,
                    ),
                  ),

                  const SizedBox(width: 15),

                  // Username
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentAccountType != AccountType.none
                              ? currentAccountType.toString().split('.').last
                              : 'Not connected',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Background image edit button
            Positioned(
              top: 20,
              right: 20,
              child: Row(
                children: [
                  // Edit button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _showBackgroundImageOptions,
                      tooltip: 'Change background',
                    ),
                  ),
                ],
              ),
            ),

            // Close sidebar button
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.onClose != null) {
                      widget.onClose!();
                    }
                  },
                  tooltip: 'Close sidebar',
                ),
              ),
            ),

            // Loading indicator (when changing background)
            if (_isLoadingImage)
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(width: 16),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),

                // Trailing widget
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
