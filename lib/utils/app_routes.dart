import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/pages/Anilist/anilist_user_profile_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_user_profile_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_user_profile_page.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';
import 'package:mywatchlist/widgets/Anilist/calendar/anilist_calendar_page.dart';
import 'package:mywatchlist/widgets/Kitsu/calendar/kitsu_calendar_page.dart';
import 'package:mywatchlist/pages/side_bar.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/bookmarks_screen.dart';
import 'package:mywatchlist/screens/calendar/calendar_screen.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/screens/mal_web/mal_chat_screen.dart';
import 'package:mywatchlist/screens/mal_web/messages_screen.dart';
import 'package:mywatchlist/screens/manage_accounts_page.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/settings/data_source_settings.dart';
import 'package:mywatchlist/screens/settings/about_settings.dart';
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
import 'package:mywatchlist/services/notifications/mal_hub_poller.dart' show MalHubPayload, MalMessageLink;
import 'package:mywatchlist/user/base_user.dart' show AuthStatus;
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_profile_view.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_profile_view.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/widgets/Simkl/calendar/simkl_calendar.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart' show openSimklTitle;
import 'package:mywatchlist/services/api/SimKl/simkl_kind.dart';
import 'package:mywatchlist/services/notifications/simkl_release_planner.dart' show parseSimklTitlePayload;
import 'package:mywatchlist/widgets/Simkl/simkl_profile_view.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_states.dart' show simklSignedIn;
import 'package:mywatchlist/widgets/user/profile/user_pop_sheet.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_explore_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_search_all_page.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_chips.dart' show openAnilistSearch;
import 'package:mywatchlist/screens/mal_web/notifications_screen.dart' show MalNotificationsScreen;
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuMediaKind;
import 'package:mywatchlist/widgets/Kitsu/kitsu_open.dart' show openKitsuTitle;
import 'package:mywatchlist/pages/Anilist/anilist_notifications_page.dart' show openAnilistNotifications;
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistTitle;
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/services/notifications/notification_payload.dart';

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
        return const ManageAccountsPage();
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
      case SettingsSection.dataSources:
        return const DataSourceSettingsPage();
      case SettingsSection.about:
        return const AboutSettingsPage();
    }
  }

  /// Opens the About page (shortcut for `openSettingsPage(context, SettingsSection.about)`).
  static Future<void> openAbout(BuildContext context) =>
      openSettingsPage(context, SettingsSection.about);

  /// Opens the bookmarks screen (`lib/screens/bookmarks_screen.dart`).
  static Future<void> openBookmarks(BuildContext context) =>
      push<void>(context, BookmarksScreen(tracker: _activeTracker(context)));

  /// Opens the weekly airing calendar (`lib/screens/calendar/calendar_screen.dart`); a Simkl
  /// account gets Simkl's own calendar (`SimklCalendarPage`).
  static Future<void> openCalendar(BuildContext context) =>
      push<void>(
          context,
          switch (_activeTracker(context)) {
            AccountType.simkl => const SimklCalendarPage(),
            AccountType.anilist => const AnilistCalendarPage(),
            AccountType.kitsu => const KitsuCalendarPage(),
            _ => const CalendarScreen(),
          });

  /// The active tracker's own search: AniList's, Simkl's, Kitsu's search page, or the MAL one.
  static Future<void> openTrackerSearch(BuildContext context) async {
    switch (_activeTracker(context)) {
      case AccountType.anilist:
        openAnilistSearch(context);
      case AccountType.simkl:
        await push<void>(context, const SimklSearchAllPage());
      case AccountType.kitsu:
        await push<void>(context, const KitsuExplorePage());
      case _:
        await openSearch(context);
    }
  }

  /// The active tracker; null without an [AccountBloc] (tests) or while loading.
  static AccountType? _activeTracker(BuildContext context) {
    try {
      final state = context.read<AccountBloc>().state;
      return state is AccountLoaded ? state.selectedAccountType : null;
    } catch (_) {
      return null;
    }
  }

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

  /// Opens the chat that holds MyAnimeList message [id] (a message of the sent box with
  /// [sent]). Only the id is known (a notification, a link): the person comes from MAL.
  static Future<void> openMalMessage(BuildContext context,
          {required int id, bool sent = false, int? threadId}) =>
      push<void>(
        context,
        MalChatScreen(counterpart: '', messageId: id, messageSent: sent, messageThreadId: threadId),
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

  /// Shows the user's list: the home shell's My List tab; outside the shell, the list as a page.
  static void openUserList(BuildContext context, Widget page) {
    final shell = HomeShell.maybeOf(context);
    if (shell != null) {
      shell.selectTab(HomeTab.userList);
      return;
    }
    push<void>(
      context,
      Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: page),
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
    // A Simkl show or movie (`simkl:tv:<id>`, `simkl:movie:<id>`) opens its Simkl page.
    final simkl = parseSimklTitlePayload(payload);
    if (simkl != null) {
      await openSimklTitle(context,
          simklId: simkl.simklId, kind: simkl.movie ? SimklKind.movie : SimklKind.tv);
      return;
    }
    final tagged = NotificationPayload.parse(payload);
    if (tagged != null && !tagged.isLegacy) {
      await openTrackerPayload(context, tagged);
      return;
    }
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

  /// How long the home shell takes to show another tracker's app ([TrackerSwitchScreen]
  /// stays 700 ms), plus a margin; a page pushed earlier would close with the old app.
  static const Duration trackerSwitchWait = Duration(milliseconds: 1100);

  /// Opens a tracker-tagged [payload] on its tracker. Owner rule: switching account is switching
  /// app, so a notification of another connected tracker first makes it the active account (its
  /// app shows), then opens that tracker's own page. A tracker that is not signed in stays
  /// inactive and only its pages that need no account open.
  static Future<void> openTrackerPayload(BuildContext context, NotificationPayload payload,
      {bool Function(AccountType tracker)? signedIn, Duration? switchWait}) async {
    final navigator = Navigator.of(context);
    final tracker = payload.tracker;
    final active = _activeTracker(context);
    final connected = (signedIn ?? UserManager.instance.isAuthenticated)(tracker);
    if (active != null && active != tracker && connected) {
      context.read<AccountBloc>().add(ChangeAccountEvent(tracker));
      await Future<void>.delayed(switchWait ?? trackerSwitchWait);
    }
    if (!navigator.mounted) return;
    final ctx = navigator.context;
    final id = payload.intId;
    switch (payload.kind) {
      case PayloadKind.anime || PayloadKind.manga:
        if (id == null) return;
        final manga = payload.kind == PayloadKind.manga;
        switch (tracker) {
          case AccountType.anilist:
            await openAnilistTitle(ctx, category: manga ? 'manga' : 'anime', id: id);
          case AccountType.kitsu:
            await openKitsuTitle(ctx, kind: manga ? KitsuMediaKind.manga : KitsuMediaKind.anime, id: '$id');
          case AccountType.simkl:
            await openSimklTitle(ctx, simklId: id);
          case AccountType.myanimelist || AccountType.none:
            await openContent(ctx, id: id, category: manga ? 'manga' : 'anime');
        }
      case PayloadKind.calendar:
        await openCalendar(ctx);
      case PayloadKind.bookmarks:
        await openBookmarks(ctx);
      case PayloadKind.notifications:
        if (tracker == AccountType.anilist) {
          await openAnilistNotifications(ctx);
        } else if (tracker == AccountType.myanimelist) {
          await MalNotificationsScreen.open(ctx);
        }
      case PayloadKind.hub:
        final link = MalMessageLink.parse(payload.extra);
        if (link != null && link.id != null) {
          await openMalMessage(ctx, id: link.id!, sent: link.sent, threadId: link.threadId);
        } else if (link != null) {
          await openMalMessages(ctx, sent: link.sent);
        } else {
          await MalNotificationsScreen.open(ctx);
        }
      case PayloadKind.message:
        if (id != null) await openMalMessage(ctx, id: id, threadId: payload.intExtra);
      case PayloadKind.messages:
        await openMalMessages(ctx);
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
