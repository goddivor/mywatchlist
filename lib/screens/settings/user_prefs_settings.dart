import 'package:flutter/material.dart';
import 'package:mywatchlist/pages/settings/coming_soon_page.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';

/// Settings page for DailyAL's user preferences (startup page, NSFW, titles…).
///
/// Stub created by the app shell so the settings hub and `AppRoutes.openSettingsPage`
/// already link here; the owning feature unit replaces the body.
class UserPrefSettingsPage extends StatelessWidget {
  const UserPrefSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const section = SettingsSection.userPreferences;
    return ComingSoonPage(
      title: section.title,
      icon: section.icon,
      subtitle: section.description,
    );
  }
}
