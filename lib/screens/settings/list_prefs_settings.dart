import 'package:flutter/material.dart';
import 'package:mywatchlist/pages/settings/coming_soon_page.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';

/// Settings page for user list display preferences.
///
/// Stub created by the app shell so the settings hub and `AppRoutes.openSettingsPage`
/// already link here; the owning feature unit replaces the body.
class ListPreferenceSettingsPage extends StatelessWidget {
  const ListPreferenceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const section = SettingsSection.listPreferences;
    return ComingSoonPage(
      title: section.title,
      icon: section.icon,
      subtitle: section.description,
    );
  }
}
