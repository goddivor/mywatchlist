import 'package:flutter/material.dart';
import 'package:mywatchlist/screens/settings/language_settings.dart';
import 'package:mywatchlist/screens/settings/mal_home_settings.dart';
import 'package:mywatchlist/screens/settings/theme_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Make sure to use Navigator.of(context).pop() for proper context
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // App Settings Section
          _buildSectionHeader(theme, 'App Settings'),

          // Theme Settings
          _buildSettingTile(
            context,
            icon: Icons.color_lens_outlined,
            title: 'Theme Settings',
            subtitle: 'Change app appearance and colors',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ThemeSettings(),
                ),
              );
            },
          ),

          // Language Settings
          _buildSettingTile(
            context,
            icon: Icons.language_outlined,
            title: 'Language Settings',
            subtitle: 'Change app language',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LanguageSettings(),
                ),
              );
            },
          ),

          // Home Page Settings
          _buildSettingTile(
            context,
            icon: Icons.home_outlined,
            title: 'Home Page Settings',
            subtitle: 'Customize content and layout',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeSettingsPage(),
                ),
              );
            },
          ),

          const Divider(),

          // Account Settings Section
          _buildSectionHeader(theme, 'Account Settings'),

          // MyAnimeList Account
          _buildSettingTile(
            context,
            icon: Icons.account_circle_outlined,
            title: 'MyAnimeList Account',
            subtitle: 'Manage your MAL connection',
            onTap: () {
              // Navigate to MAL account settings
            },
          ),

          // Other Accounts
          _buildSettingTile(
            context,
            icon: Icons.link_outlined,
            title: 'Connected Services',
            subtitle: 'Manage AniList, Kitsu, and other services',
            onTap: () {
              // Navigate to services settings
            },
          ),

          const Divider(),

          // App Info Section
          _buildSectionHeader(theme, 'App Information'),

          // About
          _buildSettingTile(
            context,
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Version, credits, and legal information',
            onTap: () {
              // Navigate to about page
            },
          ),

          // Help & Feedback
          _buildSettingTile(
            context,
            icon: Icons.help_outline,
            title: 'Help & Feedback',
            subtitle: 'Get support or report issues',
            onTap: () {
              // Navigate to help page
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
      onTap: onTap,
    );
  }
}
