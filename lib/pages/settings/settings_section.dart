import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// One page of the settings hub. `AppRoutes.openSettingsPage` opens any of them, so a
/// feature unit can link to a settings page without importing it.
enum SettingsSection {
  accounts,
  theme,
  language,
  homePage,
  notifications,
  userPreferences,
  listPreferences,
  animeManga,
  dub,
  downloads,
  backup,
  storage,
  about,
}

/// Label, description and icon of each settings page (one source for the hub, the stubs
/// and any link to them).
extension SettingsSectionInfo on SettingsSection {
  String get title {
    switch (this) {
      case SettingsSection.accounts:
        return S.current.Settings_Accounts;
      case SettingsSection.theme:
        return S.current.Theme_Settings;
      case SettingsSection.language:
        return S.current.Language_settings;
      case SettingsSection.homePage:
        return S.current.Home_Page_Setting;
      case SettingsSection.notifications:
        return S.current.Notification_Settings;
      case SettingsSection.userPreferences:
        return S.current.User_Preferences;
      case SettingsSection.listPreferences:
        return S.current.List_preferences;
      case SettingsSection.animeManga:
        return S.current.Anime_Manga_settings;
      case SettingsSection.dub:
        return S.current.Dub_Settings;
      case SettingsSection.downloads:
        return S.current.Settings_Downloads;
      case SettingsSection.backup:
        return S.current.Backup_And_Restore;
      case SettingsSection.storage:
        return S.current.Settings_Storage;
      case SettingsSection.about:
        return S.current.About;
    }
  }

  String get description {
    switch (this) {
      case SettingsSection.accounts:
        return S.current.Settings_Accounts_Desc;
      case SettingsSection.theme:
        return S.current.Theme_setting_desc_v2;
      case SettingsSection.language:
        return S.current.Language_settings_desc_v2;
      case SettingsSection.homePage:
        return S.current.HomePageSettings_desc;
      case SettingsSection.notifications:
        return S.current.Settings_Notifications_Desc;
      case SettingsSection.userPreferences:
        return S.current.User_Preferences_desc;
      case SettingsSection.listPreferences:
        return S.current.List_preferences_desc;
      case SettingsSection.animeManga:
        return S.current.Anime_Manga_settings_desc;
      case SettingsSection.dub:
        return S.current.Dub_Settings_Desc;
      case SettingsSection.downloads:
        return S.current.Settings_Downloads_Desc;
      case SettingsSection.backup:
        return S.current.Backup_And_Restore_desc;
      case SettingsSection.storage:
        return S.current.Settings_Storage_Desc;
      case SettingsSection.about:
        return S.current.About_desc;
    }
  }

  IconData get icon {
    switch (this) {
      case SettingsSection.accounts:
        return Icons.manage_accounts_outlined;
      case SettingsSection.theme:
        return Icons.palette_outlined;
      case SettingsSection.language:
        return Icons.translate;
      case SettingsSection.homePage:
        return Icons.dashboard_customize_outlined;
      case SettingsSection.notifications:
        return Icons.notifications_outlined;
      case SettingsSection.userPreferences:
        return Icons.tune;
      case SettingsSection.listPreferences:
        return Icons.view_list_outlined;
      case SettingsSection.animeManga:
        return Icons.movie_filter_outlined;
      case SettingsSection.dub:
        return Icons.record_voice_over_outlined;
      case SettingsSection.downloads:
        return Icons.download_outlined;
      case SettingsSection.backup:
        return Icons.settings_backup_restore;
      case SettingsSection.storage:
        return Icons.storage_outlined;
      case SettingsSection.about:
        return Icons.info_outline;
    }
  }
}
