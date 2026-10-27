import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/settings/coming_soon_page.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';
import 'package:mywatchlist/pages/side_bar.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/bookmarks_screen.dart';
import 'package:mywatchlist/screens/calendar/calendar_screen.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/screens/manage_accounts_page.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/settings/about_settings.dart';
import 'package:mywatchlist/screens/settings/accounts_settings.dart';
import 'package:mywatchlist/screens/settings/anime_manga_settings.dart';
import 'package:mywatchlist/screens/settings/backup_settings.dart';
import 'package:mywatchlist/screens/settings/download_settings.dart';
import 'package:mywatchlist/screens/settings/dub_settings.dart';
import 'package:mywatchlist/screens/settings/language_settings.dart';
import 'package:mywatchlist/screens/settings/list_prefs_settings.dart';
import 'package:mywatchlist/screens/settings/mal_home_settings.dart';
import 'package:mywatchlist/screens/settings/notifications_settings.dart';
import 'package:mywatchlist/screens/settings/settings_page.dart';
import 'package:mywatchlist/screens/settings/storage_settings.dart';
import 'package:mywatchlist/screens/settings/theme_settings.dart';
import 'package:mywatchlist/screens/settings/user_prefs_settings.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_screen.dart';
import 'package:mywatchlist/services/auth/anilist_auth_v2.dart';
import 'package:mywatchlist/services/auth/mal_auth_v2.dart';
import 'package:mywatchlist/services/auth/simkl_auth_v2.dart';
import 'package:mywatchlist/widgets/user/profile/user_pop_sheet.dart';

export 'package:mywatchlist/pages/settings/settings_section.dart';

/// Cross-unit navigation: every feature links to another feature through these helpers,
/// so no unit has to import (or edit) another unit's screens.
///
/// Each helper pushes a [MaterialPageRoute] on the nearest navigator (no forced text
/// direction, so right-to-left languages keep working).
abstract final class AppRoutes {
  /// Pushes [page] on the navigator of [context]; the base of every helper below.
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
  }

  /// Opens the settings hub (one tile per [SettingsSection]).
  static Future<void> openSettings(BuildContext context) =>
      push<void>(context, const SettingsPage());

  /// Opens one settings page directly, e.g. `openSettingsPage(context, SettingsSection.theme)`.
  static Future<void> openSettingsPage(
          BuildContext context, SettingsSection section) =>
      push<void>(context, settingsPageFor(section));

  /// The widget of a settings page (used by the hub and by [openSettingsPage]).
  static Widget settingsPageFor(SettingsSection section) {
    switch (section) {
      case SettingsSection.accounts:
        return const AccountsSettingsPage();
      case SettingsSection.theme:
        return const ThemeSettings();
      case SettingsSection.language:
        return const LanguageSettings();
      case SettingsSection.homePage:
        return const HomeSettingsPage();
      case SettingsSection.notifications:
        return const NotificationSettingsPage();
      case SettingsSection.userPreferences:
        return const UserPrefSettingsPage();
      case SettingsSection.listPreferences:
        return const ListPreferenceSettingsPage();
      case SettingsSection.animeManga:
        return const AnimeMangaSettingsPage();
      case SettingsSection.dub:
        return const DubSettingsPage();
      case SettingsSection.downloads:
        return const DownloadSettings();
      case SettingsSection.backup:
        return const BackupRestoreSettingsPage();
      case SettingsSection.storage:
        return const StorageSettingsPage();
      case SettingsSection.about:
        return const AboutSettingsPage();
    }
  }

  /// Opens the About page (shortcut for `openSettingsPage(context, SettingsSection.about)`).
  static Future<void> openAbout(BuildContext context) =>
      openSettingsPage(context, SettingsSection.about);

  /// Opens the bookmarks screen (`lib/screens/bookmarks_screen.dart`).
  static Future<void> openBookmarks(BuildContext context) =>
      push<void>(context, const BookmarksScreen());

  /// Opens the weekly airing calendar (`lib/screens/calendar/calendar_screen.dart`).
  static Future<void> openCalendar(BuildContext context) =>
      push<void>(context, const CalendarScreen());

  /// Opens the global search screen, optionally prefilled with [query], on [category]
  /// (`all`, `anime`, `manga`, `character`, `person`, `user`, `forum`, `featured`, `news`,
  /// `club`, `interest_stack`) and with initial [filters]. For the ready-made searches (genre,
  /// studio, magazine, tag, season…) see the static entry points of [GeneralSearchScreen].
  static Future<void> openSearch(
    BuildContext context, {
    String? query,
    String category = SearchCategory.all,
    SearchFilters? filters,
  }) =>
      push<void>(
        context,
        GeneralSearchScreen(
          searchQuery: query,
          category: category,
          filters: filters,
          showBackButton: true,
        ),
      );

  /// Whether [tracker] has a real profile screen (MyAnimeList; no tracker selected falls back
  /// to MyAnimeList, as the home shell does). The others open a placeholder page until
  /// their profile unit lands.
  static bool _hasProfileScreen(AccountType tracker) =>
      tracker == AccountType.myanimelist || tracker == AccountType.none;

  /// Opens the profile of [username] on [tracker]; null [username] = the signed-in user.
  static Future<void> openUserProfile(
    BuildContext context, {
    required AccountType tracker,
    String? username,
  }) =>
      push<void>(
        context,
        _hasProfileScreen(tracker)
            ? UserProfileScreen(username: username)
            : _UserProfileStub(
                title: S.current.Profile,
                icon: Icons.person_outline,
                tracker: tracker,
                username: username,
              ),
      );

  /// Opens the list statistics of [username] on [tracker] (the profile, on its Stats tab);
  /// null [username] = the signed-in user.
  static Future<void> openUserStats(
    BuildContext context, {
    required AccountType tracker,
    String? username,
  }) =>
      push<void>(
        context,
        _hasProfileScreen(tracker)
            ? UserProfileScreen(username: username, initialTab: UserProfileTab.stats)
            : _UserProfileStub(
                title: S.current.Stats,
                icon: Icons.bar_chart_rounded,
                tracker: tracker,
                username: username,
              ),
      );

  /// Opens the quick profile sheet (header, main numbers, actions) of a MyAnimeList user;
  /// null [username] = the signed-in user. Other trackers open their full profile page.
  static Future<void> openUserPop(
    BuildContext context, {
    required AccountType tracker,
    String? username,
  }) {
    if (!_hasProfileScreen(tracker)) {
      return openUserProfile(context, tracker: tracker, username: username);
    }
    return showUserPopSheet(context, username: username);
  }

  /// Opens the anime or manga detail screen of MAL id [id] ([category] = `anime` | `manga`).
  static Future<void> openContent(BuildContext context,
          {required int id, String category = 'anime'}) =>
      push<void>(
        context,
        ContentDetailedScreen(node: null, id: id, category: category),
      );

  /// Opens the login screen (tracker picker), replacing nothing.
  static Future<void> openLogin(BuildContext context) =>
      Navigator.of(context).pushNamed<void>('/login');

  /// Opens the tracker manager (connect, switch, sign out).
  static Future<void> openManageAccounts(BuildContext context) =>
      push<void>(context, const ManageAccountsPage());

  /// Opens the sidebar of the home shell; outside the shell, pushes it as a page.
  static void openSidebar(BuildContext context) {
    final shell = HomeShell.maybeOf(context);
    if (shell != null) {
      shell.openSidebar();
      return;
    }
    push<void>(
      context,
      const Scaffold(body: SafeArea(child: AppSidebar())),
    );
  }

  /// Starts the sign-in flow of [tracker] again (session expired). OAuth trackers open
  /// their browser flow directly; Kitsu (username/password) opens the tracker manager.
  static Future<void> signInAgain(BuildContext context, AccountType tracker) async {
    switch (tracker) {
      case AccountType.myanimelist:
        await MalAuthV2().handleSignIn(context: context);
      case AccountType.anilist:
        await AnilistAuthV2().handleSignIn(context: context);
      case AccountType.simkl:
        await SimklAuthV2().handleSignIn(context: context);
      case AccountType.kitsu:
        await openManageAccounts(context);
      case AccountType.none:
        await openLogin(context);
    }
  }

  /// Routes a notification payload (see [NotificationRoute] for the format); unknown or
  /// empty payloads do nothing. Called by the home shell once its first frame is drawn.
  static Future<void> openFromNotification(
      BuildContext context, String? payload) async {
    final route = NotificationRoute.parse(payload);
    if (route == null) return;
    switch (route.kind) {
      case NotificationRouteKind.content:
        await openContent(context, id: route.id!, category: route.category!);
      case NotificationRouteKind.calendar:
        await openCalendar(context);
      case NotificationRouteKind.bookmarks:
        await openBookmarks(context);
    }
  }

  /// Display name of a tracker (brand names, never translated).
  static String trackerLabel(AccountType tracker) {
    switch (tracker) {
      case AccountType.myanimelist:
        return 'MyAnimeList';
      case AccountType.anilist:
        return 'AniList';
      case AccountType.kitsu:
        return 'Kitsu';
      case AccountType.simkl:
        return 'Simkl';
      case AccountType.none:
        return '';
    }
  }
}

