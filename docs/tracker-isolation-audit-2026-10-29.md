# Tracker isolation audit (MyWatchList, branch `dev` @ 631fd0c)

Owner rule (2026-10-29): switching the active account (MAL, AniList, Kitsu, Simkl) is like switching to another app.
1. Every screen shows the ACTIVE tracker's own data.
2. Every tracker-related setting is stored per tracker.
3. Exception, notifications: every connected tracker notifies, active or not, as long as its own switch(es) are on.
4. MAL private messages raise a "New message from X" phone notification (chat-app style).

Read-only audit: nothing was modified or run. Line numbers are those of `dev` at 631fd0c.

## 0. Where the active tracker lives (sources of truth)

| Holder | File:line | Notes |
|---|---|---|
| `AccountBloc` / `AccountLoaded.selectedAccountType` | `lib/user/accounts/account_bloc.dart:62`, persisted under `selected_account_type` (`:84`) | Single owner. `_publish` (`:209-218`) mirrors to the next three. |
| `AccountManagerSingleton().selectedAcc` | `lib/user/accounts/provider/account_manager_singleton.dart` | Context-free copy for static API code (`MalApi._get` `mal_api.dart:814`, `_requireMalAccount` `:951`, `list_entry_service.dart:63`, `weekly_data.dart:128`, `backup_settings.dart:164`, `mal_user_page.dart:27`, `anilist_user_page.dart:30`). Also set in `main.dart:114-118`. |
| `AccountManager.instance` | `lib/user/accounts/account_manager.dart:22-60` | Mirror. |
| `UserManager.instance.currentTracker` | `lib/user/user_manager.dart:33-35`, pref `current_tracker` (`:130`) | Listened to by `NotificationService.bindTracker`, `PrefSubtitle` (`pref_widgets.dart:190`), the sidebar. |

The background WorkManager isolate never knows the active tracker (it does not need to under rule 3).

Readers of `selectedAccountType` (all checked): `home_screen.dart:380` (tab set, OK), `homeappbar.dart:143` (bell, leak, see A2), `homeappbar.dart:191` (avatar, OK), `side_bar.dart:185` (see A3), `app_routes.dart:121` (calendar, leak, see A1), `calendar_screen.dart:34` (MAL calendar "list known" only on MAL), `recommendations_section.dart:68` and `reviews_list_screen.dart:194` (MAL write actions hidden off MAL, OK because these are MAL screens), `home_sections.dart:257` (cache signature, OK), `login_page.dart:38,99`, `accounts_panel.dart:64` (OK).

---

## A. Routes and screens

### A1. `AppRoutes` (`lib/utils/app_routes.dart`)

