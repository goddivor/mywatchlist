import 'package:flutter/material.dart';
import 'package:mywatchlist/pages/settings/coming_soon_page.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';

/// Settings page for anime/manga detail page settings (tabs, order).
///
/// Stub created by the app shell so the settings hub and `AppRoutes.openSettingsPage`
/// already link here; the owning feature unit replaces the body.
class AnimeMangaSettingsPage extends StatelessWidget {
  const AnimeMangaSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const section = SettingsSection.animeManga;
    return ComingSoonPage(
      title: section.title,
      icon: section.icon,
      subtitle: section.description,
    );
  }
}
