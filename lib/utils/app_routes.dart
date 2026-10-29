import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/pages/Anilist/anilist_user_profile_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_user_profile_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_user_profile_page.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';
import 'package:mywatchlist/pages/side_bar.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/bookmarks_screen.dart';
import 'package:mywatchlist/screens/calendar/calendar_screen.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/screens/mal_web/message_thread_screen.dart';
import 'package:mywatchlist/screens/mal_web/messages_screen.dart';
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
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart' show MalMessage;
import 'package:mywatchlist/services/auth/anilist_auth_v2.dart';
import 'package:mywatchlist/services/auth/mal_auth_v2.dart';
import 'package:mywatchlist/services/auth/simkl_auth_v2.dart';
import 'package:mywatchlist/services/notifications/mal_hub_poller.dart' show MalHubPayload;
import 'package:mywatchlist/user/base_user.dart' show AuthStatus;
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_profile_view.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_profile_view.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_profile_view.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_states.dart' show simklSignedIn;
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

  /// The profile screen of [tracker] pushed as a page. AniList shows any public profile by
  /// username, Kitsu one by user id (a username that is not a number opens the signed-in
  /// profile), Simkl only the signed-in one.
  static Widget _profileScreen(AccountType tracker, String? username,
      {UserProfileTab? tab}) {
    switch (tracker) {
      case AccountType.anilist:
      case AccountType.kitsu:
      case AccountType.simkl:
        return TrackerProfileScreen(tracker: tracker, username: username);
      case AccountType.myanimelist:
      case AccountType.none:
        return UserProfileScreen(
            username: username, initialTab: tab ?? UserProfileTab.stats);
    }
  }

  /// Opens the profile of [username] on [tracker]; null [username] = the signed-in user.
  /// [tab] picks the MyAnimeList profile tab (another user's opens on their list by
  /// default); other trackers have a single profile page and ignore it.
  static Future<void> openUserProfile(
    BuildContext context, {
    required AccountType tracker,
    String? username,
    UserProfileTab? tab,
  }) =>
      push<void>(context, _profileScreen(tracker, username, tab: tab));

  /// Opens the list statistics of [username] on [tracker] (the profile, on its Stats tab);
  /// null [username] = the signed-in user.
  static Future<void> openUserStats(
    BuildContext context, {
    required AccountType tracker,
    String? username,
  }) =>
      push<void>(
          context, _profileScreen(tracker, username, tab: UserProfileTab.stats));

  /// Opens the quick profile sheet (header, main numbers, actions) of a MyAnimeList user;
  /// null [username] = the signed-in user. Other trackers open their full profile page.
  static Future<void> openUserPop(
    BuildContext context, {
    required AccountType tracker,
    String? username,
  }) {
    if (tracker != AccountType.myanimelist && tracker != AccountType.none) {
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

  /// Opens the MyAnimeList private messages on the inbox, or on the sent box with [sent].
  static Future<void> openMalMessages(BuildContext context, {bool sent = false}) =>
      push<void>(context, MalMessagesScreen(initialTab: sent ? 1 : 0));

  /// Opens the thread of MyAnimeList message [id] (a message of the sent box with [sent]).
  /// Only the id is known (a notification, a link): subject and names come from the page.
  static Future<void> openMalMessage(BuildContext context,
          {required int id, bool sent = false, int? threadId}) =>
      push<void>(
        context,
        MalMessageThreadScreen(
          message: MalMessage(
            id: id,
            counterpart: '',
            subject: '',
            // An inbox message reached from its notification is unread: reading it lowers the badge.
            isRead: sent,
            isSent: sent,
            threadId: threadId,
          ),
        ),
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
      case NotificationRouteKind.malMessage:
        await openMalMessage(context, id: route.id!, sent: route.sent, threadId: route.threadId);
      case NotificationRouteKind.malMessages:
        await openMalMessages(context, sent: route.sent);
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

enum NotificationRouteKind { content, calendar, bookmarks, malMessage, malMessages }

/// Destination encoded in a local notification payload.
///
/// Format (plain string, what `flutter_local_notifications` carries): `anime:<malId>`,
/// `manga:<malId>`, `calendar` or `bookmarks`. The notifications unit writes these. A MAL hub
/// payload pointing to `mymessages.php` (see [MalHubPayload.messageLink]) is a private
/// message thread (`go=read&id=`) or a message box (inbox, `go=sent`).
class NotificationRoute {
  final NotificationRouteKind kind;
  final String? category;

  /// The MAL id of the content, or of the message.
  final int? id;

  /// A message (or box) of the sent box.
  final bool sent;

  /// The message's thread, when the payload has it.
  final int? threadId;

  const NotificationRoute._(this.kind, {this.category, this.id, this.sent = false, this.threadId});

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
    if (MalHubPayload.isHub(value)) {
      final link = MalHubPayload.messageLink(value);
      if (link == null) return null;
      return link.isThread
          ? NotificationRoute._(NotificationRouteKind.malMessage,
              id: link.id, sent: link.sent, threadId: link.threadId)
          : NotificationRoute._(NotificationRouteKind.malMessages, sent: link.sent);
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

/// A pushed profile page of AniList, Kitsu or Simkl: the tracker's profile view with a back
/// button when the account is connected (or when another AniList user is shown), else the
/// tracker's own sign-in prompt under a plain app bar.
@visibleForTesting
class TrackerProfileScreen extends StatelessWidget {
  final AccountType tracker;
  final String? username;

  const TrackerProfileScreen({super.key, required this.tracker, this.username});

  @override
  Widget build(BuildContext context) {
    switch (tracker) {
      case AccountType.anilist:
        if (username != null) {
          return Scaffold(
              body: AnilistProfileView(username: username, showBack: true));
        }
        return _own(
          UserAnilistV2.instance,
          signedIn: (u) => u.status == AuthStatus.AUTHENTICATED,
          view: (u) => AnilistProfileView(key: ValueKey(u.username), showBack: true),
          prompt: const AnilistUserProfilePage(isSelf: true),
        );
      case AccountType.kitsu:
        final id = username == null ? null : int.tryParse(username!.trim());
        if (id != null) {
          return Scaffold(
              body: KitsuProfileView(userId: '$id', showBack: true));
        }
        return _own(
          UserKitsuV2.instance,
          signedIn: (u) => u.status == AuthStatus.AUTHENTICATED,
          view: (u) => KitsuProfileView(key: ValueKey(u.username), showBack: true),
          prompt: const KitsuUserProfilePage(isSelf: true),
        );
      case AccountType.simkl:
        return _own(
          UserSimklV2.instance,
          signedIn: (_) => simklSignedIn,
          view: (u) => SimklProfileView(key: ValueKey(u.username), showBack: true),
          prompt: const SimklUserProfilePage(isSelf: true),
        );
      case AccountType.myanimelist:
      case AccountType.none:
        return UserProfileScreen(username: username);
    }
  }

  Widget _own<U extends ChangeNotifier>(
    U user, {
    required bool Function(U user) signedIn,
    required Widget Function(U user) view,
    required Widget prompt,
  }) {
    return ListenableBuilder(
      listenable: user,
      builder: (context, _) => signedIn(user)
          ? Scaffold(body: view(user))
          : Scaffold(appBar: AppBar(), body: prompt),
    );
  }
}