| # | Where | What happens now | What the rule requires |
|---|---|---|---|
| A1.1 | `openCalendar` `:114-115`, `_isSimklActive` `:118-125` | Simkl gets `SimklCalendarPage`; **AniList, Kitsu and MAL all get the MAL `CalendarScreen`** (LiveChart schedule via `MwlApi.getLiveChartSchedule` + MAL seasonal list, `calendar_cubit.dart:15-23`, `airing_schedule.dart:75-76`). On AniList/Kitsu the MAL calendar runs with `listKnown=false` (`calendar_screen.dart:33-34`): no Watching/Plan chips, no list highlight. | Switch on the active tracker: AniList → an AniList calendar (AniList `airingSchedules`), Kitsu → a Kitsu calendar (see section E), Simkl → `SimklCalendarPage`, MAL → `CalendarScreen`. |
| A1.2 | `openSearch` `:131-149` | Always pushes the MAL `GeneralSearchScreen` (no tracker check). Reached by the default search button of `AppBarHome` (A2.1) on Kitsu/Simkl/AniList tabs, by `simkl_user_page.dart:35`, by the startup page "Search" (`home_screen.dart:233`). | Dispatch on the active tracker: AniList → `openAnilistSearch` (`lib/widgets/Anilist/anilist_chips.dart:16`), Kitsu → `KitsuBrowseScreen.search(isAnime:)` (`lib/pages/Kitsu/kitsu_browse_screen.dart:31`), Simkl → a standalone Simkl search (does not exist yet; today search lives only in the Explore tab's `SearchBar`, `simkl_explore_page.dart:161-176,220`), MAL → `GeneralSearchScreen`. MAL-specific callers inside MAL screens (seasonal, detail, explore sections, plainscreen) can keep calling a MAL-only helper. |
| A1.3 | `openBookmarks` `:109-110` | Opens `BookmarksScreen`, which lists every tracker's bookmarks with a tracker filter chip, default "all" (`bookmarks_screen.dart:31,86,105`). In practice only MAL screens can bookmark (`detail_actions.dart:57-68` forces `tracker: myanimelist`; other `BookmarkButton` callers are all MAL screens: `character_screen.dart:471`, `forum_posts_screen.dart:159`, `club_screen.dart:121`, `featured_screen.dart:343`, `interest_stack_detail_screen.dart:200`, `user_profile_view.dart:305`). So on AniList/Kitsu/Simkl the bookmark icon shows **MAL bookmarks** and opens MAL screens (`bookmark_opener.dart:16-41`, opens via `openableId`/`malId` → `AppRoutes.openContent`). | Bookmarks per tracker: the screen opens filtered to the active tracker (no cross-tracker mix), AniList/Kitsu/Simkl media pages get a bookmark button keyed by their own id, `openBookmark` opens the tracker's own page (`AnilistMediaPage`, `KitsuMediaPage`, `SimklMediaPage`). Until then hide the bookmark icon for trackers without bookmarks. |
| A1.4 | `openContent` `:199-204` | Always MAL `ContentDetailedScreen`. Callers outside MAL code: notification taps (`content` payload `anime:<malId>`, `:274-275`), `bookmark_opener.dart:39-41`, `calendar_screen.dart:354`, `deep_links.dart:177`. Kitsu/Simkl/AniList media pages call it only from an explicit "Open on MyAnimeList" menu item (`kitsu_media_page.dart:207`, `simkl_media_page.dart:258`, `anilist_media_page.dart:284`); that is an explicit user choice and can stay. | Notification taps, bookmarks and calendars must open the tracker's own detail page. Payloads must carry the tracker (see A1.5). |
| A1.5 | `openFromNotification` `:269-284`, `NotificationRoute.parse` `:330-356` | Payload formats `anime:<malId>`, `manga:<malId>`, `calendar`, `bookmarks`, `malhub:…` carry **no tracker**. An airing reminder tapped while AniList is active opens the MAL detail; `calendar` opens whatever `openCalendar` picks. AniList inbox taps (`anilist:notifications`) are opened by `NotificationService._openOwn` (`notification_service.dart:223-229`) on top of whatever shell is active; MAL hub taps (`openMalHubPayload`) likewise. | Add the tracker to every payload (e.g. `anilist:anime:<id>`, `kitsu:anime:<id>`, `simkl:anime:<id>`, keep `anime:<id>` = MAL for old alarms). A tap on a notification of tracker T switches the active account to T first (AccountBloc `ChangeAccountEvent`), then opens T's screen: "another app" opens its own UI. |
| A1.6 | `openUserProfile` / `_profileScreen` `:150-195` | Tracker-aware (takes `tracker`). OK. | Keep. Callers passing `tracker: AccountType.myanimelist` are all inside MAL screens (`search_tiles.dart:519,527`, `explore_sections.dart:626`, `friends_section.dart:161`, `user_pop_sheet.dart:122`, `forum_common.dart:39`, `home_sections.dart:345`). OK. |
| A1.7 | `openMalMessages` / `openMalMessage` `:207-230` | MAL only, fine as MAL routes. | Reachable only from MAL UI or a MAL notification tap (which must switch to MAL first, A1.5). |

### A2. Home / tab app bar `AppBarHome` (`lib/widgets/MAL/home/homeappbar.dart`)

| # | Where | Now | Required |
|---|---|---|---|
| A2.1 | search `:121-126` | Default `onSearchTap ?? AppRoutes.openSearch` = MAL search. Tabs that do not override: Kitsu home `kitsu_home_page.dart:117`, Kitsu explore `kitsu_explore_page.dart:104`, Kitsu forum `kitsu_forum_page.dart:52`, Kitsu list `kitsu_user_page.dart:28-34`, Simkl home `simkl_home_page.dart:80`, Simkl explore `simkl_explore_page.dart:215`, Simkl forum `simkl_forum_page.dart:15`, Simkl list `simkl_user_page.dart:29-35` (explicit `AppRoutes.openSearch`), AniList explore `anilist_explore_page.dart:134`. Overridden correctly: AniList home (`anilist_home_page.dart:93`), AniList list (`anilist_user_page.dart:39-46`). | Fix at the source: `AppRoutes.openSearch` dispatches on the tracker (A1.2), and `AppBarHome` keeps the default. Then the explicit Simkl override can go. |
| A2.2 | bookmarks `:127-132` | Always `BookmarksScreen` (MAL bookmarks in practice). Shown on Kitsu home/explore, Simkl home/explore, AniList home/explore. | Per tracker (A1.3), or hidden while the tracker has no bookmarks. |
| A2.3 | calendar `:133-138` | `AppRoutes.openCalendar` → MAL calendar on AniList (home, explore) and Kitsu (home, explore). Simkl OK. | Per tracker (A1.1). |
| A2.4 | bell `:139-146` | `MalBellWithLabel` only when the active account is MAL; nothing otherwise. AniList puts its own `AnilistNotificationBell` inside the home title only (`anilist_home_page.dart:196`), so the AniList explore/list/forum tabs have no bell while MAL has one on every tab. Kitsu and Simkl: no bell. | `AppBarHome` shows the active tracker's bell: MAL → `MalBellWithLabel`, AniList → `AnilistNotificationBell` (and drop the duplicate in `_HomeTitle`), Kitsu → a Kitsu bell once Kitsu notifications exist (C3), Simkl → none (no inbox API). |
| A2.5 | settings `:147-152` | Opens the shared settings hub. | Settings hub must show the active tracker's scoped settings (section B). |

### A3. Sidebar (`lib/pages/side_bar.dart`)

| # | Where | Now | Required |
|---|---|---|---|
| A3.1 | Bookmarks `:219-223` | `AppRoutes.openBookmarks` → all/MAL bookmarks. | Active tracker's bookmarks (A1.3). |
| A3.2 | Calendar `:224-228` | `AppRoutes.openCalendar` → MAL calendar for AniList/Kitsu. | Per tracker (A1.1). |
| A3.3 | MAL notifications + messages `:229-240` | Shown only for MAL (correct). AniList has no "Notifications" entry (its inbox `openAnilistNotifications`, `pages/Anilist/anilist_notifications_page.dart`, is reachable only from the AniList home bell). | Add per tracker entries: AniList → Notifications (inbox, with unread count `AnilistUnreadCount`); Kitsu → Notifications once built. |
| A3.4 | Header background `:42-87` (`sidebar_bg_image_path_v1`, `utils/sidebar_bg_manager.dart:27`) | One picture for all trackers. | Owner decision: per tracker if "another app" includes looks (cheap: key by tracker). |
| A3.5 | Profile entries `:201-218` | MAL: six DailyAL shortcuts; others: one Profile entry. | OK. |

### A4. Home shell (`lib/screens/home_screen.dart`)

| # | Where | Now | Required |
|---|---|---|---|
| A4.1 | `_createTab` `:449-482` | Per tracker tab set. OK. | Keep. |
| A4.2 | startup page `:220-234`, `_tabForStartup` `:271-286` | `Preferences.general.startupPage` is global (`general_preferences.dart:29`). "Calendar" startup opens `openCalendar` (MAL calendar on AniList/Kitsu); "Search" opens MAL search. | Startup page per tracker (B), and the routes per tracker (A1). Read the active tracker's value when the shell builds for a tracker (not only in `initState`), so a switch applies that tracker's startup tab. |
| A4.3 | `keepPagesInMemory` `:394-399` | Global. | App behaviour, can stay global. |

### A5. Other screens / entry points

| # | Where | Now | Required |
|---|---|---|---|
| A5.1 | Calendar screen `lib/screens/calendar/calendar_screen.dart` | MAL-only data (see A1.1). Rows open MAL detail `:354`. | Stays the MAL calendar; other trackers get their own pages. |
| A5.2 | Deep links `lib/utils/deep_links.dart:117-200`, manifest `android/app/src/main/AndroidManifest.xml:124-127` | Only `myanimelist.net` hosts are claimed; any MAL link opens a MAL screen whatever the active tracker. `anilist.co` / `kitsu.app` / `simkl.com` links from outside the app are not handled (AniList links inside AniList content are handled by `widgets/Anilist/social/anilist_links.dart`). | Owner decision. Consistent with "another app": a MAL link opens MAL (switching to MAL if connected); optionally claim `anilist.co`, `kitsu.app`, `simkl.com` and route them to their tracker. Today no leak of data, only a routing gap. |
| A5.3 | Shared MAL-only gates (`mal_api.dart:814,951`, `list_entry_service.dart:63`, `weekly_data.dart:128`, `backup_settings.dart:164`, `recommendations_section.dart:68`, `reviews_list_screen.dart:194`) | MAL screens degrade when another tracker is active. | Fine once no non-MAL entry point opens MAL screens (A1.3, A1.4, A1.5). |
| A5.4 | Settings `PrefSubtitle.malOnly` note (`pref_widgets.dart:175-215`, used in `anime_manga_settings.dart:75,124,134`, `user_prefs_settings.dart:126,170,178,186`) | Shows "MAL only" under options when another tracker is active; the value itself is shared. | Becomes "this tracker's value" once settings are per tracker (B); the note stays for options a tracker cannot honour. |

---

## B. Settings per tracker

### B1. Inventory of preference stores read by tracker screens

All four `PreferencesStore` groups are **single global JSON blobs**: `prefs_general_v1`, `prefs_content_v1`, `prefs_list_v1`, `prefs_notifications_v1` (`lib/user/preferences/preferences_store.dart:17-20`). Home layout is one global key `mal_home_preferences` (`lib/user/MAL/mal_home_page_preferences.dart:390,402`).

| Store / key | Field | Read by (tracker screens) | Must become per tracker? |
|---|---|---|---|
| `mal_home_preferences` (`MalHomePreferences`, `HomePreferencesBloc` created once in `main.dart:148`) | `sections`, `tileSize` | MAL home `mal_home_page.dart:64,115`, AniList home `anilist_home_page.dart:103-117` (`AnilistHomePlan.of`), Kitsu home `kitsu_home_page.dart:96-102`, Simkl home `simkl_home_page.dart:82-92` (`simklHomePlan`), plus `search_home_view.dart:260`, `home_showcase.dart:97`, `relatedanimewidget.dart:85`, `recommanimewidget.dart:20` (tile size). Edited by `screens/settings/mal_home_settings.dart` (`HomeSettingsPage`). **Changing the AniList home layout changes MAL's** (the owner's own example). | **Yes** (sections + tile size). |
| `prefs_list_v1` | `defaultCategory`, `defaultAnimeTab`, `defaultMangaTab` | `user_list_view.dart:109` (MAL, Kitsu `kitsu_user_page.dart:44`, Simkl `simkl_user_page.dart:46`), `anilist_list_view.dart:101` | **Yes** |
| `prefs_list_v1` | `cardProfiles` (card layout) | `user_list_view.dart:232-233`, `anilist_list_view.dart:322-323`, `card_layout_editor.dart`, `list_sort_filter.dart`, `card_profiles_section.dart` | **Yes** |
| `prefs_general_v1` | `defaultDisplayType`, `userListAnimeSort`, `userListMangaSort` | fallback of `ListViewStore.defaults` (`list_view_store.dart:58-75`); `weekly_data.dart` | **Yes** (the saved per-list state itself is already per tracker: `user_list_view_v1:<tracker>:<category>`, `user_list_place_v1:<tracker>`, `list_view_store.dart:53-55`) |
| `prefs_general_v1` | `preferredTitle` (title language) | MAL detail/lists, AniList services (`anilist_discover_service.dart:686`, `anilist_feeds_service.dart`, `anilist_profile_service.dart`), Kitsu (`kitsu_library.dart`, `kitsu_catalog.dart`), `home_showcase.dart` | **Yes** |
| `prefs_general_v1` | `nsfw` | MAL (`mal_api.dart`, `mal_anime.dart`, search, explore, `animegridcard.dart`), AniList (`anilist_discover_service.dart:688` `_appAdult`), Kitsu (`kitsu_graphql.dart`, `kitsu_feed_parts.dart`) | **Yes** |
| `prefs_general_v1` | `startupPage` | `home_screen.dart:220` | **Yes** (default tab) |
| `prefs_general_v1` | `showPriority`, `showAiringInfo`, `showAnimeMangaCard`, `autoAddStartEndDate` | list cards (`entry_cards.dart`, `entry_parts.dart`), editors (`contenteditwidget.dart`, `mal_user_list_adapter.dart`, `kitsu_user_list_adapter.dart`) | **Yes** |
| `prefs_general_v1` | `detailsExpanded` | `user_profile_view.dart` (MAL profile) | Yes (MAL scope) |
| `prefs_general_v1` | `statsChartColors` | stats of all four profiles (`stats_section.dart`, `profile_stats.dart`, `kitsu_profile_view.dart`, `simkl_profile_view.dart`) | Optional (visual); per tracker if "another app" covers looks |
| `prefs_general_v1` | `autoTranslateSynopsis`, `preferredLinkType`, `allowYoutubePlayer`, `showOnlyLastQuote` | MAL detail widgets | Yes (MAL scope; other trackers get their own copy when they use it) |
| `prefs_general_v1` | `showDubStatus`, `dubLanguage`, `dubIconStyle`, `dubMinSourceCount` | `cache/dub_info.dart` (keyed by MAL id) | Yes if dub badges appear on other trackers; else MAL scope |
| `prefs_general_v1` | `keepPagesInMemory` | `home_screen.dart:394` | No (app behaviour) |
| `prefs_content_v1` | `animeTabs`, `mangaTabs` (detail tabs) | MAL detail only (`detail_sections.dart`, `tabs_customizer.dart`, `detail_tabs_editor.dart`) | **Yes** (MAL scope now; AniList/Kitsu/Simkl media pages get their own when made customisable) |
| `prefs_content_v1` | `showCountdownOnDetail`, `showDetailBackground`, `showPrivateNotes`, `hideScore`, `defaultAnimeAddStatus`, `defaultMangaAddStatus`, `globalSeasonalFilter` | MAL detail/editor/seasonal | **Yes** (each tracker's detail/editor has its own value) |
| `prefs_content_v1` | `timezone` | calendars (MAL, Simkl `simkl_media_format.dart`), cards, profiles | No (device-level); owner may decide otherwise |
| `prefs_notifications_v1` | `subscribedAt` (master, `notification_preferences.dart:30`), `watchingList`, `planToWatchList`, `dailyReleases`, `largeImage` | airing planner (`notification_planner.dart`), settings, every poller's "master" gate | **Yes**: airing switches per tracker; see C |
| `mal_hub_push_v1`, `mal_friends_push_v1`, `mal_pm_push_v1` (`mal_hub_poller.dart:268-269,551`), `anilist_push_v1` (`notification_service.dart:789`) | tracker notification switches | pollers | Already per tracker (by name) |
| `bookmarks_v1` (`cache/bookmarks.dart:106`) | bookmarks | `BookmarksScreen` | Items are tracker-tagged; the screen must filter (A1.3) |
| `search_query_history`, `search_recent_anime/manga`, `search_display_type`, `search_grid_*` (`screens/search/search_history.dart:11-17`) | MAL search history/layout | `GeneralSearchScreen` | MAL scope (fine once other trackers stop opening MAL search) |
| `weekly_view_v1`, `seasonal_group_v1` | MAL screens | MAL only | MAL scope, fine |
| `anilist_search_layout_v1`, `anilist_catalog_v1` | AniList only | AniList only | Already scoped |
| `list_status_cache_v1:<tracker>:<category>`, home section caches (`HomeUserListSection.cacheKeyFor`, `home_sections.dart:247-252`) | caches | | Already per tracker |
| `sidebar_bg_image_path_v1`, theme keys (`theme_bloc.dart:23-36`), `language_code` | looks | | No by default; owner decision for sidebar/theme |
| `cross_tracker_enabled` (`user/user_preference.dart:18`) | sync between trackers | | No (cross-tracker by nature) |
| `notifications_feed_tracker_v1` (`notification_service.dart:145`) | "which tracker fed the reminders" | | Remove when all trackers feed (C) |

### B2. Settings pages that edit these values

`screens/settings/mal_home_settings.dart` (home layout), `user_prefs_settings.dart` (general: title, nsfw, startup, lists, stats colours), `list_prefs_settings.dart` (default category/tabs), `prefs/card_profiles_section.dart` + `widgets/user/list/card_layout_editor.dart` (card layout), `anime_manga_settings.dart` + `prefs/detail_tabs_editor.dart` (content/detail tabs), `dub_settings.dart`, `notifications_settings.dart`. None knows which tracker it edits; the settings hub (`settings_page.dart`, `pages/settings/settings_section.dart`) is global.

Required: tracker-scoped pages edit the **active** tracker's copy and say so in the page header ("Settings for AniList"); app-scoped pages (theme, language, downloads, backup, storage, about, accounts) stay global.

### B3. Suggested mechanism (keeps readers untouched)

- Split each group into app-scoped fields and tracker-scoped fields. Store tracker-scoped values under `prefs_<group>_v2:<tracker>`; migration copies the current global blob into all four trackers once (nobody loses their settings).
- `PreferencesBloc` follows `UserManager.instance` (current tracker) and swaps the tracker-scoped part of its state on a switch; `Preferences.general.nsfw` etc. keep returning the active tracker's value, so the ~40 readers listed above need no change.
- `HomePreferencesBloc` does the same (load `home_preferences_v2:<tracker>` on switch; migrate `mal_home_preferences` into all four).
- Background isolate: `PreferencesStore(prefs).read()` is used by the workers (`main.dart:375,400`); it must take an explicit tracker (`readFor(tracker)`) because the worker has no active tracker.

---

## C. Notifications

### C1. What runs today

**Airing reminders (local alarms)** — `lib/services/notifications/notification_service.dart`, planner `notification_planner.dart`:
- Scheduled with exact alarms from the app process only: at start (`refreshIfDue`, once a day, `main.dart:193`), on preference changes (`bindPreferences` `:264-273`), when the feeding tracker changes (`bindTracker` `:279-306`). No background refresh: if the app is not opened, alarms run out after the projected 3 weeks (`notification_planner.dart:14`).
- **One tracker only**: `candidateTracker` (`:549-560`) = the active tracker if it is AniList/Kitsu/Simkl and connected, else MAL. `_loadMalCandidates` (`:568-602`) loads that one tracker's Watching/Plan to watch. A user active on AniList with MAL connected gets **no MAL reminders**, and switching tracker cancels all alarms and replans from the new one (`_run` `:406` `cancelAll`).
- Schedule source is LiveChart via `AiringSchedule` keyed by MAL id (`:542-545`, `airing_schedule.dart:75-76,115`); AniList/Kitsu/Simkl entries without a MAL id are dropped (`anilist_list_service.dart:565`, `kitsu_library.dart:181`, `simkl_list_service.dart:503`). AniList's own exact `airingSchedules`/`nextAiringEpisode` and Simkl's calendar file are not used.
- Payload `anime:<malId>` (`notification_planner.dart:46`) → MAL detail on tap whatever the tracker (A1.5).
- Switches: master "Airing reminders" (`subscribedAt`, default **off**, `notification_preferences.dart:23,30`), Watching, Plan to watch, Large image (`notifications_settings.dart:117-152`). Global, not per tracker.

**WorkManager job** — `main.dart:342-510`:
- One periodic job `com.teen.mywatchlist.mal_hub_poll`, every 30 min (`:346`), constraints network + battery not low (`:445`), policy `keep`.
- Callback (`:349-357`) runs `runMalHubWorker` (`:362-384`: MAL hub + friends + PMs via `MalHubMessagesPoller`) then `runAnilistWorker` (`:390-414`: `AnilistBackgroundNotifier.poll`, AniList inbox).
- Registered only while `MalBackgroundPolling._defaultWanted` (`:472-478`): **master airing switch on** AND (MAL signed in with hub/friends/PM switch on, OR AniList `wanted` = master on + signed in + `anilist_push_v1`).
- No Kitsu and no Simkl round; no airing-reminder refresh in the background.

**Foreground polling**:
- `MalHubPoller` (`mal_hub_poller.dart:238-526`) started by `NotificationService.init` (`notification_service.dart:203`), first round 5 s after start, then every 30 min only while resumed (`:346-377`); friends every 3 h; PMs piggyback on every round (`MalHubMessagesPoller.poll` `:667-670`).
- AniList: no foreground system-notification poll (the bell's `AnilistUnreadCount` only updates the badge); system notifications come from the WorkManager round only.

**Who notifies when not active**: MAL hub/friends/PM and AniList inbox do not look at the active tracker (they check `isAuthenticated(tracker)` only: `mal_hub_poller.dart:257-258,545`, `notification_service.dart:778`). So rule 3 already holds for those **only when the airing master switch is on**. Airing reminders violate rule 3 (active tracker only). Kitsu and Simkl notify nothing except airing reminders while active.

### C2. Settings > Notifications today (`lib/screens/settings/notifications_settings.dart`)

| Group | Switches | Gate |
|---|---|---|
| Master card `:117,304-344` | "Airing reminders" (`subscribedAt`) | requests POST_NOTIFICATIONS only when turned on (`:69-83`) |
| Notify `:120-137` | Watching list, Plan to watch | global |
| MAL `_MalHubGroup` `:193-243` | Hub notifications, Friends' activity, Private messages | shown only if MAL signed in (`:198-199`); **disabled while master is off** (`:212,222,232`) |
| AniList `_AnilistGroup` `:245-271` | "AniList notifications" push | shown only if AniList signed in; **disabled while master is off** (`:262`) |
| Look `:141-151` | Large image | global |
| Status `_Status` `:346-417` | "Needs account" notice uses `candidateTracker(currentTracker)` (`:360`) | single-tracker logic |

No Kitsu group, no Simkl group, no per-tracker airing switch.

### C3. What is missing for rule 3

1. **Master switch semantics**: the airing master gates every tracker's inbox/PM notifications (`mal_hub_poller.dart:403,431,454,544,649`, `notification_service.dart:808`, `main.dart:474`). Rule 3 wants per tracker switches. Proposal: a global "allow notifications" (permission + kill switch, default on once permission granted) and, per tracker, its own switches; airing reminders become one switch per tracker.
2. **Airing reminders for every connected tracker**: union of the candidates of all connected trackers whose airing switch is on, deduplicated by anime (same MAL id or same anime across trackers → one alarm, tap opens it on the tracker that owns the entry, preferring the active one). Use each tracker's best schedule source: AniList `airingSchedules`/`nextAiringEpisode` (exact, no MAL id needed), Simkl calendar file, LiveChart for MAL and Kitsu (by MAL id) or Kitsu `nextRelease`. Drop `candidateTracker`, `feedKey`, the replan-on-switch.
3. **Background refresh of the reminders**: add an airing replan to the WorkManager round (daily), so alarms keep coming without opening the app; today only the app process plans.
4. **AniList**: already polled when not active (inbox: AIRING, RELATED_MEDIA_ADDITION, activity, messages, follows... per the AniList account's notification options, `widgets/Anilist/settings/notification_types_sheet.dart`). Missing: independence from the airing master; a foreground round; dedupe between AniList's own AIRING inbox items and local airing alarms (user picks one, or the planner skips AniList entries when AniList AIRING notifications are on). Tap must switch to AniList (A1.5).
5. **Kitsu**: no notifications at all except airing reminders while active. Kitsu has no airing schedule endpoint; options: (a) airing reminders from the Kitsu library mapped to MAL ids + LiveChart (exists: `KitsuLibrary.airingCandidates`, `kitsu_library.dart:173`) and/or `Anime.nextRelease` (GraphQL, already parsed `kitsu_graphql.dart:623,739`); (b) Kitsu's notifications feed (`/api/edge/feeds/notifications/<userId>`, JSON:API activity groups) is not implemented in the codebase; a fix unit must verify which verbs it carries (follows, comments, likes, mentions, possibly episode "aired" items) before promising it. Needs a Kitsu group in settings and a Kitsu round in the worker.
6. **Simkl**: no inbox/notification API. Only airing: Simkl calendar file `https://data.simkl.in/calendar/v2/anime.json` (`simkl_cdn.dart:25-31,94-96`, rolling 33-day window, Simkl ids) joined with the user's list (`SimklListService.anime()`, `simkl_list_service.dart:499-515`). Needs a Simkl group (airing switch) in settings and use in the planner/worker; today only via MAL-id mapping while Simkl is active.
7. **MAL airing**: works only while MAL is the feeding tracker (active, or fallback). MAL hub `onAir` items (`mal_hub_texts.dart:43-45`) and `relatedAnimeAdd` (`:37-42`) already come through the hub poller; airing alarms must also run when MAL is not active.
8. **Background job registration** must become "any connected tracker has any switch on" (`main.dart:472-478`) and run one round per tracker (MAL, AniList, Kitsu, Simkl), each never throwing.

---

## D. MAL private messages (rule 4)

### D1. What exists

- `MalMessagesWatcher` (`lib/services/notifications/mal_hub_poller.dart:534-622`): reads the first page of the MAL inbox through the **website** (`MalMessagesApi.inbox`, `services/api/MAL/web/mal_messages_api.dart:628`, scraping `mymessages.php` with the MAL website cookies of `MalWebSession`, `services/auth/mal_web_session.dart:107-160`). New unread ids not in `mal_pm_seen_v1` → `HubSystemNotification` titled `Mhw_Message_From` = "{sender} sent you a message", body = subject, payload `MalHubPayload.message` → opens the thread in-app (`app_routes.dart:280-281`). Switch `mal_pm_push_v1` (default on).
- `MalHubMessagesPoller` (`:626-671`): calls `watcher.check()` after every hub round.
- Foreground: `MalHubPoller.start` (`:313-325`): first round 5 s after app start, then every **30 min**, only while the app is resumed; on resume, polls only if 30 min passed since the last poll (`:372-377`).
- Background: WorkManager job every **30 min** (`main.dart:346,349-357,362-384`), network + battery-not-low constraints.

### D2. When a phone notification is raised today

All of these must hold (`_check`, `mal_hub_poller.dart:585-621`):
1. MAL OAuth account signed in (`_canRead`, `:545`).
2. A MAL **website session** exists and is valid (`_requireSession`, `mal_messages_api.dart:606-609`): otherwise `MalWebNoSession`/expired is thrown and swallowed (`:617-619`): silent, no notification, no hint in Settings > Notifications.
3. A previous successful check exists (`stored == null` → the first look only records, `:594-599`).
4. The message is unread on MAL and its id was not seen in a previous check (`:600-603`).
5. `push.value` (PM switch) on, AND `_mayNotify()` = **the airing master switch on** (`Preferences.current.notifications.enabled`, `:544`; worker `:649`), AND the system allows notifications (`:604`).
6. A round actually runs: app in foreground at a 30-min tick, or the WorkManager job runs. The job is registered only if the **airing master switch is on** (`main.dart:474`).
Then it shows it in the **"MAL hub" channel** (`MalHubChannel.hub`, `:615`) with default importance (`PluginMalHubNotifier.show` `:180-197`, no `importance:` → `Importance.defaultImportance`: no heads-up pop-up), grouped with hub items; when 2+ arrive together the summary's payload is `malhub:` (opens the hub screen, not messages, `:199-220`).

### D3. Why the owner may never see one

1. **Gated by "Airing reminders"**: the master card is labelled "Airing reminders" (`Notif_Master_Title`) and defaults to off (`subscribedAt == null`). With it off: the PM switch is greyed out (`notifications_settings.dart:232`), `_mayNotify` is false, and the WorkManager job is never registered (`main.dart:472-478`). On Android 13 (the test phone) the POST_NOTIFICATIONS permission is only requested when that master switch is turned on (`notifications_settings.dart:75`), so the app may not even hold the permission.
2. **Website session missing or expired**: PMs need the MAL website cookies (captured from the login WebView), separate from the OAuth token; any failure is swallowed silently.
3. **Latency**: 30 min at best in foreground; in background WorkManager periodic work is batched by Doze, needs battery-not-low, and MIUI (Xiaomi 21061119BI) commonly defers or kills background jobs unless Autostart / "No restrictions" battery mode are set. Not chat-app speed.
4. **Silent presentation**: default-importance channel shared with hub items: it lands silently in the shade, no pop-up; if the user muted "MAL hub" in Android settings, PMs are muted too. No `MessagingStyle`, no sender avatar, no per-conversation grouping.
5. **First run swallows**: messages already unread at the first successful check are never announced.
6. Notifications are never cancelled when the message is read (no cancel path for the `0x60000000 | id` ids, `:609`).

### D4. What rule 4 needs

- Decouple PMs from the airing master (own switch, default on, permission request from the MAL group or onboarding).
- Dedicated channel `mal_messages`, `Importance.high` (heads-up), `MessagingStyle` with the sender as `Person` (avatar from `MalUserPictures`), title "New message from X", one notification per conversation (thread id), tap opens the thread (payload already does).
- Faster foreground polling of the inbox only (e.g. 2-5 min while resumed, a cheap single request) separate from the hub's 30 min; background stays at WorkManager's 15-min minimum (no constraint `requiresBatteryNotLow` for this one), documented MIUI limits.
- Visible state in Settings when the website session is missing/expired, with a "Reconnect" action.
- Cancel the system notification once the thread is read (in-app or seen read on MAL at the next check).

---

## E. Calendar / airing data sources per tracker

| Tracker | Source in the codebase | Notes |
|---|---|---|
| MAL | LiveChart schedule via `MwlApi.i.getLiveChartSchedule` (`airing_schedule.dart:75-76`, keyed by MAL id) + MAL seasonal list with `my_list_status` (`calendar_cubit.dart:15-23`); weekly `broadcast` slot fallback (`notification_planner.dart:9-10`). MAL hub `onAir` notifications. | Current `CalendarScreen`. |
| AniList | `Page.airingSchedules(airingAt_greater, airingAt_lesser, sort: TIME)`: `AnilistDiscoverService.airing(from, to, page, perPage)` (`services/api/Anilist/anilist_discover_service.dart:946-980`, returns `AnilistAiring` with media, episode, UTC time, adult filtered), `AnilistFeedsService` airing rows (`anilist_feeds_service.dart:90-92,343`), legacy `AnilistApi.getAiringSchedule` (`anilist_api.dart:279-339`, unused). Per media: `nextAiringEpisode` (`anilist_media.dart:90,120`), `airingSchedule(notYetAired)` (`anilist_media_detail.dart:630-631`). User list status: `AnilistListService.all('anime')`. Inbox AIRING notifications. | Build an AniList calendar page on `airing()` paged over 7 days (filter "my list" with the list service). |
| Kitsu | No airing schedule endpoint. `Anime.nextRelease` (GraphQL, `kitsu_graphql.dart:623,739,1450`; shown on the media page `kitsu_media_page.dart:275,536`, `kitsu_library_box.dart:375`), library `releaseState` and MAL mapping (`kitsu_library.dart:173-200`). | Kitsu calendar = the user's Watching/Plan entries with `nextRelease` (GraphQL library query adding `nextRelease`), optionally enriched by LiveChart through MAL ids. Kitsu notifications feed: not implemented, verify the API first. |
| Simkl | Calendar file `data.simkl.in/calendar/v2/anime.json` (`simkl_cdn.dart:25-31,92-100`, 33-day window, `finale_type`), `SimklCalendarPage` (`widgets/Simkl/calendar/simkl_calendar.dart:197`) joined with the list (`simklAiringOn`). | Already a page; reuse for reminders. No notification API. |

---

## F. Proposed implementation units (disjoint file sets)

Order: U5 and U4 first (APIs others read), then U1, U2, U3, U8, U9 in parallel; U6 then U7 (U7 depends on U6's master rework only through `main.dart`, which U6 owns).

| Unit | Scope | Files it owns (nobody else edits them) |
|---|---|---|
| **U1 `tracker-routes`** | Tracker dispatch for `openCalendar`, `openSearch`, `openBookmarks`; tracker-tagged `NotificationRoute` (+ legacy `anime:<id>` = MAL); a tap switches the active account first; `AppBarHome` bell/search/bookmarks/calendar per tracker (AniList bell on every AniList tab, removed from `_HomeTitle`); sidebar entries per tracker (AniList notifications entry); startup page read per tracker when the shell builds. Consumes the screens of U2, U3, U9 by name (stub to the existing MAL screen until they land, or land after them). | `lib/utils/app_routes.dart`, `lib/widgets/MAL/home/homeappbar.dart`, `lib/pages/side_bar.dart`, `lib/screens/home_screen.dart`, `lib/pages/Anilist/anilist_home_page.dart` (bell only), `lib/pages/Simkl/simkl_user_page.dart` (drop the explicit MAL search) |
| **U2 `anilist-calendar`** | AniList weekly calendar page on `AnilistDiscoverService.airing` (7 days, paged, "in my list" filter, time zone pref, rows open `AnilistMediaPage`). | new `lib/widgets/Anilist/calendar/**`; `lib/services/api/Anilist/anilist_discover_service.dart` only if paging needs a change; own l10n fragment |
| **U3 `kitsu-calendar`** | Kitsu calendar from the library (Watching/Plan) + `nextRelease`, optional LiveChart enrichment by MAL id; rows open `KitsuMediaPage`. | new `lib/widgets/Kitsu/calendar/**`; `lib/services/api/Kitsu/kitsu_library.dart` (query with `nextRelease`); own l10n fragment |
| **U9 `simkl-search`** | Standalone Simkl search screen (reuse the Explore search logic) so `openSearch` has a Simkl target. | new `lib/widgets/Simkl/search/**`; `lib/pages/Simkl/simkl_explore_page.dart` (extract shared search widget) |
| **U4 `home-layout-per-tracker`** | `HomePreferencesBloc` follows `UserManager.currentTracker`, stores `home_preferences_v2:<tracker>`, migrates `mal_home_preferences` into the four; home settings page edits the active tracker's layout and names it (sections offered = those the tracker can fill). Home pages untouched (they keep reading `state.preferences`). | `lib/user/MAL/mal_home_page_preferences.dart`, `lib/user/MAL/mal_home_preferences_bloc.dart`, `lib/screens/settings/mal_home_settings.dart` |
| **U5 `prefs-per-tracker`** | Split general/content/list groups into app vs tracker scope; per-tracker storage + one-time migration; `PreferencesBloc` swaps scope on tracker change; `PreferencesStore.readFor(tracker)` for isolates; tracker-scoped settings pages show "Settings for <tracker>"; `PrefSubtitle` note kept for options a tracker cannot honour. Excludes `notification_preferences.dart`. | `lib/user/preferences/**` except `notification_preferences.dart`; `lib/screens/settings/user_prefs_settings.dart`, `list_prefs_settings.dart`, `anime_manga_settings.dart`, `dub_settings.dart`, `lib/screens/settings/prefs/**`, `lib/widgets/user/list/card_layout_editor.dart`, `lib/screens/settings/settings_page.dart` |
| **U8 `bookmarks-per-tracker`** | Bookmarks screen opens on the active tracker only; bookmark buttons on AniList/Kitsu/Simkl media (and character/staff where they exist) pages keyed by their own ids; `openBookmark` opens the tracker's own page. | `lib/screens/bookmarks_screen.dart`, `lib/widgets/bookmarks/**`, `lib/cache/bookmarks.dart`, `lib/pages/Anilist/anilist_media_page.dart`, `lib/pages/Kitsu/kitsu_media_page.dart`, `lib/pages/Simkl/simkl_media_page.dart` (button only) |
| **U6 `notifications-all-trackers`** | New notification policy: global "allow notifications" (permission + kill switch) separate from airing; per-tracker airing switches; planner fed by every connected tracker (dedupe by anime, tracker-tagged payloads per U1's format), AniList via `airingSchedules`, Simkl via its calendar file, MAL/Kitsu via LiveChart; drop `candidateTracker`/`feedKey`/replan-on-switch; WorkManager round per tracker (MAL hub, AniList inbox, Kitsu, Simkl airing replan) and `wanted` = any tracker with any switch on; Settings > Notifications with one group per connected tracker (MAL, AniList, Kitsu, Simkl). Kitsu inbox only after verifying the API (else document it). | `lib/services/notifications/**` except `mal_hub_poller.dart`; `lib/main.dart` (worker + `MalBackgroundPolling`); `lib/screens/settings/notifications_settings.dart`; `lib/user/preferences/notification_preferences.dart`; `lib/services/api/Anilist/anilist_list_service.dart`, `lib/services/api/SimKl/simkl_list_service.dart` (candidate loaders only) |
| **U7 `mal-pm-chat-notifications`** | PM path independent of the airing master (its own switch only + system permission); `mal_messages` high-importance channel, `MessagingStyle`, sender avatar, one notification per thread, cancel on read; fast foreground inbox poll (2-5 min while resumed); session-missing/expired state exposed (a `ValueNotifier`) for U6's settings group to display. Coordinates with U6 through two names: `MalMessagesWatcher.instance.push` and the new session-state notifier. | `lib/services/notifications/mal_hub_poller.dart`, `lib/widgets/mal_web/message_tiles.dart`, `lib/screens/mal_web/message_thread_screen.dart` (cancel on read) |

Cross-unit contracts to fix before the wave: the tracker-tagged payload format (U1 parses, U6 and U7 write), `PreferencesStore.readFor(tracker)` (U5 provides, U6 uses in the worker), and the global "allow notifications" getter (U6 provides, U7 reads).