enum NotificationRouteKind { content, calendar, bookmarks }

/// Destination encoded in a local notification payload.
///
/// Format (plain string, what `flutter_local_notifications` carries): `anime:<malId>`,
/// `manga:<malId>`, `calendar` or `bookmarks`. The notifications unit writes these.
class NotificationRoute {
  final NotificationRouteKind kind;
  final String? category;
  final int? id;

  const NotificationRoute._(this.kind, {this.category, this.id});

  /// Payload for the detail screen of [category] (`anime` | `manga`) [id].
  static String contentPayload(String category, int id) => '$category:$id';

  /// Parses [payload]; null when it is empty or not one of the documented forms.
  static NotificationRoute? parse(String? payload) {
    final value = payload?.trim();
    if (value == null || value.isEmpty) return null;
    if (value == 'calendar') {
      return const NotificationRoute._(NotificationRouteKind.calendar);
    }
    if (value == 'bookmarks') {
      return const NotificationRoute._(NotificationRouteKind.bookmarks);
    }
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final category = parts[0];
    final id = int.tryParse(parts[1]);
    if ((category != 'anime' && category != 'manga') || id == null || id <= 0) {
      return null;
    }
    return NotificationRoute._(NotificationRouteKind.content,
        category: category, id: id);
  }
}

class _UserProfileStub extends StatelessWidget {
  final String title;
  final IconData icon;
  final AccountType tracker;
  final String? username;

  const _UserProfileStub({
    required this.title,
    required this.icon,
    required this.tracker,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    final label = AppRoutes.trackerLabel(tracker);
    final who = username == null || username!.isEmpty
        ? label
        : (label.isEmpty ? username! : '$username · $label');
    return ComingSoonPage(
      title: title,
      icon: icon,
      subtitle: who.isEmpty ? null : who,
    );
  }
}
