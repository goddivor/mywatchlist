import 'package:flutter/material.dart';
import 'package:mywatchlist/pages/settings/coming_soon_page.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';

/// Settings page for the About page (version, changelog, updates, credits).
///
/// Stub created by the app shell so the settings hub and `AppRoutes.openSettingsPage`
/// already link here; the owning feature unit replaces the body.
class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const section = SettingsSection.about;
    return ComingSoonPage(
      title: section.title,
      icon: section.icon,
      subtitle: section.description,
    );
  }
}
