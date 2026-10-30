#!/usr/bin/env node
/*
 * _generate-units.mjs — single source of the DailyAL → MyWatchList port queue.
 *
 * Edit the UNITS array below, then run `node work/_generate-units.mjs`. It writes:
 *   work/INDEX.md            (only its Status column is hand-edited; it is read back here)
 *   work/handoffs/<id>.md    (one spec per unit, given to the builder)
 *   work/START-PROMPTS.md    (one start block per unit)
 *   work/units.json          (machine view read by tools/mab/)
 * Never hand-edit the generated files except the INDEX Status column. Idempotent.
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = dirname(fileURLToPath(import.meta.url));
const DAL = "/home/thinkpad/.cache/mwl-mab/dailyal-108";

const GROUPS = [
  { id: "foundation", title: "Foundation and shared shapes", priority: "P0" },
  { id: "detail", title: "Anime/manga detail screen", priority: "P1" },
  { id: "user", title: "User list, profile and edit", priority: "P0" },
  { id: "discovery", title: "Home, explore, search, calendar", priority: "P1" },
  { id: "settings", title: "Settings, notifications, prefs", priority: "P1" },
  { id: "community", title: "Forum, clubs, featured, characters", priority: "P2" },
  { id: "trackers", title: "Other trackers (AniList, Kitsu, Simkl)", priority: "P2" },
  { id: "release", title: "Versioning, CI, update, platform", priority: "P2" },
];

/* model: opus | sonnet | haiku. ui: true → the UI directive applies (compare DAL vs MWL, keep the better, improve). */
const UNITS = [
  // ───────────────────────────── Foundation ─────────────────────────────
  {
    id: "gate-fix", title: "Make the merge gate meaningful", kind: "foundation", priority: "P0", group: "foundation", model: "opus",
    needs: [],
    owns: ["test/widget_test.dart", "test/flutter_test_config.dart", "test/smoke/**", "test/helpers/**", "android/app/src/main/AndroidManifest.xml"],
    goal: [
      "Set the test layout: `test/smoke/` (yours), `test/helpers/` (shared fakes, yours), `test/units/<unit-id>/` (one folder per later unit). Replace the default Flutter counter test `test/widget_test.dart` (it fails on `dev`) with real, fast smoke tests: pure-Dart tests of enums/parsers/helpers that need no network, and at least one widget test that pumps a small MWL widget. No test may hit the network.",
      "Add `<uses-permission android:name=\"android.permission.INTERNET\"/>` to the MAIN manifest (today it is only in the debug manifest, so a release APK has no network).",
    ],
    bugs: ["test/widget_test.dart pumps a counter app that does not exist → `flutter test` red on dev.", "INTERNET permission missing from android/app/src/main/AndroidManifest.xml."],
    dod: ["`tools/heavy.sh tools/verify.sh` exits 0 on the branch.", "Tests run in under 30 s alone."],
  },
  {
    id: "auth-refresh", title: "Token refresh and retry for all trackers", kind: "unit", priority: "P0", group: "foundation", model: "sonnet",
    needs: ["gate-fix"],
    owns: ["lib/user/base_user.dart", "lib/user/user_manager.dart", "lib/user/user_mal_v2.dart", "lib/user/user_anilist_v2.dart", "lib/user/user_kitsu_v2.dart", "lib/user/user_simkl_v2.dart", "lib/services/auth/**", "lib/services/api/MAL/mal_connect.dart"],
    dal: ["lib/api/auth/auth.dart", "lib/api/malconnect.dart"],
    goal: [
      "Refresh tokens before expiry and on HTTP 401 for MAL, AniList and Kitsu (Simkl has no refresh token: on 401, mark the account as needing re-login).",
      "Make every authenticated MAL request go through the refreshing path (today `makeAuthenticatedRequest` / `refreshCurrentToken` in base_user.dart are never called and only Kitsu checks expiry).",
      "Retry transient network errors with backoff (DAL: RetryOptions, 8 attempts). Never retry 4xx except 401-after-refresh once.",
    ],
    bugs: ["MAL token (~31 days) expires silently: no 401 handling anywhere in lib/services."],
    dod: ["Unit tests (in test/units/auth-refresh/) cover: expired token refreshed before call, 401 → refresh → retry once, refresh failure → logged-out state."],
  },
  {
    id: "backend-parsers", title: "mwl-api: port DAL's missing routes and HTML parsers", kind: "shared", priority: "P1", group: "foundation", model: "opus",
    needs: ["gate-fix"],
    owns: ["mwl-api/**", "mwl-rust-api/**", "lib/services/api/mwl_api.dart"],
    dal: ["dal-api/", "dal-api/dal_commons/ (or wherever dal_commons lives)", "dal-rust-api/"],
    goal: [
      "Port into mwl-api / mwl_commons the parsers DAL has and MWL lacks: parseCharacterAllPage, parseCharacterPage, parseCharacterPeopleHome, parseMagazines, parseClubPage/_getClubDetails, parseClubPageViewAll, parseLiveChartSchedule, parseUserAboutPage, allSearchResultFromHtml, forumHtmlFromHtml, animeReviewHtmlfromHtml.",
      "Add the routes: `content/characters`, `character/*id/pics`, `people/*id/pics`, `characters` and `people` (top lists), `magazines`, `studios`, `clubs/type`; give `reviews` and `users/about` real parsers instead of raw text.",
      "Parse large JSON/HTML off the UI isolate (Isolate.run/compute) in mwl_api.dart (:120, :140, :543) — performance.md #9.",
      "Expose each new route in the app client `lib/services/api/mwl_api.dart` (typed methods + models). Keep the MWL-only routes (`users/search`, `stacks/*`, `content/featured`).",
      "This is a shared shape: later units (explore, profile, reviews, characters, calendar) build on these client methods. Document each method's return type in the PR body.",
    ],
    dod: ["`dart analyze` clean in mwl-api.", "Parser tests with saved HTML fixtures under mwl-api/test/ (no live network)."],
  },
  {
    id: "mal-auth-calls", title: "Route every MAL request through the token-refresh path", kind: "unit", priority: "P0", group: "foundation", model: "sonnet",
    needs: ["auth-refresh"],
    owns: ["lib/services/api/MAL/mal_api.dart", "lib/services/api/MAL/mal_user.dart", "lib/services/api/MAL/mal_user_prof.dart", "lib/services/api/MAL/mal_forum_api.dart", "lib/services/api/MAL/mal_clubs_api.dart", "lib/services/api/MAL/user_anime_statistics.dart"],
    goal: [
      "The owner's phone: after months without opening the app, MAL no longer works — the token expired and nothing refreshes it. auth-refresh added the mechanism (`MalConnect.authGet/authPut/authDelete`, `BaseUser.sendAuthenticated`, `MalSessionExpired`) but the 22 call sites in mal_api.dart / mal_user.dart (and any other authenticated MAL call in the files you own) still use raw `http.*` with a hand-built Bearer header.",
      "Move EVERY authenticated MAL call onto that path, so: token near expiry → refreshed first; 401 → refresh + one replay; refresh refused → the account enters `needsReLogin` (no crash, no silent empty screens). Public (client-id only) calls stay as they are.",
      "Where a caller would get an exception, make sure `MalSessionExpired` surfaces as a clear error state the UI can show (no infinite spinner); the visible 'sign in again' prompt itself belongs to accounts-ux.",
      "Do not change behaviour otherwise: same endpoints, same parameters, same models.",
    ],
    bugs: ["MAL token never refreshed in real calls → app stops working after ~1 month (owner's phone)."],
    dod: ["`grep -nE \"Bearer|http\\.(get|put|post|delete|patch)\\(\" lib/services/api/MAL/*.dart` shows no authenticated raw call left (list any public call kept, with why, in the PR body).", "Offline tests in test/units/mal-auth-calls/ with a fake client: expired token → refresh then the MAL call succeeds; refresh rejected → MalSessionExpired / needsReLogin."],
  },
  {
    id: "l10n-pipeline", title: "Restore the localization pipeline (ARB sources, per-unit fragments, working language picker)", kind: "contract", priority: "P0", group: "foundation", model: "opus",
    needs: ["gate-fix"],
    owns: ["lib/l10n/**", "l10n.yaml", "lib/generated/**", "lib/user/language/**", "lib/screens/settings/language_settings.dart", "lib/main.dart", "pubspec.yaml", "pubspec.lock", "tools/l10n/**", "tools/verify.sh", ".gitignore", "CLAUDE.md"],
    dal: ["lib/l10n/*.arb", "lib/generated/", "lib/pages/settings/langsettings.dart", "lib/user/user.dart (setLocale)"],
    goal: [
      "MWL has generated messages for 11 locales but no .arb sources, so strings cannot change. Rebuild ARB sources (start from DAL's lib/l10n/*.arb, add MWL's own keys found in lib/generated) and a reproducible generation step.",
      "PARALLEL-SAFE STRINGS (the reason this is a contract): design it so parallel units never edit the same file to add strings. Required shape: each unit adds its keys ONLY in `lib/l10n/units/<unit-id>/intl_<locale>.arb` (English mandatory, other locales optional, fallback to English); `tools/l10n/build.sh` merges base + all fragments and regenerates `S`. Merged ARBs and `lib/generated/` become build outputs (git-ignored), and `tools/verify.sh` runs the build step first. Document the procedure in CLAUDE.md (Localization section).",
      "Fix the language setting: picker codes vs generated locale names mismatch (only en/ja load), `language_bloc.dart:27` emits after await in a `void async` handler, saved language never applied at startup (`S.load` never called), `main.dart:203` hardcodes en_US and MaterialApp ignores LanguageBloc, two storage keys. Add the missing locales to the picker (ar, id, tr) and RTL for Arabic.",
      "Also fix `main.dart:60-75`: an AccountBloc is created and listened to but never provided (the provided one is a different instance at l.91), so the AccountManagerSingleton listener is dead.",
    ],
    bugs: ["Language picker broken (see goal).", "AccountBloc double instance in main.dart."],
    dod: ["Switching to French in settings changes the UI immediately and survives a restart.", "A fresh clone + `tools/l10n/build.sh` + `flutter analyze` is green.", "CLAUDE.md explains how a unit adds a string."],
  },
  {
    id: "deps-prefs-contract", title: "Dependencies, Android permissions and the preferences contract", kind: "contract", priority: "P0", group: "foundation", model: "opus",
    needs: ["l10n-pipeline"],
    owns: ["lib/utils/deep_links.dart", "test/units/deep-links/**", "android/build.gradle", "android/build.gradle.kts", "docs/PERFORMANCE.md", "pubspec.yaml", "pubspec.lock", "android/app/src/main/AndroidManifest.xml", "android/app/build.gradle", "android/app/build.gradle.kts", "linux/flutter/generated_plugin_registrant.cc", "linux/flutter/generated_plugins.cmake", "macos/Flutter/GeneratedPluginRegistrant.swift", "windows/flutter/generated_plugin_registrant.cc", "windows/flutter/generated_plugins.cmake", "lib/main.dart", "lib/user/preferences/**", "lib/user/userpref.dart", "lib/user/user_preference.dart", "lib/user/anime_manga_pref.dart", "lib/user/anime_manga_pref.g.dart", "lib/user/anime_manga_tab_pref.dart", "lib/user/anime_manga_tab_pref.g.dart", "lib/user/list_pref.dart", "lib/user/user.dart", "lib/services/notifications/notification_service.dart"],
    dal: ["lib/user/userpref.dart", "lib/user/anime_manga_pref.dart", "lib/user/anime_manga_tab_pref.dart", "lib/user/list_pref.dart", "lib/user/hompagepref.dart", "lib/notifservice.dart (NotifPref)", "pubspec.yaml", "android/app/src/main/AndroidManifest.xml"],
    goal: [
      "Add, in ONE pass, every dependency the queued units need (check pins against pub.dev; record them in docs/STACK.md is not yours — list them in the PR body): flutter_local_notifications, timezone, dynamic_color, flex_color_picker, translator_plus, package_info_plus, device_info_plus, add_2_calendar, open_filex, flutter_displaymode, graphview, fl_chart, share_plus (if absent), path_provider (if absent), file_picker (if absent), build_runner (dev). Move json_serializable to dev_dependencies.",
      "Manifest: POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED + the flutter_local_notifications receivers, calendar permissions, REQUEST_INSTALL_PACKAGES + a FileProvider for the in-app updater. Keep the OAuth intent filters.",
      "PREFERENCES CONTRACT (shared shape every later unit reads): a `PreferencesBloc` (BLoC, per project convention) in `lib/user/preferences/` holding typed, persisted models for ALL DAL preferences: user prefs (preferred title EN/JA/Romaji, startup page, NSFW, show anime/manga card, allow YouTube player, keep pages in memory, show priority, auto-translate synopsis, only last quote, auto start/end date, airing info in list, stats chart colors, preferred link type), anime/manga prefs (countdown on detail, detail background, show private notes, hide score, global seasonal filter, timezone, default add-to-list status anime/manga, detail tab order/visibility), list prefs (default list tab, card view props), notification prefs (enabled lists, large image). Events to update each field; a getter API that non-widget code can call.",
      "Remove dead language code left by l10n-pipeline: `getLanguage`/`setLanguage` (key `language`) in lib/user/user_preference.dart, `UserMal.setLocale`/`runPostInitialization` in lib/user/user.dart (a third language setting nobody calls); drop the unused third-party `flutter_localization` from pubspec.yaml (keep the SDK `flutter_localizations`).",
      "Remove the duplicates (TimezonePref declared twice, the unused models replaced by the contract), keeping existing saved values readable (migrate keys).",
      "Create the stub `lib/services/notifications/notification_service.dart` with a no-op `init()` called from main.dart; the notifications unit fills it.",
    ],
    dod: ["`test/units/deps-prefs-contract/` covers persistence round-trip and key migration.", "App starts on the emulator with the new providers (checker verifies).", "PR body lists every added dependency with its version and the unit that needs it."],
  },
  {
    id: "app-shell", title: "App shell seams: settings hub, sidebar, home shell, startup", kind: "foundation", priority: "P0", group: "foundation", model: "opus", ui: true,
    needs: ["deps-prefs-contract"],
    owns: ["lib/screens/settings/settings_page.dart", "lib/screens/settings/accounts_settings.dart", "lib/screens/settings/about_settings.dart", "lib/screens/settings/notifications_settings.dart", "lib/screens/settings/user_prefs_settings.dart", "lib/screens/settings/anime_manga_settings.dart", "lib/screens/settings/list_prefs_settings.dart", "lib/screens/settings/backup_settings.dart", "lib/screens/settings/storage_settings.dart", "lib/screens/settings/dub_settings.dart", "lib/pages/settings/**", "lib/pages/side_bar.dart", "lib/utils/sidebar_extension.dart", "lib/screens/home_screen.dart", "lib/screens/open_screen.dart", "lib/screens/bookmarks_screen.dart", "lib/screens/calendar/calendar_screen.dart", "lib/utils/app_routes.dart"],
    dal: ["lib/pages/settings_page.dart", "lib/pages/side_bar.dart", "lib/screens/homescreen.dart", "lib/screens/openscreen.dart"],
    goal: [
      "Rebuild the settings hub (UI directive applies) with one tile per settings page. Create each settings page file listed in Owns as a STUB (title + 'coming soon') — later units own and fill them. Remove the empty `onTap` stubs (MAL Account :147, Connected Services :158, About :174, Help :185).",
      "Create stub screens `lib/screens/bookmarks_screen.dart` and `lib/screens/calendar/calendar_screen.dart`, and a tiny route helper `lib/utils/app_routes.dart` (openBookmarks, openCalendar, openUserProfile(tracker, username), openSettingsPage(...)) so feature units can link to each other without touching each other's files. openUserProfile may push a stub until the profile unit fills it.",
      "Make the sidebar actually reachable (today `AppSidebar` is only built by `SidebarBuilder`, which nothing calls) and wire: profile, stats, bookmarks, calendar, settings, login/logout. About must open the About page.",
      "Session expired (post-merge finding #71): listen to the session-expired notifier exposed by the MAL API layer (added by the #71 fix; if absent on your base, report it) and show a non-blocking banner/snackbar 'MAL session expired — sign in again' that opens the re-login flow.",
      "Home shell: honor the startup-page preference from the contract; open screen shows a loader instead of `loadingError()` while loading (open_screen.dart:45); hook for routing from a notification payload (calls into notification_service).",
      "FLUIDITY (work/inventory/performance.md #2, #5): remove the per-tab animated `Opacity` wrap (home_screen.dart:236-237, saveLayer over the whole page on every tab switch); build only the current tab unless the keepPagesInMemory pref is on (DAL homescreen.dart:293-297) so 5 tabs don't fire their network calls at once; scope the AccountBloc/ThemeBloc builders (:88, :105) with buildWhen/BlocSelector so they don't rebuild the whole shell.",
    ],
    bugs: ["settings_page.dart empty onTaps.", "Sidebar never shown.", "open_screen.dart:45 shows an error widget while loading."],
    dod: ["Every settings tile opens its page (stub or real).", "Sidebar opens from the home shell on the emulator.", "app_routes.dart helpers are documented with a one-line comment each."],
  },
  {
    id: "detail-split", title: "Split the 1852-line detail screen into sections with seams", kind: "foundation", priority: "P0", group: "detail", model: "opus", ui: true,
    needs: ["deps-prefs-contract"],
    owns: ["lib/screens/MAL/contentdetailedscreen.dart", "lib/screens/MAL/detail/**"],
    dal: ["lib/screens/contentdetailedscreen.dart"],
    goal: [
      "Split `lib/screens/MAL/contentdetailedscreen.dart` into `lib/screens/MAL/detail/`: `detail_screen.dart` (scaffold + scroll/tab sync), `header/` (cover, scores, meta), `actions/` (app bar actions), `sections/` (one file per section wrapper), `detail_sections.dart` (ordered section registry that reads the detail tab order/visibility pref from the contract). Keep `contentdetailedscreen.dart` as a thin re-export so callers don't change.",
      "Fix: `super.dispose()` called before disposing own controllers (:159); scroll listener re-added on every `updateVisibleSections()` (:338); info button on the cover is a no-op (:1104) → opens a More Info modal; search icon in app bar is a no-op (:939) → opens search.",
      "Leave empty, documented extension points in `actions/` for share / open in browser / bookmark (the detail-header unit fills them).",
      "FLUIDITY (performance.md #4): register the scroll listener ONCE in initState, dispose every TabController you replace (only the last is disposed at :161), update the selected tab only when the visible section changes — not localToGlobal on every scroll tick.",
      "Remove the second `TitleLang` enum declared in contentdetailedscreen.dart:54 and use the one in constants.dart (deps-prefs-contract finding); read the preferred title from `Preferences.general` instead of a per-screen default.",
      "Behaviour must stay identical otherwise (no visual redesign here beyond what the split needs); the later detail units redesign their own parts.",
    ],
    bugs: ["dispose order :159", "listener leak :338", "dead info button :1104", "dead search button :939"],
    dod: ["No file under lib/screens/MAL/detail/ over ~400 lines.", "Detail screen behaves as before on the emulator (checker compares)."],
  },
  {
    id: "shared-kit", title: "Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher", kind: "kit", priority: "P0", group: "foundation", model: "opus", ui: true,
    needs: ["deps-prefs-contract"],
    owns: ["lib/enums.dart", "lib/widgets/common/share_builder.dart", "lib/widgets/common/app_bar_menu.dart", "lib/widgets/common/score_reveal.dart", "lib/widgets/common/select/**", "lib/widgets/common/adaptive_layout.dart", "lib/utils/web_launcher.dart", "lib/constants/constants.dart"],
    dal: ["lib/widgets/common/share_builder.dart", "lib/widgets/customappbar.dart", "lib/widgets/selectbottom.dart", "lib/widgets/selecttopper.dart", "lib/widgets/home/nodebadge.dart (_CardScoreRevealWidget)", "lib/widgets/web/c_webview.dart", "lib/widgets/common/adaptive_layout.dart"],
    goal: [
      "Share builder (choose fields: title, URL, synopsis…; copy or share) usable by any screen.",
      "App bar overflow menu widget with Share / Open in browser / Bookmark slots (callbacks, no feature logic).",
      "Select widgets missing from MWL: SelectButton, SelectSheet, SelectDate, ThreeStateSelectBar, SearchableSelect (long lists), showTopSheet.",
      "Score reveal widget honoring the hide-score preference (tap/eye to reveal one score).",
      "Web launcher: custom tabs / in-app webview instead of the deprecated `launch()`; restore internal MAL URI handling commented out around constants.dart:1148-1152 (route to in-app screens via app_routes when the app-shell unit has merged, else leave a TODO and report).",
      "Adaptive layout helper (phone / tablet breakpoints) for later tablet work.",
    ],
    dod: ["Each widget has a widget test under test/units/shared-kit/ and a usage example in the PR body."],
  },

  {
    id: "perf-foundation", title: "Fluidity foundation: 120 Hz, image decoding, shimmers, root rebuilds", kind: "foundation", priority: "P0", group: "foundation", model: "opus",
    needs: ["deps-prefs-contract"],
    owns: ["lib/main.dart", "lib/widgets/common/app_image.dart", "lib/widgets/common/avatar_widget.dart", "lib/widgets/common/image_preview.dart", "lib/widgets/loading/**", "lib/utils/page_transitions.dart", "android/app/src/main/AndroidManifest.xml", "docs/PERFORMANCE.md"],
    dal: ["lib/main.dart:62 (FlutterDisplayMode.setHighRefreshRate)", "lib/widgets/avatarwidget.dart:219 (fadeInDuration zero)", "lib/screens/homescreen.dart:293-297", "android/app/src/main/AndroidManifest.xml:59-61 (EnableImpeller=false)"],
    goal: [
      "The owner says MWL lags on scroll and page changes while DAL is fluid. Read work/inventory/performance.md first; you own the global fixes (#1, #3 helper, #5 main.dart, #8, #10, #11, #13, #14 preview, #15).",
      "High refresh rate: `FlutterDisplayMode.setHighRefreshRate()` before runApp (dependency added by deps-prefs-contract).",
      "Shared image widget `lib/widgets/common/app_image.dart` wrapping CachedNetworkImage: decode at displayed size (memCacheWidth/Height = logical size × devicePixelRatio, maxWidthDiskCache), short or zero fade, cheap placeholder. Use it in avatar_widget.dart (zero fade, no blur BoxShadow on repeated avatars) and image_preview.dart (also replace Image.network; replace the BackdropFilter blur over PhotoView by a static scrim).",
      "Shimmers: one shared animation ticker inside the shimmer widget (lib/widgets/loading/) so 38 call sites stop running 38 tickers — callers unchanged.",
      "main.dart: scope the ThemeBloc builder around MaterialApp (:192) with buildWhen so only theme changes rebuild it.",
      "Impeller vs Skia: do NOT flip blindly. Leave the manifest flag configurable and write in docs/PERFORMANCE.md the A/B procedure the checker runs (profile build, gfxinfo janky %, same gesture, MWL vs DAL).",
      "Write docs/PERFORMANCE.md: the project's fluidity rules (the list in every UI handoff) + how to measure.",
    ],
    bugs: ["60 Hz only", "full-resolution image decode", "38 shimmer tickers", "blur re-rendered every frame in the image viewer"],
    dod: ["Checker measures home scroll + detail open on a --profile build: janky frames % no worse than DAL's on the same gesture."],
  },

  // ───────────────────────────── User ─────────────────────────────
  {
    id: "accounts-ux", title: "Redesign the account picker, account switcher and account management", kind: "screen", priority: "P1", group: "user", model: "sonnet", ui: true,
    needs: ["app-shell"],
    owns: ["lib/services/auth/kitsu_auth.dart", "lib/user/user.dart", "lib/user/base_user.dart", "lib/screens/account_switcher_page.dart", "lib/screens/manage_accounts_page.dart", "lib/screens/onboarding_trackers.dart", "lib/pages/login_page.dart", "lib/screens/settings/accounts_settings.dart", "lib/user/trackers/**", "lib/widgets/common/acc_widget.dart", "lib/widgets/common/signin_widget.dart", "lib/widgets/common/logout_dialog.dart", "lib/widgets/Kitsu/kitsu_login_dialog.dart", "lib/user/accounts/**"],
    dal: ["lib/pages/settings/accounts_settings.dart", "lib/widgets/user/signinpage.dart"],
    goal: [
      "The owner says the current flow (select an account, then press Continue, for every app) is badly done. Redesign the whole account experience: first-run tracker connection, switching the active account (one tap, no Continue step), adding/removing accounts, re-login when a token is dead.",
      "Session expiry UX: show a clear 'sign in again' prompt for any tracker in `UserManager.trackersNeedingReLogin` / `needsReLogin` (from auth-refresh), and keep AccountManager / AccountBloc informed when a session dies (lib/user/accounts/**).",
      "Two `AuthStatus` enums exist (lib/user/user.dart and lib/user/base_user.dart) and comparisons across them are always false: keep one, migrate every use (app-shell finding). Replace the hardcoded English of logout_dialog.dart.",
      "Fill the Accounts settings page stub (login/logout per tracker, active account, connected services).",
      "Tracker logos via AppImage instead of Image.network (onboarding_trackers.dart:192).",
      "This is an MWL-only flow (DAL has one MAL account): design it from scratch for 4 trackers; look at DAL only for the sign-in visuals.",
    ],
    dod: ["Switching account is one tap from the home shell.", "No dead buttons.", "Before/after screenshots described in the PR body (the checker re-takes them)."],
  },
  {
    id: "edit-sheet", title: "Edit-entry sheet: fix pre-fill, dates, episodes, private notes", kind: "unit", priority: "P0", group: "user", model: "sonnet", ui: true,
    needs: ["deps-prefs-contract"],
    owns: ["lib/services/api/MAL/models/my_anime_list_status.dart", "lib/services/api/MAL/models/my_manga_list_status.dart", "lib/widgets/user/contenteditwidget.dart", "lib/widgets/user/edit/**", "lib/user/private_notes/**"],
    dal: ["lib/widgets/user/contenteditwidget.dart", "commits 704b5b5, 7d02a3f, e7eef19, b5f1e8d, ee084b6, 2f6b9da, 3f89382, fe88690, e773650 (private notes)"],
    goal: [
      "Pre-fill everything from the existing entry: start/finish dates, priority, comments, tags, rewatch count (`_loadFromContent` l.104-128 skips them); chapters/volumes are forced to '0' on load (~l.115-122).",
      "Auto start/end dates only when the `autoAddStartEndDate` pref is on and only when the date is empty; set finish date when completing through the episode count (l.273-285); fill start date when episode count goes 0→1.",
      "Total episodes for airing shows (DAL e7eef19/b5f1e8d); default add-to-list status from the pref instead of hard-coded `plan_to_watch`.",
      "No infinite spinner when `contentDetailed` is null: show a retry/fallback (DAL 7d02a3f).",
      "Comments in a popup editor (DAL ee084b6); decode HTML entities in comments and tags.",
      "Private notes: local-only note per entry (`lib/user/private_notes/`), shown in the sheet when the `showPrivateNotes` pref is on; expose `PrivateNotesStore.export()/import()` for the backup unit.",
      "Split the 1567-line widget into `lib/widgets/user/edit/` parts while you are there.",
    ],
    bugs: ["pre-fill gaps", "chapters/volumes = 0", "auto dates overwrite existing ones", "no finish date via episode count", "infinite spinner"],
    dod: ["Editing an existing completed entry on the emulator shows its real dates/score/progress.", "Private note survives app restart."],
  },
  {
    id: "user-list-mal", title: "MAL user anime/manga list (status tabs, sort/filter, view modes, status cache)", kind: "screen", priority: "P0", group: "user", model: "opus", ui: true,
    needs: ["perf-foundation", "shared-kit", "edit-sheet"],
    owns: ["lib/pages/MAL/mal_user_page.dart", "lib/widgets/user/list/**", "lib/widgets/common/list_sort_filter.dart", "lib/user/list_cache/**"],
    dal: ["lib/pages/userpage.dart", "lib/widgets/user/contentlistwidget.dart", "lib/user/contentbuilder.dart", "lib/widgets/listsortfilter.dart", "lib/user/userlistcache.dart", "lib/widgets/user/customizedlist.dart"],
    goal: [
      "Replace the placeholder MAL user page with the full list: anime/manga, status tabs (respecting the custom list tabs pref), sort & filter popup, grid/list + compact/comfortable/cover-only/spacious view modes, custom card layout editor (card view props pref), show priority, airing info, hide-score reveal, pull to refresh, pagination, quick edit opening the edit sheet.",
      "User list status cache with persistence (DAL b490f94/5f1a965): `lib/user/list_cache/` exposes the status of any id so cards elsewhere can show badges. This cache is a shared shape for cards-upgrade: document its API in the PR body.",
      "Design the list widgets tracker-agnostic (a list-entry view model) so the AniList/Kitsu/Simkl units reuse them.",
    ],
    dod: ["The owner's real MAL list loads on the emulator, all statuses, sort and filters work.", "Status cache survives restart."],
  },
  {
    id: "list-cards-dal", title: "My List grid display: the same visual as DailyAL's grid (the rest of MWL's My List stays)", kind: "unit", priority: "P0", group: "user", model: "opus", ui: true,
    needs: ["user-list-mal", "theme-colors"],
    owns: ["lib/widgets/user/list/cards/**", "lib/widgets/user/list/list_entry_view.dart"],
    dal: ["lib/widgets/home/animecard.dart", "lib/widgets/home/nodebadge.dart", "lib/widgets/user/contentlistwidget.dart (grid mode)"],
    goal: [
      "OWNER'S FINAL DECISION: keep MWL's My List interface (header, tabs, toolbar, icons, list/compact/other non-grid modes) exactly as it is. The GRID display types must have THE SAME VISUAL AS DAILYAL'S GRID — this screen element only; everything else in the app follows the normal UI directive.",
      "Reproduce DailyAL's grid card (read lib/widgets/home/animecard.dart and the grid branch of lib/widgets/user/contentlistwidget.dart): clean rounded cover with no text or gradient on the image; directly under it a compact bar — left ★ mean score (or '-'; hide-score tap-to-reveal respected); right a coloured status chip (CW / CMPL / OH / DR / PTW) containing the edit pencil; then the title on one line with ellipsis; then the genres in small text on one line; small badges top-right on the cover (unseen / behind counts). Same card proportions, cover ratio, spacing between cards, corner radius and border/elevation as DailyAL. Status chip colours come from the theme-colors status tokens so they stay readable in light, dark and black.",
      "IMPORTANT FEATURE (owner): the two badges top-right of the cover, as in DailyAL — a BLUE badge = number of episodes already aired / available, a RED badge = aired episodes the user has NOT watched yet (aired − watched). Today MWL shows a single pink '+1'. Aired count: the calendar unit's `AiringSchedule.instance.nextEpisode(malId)` (next episode − 1) first, then the weekly estimate (`estimateAiredEpisodes`), then the total for finished shows; hide the red badge at 0, hide both when unknown. Same badges for manga only if a chapter count is known. Colours from the theme-colors tokens (readable in light/dark/black).",
      "BADGE RULE PER DISPLAY MODE (owner): when the card already shows the progress text ('4 / 12 ep.') only the red unwatched badge ('+N') is needed; when the display mode does NOT show the progress (comfortable, cover-only, DailyAL-style grid card where the bar shows score/status, compact…) the card must show BOTH badges — blue = episodes aired, red = aired − watched — following DailyAL's rule (blue hidden when equal to red, i.e. nothing watched yet; both hidden when caught up). Apply this rule consistently in every display mode and in custom layouts (a layout without the progress field gets both badges).",
      "EQUAL CARD HEIGHTS (owner): MWL's grid cards have different heights because titles wrap to 1 or 2 lines. DailyAL avoids it: the title is ONE line with ellipsis and the genres ONE line, inside a fixed-height text block, so every card in a row has the same height. Do the same (fixed mainAxisExtent / childAspectRatio computed from the cover ratio + fixed text block), whatever the title length or text scale (clamp, never overflow).",
      "Keep MWL's behaviour: tap opens the detail, pencil / long press opens the edit sheet, the status cache updates the chip, airing info and priority prefs, the grid column/height settings, custom card layouts (the DailyAL grid card becomes the default grid layout).",
      "Fluidity: AppImage at card size, no per-card Opacity/ClipRRect/blur, fixed extents.",
    ],
    dod: ["Checker: side-by-side screenshots of MWL's grid vs DailyAL's grid on the owner's account — same visual; other display modes unchanged.", "Widget tests: grid card renders score/status/title/genres, hide-score, French labels."],
  },
  {
    id: "user-profile-mal", title: "MAL user profile, stats charts and user pop-up", kind: "screen", priority: "P1", group: "user", model: "sonnet", ui: true,
    needs: ["mal-auth-calls", "app-shell", "shared-kit", "backend-parsers"],
    owns: ["lib/services/api/MAL/scrapper/user_profile_page.dart", "test/units/profile-polish/profile_polish_test.dart", "test/units/app-shell/app_routes_test.dart", "lib/utils/app_routes.dart", "lib/pages/MAL/mal_user_profile_page.dart", "lib/screens/user_profile/**", "lib/widgets/user/profile/**", "lib/widgets/charts/**", "lib/services/api/MAL/scrapper/user_anime_statistics.dart", "lib/services/api/MAL/scrapper/user_friends.dart", "lib/services/api/MAL/scrapper/user_history.dart", "lib/services/api/MAL/user_anime_statistics.dart", "lib/services/api/MAL/mal_user_prof.dart", "lib/cache/cached_user_profile.dart"],
    dal: ["lib/screens/user_profile.dart", "lib/widgets/user/user_header.dart", "lib/widgets/user/stats_screen.dart", "lib/user/charts/", "lib/widgets/barchart.dart", "lib/pages/userpop.dart", "lib/cache/cacheduserprof.dart", "lib/util/insight_service.dart"],
    goal: [
      "Own profile and any other user's profile: header, about (users/about parser from backend-parsers), favorites, friends, clubs, history, stats with charts (fl_chart; colors from the stats chart pref), insights.",
      "User pop-up sheet (profile header, set/remove profile background, report user).",
      "Point `openUserProfile` and `openUserStats` in lib/utils/app_routes.dart at your real screens (one-line changes; app-shell merged, you own the file now).",
    ],
    dod: ["Owner's profile and a friend's profile render on the emulator with stats."],
  },
  {
    id: "profile-polish", title: "Profile screen: readable themed header, chart colours from status tokens, lighter surfaces, no Jikan wait", kind: "unit", priority: "P0", group: "user", model: "opus", ui: true,
    needs: ["user-profile-mal", "theme-colors"],
    owns: ["lib/screens/user_profile/**", "lib/widgets/user/profile/**", "lib/widgets/charts/**", "lib/pages/MAL/mal_user_profile_page.dart"],
    dal: ["lib/screens/user_profile.dart", "lib/widgets/user/user_header.dart", "lib/widgets/user/stats_screen.dart", "lib/user/charts/"],
    goal: [
      "Owner's screenshots of his own profile, light Spring theme: 'the rendering / colours are too weird'. Seen: a dark teal gradient header block under a light theme; the app-bar title (username) dark on dark, invisible; tab labels dark grey on the dark header; the status bar barely readable; the 'Anime list' bars use arbitrary hardcoded colours (green, blue, orange, red, brown) unrelated to the theme; grey stat tiles inside grey cards look heavy; 'male' shown raw.",
      "Header: follow the theme (light header in light mode, dark in dark/black) or, when a profile background image is set, a proper scrim token so the title, tabs, icons and status bar are always readable; compare with DailyAL's profile header and keep the better. Collapsing app bar with an opaque themed background.",
      "Charts: status bars and score distribution use the theme-colors status tokens (watching/completed/on hold/dropped/plan) and the stats chart colour preference; labels readable; consistent with the list status chips.",
      "Surfaces: one level of card, no grey-in-grey stacks; spacing and typography consistent with the rest of the app (theme fonts).",
      "Issue #118 items for this screen: show the MAL `/users/@me` data immediately and merge Jikan when (if) it arrives (never wait minutes); French: gender localised (not raw 'male'), averages with the locale NumberFormat (8,90 in French), media types translated.",
    ],
    dod: ["Checker: screenshots of the own profile and a friend's profile in light, dark and black — readable header/title/tabs/status bar, chart colours = status colours.", "Widget tests: header readable (contrast) in light/dark, tokens used, French formatting."],
  },
  {
    id: "profile-tabs", title: "Profile tabs (Friends, Clubs, History) never hang: timeout + MAL page fallback", kind: "unit", priority: "P0", group: "user", model: "sonnet", ui: true,
    needs: ["profile-polish", "backend-parsers"],
    owns: ["lib/l10n/units/mal-friends-json/**", "test/smoke/html_parsers_test.dart", "lib/screens/user_profile/sections/**", "lib/services/api/mwl_api.dart", "mwl-api/**", "lib/services/api/MAL/scrapper/user_friends.dart", "lib/services/api/MAL/scrapper/user_history.dart"],
    goal: [
      "Owner's screenshot: the profile Friends tab spins forever on 'Loading profile…'. friends_section.dart calls `MwlApi.getUserFriends`, which goes through an mwl-api route (Jikan-backed) with no timeout; Jikan is unreachable on the owner's network, so no error ever shows. Same risk for Clubs and History.",
      "Every profile tab ends in content, an empty state or an error with Retry within ~12 s: client timeouts on these MwlApi calls; read friends / clubs / history from MAL's own profile pages (myanimelist.net/profile/<name>/friends, /clubs, /history — parsers exist in lib/services/api/MAL/scrapper/ and mwl_commons) when Jikan fails or first; parse off the UI isolate.",
      "A tab never waits for the rest of the profile to load; translated states; theme tokens only.",
    ],
    dod: ["Tests with a failing fake Jikan: Friends / Clubs / History end in content or a state within the timeout.", "Checker: owner's profile Friends tab loads on his network."],
  },
  {
    id: "sync-dialog", title: "Cross-tracker sync: two-way dialog, cancel, lazy load, decimal scores", kind: "unit", priority: "P1", group: "user", model: "sonnet", ui: true,
    needs: ["edit-sheet", "auth-refresh"],
    owns: ["lib/services/tracker_sync_service.dart", "lib/widgets/user/cross_tracker_widget.dart", "lib/widgets/user/tracker_search_sheet.dart", "lib/widgets/user/sync/**"],
    dal: ["lib/util/sync_helper.dart", "commits 7c9c165, c64ccc0, c4f7276, ce3b001, 7ab3460, 146c681"],
    goal: [
      "Sync dialog with loading indicators, lazy loading and a Cancel button; both directions (MAL ⇄ AniList at least; Kitsu/Simkl where their API allows), not only MAL → others.",
      "Decimal scores / AniList POINT_10_DECIMAL (today `.toInt()` truncates).",
      "Per-tracker edit (status, score, progress, dates) of the linked entry inside the sheet, not only 'sync MAL values'.",
    ],
    dod: ["Editing on MAL then syncing to AniList updates AniList on the emulator (owner's accounts)."],
  },

  // ───────────────────────────── Detail ─────────────────────────────
  {
    id: "detail-header", title: "Detail header and actions: share, browser, bookmark, More Info, hide score, custom tabs, countdown", kind: "screen", priority: "P1", group: "detail", model: "sonnet", ui: true,
    needs: ["detail-split", "shared-kit", "bookmarks"],
    owns: ["lib/screens/MAL/detail/detail_data.dart", "lib/screens/MAL/detail/detail_screen.dart", "lib/screens/MAL/detail/sections/media_section.dart", "lib/screens/MAL/detail/header/**", "lib/screens/MAL/detail/actions/**", "lib/screens/MAL/detail/detail_sections.dart", "lib/screens/MAL/detail/tabs_customizer.dart"],
    dal: ["lib/screens/contentdetailedscreen.dart", "lib/screens/moreinfo.dart", "AnimeMangaPageTabEdit", "CountDownWidget"],
    goal: [
      "App bar menu: share (share builder), open in browser, bookmark toggle (`BookmarkButton` / `Bookmarks` from the bookmarks unit), search by genre.",
      "Wire the schedule links from detail-synopsis-media (PR #103): add `scheduleLinks` to `DetailData.copyWith`; in detail_screen.dart, after an anime loads, call `ScheduleLinks.forMalId(id)` and copy the result in when mounted; in sections/media_section.dart pass `fallbackImageUrl: data.coverUrl` to `VideosWidget`.",
      "More Info modal reachable from the cover info button.",
      "Hide-score with tap to reveal; preferred title language from the pref (not a per-screen toggle only); detail background pref; next-episode countdown pref.",
      "Customize / reorder / hide sections, persisted in the contract pref. Manga default order: keep Stats and Score stats on manga pages (an MWL extra over DailyAL, orchestrator recommendation pending the owner) — change the manga default in the contract only through a finding if it lives outside your files.",
      "Redesign the header (UI directive): compare DAL and MWL side by side.",
    ],
    dod: ["All header buttons do something on the emulator."],
  },
  {
    id: "detail-related-graph", title: "Related: view-all grid with statuses and the relation graph (share as PNG)", kind: "unit", priority: "P1", group: "detail", model: "sonnet", ui: true,
    needs: ["detail-split", "shared-kit", "user-list-mal"],
    owns: ["lib/widgets/MAL/content/relatedanimewidget.dart", "lib/widgets/graph/**"],
    dal: ["lib/widgets/anime_graph.dart", "lib/pages/animedetailed/relatedanimewidget.dart", "commits e773650 (graph node select, share PNG), db3355e (graph toggle)"],
    goal: ["Implement the stubbed graph (`_setAnimeGraph` empty l.61, `_animeGraph` returns SizedBox l.77-79) with graphview via the backend `getAnimeGraph`; node layout, order types, long-press to select/reposition; share graph as PNG with branding; view-all grid showing list statuses (status cache)."],
    dod: ["Graph renders for a franchise with many entries (e.g. Monogatari) on the emulator."],
  },
  {
    id: "detail-synopsis-media", title: "Synopsis translation, streaming links, videos fallback", kind: "unit", priority: "P2", group: "detail", model: "sonnet", ui: true,
    needs: ["detail-split", "deps-prefs-contract"],
    owns: ["lib/widgets/MAL/content/synopsis_widget.dart", "lib/widgets/MAL/content/media_platforms.dart", "lib/widgets/MAL/content/videowidget.dart", "lib/widgets/common/translator.dart"],
    dal: ["lib/pages/animedetailed/synopsiswidget.dart", "lib/widgets/translator.dart", "lib/pages/animedetailed/media_platforms.dart", "lib/pages/animedetailed/videoswidget.dart"],
    goal: [
      "Synopsis translation (translator_plus) with the auto-translate pref; reusable translator widget (character bios use it later).",
      "media_platforms.dart: `_scheduleData` is never assigned (:125, used :482) → schedule related links never show; preferred link type from the pref instead of hard-coded `streaming` (:55, :233).",
      "Video fallback image; respect the allow-YouTube-player pref.",
    ],
    bugs: ["_scheduleData never assigned"],
    dod: ["Synopsis translates to French on the emulator."],
  },
  {
    id: "detail-social", title: "Reviews AI summary + share, interest stacks and user updates linking to profiles", kind: "unit", priority: "P2", group: "detail", model: "sonnet", ui: true,
    needs: ["detail-split", "user-profile-mal", "backend-parsers"],
    owns: ["lib/widgets/MAL/content/show_reviews.dart", "lib/widgets/MAL/review/**", "lib/widgets/MAL/content/intereststackwidget.dart", "lib/widgets/MAL/content/userupdate_widget.dart", "lib/screens/MAL/interest_stack_detail_screen.dart"],
    dal: ["lib/pages/animedetailed/reviewpage.dart", "ReviewGeneratedSummary", "lib/pages/animedetailed/intereststackwidget.dart", "lib/pages/animedetailed/userupdates.dart"],
    goal: [
      "Review AI summary (verdict, pros/cons) via backend `getReviewsSummary`; share a review; reviewer tap → profile (TODO at review_detail_page.dart:92).",
      "Interest stacks: username tap → profile (intereststackwidget.dart:195); edit button on stack entries works (interest_stack_detail_screen.dart:771) — call the edit sheet directly.",
      "Reviews: remove the SingleChildScrollView created per review item (show_reviews.dart:174, performance.md #6).",
      "User updates: user/avatar tap → profile (userupdate_widget.dart:91, :107).",
    ],
    dod: ["Every user name in these widgets opens `AppRoutes.openUserPop` (quick user sheet with a link to the full profile)."],
  },
  {
    id: "detail-resilience", title: "Detail sections: no endless skeletons, MAL fallbacks when Jikan fails, round avatars without box shadows", kind: "unit", priority: "P0", group: "detail", model: "opus", ui: true,
    needs: ["detail-header", "detail-social", "cards-upgrade"],
    owns: ["lib/screens/MAL/detail/actions/more_info_modal.dart", "lib/widgets/MAL/content/more_info_widget.dart", "lib/screens/MAL/detail/sections/**", "lib/screens/MAL/detail/pages/**", "lib/widgets/MAL/content/scorestatisticswidget.dart", "lib/widgets/MAL/content/animestatisticswidget.dart", "lib/widgets/MAL/content/userupdate_widget.dart", "lib/widgets/MAL/content/show_forum.dart", "lib/widgets/MAL/content/show_reviews.dart", "lib/widgets/MAL/content/show_featured.dart", "lib/widgets/MAL/content/intereststackwidget.dart", "lib/widgets/MAL/home/animecharacterwidget.dart", "lib/screens/MAL/characters_staff_screen.dart", "lib/services/api/Jikan/**"],
    goal: [
      "Owner's screenshots of an anime detail page (Shuiro no Kamen): Score Stats shows grey placeholder bars forever, User Updates shows skeleton cards forever, Forums and Reviews show 'Failed to load'. Jikan (api.jikan.moe) is unreachable from the owner's network (the checker saw a 134 s timeout). The page must still be useful.",
      "Every Jikan call gets a timeout (e.g. 12 s) in lib/services/api/Jikan/jikan_client.dart (issue #118 item). Every detail section has exactly one of: content, a translated empty state, or a translated error with Retry — never an endless skeleton.",
      "Fallback sources when Jikan fails: statistics and score distribution from the official MAL API fields where available and/or the mwl-api MAL page parsers (backend-parsers: stats/reviews/forum parsers through MwlApi); forum topics from the MAL forum API (lib/services/api/MAL/mal_forum_api.dart, read only) or the mwl-api forum parser; reviews from the mwl-api `reviews` route; user updates from the mwl-api if a parser exists, else a clean empty/error state. Document which source each section uses in the PR body.",
      "Owner: 'I only want the circular image — why is there always a weird rectangular shadow behind it?' Staff and character avatars (and the placeholder avatar) must be a clean circle with NO rectangular BoxShadow / Material elevation / grey box behind; same clean treatment for interest-stack posters (intereststackwidget.dart:165 has a blurRadius 10 shadow) and characters_staff_screen.dart:557 elevation. Use AppImage + ClipOval/CircleAvatar, theme colours only.",
      "Score Stats empty bars: when there is no data, show the empty state instead of grey bars; when there is data, bars use the theme accent with readable labels (colour rule).",
    ],
    bugs: ["endless skeletons on Jikan failure", "no Jikan timeout", "rectangular shadow behind round avatars", "heavy shadow on stack posters"],
    dod: ["Widget tests with a failing fake Jikan: each section ends in content (fallback) or an error/empty state within the timeout.", "Checker: the Shuiro no Kamen page with Jikan unreachable shows fallbacks or clean states; avatars are clean circles in light/dark."],
  },
  {
    id: "detail-more-info", title: "More-info links: studios, magazines, authors, genres, season, media type", kind: "unit", priority: "P2", group: "detail", model: "sonnet", ui: true,
    needs: ["detail-resilience", "detail-split", "search-upgrade"],
    owns: ["lib/widgets/MAL/content/more_info_widget.dart", "lib/widgets/MAL/content/adaptation_widget.dart", "lib/widgets/MAL/content/animestatisticswidget.dart", "lib/widgets/MAL/content/scorestatisticswidget.dart"],
    dal: ["lib/screens/moreinfo.dart", "commits 6f90a5a (author navigation), 024654e (serialization → magazine filter), 399851c"],
    goal: ["animestatisticswidget.dart:23-25 hardcodes English status labels (Watching, On Hold…): use the shared status maps of lib/enums.dart (fix #84).", "Give MoreInfoWidget a modal mode (DailyAL `isModal`) so the detail screen's More Info dialog does not wrap it in an extra scroll view (detail-split finding).", "Studio and genre taps are TODO prints (more_info_widget.dart:111, :238) → open the filtered search; add taps for magazine/serialization, authors (→ person page), season, media type. Use the search entry points the search-upgrade unit exposes."],
    dod: ["Each chip/link in More Info opens a relevant in-app screen."],
  },

  // ───────────────────────────── Discovery ─────────────────────────────
  {
    id: "bookmarks", title: "Bookmarks: store, screen, add/remove", kind: "unit", priority: "P1", group: "discovery", model: "sonnet", ui: true,
    needs: ["app-shell", "shared-kit"],
    owns: ["test/units/app-shell/app_routes_test.dart", "lib/cache/bookmarks.dart", "lib/screens/bookmarks_screen.dart", "lib/widgets/bookmarks/**", "lib/screens/plainscreen.dart"],
    dal: ["lib/cache/book_marks.dart", "lib/widgets/home/bookmarks_widget.dart", "BookmarkTag"],
    goal: ["Bookmark any anime/manga/character/person/forum topic; bookmarks screen (fills app-shell's stub) with tags/filters; fix plainscreen.dart:31-34 pushing an empty SizedBox; expose `Bookmarks.toggle/isBookmarked` for other units; include bookmarks in `export()/import()` for backup."],
    dod: ["Bookmark from detail (after detail-header) and from the sidebar entry on the emulator."],
  },
  {
    id: "calendar", title: "Anime calendar, weekly schedule, .ics export, add to device calendar", kind: "screen", priority: "P1", group: "discovery", model: "sonnet", ui: true,
    needs: ["perf-foundation", "app-shell", "shared-kit", "backend-parsers", "user-list-mal"],
    owns: ["test/units/app-shell/app_routes_test.dart", "lib/screens/calendar/**", "lib/widgets/calendar/**"],
    dal: ["lib/widgets/home/anime_calendar.dart", "lib/widgets/user/weeklyanime.dart", "commits 1e3e833 (ics), 17dd437 (add to calendar), 970111b ('All' filter)"],
    goal: ["Per-day schedule with status filter chips (incl. 'All' and 3-state 'in list'), timezone pref (JST/UTC/local), .ics download/share, add to device calendar with recurring option; fills app-shell's calendar stub."],
    dod: ["Calendar shows this week's airing anime with the owner's watching list highlighted."],
  },
  {
    id: "explore-seasonal", title: "Explore page and seasonal screen", kind: "screen", priority: "P1", group: "discovery", model: "sonnet", ui: true,
    needs: ["perf-foundation", "shared-kit", "backend-parsers", "user-list-mal"],
    owns: ["lib/pages/MAL/mal_explore_page.dart", "lib/screens/explore/**", "lib/screens/seasonal/**", "lib/cache/top_characters.dart"],
    dal: ["lib/pages/explorepage.dart", "lib/pages/search/allrankingwidget.dart", "lib/pages/search/all_genre_widget.dart", "lib/pages/search/seasonalwidget.dart", "lib/screens/seasonal_screen.dart", "lib/cache/topcharactermanager.dart"],
    goal: [
      "Explore page (today it is just the search screen): rankings, genres grid, random pickers (random / from watching / from plan-to-watch), seasonal widget + weekly schedule entry, global recommendations / reviews / interest stacks, top characters and seiyuu (backend routes).",
      "Dedicated seasonal screen: season/year switcher, header image, sort/filter by score/members, global seasonal filter pref.",
    ],
    dod: ["Every Explore card opens a working screen on the emulator."],
  },
  {
    id: "search-upgrade", title: "Search: user results, search by id, autocomplete, searchable filters", kind: "screen", priority: "P2", group: "discovery", model: "sonnet", ui: true,
    needs: ["perf-foundation", "shared-kit", "user-profile-mal"],
    owns: ["lib/utils/app_routes.dart", "lib/screens/search/**", "lib/widgets/MAL/search/**"],
    dal: ["lib/screens/generalsearchscreen.dart", "lib/widgets/search/filtermodal.dart", "commits da37082, 6b2aafd, fa2fb68, 3f1f0fd, 158e206 (autocomplete), db3355e (search by id, 3-state)"],
    goal: [
      "User result tap → profile (TODO :2227) and 'User found as …' shortcut; search by MAL id; autocomplete with throttle; SearchableSelect for producers/magazines; three-state include/exclude.",
      "Move the search/filter UI off lib/widgets/MAL/search/selectbottom.dart (SelectBar, MutiSelectBar, MultiSelectDropdown) onto the shared-kit select widgets (lib/widgets/common/select/select.dart), then delete what becomes unused.",
      "`_SeasonalSection._maxYear` hard-coded 2027 (:3643) → current year + 1.",
      "Give `AppRoutes.openSearch` an optional category / initial query (lib/utils/app_routes.dart, detail-split finding) so the detail screen can open search on the right category.",
      "Expose static entry points (e.g. `GeneralSearchScreen.byGenre/byStudio/byMagazine/byTag/bySeason`) used by more-info and featured units; list them in the PR body.",
      "Split the 3719-line file into parts under lib/screens/search/; while splitting, remove the ~12 ClipRRect per result item where a decoration radius suffices and use AppImage (performance.md #7).",
    ],
    bugs: ["user tap TODO", "maxYear 2027"],
    dod: ["Searching a username opens the profile; searching '1' finds Cowboy Bebop by id."],
  },
  {
    id: "home-wiring", title: "Home: working chips, bookmarks/calendar buttons, maintenance dialog, user-list and forum sections", kind: "screen", priority: "P1", group: "discovery", model: "sonnet", ui: true,
    needs: ["theme-colors", "perf-foundation", "bookmarks", "calendar", "explore-seasonal", "user-list-mal"],
    owns: ["lib/pages/MAL/mal_explore_page.dart", "lib/widgets/common/bottomnavbar.dart", "lib/pages/MAL/mal_home_page.dart", "lib/widgets/MAL/home/homeappbar.dart", "lib/widgets/MAL/home/accordion.dart", "lib/widgets/MAL/home/section_header.dart", "lib/widgets/MAL/home/news_widget.dart", "lib/widgets/MAL/home/show_news.dart", "lib/widgets/home/**", "lib/user/MAL/**", "lib/screens/settings/mal_home_settings.dart"],
    dal: ["lib/pages/homepage.dart", "lib/widgets/homeappbar.dart", "lib/widgets/home/feature_first.dart", "lib/util/homepageutils.dart", "lib/pages/settings/homepagesettings.dart"],
    goal: [
      "Top chips (Categories, Genres, Top anime/manga, Top airing, Popular) are all `() {}` (mal_home_page.dart:44-52) → open the explore/ranking screens; bookmarks and calendar buttons `() {}` (:222-224) → app_routes.",
      "MAL under-maintenance dialog (API exists mal_api.dart:1067).",
      "The avatar switcher (homeappbar.dart) still pushes AccountSwitcherPage as a full slide page: open it as a bottom sheet instead (accounts-ux finding). Sidebar entry point (app-shell finding): a visible button in the home app bar (the account avatar, as in DailyAL) calls `AppRoutes.openSidebar` — the edge swipe alone fights Android gesture navigation. Replace the direct `SettingsPage` push (mal_home_page.dart:228) by `AppRoutes.openSettings`.",
      "homeappbar.dart tooltips (Search, Bookmarks, Calendar, Settings) are hardcoded English → S (user-list-mal finding).",
      "mal_home_page.dart:182 passes Colors.white to the pull-to-refresh indicator: drop it, the theme sets it now (theme-colors finding).",
      "BottomNavBar (lib/widgets/common/bottomnavbar.dart): honour `startIndex` changes (`didUpdateWidget`) so the shell can switch tab from code, and move its hardcoded tab titles to `S`.",
      "Home sections: user-list section, forum section, custom items (forum boards, user list status, season/year).",
      "News items: drop ClipRRect + Opacity per item (news_widget.dart:54-56), use AppImage (performance.md #7).",
      "Explore tab header: use the same home app bar (avatar opening the sidebar, search, bookmarks, calendar) on lib/pages/MAL/mal_explore_page.dart instead of its plain app bar (owner-away decision, consistency).",
      "First-run feature showcase (tile size, preferred title, startup page).",
    ],
    bugs: ["dead chips", "dead bookmarks/calendar buttons"],
    dod: ["No dead button on the MAL home on the emulator."],
  },
  {
    id: "cards-upgrade", title: "Anime cards: quick edit, status badges, score reveal, real airing progress", kind: "unit", priority: "P1", group: "discovery", model: "sonnet", ui: true,
    needs: ["perf-foundation", "user-list-mal", "edit-sheet", "shared-kit"],
    owns: ["lib/widgets/MAL/home/animegridcard.dart", "lib/widgets/MAL/home/animecardbar.dart", "lib/widgets/MAL/home/contentlistwidget.dart", "lib/widgets/MAL/home/animecharacterwidget.dart"],
    dal: ["lib/widgets/home/animecard.dart", "lib/widgets/home/nodebadge.dart"],
    goal: [
      "`showContentEditSheet` is an empty stub (animegridcard.dart:620-623) → open the edit sheet.",
      "Card images through `AppImage` (perf-foundation) with decode size = card size; no ClipRRect+Opacity per card when a borderRadius/alpha does it (performance.md #3, #7).",
      "`releaseProgress` faked as (eps-1)/eps (~l.389) → real schedule data or hide.",
      "RTL: score/members badges render in a jumbled order in Arabic ('k 252 | 9.04') — build them as separate directional widgets / use Directionality-safe formatting (batch-1 check).",
      "Status badge from the list status cache, score reveal, favourites count, recommendation badge, NSFW blur per pref, preferred title.",
    ],
    bugs: ["dead edit button on every card", "fake airing progress"],
    dod: ["Card edit button opens the sheet on the emulator."],
  },

  // ───────────────────────────── Settings ─────────────────────────────
  {
    id: "settings-prefs-pages", title: "Settings pages: user prefs, anime/manga, list prefs", kind: "screen", priority: "P1", group: "settings", model: "sonnet", ui: true,
    needs: ["app-shell"],
    owns: ["lib/screens/settings/user_prefs_settings.dart", "lib/screens/settings/anime_manga_settings.dart", "lib/screens/settings/list_prefs_settings.dart", "lib/screens/settings/prefs/**"],
    dal: ["lib/pages/settings/userprefsetting.dart", "lib/pages/settings/anime_manga_settings.dart", "lib/pages/settings/list_pref_settings.dart"],
    goal: ["Fill the three stubs with every preference of the contract (UI only: values come from PreferencesBloc). Redesign per UI directive."],
    dod: ["Each toggle persists across restart."],
  },
  {
    id: "theme-colors", title: "Theme colours: status bar, coherent accents per theme, colour tokens, contrast", kind: "foundation", priority: "P0", group: "settings", model: "opus", ui: true,
    needs: ["perf-foundation", "deps-prefs-contract"],
    owns: ["lib/widgets/charts/chart_palette.dart", "lib/widgets/common/bottomnavbar.dart", "lib/widgets/common/nav_indicator.dart", "test/smoke/nav_indicator_test.dart", "lib/user/theme/**", "lib/screens/settings/theme_settings.dart", "lib/widgets/common/app_colors.dart", "lib/widgets/common/background.dart", "lib/utils/sidebar_bg_manager.dart", "lib/user/userpref.dart", "docs/THEME.md"],
    dal: ["lib/theme/theme.dart", "lib/theme/themedata.dart", "lib/pages/settings/themesettings.dart"],
    goal: [
      "The owner reports colour bugs. Seen on the emulator (Spring theme, light): the status bar clock and icons are WHITE on a near-white pink background (unreadable) — no `systemOverlayStyle` exists anywhere in lib/; the selected tab is dark teal, the card edit button orange, the score star green and the chips grey on a pink theme: the palette is not coherent; many colours are hardcoded (`Colors.*` / `Color(0x…)` in ~25 files: animegridcard, constants, scorestatisticswidget, reviews, featured, entry cards, charts, side_bar…).",
      "Fix the theme at the source: `appBarTheme.systemOverlayStyle` (and the navigation bar) per brightness for every theme mode (light, dark, black, Auto) and every seasonal theme, with a transparent status bar and readable icons; one coherent accent per theme driving `ColorScheme` (primary, secondary, tertiary, containers, surfaces, outline) so chips, tabs, FABs, badges, switches and the bottom bar all use it; correct contrast in dark and black (WCAG AA for text).",
      "Add semantic colour tokens as a `ThemeExtension` in lib/widgets/common/app_colors.dart (e.g. score, status per list status — watching/completed/on hold/dropped/plan —, success/warning/danger, overlay scrims for text on images, badge background/foreground) with light/dark values, so screens never hardcode colours. Document them in docs/THEME.md with a usage table.",
      "Theme settings (taken over from settings-theme-about-backup): Material You 'Auto' accent (dynamic_color, Android 12+), custom colour picker (flex_color_picker), keep the 19 presets; the background image path moves off the legacy `UserMal.instance.pref.bgImagePath` (sidebar_bg_manager.dart:240-247) into ThemeBloc / the contract, then delete the reduced lib/user/userpref.dart if nothing else needs it.",
      "Issue #110 item 2: lib/widgets/common/background.dart ignores `forceBg` and decodes the full image — honour it and decode at screen size (AppImage/SizedDecodeImage).",
      "Owner's words: buttons and coloured areas whose colour makes the text unreadable, and dark mode, must be handled properly everywhere. So: every filled/tonal/outlined button, chip, badge, FAB, snackbar, dialog, bottom sheet, nav bar and app bar gets its foreground from the matching `on*` role (onPrimary, onPrimaryContainer, onSurfaceVariant…), never a fixed white/black; text on images always sits on the scrim token; verify AA contrast (4.5:1 text, 3:1 large text/icons) for every accent preset × light/dark/black with a unit test that computes the contrast ratios of the ColorScheme roles you generate.",
      "Dark and black modes: real dark surfaces (no light cards or white sheets left in dark), elevated surfaces distinguishable, images and shimmers adapted, the status bar and navigation bar icons light; black mode = true black backgrounds with readable dark-grey surfaces.",
      "Bottom navigation bar (owner request, screenshot): REMOVE the small underline bar that appears under the active icon; the active tab keeps only its rounded tinted background (pill) and the accent-coloured icon. Inactive icons readable in every theme. Update test/smoke/nav_indicator_test.dart accordingly.",
      "Compare with DailyAL's theme (lib/theme/): keep what is better.",
    ],
    bugs: ["white status bar icons on light themes", "incoherent accent colours", "hardcoded colours", "Background ignores forceBg"],
    dod: ["Widget tests: overlay style per brightness, ColorScheme built from the accent, tokens resolve in light and dark.", "Checker: screenshots of home, detail, list, settings in Spring/Summer/Autumn/Winter light, dark and black: readable status bar, one accent family per theme, no garish leftovers."],
  },
  {
    id: "settings-theme-about-backup", title: "About, backup & restore, clear storage", kind: "screen", priority: "P1", group: "settings", model: "sonnet", ui: true,
    needs: ["theme-colors", "app-shell", "edit-sheet", "bookmarks"],
    owns: ["test/units/app-shell/app_routes_test.dart", "test/units/app-shell/settings_hub_test.dart", "lib/screens/settings/about_settings.dart", "lib/screens/settings/backup_settings.dart", "lib/screens/settings/storage_settings.dart", "lib/cache/cachemanager.dart", "lib/screens/settings/download_settings.dart"],
    dal: ["lib/pages/settings/themesettings.dart", "lib/pages/settings/about.dart", "lib/pages/settings/backup_restore.dart", "lib/cache/cachemanager.dart"],
    goal: [
            "About: version (package_info_plus), changelog, licences, links to goddivor/mywatchlist, and the feedback entry (report a bug / open an issue on goddivor/mywatchlist) — the owner chose to move Help & Feedback here instead of a separate settings page.",
      "Backup & restore UI (JSON export/import) wiring the existing cachemanager methods (:127, :145) + private notes + bookmarks export/import.",
      "Clear app storage / caches.",
          ],
    dod: ["Backup on the emulator, clear storage, restore → bookmarks and private notes are back."],
  },
  {
    id: "notifications", title: "Airing notifications", kind: "unit", priority: "P1", group: "settings", model: "sonnet", ui: true,
    needs: ["perf-foundation", "app-shell", "user-list-mal"],
    owns: ["lib/main.dart", "lib/services/notifications/**", "lib/screens/settings/notifications_settings.dart", "android/app/src/main/res/drawable/ic_stat_notification.xml", "android/app/src/main/res/drawable-*/ic_stat_notification.png"],
    dal: ["lib/notifservice.dart", "lib/pages/settings/notifsettings.dart", "commits 820a295, 92cc38d"],
    goal: ["Use the calendar unit's `AiringSchedule.instance` (`ensureLoaded()`, `nextEpisode(malId)` → episode number + UTC time) as the source of airing times; fall back to the weekly broadcast slot only when it returns null. Schedule airing notifications for watching / plan-to-watch lists (flutter_local_notifications + timezone), large image pref, permission request, test notification, clear and reschedule all, reschedule after boot, open the detail screen from a notification (cold and warm start) through the app-shell hook: read the payload of the notification that launched the app in main.dart and pass it to `OpenScreen(notificationPayload:)`; payload format `anime:<id>`, `manga:<id>`, `calendar`, `bookmarks` (documented in lib/utils/app_routes.dart). Fill the notification_service stub. Also call `ListStatusCache.instance.ensureLoaded()` at startup in main.dart so status badges show from the first frame (user-list-mal finding)."],
    dod: ["Test notification shows on the emulator and opens the right anime."],
  },
  {
    id: "dub-info", title: "Dub info (MyDubList): icons, languages, settings", kind: "unit", priority: "P2", group: "settings", model: "sonnet", ui: true,
    needs: ["cards-upgrade", "app-shell"],
    owns: ["test/units/app-shell/app_routes_test.dart", "lib/cache/dub_info.dart", "lib/screens/settings/dub_settings.dart", "lib/widgets/MAL/home/animegridcard.dart", "lib/widgets/common/dub_icon.dart"],
    dal: ["lib/pages/settings/dubsettings.dart", "lib/cache/dubinfomanager.dart", "commits 17dd437, 6f75ed3"],
    goal: ["Dub status icon on cards (asset MyDubListIcons.ttf is already present), dub languages, min source count, icon style, report/support links; fill the dub settings stub."],
    dod: ["Dub icon visible on dubbed anime cards on the emulator."],
  },
  {
    id: "api-prefs", title: "API layer: NSFW, timezone, Jikan rate limits, MAL maintenance", kind: "unit", priority: "P1", group: "settings", model: "sonnet",
    needs: ["deps-prefs-contract", "mal-auth-calls"],
    owns: ["lib/services/api/MAL/mal_api.dart", "lib/services/api/MAL/mal_user.dart", "lib/services/api/Jikan/**", "lib/services/api/MAL/mal_anime.dart"],
    dal: ["lib/api/malapi.dart", "commit 1d1f930 (rate limit)"],
    goal: ["Send `nsfw=` from the pref; use the timezone pref (mal_api.dart:827, :884); handle Jikan 429 with backoff + caching; expose a `isUnderMaintenance()` helper for home-wiring."],
    dod: ["Rapid navigation on the emulator no longer produces Jikan 429 errors."],
  },

  // ───────────────────────────── Community ─────────────────────────────
  {
    id: "forum-clubs", title: "Forum posting, profile links, club members in-app", kind: "screen", priority: "P2", group: "community", model: "sonnet", ui: true,
    needs: ["mal-auth-calls", "user-profile-mal", "shared-kit"],
    owns: ["lib/screens/forum/**", "lib/widgets/forum/**", "lib/pages/MAL/mal_forum_page.dart", "lib/services/api/MAL/mal_clubs_api.dart", "lib/services/api/MAL/mal_forum_api.dart"],
    dal: ["lib/screens/forumposts.dart", "lib/screens/forumtopicsscreen.dart", "lib/pages/forumpage.dart", "lib/screens/clubscreen.dart"],
    goal: ["MalForumPage:206 pushes SettingsPage directly → `AppRoutes.openSettings` (app-shell finding); Reply FAB only copies the URL (forum_posts_screen.dart:117-126) → open a webview to post (DAL); post avatar → profile (post_widget.dart:346); club members/staff → in-app profile instead of browser (tap = `AppRoutes.openUserPop` quick sheet, as DailyAL; user-profile-mal finding); replace the club scraping in mal_clubs_api.dart by the backend methods `MwlApi.getClubPage/getClubMembers/getClubForumTopics/getClubComments` (backend-parsers finding); HTML parsing off the UI isolate in mal_clubs_api.dart (:20, :34, :61) and the forum API (performance.md #9); share/browser menus; redesign per UI directive."],
    bugs: ["reply FAB", "avatar tap"],
    dod: ["Reply opens the MAL post form in-app on the emulator."],
  },
  {
    id: "featured-characters", title: "Featured tags search, character screen sort/dedupe/bookmark/share", kind: "screen", priority: "P2", group: "community", model: "sonnet", ui: true,
    needs: ["detail-resilience", "search-upgrade", "bookmarks", "detail-synopsis-media"],
    owns: ["lib/services/api/MAL/scrapper/character_page.dart", "lib/screens/MAL/featured_screen.dart", "lib/widgets/MAL/content/show_featured.dart", "lib/widgets/MAL/content/show_forum.dart", "lib/widgets/MAL/content/show_news.dart", "lib/screens/MAL/character_screen.dart", "lib/screens/MAL/characters_staff_screen.dart"],
    dal: ["lib/screens/featurescreen.dart", "lib/widgets/featured/tagswidget.dart", "lib/screens/characterscreen.dart", "commits 01d7daf, bf06d05"],
    goal: ["Featured tags tap → tag search (featured_screen.dart:281 `onTap: null`); character/person: sort voice roles by favorites (with rate-limit toast), dedupe, bookmark FAB, share, bio translation (translator widget).", "Character screen: CustomScrollView + slivers instead of an eager Column in SingleChildScrollView (:251-256); parse off the UI isolate (:129) — performance.md #9, #12."],
    bugs: ["featured tags not tappable"],
    dod: ["Tapping a featured tag opens tag search on the emulator."],
  },

  // ───────────────────────────── Other trackers ─────────────────────────────
  {
    id: "anilist-pages", title: "AniList: home, explore, user list, profile (replace placeholders)", kind: "screen", priority: "P2", group: "trackers", model: "sonnet", ui: true,
    needs: ["user-list-mal", "user-profile-mal", "home-wiring"],
    owns: ["lib/pages/Anilist/**", "lib/services/api/Anilist/**", "lib/widgets/Anilist/**"],
    goal: ["Replace the 5 AniList placeholder pages with real ones reusing the tracker-agnostic list/profile widgets; AniList GraphQL for lists Feed airing notifications for this tracker's Watching / Plan to watch lists by mapping entries to MAL ids (notifications unit API; report the change as a finding if it needs files outside yours). On the preference pages, mark MAL-only options with a visible note for this tracker (report the file change as a finding if the page is not yours). Authenticated calls go through `user.sendAuthenticated` (auth-refresh) instead of hand-built Bearer headers., profile, trending/seasonal; home sections honoring HomePreferencesBloc."],
    dod: ["Owner's AniList list and profile render on the emulator."],
  },
  {
    id: "kitsu-pages", title: "Kitsu: home, explore, user list, profile (replace placeholders)", kind: "screen", priority: "P2", group: "trackers", model: "sonnet", ui: true,
    needs: ["user-list-mal", "user-profile-mal", "home-wiring"],
    owns: ["lib/pages/Kitsu/**", "lib/services/api/Kitsu/**", "lib/widgets/Kitsu/kitsu_*.dart"],
    goal: ["Same as anilist-pages for Kitsu (JSON:API). Feed airing notifications for this tracker's Watching / Plan to watch lists by mapping entries to MAL ids (notifications unit API; report the change as a finding if it needs files outside yours). On the preference pages, mark MAL-only options with a visible note for this tracker (report the file change as a finding if the page is not yours). Authenticated calls go through `user.sendAuthenticated` (auth-refresh) instead of hand-built Bearer headers."],
    dod: ["Owner's Kitsu list renders on the emulator."],
  },
  {
    id: "simkl-pages", title: "Simkl: home, explore, user list, profile (replace placeholders)", kind: "screen", priority: "P2", group: "trackers", model: "sonnet", ui: true,
    needs: ["user-list-mal", "user-profile-mal", "home-wiring"],
    owns: ["lib/pages/Simkl/**", "lib/services/api/SimKl/**", "lib/widgets/Simkl/**"],
    goal: ["Same as anilist-pages for Simkl. Feed airing notifications for this tracker's Watching / Plan to watch lists by mapping entries to MAL ids (notifications unit API; report the change as a finding if it needs files outside yours). On the preference pages, mark MAL-only options with a visible note for this tracker (report the file change as a finding if the page is not yours). Authenticated calls go through `user.sendAuthenticated` (auth-refresh) instead of hand-built Bearer headers."],
    dod: ["Owner's Simkl list renders on the emulator."],
  },

  // ───────────────────────────── Release ─────────────────────────────
  {
    id: "versioning-ci", title: "yyyy.m.n versioning and a release workflow that passes", kind: "unit", priority: "P2", group: "release", model: "sonnet",
    needs: ["deps-prefs-contract"],
    owns: [".github/**", "analysis_options.yaml", "tools/release/**"],
    dal: [".github/workflows/", "update_gradle.sh", "pubspec.yaml version"],
    goal: ["Version scheme yyyy.m.n+code (DAL style) — pubspec is the contract's file: put the version bump script in tools/release/ and report the one-line pubspec change as a finding; release workflow: run tools/l10n/build.sh instead of `flutter gen-l10n` (generated l10n files are no longer in git), create an empty placeholder `assets/.env` before analyze when the secrets are absent, build_runner from dev deps, APK split + universal, sha1."],
    dod: ["Workflow YAML validated with `actionlint` if available, else reviewed line by line in the PR body."],
  },
  {
    id: "l10n-quality", title: "Final translation pass: French (and Arabic) wording of the base and of every unit", kind: "unit", priority: "P2", group: "release", model: "sonnet",
    needs: ["mal-hub-wiring", "anilist-client-limits", "anilist-list-fidelity", "anilist-people-pages", "anilist-search-filters", "anilist-social", "anilist-notifications", "anilist-settings", "anilist-media-page", "anilist-profile-plus", "anilist-home-extras", "mal-episodes", "mal-detail-sidebar", "mal-seasonal-groups", "mal-list-time", "mal-profile-extras", "mal-list-xml", "mal-web-writes-2", "mal-api-small", "mal-notifications", "mal-messages", "ux-polish-2", "home-rows-kinds", "ux-explore", "ux-search", "ux-reviews", "ux-detail-content", "ux-edit-sheet", "ux-calendar", "ux-seasonal", "ux-theme", "ux-home", "ux-stack", "ux-forum", "kitsu-graphql", "kitsu-media-page", "kitsu-community", "kitsu-profile-plus", "kitsu-home-extras", "simkl-api-compliance", "simkl-auth-v2", "simkl-cdn-feeds", "simkl-media-page", "simkl-profile-plus", "simkl-list-sync", "mal-session", "profile-lists", "explore-weekly", "jikan-leftovers", "bookmarks-everywhere", "home-rows", "launch-update-check", "small-fixes", "tenrai-client", "splash-screen", "stack-polish", "color-sweep", "backup-fixes", "release-fixes", "explore-polish", "tracker-wiring", "gate-fix", "auth-refresh", "backend-parsers", "mal-auth-calls", "l10n-pipeline", "deps-prefs-contract", "app-shell", "detail-split", "shared-kit", "perf-foundation", "accounts-ux", "edit-sheet", "user-list-mal", "user-profile-mal", "sync-dialog", "detail-header", "detail-related-graph", "detail-synopsis-media", "detail-social", "detail-more-info", "bookmarks", "calendar", "explore-seasonal", "search-upgrade", "home-wiring", "cards-upgrade", "settings-prefs-pages", "settings-theme-about-backup", "notifications", "dub-info", "api-prefs", "forum-clubs", "featured-characters", "anilist-pages", "kitsu-pages", "simkl-pages", "versioning-ci", "in-app-update", "deep-links"],
    owns: ["lib/services/updater/update_controller.dart", "lib/l10n/units/*/intl_fr_FR.arb", "lib/l10n/intl_fr_FR.arb", "lib/l10n/intl_ar_EG.arb", "lib/l10n/units/l10n-pipeline/**"],
    goal: ["Update dialog download sizes: replace the duplicated English-only formatBytes in lib/services/updater/update_controller.dart with the shared locale-aware one from storage_settings.dart (backup-fixes PR #175).", 
      "The base ARB files are DailyAL's machine-quality translations. Review intl_fr_FR.arb entirely: fix mistranslations (e.g. `About` = « Sur » → « À propos »), untranslated entries (Spanish, German, Indonesian at :595-598), capitalisation (« turc » next to « Portugais », :856), French typography (non-breaking space before : ; ! ?, « » quotes, no em dash). The French must be flawless: follow the redaction-francais rules if available to you.",
      "Base French (detail-header finding): `Close` = « proche » → « Fermer », `Pictures` = « Des photos » → « Images », `Aired` and `Users` untranslated. Base French: `Streaming_Platforms` has a stray trailing comma (« Plateformes de streaming, »). Base French fixes seen on the settings hub (batch-2 check): `About` = « Sur » (intl_fr_FR.arb:154) → « À propos »; `Dub_Settings` = « Signaler les doublages inexacts » (:685) → « Doublage ». Add the missing French fragments of merged units that shipped English only (e.g. lib/l10n/units/perf-foundation/: Image_Saved, Image_Save_Failed, Image_Share_Failed, Image_Share_Text) — scan every lib/l10n/units/*/ for keys without intl_fr_FR.",
      "Batch-4 French list: rankings « Tous les favoris de temps », « Top ça », « Top téléviseurs », « Haut ELLE » (Top ONA), « Top Airing Anime » untranslated; genres « action » lowercase, « Récompensé Gagnant », « Les filles aiment », « SLICE OF LIFE », « Des sports », « Le suspense », « Supernatural »; theme chips « Chuté », « Complété », « En train de regarder »; settings « Sauvegarde sur le cloud » (it is a local JSON file), « Signaler les doublages inexacts » as dub settings title, « …le taux et l'examen » under About; « Sur » (About).",
      "Add the Arabic translations missing for the l10n-pipeline unit's own strings (language picker: 'Use system language', its description, 'Available languages').",
      "Never rename or remove a key; only values change. Run tools/heavy.sh tools/l10n/build.sh.",
    ],
    dod: ["Checker: switch to French, no English left on the language picker; About tile reads « À propos »."],
  },
  {
    id: "color-sweep", title: "Colour sweep: hardcoded colours of already-merged screens onto the theme tokens", kind: "unit", priority: "P1", group: "release", model: "sonnet", ui: true,
    needs: ["stack-polish", "tracker-followups", "search-sources", "explore-polish", "profile-tabs", "theme-seasons", "detail-polish", "home-fixes", "backup-fixes", "tracker-wiring", "profile-polish", "list-cards-dal", "detail-resilience", "home-wiring", "featured-characters", "dub-info", "detail-more-info", "settings-theme-about-backup", "in-app-update", "forum-clubs", "search-upgrade", "theme-colors", "cards-upgrade", "detail-header", "detail-social", "detail-related-graph", "detail-synopsis-media", "user-list-mal", "user-profile-mal", "edit-sheet", "sync-dialog", "bookmarks", "calendar", "explore-seasonal", "settings-prefs-pages", "accounts-ux", "app-shell", "shared-kit", "notifications"],
    owns: ["lib/widgets/loading/**", "lib/widgets/MAL/home/**", "lib/widgets/MAL/content/**", "lib/widgets/MAL/review/**", "lib/widgets/user/**", "lib/widgets/charts/**", "lib/widgets/bookmarks/**", "lib/widgets/calendar/**", "lib/widgets/common/**", "lib/screens/MAL/**", "lib/screens/explore/**", "lib/screens/seasonal/**", "lib/screens/calendar/**", "lib/screens/user_profile/**", "lib/screens/settings/**", "lib/screens/bookmarks_screen.dart", "lib/pages/side_bar.dart", "lib/constants/constants.dart"],
    goal: ["Duplicate ☰ (owner, explore-polish PR #172 finding): every page under the home shell that shows the home header must not get Flutter's automatic endDrawer button — `actions: const [SizedBox.shrink()]` (an empty list does not suppress it; automaticallyImplyActions does not exist in Flutter 3.35.6): lib/pages/MAL/mal_home_page.dart:192 and the AniList / Kitsu / Simkl home and explore pages. Also call `ExploreImages.registerLicense()` from main.dart so the DailyAL licence is always listed.", 
      "Replace every hardcoded `Colors.*` / `Color(0x…)` in the owned screens with `colorScheme` roles or the app_colors tokens (theme-colors), except intrinsic content colours (e.g. a tracker's brand logo) — list those exceptions in the PR body.",
      "Dub badge on cards uses a literal dark scrim + white glyph (dub-info): use the badge/scrim tokens. Known spots (detail-resilience finding): `reviewScoreColor` in lib/widgets/MAL/review/review_logic.dart (hardcoded green/amber/red → score tokens); lib/widgets/common/avatar_widget.dart (white shimmer box and old fallback image → themed placeholder + clean circle like the detail sections); `getStatusColorInt` and `loadingGraph` in lib/constants/constants.dart.",
      "Seasonal grid spacing: lib/screens/seasonal/seasonal_screen.dart (~282-286, ~323-327) still uses 8/10/10 — reuse `listGridDelegate` / `listGridPadding` from lib/widgets/user/list/user_list_tab.dart (DailyAL gaps, fix #143).",
      "Batch-4 check: Plan to watch is orange and On hold yellow (old functions) in the edit sheet status dot (lib/widgets/user/edit/edit_labels.dart:19-26, edit_fields.dart:76,135), the sync widget (lib/widgets/user/cross_tracker_widget.dart:449) and home cards (lib/widgets/MAL/home/animegridcard.dart:1118): use the status tokens; remove/redirect the legacy getStatusColor in constants.dart:585. My List badges in dark/black: red badge salmon with dark-red text, blue badge black text — keep solid blue/red with white text like DailyAL in every mode. Calendar day pill cut to « Aujourd'» (lib/widgets/calendar/**).",
      "Check each screen in light, dark and black themes for contrast: no button, chip, badge or coloured area where the text is unreadable (owner's complaint); text on images uses the scrim token; no light surface left in dark mode.",
    ],
    dod: ["`grep -rnE \"Colors\\.|Color\\(0x\" lib/<owned>` only shows the documented exceptions.", "Checker: screenshots in light/dark/black of each touched screen."],
  },
  {
    id: "app-icon", title: "Circular adaptive launcher icon like DailyAL", kind: "unit", priority: "P0", group: "release", model: "sonnet",
    needs: ["deps-prefs-contract"],
    owns: ["pubspec.yaml", "android/app/src/main/res/mipmap-*/**", "android/app/src/main/res/mipmap-anydpi-v26/**", "android/app/src/main/res/values/ic_launcher_background.xml", "assets/images/app_icon/**", "ios/Runner/Assets.xcassets/AppIcon.appiconset/**", "tools/icon/**"],
    dal: ["android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml (adaptive icon: background + foreground + monochrome)", "android/app/src/main/res/mipmap-*/ic_launcher_foreground.png"],
    goal: [
      "Owner: 'why is the icon not circular like DailyAL's? fix it'. Today MWL ships no adaptive icon (no mipmap-anydpi-v26/ic_launcher.xml): Android puts the square dark mwl-black-bg.png logo inside its own teal circle. DailyAL ships an adaptive icon: a full dark circle with the white logo centred.",
      "Build an adaptive icon: foreground = only the white 'mwL' letters on a TRANSPARENT background, extracted from assets/images/mwl-black-bg.png (1024×1024) — e.g. with ImageMagick in a script kept in tools/icon/ (threshold the near-white pixels to an alpha mask, keep anti-aliasing), scaled to sit inside the 66 % safe zone; background = the logo's dark navy gradient (sample its colours) as a colour or a background PNG; monochrome = the letters only (Android 13 themed icons). Keep the legacy square/round mipmaps for old Android, generated from the same layers so they also look circular on round launchers.",
      "Prefer flutter_launcher_icons (already a dev dependency, config `flutter_icons:` in pubspec.yaml): set adaptive_icon_background / adaptive_icon_foreground / adaptive_icon_monochrome and regenerate with `tools/heavy.sh dart run flutter_launcher_icons`; commit the generated res files. iOS keeps a square icon (iOS masks it itself).",
    ],
    dod: ["mipmap-anydpi-v26/ic_launcher.xml (+ ic_launcher_round.xml) exist with background/foreground/monochrome.", "Checker: launcher screenshot on the emulator next to DailyAL — a full dark circle with the white mwL letters, no square inside."],
  },
  {
    id: "search-sources", title: "Search: every filter returns data without Jikan (MAL search page fallback, live-verified) + studios directory with logos", kind: "unit", priority: "P0", group: "discovery", model: "opus", ui: true,
    needs: ["search-upgrade", "profile-tabs"],
    owns: ["lib/screens/search/**", "lib/widgets/MAL/search/**", "lib/screens/studios/**", "mwl-api/**", "lib/services/api/mwl_api.dart", "lib/services/api/MAL/scrapper/mal_scrapper.dart", "tools/search-live/**"],
    dal: ["lib/screens/generalsearchscreen.dart", "dal-api/ search routes"],
    goal: [
      "Owner: filtering the anime search by a producer/studio (e.g. Arch) shows 'Couldn't load the results. Check your connection' — filtered searches go through Jikan, unreachable on his network, and the official MAL API only searches by name, rankings and seasons. A specific filter like a studio must return data; only absurd filter combinations may return nothing; never a connection error when the network works.",
      "AUDIT AND FIX EVERY SEARCH PATH (anime and manga): text, genres/themes/demographics (include/exclude), producers/studios/licensors, magazines, season/year, type, status, rating, score min/max, start/end dates, sort/order, pagination. For each, a source that works without Jikan: the official MAL API where it can, else MAL's own search page (https://myanimelist.net/anime.php with q, type, score, status, p, r, sm/sd/sy, em/ed/ey, c[], gx, genre[], o, w, and the /anime/producer/<id>, /anime/genre/<id>, /manga/magazine/<id> pages) scraped through mwl-api routes with HTML fixtures; Jikan only as a fast path when it answers. Translate MWL's filter model to these URLs exactly.",
      "LIVE VERIFICATION (owner: test every scraping method, it must return data): a script in tools/search-live/ that runs each filter once against the real MAL site (rate-limited, at most 1 request per second) and prints filter → result count; every single filter (studio Arch, a genre, a magazine, a season, each type/status/rating…) must return more than 0. Paste its full output in the PR body. Unit tests stay offline (fixtures).",
      "STUDIOS DIRECTORY (owner request): lib/screens/studios/studios_screen.dart (`StudiosScreen`) listing ALL studios with their NAME and LOGO (the mwl-api `studios` route + MAL producer pages / company logos — the owner's existing scraping in mwl-api and lib/services/api/MAL/scrapper/mal_scrapper.dart fetched the images: read it, fix it, test it live), infinite scroll (loads more when scrolling down), search box, tap → `GeneralSearchScreen.byStudio` (the anime of that studio). explore-polish adds the Explore entry button — document the constructor in the PR body.",
      "Error states say what failed (no network vs source failed vs no result), translated; theme tokens only; AppImage at tile size; parse off the UI isolate.",
    ],
    dod: ["tools/search-live output in the PR: every filter returns more than 0 results.", "Checker: studio Arch and a genre filter return anime on the owner's network; the studios directory scrolls with logos and opens the filtered search."],
  },
  {
    id: "tracker-followups", title: "Tracker follow-ups: removed rows disappear, Simkl list categories, notifications for every tracker", kind: "unit", priority: "P1", group: "trackers", model: "sonnet", ui: true,
    needs: ["tracker-wiring"],
    owns: ["lib/pages/Anilist/anilist_home_page.dart", "lib/pages/Anilist/anilist_explore_page.dart", "lib/pages/Kitsu/kitsu_home_page.dart", "lib/pages/Kitsu/kitsu_explore_page.dart", "lib/pages/Simkl/simkl_home_page.dart", "lib/pages/Simkl/simkl_explore_page.dart", "lib/main.dart", "test/units/drawer-icon/**", "lib/widgets/Anilist/**/anilist_user_list_adapter.dart", "lib/widgets/Kitsu/**/kitsu_user_list_adapter.dart", "lib/widgets/user/cross_tracker_widget.dart", "lib/pages/Simkl/**/simkl_user_page.dart", "lib/screens/settings/notifications_settings.dart", "lib/services/notifications/**"],
    goal: [
      "Findings of tracker-wiring (PR #168): the AniList and Kitsu list adapters and cross_tracker_widget.dart must drop the row when the editor returns `saved.isRemoved` (today the removed row stays as a status-less entry until refresh).",
      "simkl_user_page.dart passes `categories: const ['anime']` to UserListView and drops its title workaround.",
      "notifications_settings.dart no longer says 'needs MyAnimeList' when AniList, Kitsu or Simkl is connected (they now feed the planner); switching the active tracker reschedules notifications (listen to AccountBloc).",
    ],
    dod: ["Tests with fakes: removed row disappears; Simkl list has no manga switch; tracker switch reschedules; never writes to the owner's trackers."],
  },
  {
    id: "stack-polish", title: "Interest stack page: squeezed covers, localized date, readable tabs (DailyAL layout)", kind: "unit", priority: "P0", group: "detail", model: "sonnet", ui: true,
    needs: ["detail-polish"],
    owns: ["lib/screens/MAL/interest_stack_detail_screen.dart"],
    dal: ["lib/pages/animedetailed/intereststackwidget.dart", "lib/screens/contentdetailedscreen.dart (interest stack screen)"],
    goal: [
      "Owner screenshot of an interest stack page (Cgdct by Nih_000): the entry covers are thin 35 px strips — `AvatarWidget(height: 150.0, …)` at interest_stack_detail_screen.dart:~709 sets no width, so it takes AvatarWidget's default 35. Give the covers DailyAL's proportions (100 x 150, AppImage decoded at that size), same for the loading skeleton.",
      "Compare the whole page with DailyAL's stack screen and fix what is worse: the date 'Oct 27 2026, 1:37 AM' must follow the app locale (DateFormat with S locale); the third tab 'MyAnimeList stack…' is cut — labels fully readable (translated, shorter label or proper scrollable tabs); header title/author/description readable in light, dark and black; theme tokens only.",
      "Grep the repo for other `AvatarWidget(` calls used as covers (height > 60) without a width and list them in the PR body as findings (do not edit files you do not own).",
    ],
    dod: ["Widget test: an entry cover is 100 x 150; the date is formatted in French under fr_FR.", "Checker: the owner's stack page side by side with DailyAL."],
  },
  {
    id: "splash-screen", title: "Launch splash like DailyAL: MWL logo centred on a dark background", kind: "unit", priority: "P1", group: "release", model: "sonnet", ui: true,
    needs: ["app-icon", "release-fixes"],
    owns: ["android/app/src/main/res/values/**", "android/app/src/main/res/values-night/**", "android/app/src/main/res/values-v31/**", "android/app/src/main/res/values-night-v31/**", "android/app/src/main/res/drawable/**", "android/app/src/main/res/drawable-v21/**", "android/app/src/main/res/drawable-*/splash*", "lib/main.dart"],
    dal: ["android/app/src/main/res (system splash = launcher icon on a dark window background)"],
    goal: [
      "Owner (screenshot of DailyAL starting): when the app launches, show what DailyAL shows — the app logo centred on a dark navy background — but with MyWatchList's own logo (the round launcher icon from app-icon / assets/images/mywatchlist-logo.png).",
      "Android 12+ system splash (values-v31 / values-night-v31: windowSplashScreenBackground dark, windowSplashScreenAnimatedIcon = the MWL adaptive icon foreground, icon background if needed) and the pre-12 launch_background.xml with the same dark colour and centred logo; NormalTheme background matches so there is no white flash between the splash and Flutter's first frame. Same look in light and dark system modes, like DailyAL.",
      "No new dependency unless needed (flutter_native_splash only if hand-written resources cannot do it; justify).",
    ],
    dod: ["Test that the v31 styles reference the splash background and icon; checker: cold start on the emulator shows the MWL logo on dark, no white flash."],
  },
  {
    id: "tenrai-client", title: "Tenrai API client (all endpoints) and automatic Jikan → Tenrai failover", kind: "unit", priority: "P0", group: "foundation", model: "opus",
    needs: ["detail-polish", "search-sources"],
    owns: ["lib/services/api/Jikan/**", "lib/services/api/Tenrai/**", "lib/services/api/jikan_source.dart", "lib/screens/search/search_service.dart", "lib/widgets/user/list/mal_user_list_adapter.dart", "mwl-api/mwl_commons/lib/src/constants/constant.dart", "mwl-api/lib/**", "test/units/tenrai-client/**", "tools/tenrai-live/**"],
    goal: [
      "Owner: Jikan is down (confirmed); Tenrai (https://api.tenrai.org/v1, docs https://api.tenrai.org/documentation, OpenAPI https://api.tenrai.org/documentation/openapi.json, 103 GET paths) is a free unofficial MAL API that follows the Jikan v4 schema. 'Like the big class that handles the whole Jikan API, implement Tenrai too (every endpoint), and switch to Tenrai when Jikan is unavailable.'",
      "Build `TenraiApi` / `TenraiClient` in lib/services/api/Tenrai/ covering EVERY endpoint of the OpenAPI spec (anime, manga, characters, people, producers, genres, magazines, random, recommendations, top, seasons, reviews, schedules, news, articles, stacks, ids, unapproved/denied/deleted…) with typed query parameters, reusing the existing Jikan models where the schema matches (same envelope `data` / `pagination`). Public tier: 120 req/min, 4 req/s, 429 + Retry-After → client-side throttle and back-off. No server key (never ship a key in the app).",
      "Failover: a shared source selector (e.g. `JikanSource`) used by JikanClient/JikanApi and every direct Jikan URL in the app (constants.dart jikanV4*, search_service.dart _jikanBase, mal_user_list_adapter.dart): try Jikan; when Jikan times out / 5xx / DNS-fails, mark it down (circuit breaker, re-probe after a few minutes) and send the same request to Tenrai; endpoints Tenrai lacks (/users, /clubs, /watch, /userupdates, random/users) keep Jikan + the existing MAL-page fallbacks. JikanFallbacks.race keeps working, with Tenrai as the second fast source before the MAL scrape. Also switch mwl-api's Jikan base the same way.",
      "Live verification: tools/tenrai-live/ script calls each Tenrai endpoint once (≤ 2 req/s) and prints path → status/count; paste the output in the PR. Unit tests offline with fixtures; a test where Jikan is dead shows Tenrai answering.",
    ],
    dod: ["Every OpenAPI path has a client method (generated table in the PR body).", "With Jikan unreachable, detail sections, characters, people, top, seasons, search filters answer from Tenrai (checker on the owner's network)."],
  },
  {
    id: "profile-lists", title: "Other users' anime/manga lists, weekly tab and sidebar shortcuts like DailyAL", kind: "unit", priority: "P1", group: "user", model: "opus", ui: true,
    needs: ["mal-session", "color-sweep", "explore-weekly"],
    owns: ["lib/screens/user_profile/sections/**", "lib/screens/user_profile/user_profile_view.dart", "lib/screens/user_profile/sections/list_section.dart", "lib/screens/user_profile/sections/weekly_section.dart", "lib/widgets/user/list/mal_user_list_adapter.dart", "lib/widgets/user/profile/user_pop_sheet.dart", "lib/pages/side_bar.dart", "lib/utils/app_routes.dart", "lib/l10n/units/profile-lists/**", "test/units/profile-lists/**"],
    goal: ["Wire mal-session (PR #220): add `UserProfileTab.comments => CommentsSection(username: data.username)` with label `S.current.Ms_Comments_Tab` to the profile tabs, on the owner's and other users' profiles (owner wants it everywhere).", "Also UI report docs/ui-check-report-2026-10-28.md group D items 9-11 (List tab first for other users, remove U10/U11, label facts, duplicate club rows, DailyAL icon tab strip) and group N item 22 (replicate DailyAL's sidebar items, drop Profile/Stats duplicates).", "DailyAL feature-gap audit docs/dal-gap-report-2026-10-28.md: items P1, P2, P3, P5, L1 and the profile part of D3. Read those items (DailyAL and MWL file:line, gap, effort) and implement them.", "Owner rules: replicate DailyAL's UI where MWL's would be weaker; no explanatory captions or helper text DailyAL lacks; theme tokens only; full translatability (English + French)."],
    dod: ["Checker compares with DailyAL on the owner's network (Jikan down)."],
  },
  {
    id: "explore-weekly", title: "Weekly anime per season (MAL broadcast weekday) and Random without Jikan", kind: "unit", priority: "P1", group: "discovery", model: "opus", ui: true,
    needs: ["color-sweep"],
    owns: ["lib/screens/weekly/**", "lib/screens/explore/explore_sections.dart", "lib/screens/explore/explore_data.dart", "lib/screens/explore/random_picker.dart", "lib/screens/seasonal/seasonal_screen.dart", "lib/services/api/MAL/mal_api.dart", "lib/l10n/units/explore-weekly/**", "test/units/explore-weekly/**"],
    goal: ["DailyAL feature-gap audit docs/dal-gap-report-2026-10-28.md: items W1, E1, E2. Read those items (DailyAL and MWL file:line, gap, effort) and implement them.", "Owner rules: replicate DailyAL's UI where MWL's would be weaker; no explanatory captions or helper text DailyAL lacks; theme tokens only; full translatability (English + French)."],
    dod: ["Checker compares with DailyAL on the owner's network (Jikan down)."],
  },
  {
    id: "jikan-leftovers", title: "Videos, user updates and user probe without Jikan", kind: "unit", priority: "P1", group: "detail", model: "opus", ui: true,
    needs: ["tenrai-client", "color-sweep"],
    owns: ["lib/screens/MAL/detail/sections/featured_section.dart", "lib/screens/MAL/detail/section_frame.dart", "lib/widgets/MAL/content/show_featured.dart", "lib/screens/MAL/detail/detail_screen.dart", "lib/widgets/MAL/content/userupdate_widget.dart", "lib/services/api/Jikan/jikan_fallbacks.dart", "lib/services/api/mwl_api.dart", "mwl-api/lib/handlers/handler_core.dart", "mwl-api/mwl_commons/**", "lib/screens/search/search_service.dart", "test/units/jikan-leftovers/**"],
    goal: ["From PR #227: hide the whole Featured Articles section (title row and tab) when it has no articles \u2014 show_featured.dart must report empty to lib/screens/MAL/detail/sections/featured_section.dart / section_frame.dart.", "DailyAL feature-gap audit docs/dal-gap-report-2026-10-28.md: items D1, D2, D4, E3 \u2014 use the Tenrai failover from tenrai-client first; MAL-page scraping only for what Tenrai lacks (/userupdates). Read those items (DailyAL and MWL file:line, gap, effort) and implement them.", "Owner rules: replicate DailyAL's UI where MWL's would be weaker; no explanatory captions or helper text DailyAL lacks; theme tokens only; full translatability (English + French)."],
    dod: ["Checker compares with DailyAL on the owner's network (Jikan down)."],
  },
  {
    id: "bookmarks-everywhere", title: "Bookmarks on forum topics, clubs, articles and stacks", kind: "unit", priority: "P1", group: "discovery", model: "opus", ui: true,
    needs: ["color-sweep"],
    owns: ["lib/cache/bookmarks.dart", "lib/widgets/bookmarks/**", "lib/screens/bookmarks_screen.dart", "lib/screens/forum/forum_posts_screen.dart", "lib/screens/forum/club_screen.dart", "lib/screens/MAL/featured_screen.dart", "lib/screens/MAL/interest_stack_detail_screen.dart", "lib/l10n/units/bookmarks-everywhere/**", "test/units/bookmarks-everywhere/**"],
    goal: ["DailyAL feature-gap audit docs/dal-gap-report-2026-10-28.md: item D3 (except profile). Read those items (DailyAL and MWL file:line, gap, effort) and implement them.", "Owner rules: replicate DailyAL's UI where MWL's would be weaker; no explanatory captions or helper text DailyAL lacks; theme tokens only; full translatability (English + French)."],
    dod: ["Checker compares with DailyAL on the owner's network (Jikan down)."],
  },
  {
    id: "home-rows", title: "Home rows honour the 30-item slider; OVA/ONA and manhwa/manhua/novel rows", kind: "unit", priority: "P1", group: "discovery", model: "opus", ui: true,
    needs: ["color-sweep"],
    owns: ["lib/user/requests/requests_bloc.dart", "lib/user/MAL/mal_home_page_preferences.dart", "lib/pages/MAL/mal_home_page.dart", "lib/screens/settings/mal_home_settings.dart", "lib/l10n/units/home-rows/**", "test/units/home-rows/**"],
    goal: ["DailyAL feature-gap audit docs/dal-gap-report-2026-10-28.md: items H2, H3. Read those items (DailyAL and MWL file:line, gap, effort) and implement them.", "Owner rules: replicate DailyAL's UI where MWL's would be weaker; no explanatory captions or helper text DailyAL lacks; theme tokens only; full translatability (English + French)."],
    dod: ["Checker compares with DailyAL on the owner's network (Jikan down)."],
  },
  {
    id: "launch-update-check", title: "Check for an app update at launch like DailyAL", kind: "unit", priority: "P1", group: "release", model: "opus", ui: true,
    needs: ["color-sweep"],
    owns: ["lib/screens/home_screen.dart", "lib/services/updater/update_controller.dart", "lib/l10n/units/launch-update-check/**", "test/units/launch-update-check/**"],
    goal: ["DailyAL feature-gap audit docs/dal-gap-report-2026-10-28.md: item H1. Read those items (DailyAL and MWL file:line, gap, effort) and implement them.", "Owner rules: replicate DailyAL's UI where MWL's would be weaker; no explanatory captions or helper text DailyAL lacks; theme tokens only; full translatability (English + French)."],
    dod: ["Checker compares with DailyAL on the owner's network (Jikan down)."],
  },
  {
    id: "small-fixes", title: "Dead settings switches, dub icon on cards and tiles, report recommendation, backup keys", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: ["mal-messages", "profile-lists", "ux-edit-sheet", "mal-session", "color-sweep"],
    owns: ["lib/screens/user_profile/sections/friends_section.dart", "test/units/home-wiring/home_preferences_test.dart", "test/units/profile-tabs/profile_tabs_test.dart", "lib/user/requests/requests_bloc.dart", "lib/widgets/MAL/home/news_widget.dart", "lib/l10n/units/home-wiring/**", "lib/widgets/user/edit/edit_fields.dart", "test/units/edit-sheet/**", "lib/screens/settings/accounts_settings.dart", "lib/widgets/forum/post_widget.dart", "lib/widgets/user/list/cards/entry_parts.dart", "lib/widgets/user/list/cards/entry_cards.dart", "lib/screens/search/search_tiles.dart", "lib/cache/cachemanager.dart", "lib/user/preferences/notification_preferences.dart", "lib/l10n/units/small-fixes/**", "test/units/small-fixes/**"],
    goal: ["From mal-messages PR #264: friend rows get a 'Message' action calling `openComposeMalMessage(context, to: friend.username)` (friends_section.dart).", "From simkl-auth-v2 PR #234: in Settings > Accounts, when `UserSimklV2.instance.canUpgradeToV2` is true, offer a one-tap 'Reconnect Simkl' that calls `SimklAuthV2().handleSignIn`.", "From profile-lists PR #231: remove the 'Friends since' text from friend rows entirely (owner rule, U11) in lib/screens/user_profile/sections/friends_section.dart and update test/units/profile-tabs/profile_tabs_test.dart:299.", "From ux-home PR #229: requests_bloc.dart current-season row still asks sort=anime_score \u2014 sort by members like DailyAL; news card titles regular weight (lib/widgets/MAL/home/news_widget.dart, not ExtraBold); home settings row 'Anime News' \u2192 'News' (Hw_Sec_News in lib/l10n/units/home-wiring/).", "Owner rule (no captions DailyAL lacks): remove the edit sheet's 'of 64' episode hint and '10 \u00b7 Masterpiece' score hint (lib/widgets/user/edit/edit_fields.dart), and update the edit-sheet unit tests that pin them.", "Wire mal-session (PR #220): in Settings > Accounts, the MyAnimeList tile opens `MalSessionSettingsPage` (state, check, disconnect, connect).", "DailyAL feature-gap audit docs/dal-gap-report-2026-10-28.md: items F1, L2, B1, S1 (detailsExpanded / showOnlyLastQuote switches that do nothing, search history + recently opened in backups, community recommendation Report action). Read those items (DailyAL and MWL file:line, gap, effort) and implement them.", "Owner rules: replicate DailyAL's UI where MWL's would be weaker; no explanatory captions or helper text DailyAL lacks; theme tokens only; full translatability (English + French)."],
    dod: ["Checker compares with DailyAL on the owner's network (Jikan down)."],
  },
  {
    id: "mal-session", title: "Optional MAL website session (WebView login, native cookies, CSRF client) + profile comments", kind: "unit", priority: "P0", group: "foundation", model: "opus", ui: true,
    needs: ["color-sweep"],
    owns: ["lib/services/auth/**", "lib/widgets/auth/**", "android/app/src/main/kotlin/**", "lib/services/api/MAL/web/**", "lib/services/auth/mal_web_session*.dart", "lib/screens/settings/mal_session_settings.dart", "lib/widgets/user/profile/profile_comments*.dart", "lib/screens/user_profile/sections/comments_section.dart", "lib/l10n/units/mal-session/**", "test/units/mal-session/**", "pubspec.yaml"],
    goal: ["OWNER DECISION (overrides the separate-screen idea below): the website session is connected AUTOMATICALLY at MAL login. The OAuth flow already runs in our in-app WebView (AuthWebView) on myanimelist.net, where the user types his MAL credentials, so the WebView ends up holding MAL's website cookies: when the OAuth redirect to mywatchlist://callback arrives, read ALL myanimelist.net cookies natively (incl. HttpOnly) from that same WebView and store them with the tokens in FlutterSecureStorage (session data + cookies + csrf when read). If the cookies are missing (e.g. an older login), offer a one-tap reconnect that reopens the same login; the settings screen only shows the session state and a disconnect. Sign-out clears tokens and cookies together. Add lib/services/auth/** files of the MAL OAuth flow to what you may edit.", 
      "Reports: docs/malclient-report-2026-10-28.md and docs/malclient-fork-report-2026-10-28.md (how MALClient logs in to MAL's website and writes). MAL's official API has no endpoint for comments, forum, messages, friends, clubs, favourites or notifications; MALClient used the website session.",
      "Step 0 (foundation): an optional 'Connect MyAnimeList website' screen in settings: in-app WebView opens https://myanimelist.net/login.php (reCAPTCHA → never automate credentials), on landing back on myanimelist.net read ALL cookies natively (Android CookieManager.getCookie via a small MethodChannel in MainActivity, or flutter_inappwebview — justify), store them in FlutterSecureStorage, never log them; a `MalWebClient` (dio or http) that sends the cookies, reads `<meta name='csrf_token'>` from the home page and adds it to every POST form, checks the session with GET /editprofile.php?go=myoptions (200 = valid), and clears on logout/expiry with a clear translated state. OAuth stays the main login.",
      "Profile comments: READ them on every profile (no session needed: the comments block on /profile/<name>, desktop UA) as a Comments tab/section like MALClient; POST a comment (POST /addcomment.php form, see reports), reply (area=2) and delete (ajax.inc.php?t=78) when the session is connected; conversation view (/comtocom.php).",
      "Real write test (owner approved, his account goddivor): ONLY on his own profile: post one comment, verify it appears, delete it, verify it is gone. Never write anywhere visible to other people. If the owner must log in on the emulator WebView, stop and tell the orchestrator the exact step.",
      "Owner rules: replicate MALClient/DailyAL UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French.",
    ],
    dod: ["Offline tests on saved pages (comments block, csrf meta, form fields).", "Live: comment posted then deleted on goddivor's profile (screenshots)."],
  },
  {
    id: "kitsu-graphql", title: "kitsu-graphql", kind: "unit", priority: "P1", group: "trackers", model: "sonnet", ui: false,
    needs: ["tracker-followups"],
    owns: ["lib/services/api/Kitsu/kitsu_graphql.dart", "test/units/kitsu-graphql/**"],
    goal: ["Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `kitsu-graphql`: Read-only GraphQL client (`POST /api/graphql`, anonymous or with the token through `sendAuthenticated`), error mapping to `KitsuHttpError` / `KitsuSessionExpired`, `page`/`first` helpers, fixtures Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.", "Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only)."],
    dod: ["Offline tests on saved responses/pages; checker on the owner's accounts (read-only)."],
  },
  {
    id: "kitsu-media-page", title: "kitsu-media-page", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["kitsu-graphql", "tracker-followups"],
    owns: ["test/units/kitsu-pages/kitsu_browse_test.dart", "lib/widgets/Kitsu/kitsu_user_list_adapter.dart", "lib/pages/Kitsu/kitsu_media_page.dart", "lib/services/api/Kitsu/kitsu_media_detail.dart", "lib/widgets/Kitsu/media/**", "lib/widgets/Kitsu/kitsu_open.dart", "lib/widgets/Kitsu/kitsu_media_tile.dart", "lib/l10n/units/kitsu-media-page/**", "test/units/kitsu-media-page/**"],
    goal: ["Owner bug 2026-10-29: tapping a title in the Kitsu list says it has no MyAnimeList page. Every Kitsu entry point opens the native Kitsu title page through kitsu_open.dart (openKitsuTitle), whether or not Kitsu maps it to MAL: kitsu_user_list_adapter.dart open(), and the helpers the home rows, search tiles and related use; remove the Kitsu_No_Mal_Match dead end.", "(kitsu-community #275) link the title page to KitsuMediaDiscussionPage(kind:, mediaId:, title:) for the title's discussions.", "Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `kitsu-media-page`: Native Kitsu title page: header (cover, banner, rating, rank, users, favourites), rating histogram (A1), where to watch (A3), episodes (A4) or chapters (A5), related (A6), top reactions (A7), latest posts preview (A8), characters/staff/studios when present (A9), trailer (A10), category chips (A11), external ids; titles without MAL mapping become openable Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.", "Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only)."],
    dod: ["Offline tests on saved responses/pages; checker on the owner's accounts (read-only)."],
  },
  {
    id: "kitsu-community", title: "kitsu-community", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["kitsu-graphql", "tracker-followups"],
    owns: ["lib/pages/Kitsu/kitsu_forum_page.dart", "lib/pages/Kitsu/kitsu_post_page.dart", "lib/pages/Kitsu/kitsu_group_page.dart", "lib/services/api/Kitsu/kitsu_feed.dart", "lib/widgets/Kitsu/feed/**", "lib/l10n/units/kitsu-community/**", "test/units/kitsu-community/**"],
    goal: ["Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `kitsu-community`: Forum tab: Latest (global feed B1), News (group 596, B2), Groups (B3) with group feed, post page with comment thread (B4), media discussion page reused by the title page link Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.", "Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only)."],
    dod: ["Offline tests on saved responses/pages; checker on the owner's accounts (read-only)."],
  },
  {
    id: "kitsu-profile-plus", title: "kitsu-profile-plus", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["kitsu-graphql", "tracker-followups"],
    owns: ["lib/widgets/Kitsu/kitsu_profile_view.dart", "lib/widgets/Kitsu/profile/**", "lib/services/api/Kitsu/kitsu_profile.dart", "lib/services/api/Kitsu/kitsu_social.dart", "lib/pages/Kitsu/kitsu_user_profile_page.dart", "lib/l10n/units/kitsu-profile-plus/**", "test/units/kitsu-profile-plus/**"],
    goal: ["Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `kitsu-profile-plus`: Profile tabs Activity (C1), Reactions (C2), Posts (C3), followers/following lists (C4), favourite characters/people (C6), social links and counters (C7), other users' list (C9), user search (C8) Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.", "Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only)."],
    dod: ["Offline tests on saved responses/pages; checker on the owner's accounts (read-only)."],
  },
  {
    id: "kitsu-home-extras", title: "kitsu-home-extras", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["home-rows-kinds", "kitsu-community", "tracker-followups"],
    owns: ["lib/pages/Kitsu/kitsu_home_page.dart", "lib/pages/Kitsu/kitsu_explore_page.dart", "lib/pages/Kitsu/kitsu_browse_screen.dart", "lib/widgets/Kitsu/kitsu_rows.dart", "lib/widgets/Kitsu/kitsu_media_row.dart", "lib/services/api/Kitsu/kitsu_catalog.dart", "lib/l10n/units/kitsu-home-extras/**", "test/units/kitsu-home-extras/**"],
    goal: ["Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `kitsu-home-extras`: Home \"News\" row from group 596 (reads `kitsu_feed.dart`), \"Popular with people you follow\" (B8, token), random pick (D2), trending in a category (D1), account title-language / rating-system defaults (C10) Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.", "Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only)."],
    dod: ["Offline tests on saved responses/pages; checker on the owner's accounts (read-only)."],
  },
  {
    id: "simkl-api-compliance", title: "simkl-api-compliance", kind: "unit", priority: "P1", group: "trackers", model: "sonnet", ui: false,
    needs: ["tracker-followups"],
    owns: ["lib/services/api/SimKl/simkl_client.dart", "test/units/simkl-api-compliance/**"],
    goal: ["Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `simkl-api-compliance`: `app-name`, `app-version` and `User-Agent: MyWatchList/<version>` on every call; reads `X-RateLimit-Remaining` / `Retry-After` (429 \u2192 typed error); doc links to api.simkl.org Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.", "Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only)."],
    dod: ["Offline tests on saved responses/pages; checker on the owner's accounts (read-only)."],
  },
  {
    id: "simkl-auth-v2", title: "simkl-auth-v2", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["ux-edit-sheet", "simkl-api-compliance", "tracker-followups"],
    owns: ["lib/services/api/SimKl/simkl_api.dart", "lib/widgets/user/sync/tracker_clients.dart", "lib/services/auth/simkl_auth.dart", "lib/services/auth/simkl_auth_v2.dart", "lib/services/auth/simkl_authresp.dart", "lib/user/user_simkl_v2.dart", "test/units/simkl-auth-v2/**"],
    goal: ["From PR #226: lib/services/api/SimKl/simkl_api.dart and lib/widgets/user/sync/tracker_clients.dart call Simkl directly \u2014 route them through SimklClient (app-name/app-version/User-Agent, 429 back-off).", "Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `simkl-auth-v2`: Real AUTH V2: `/oauth2/authorize` with PKCE S256, `/oauth2/token` with refresh, scopes `media:read media:write`, refresh through auth-refresh; anonymous catalogue calls moved to the token or the CDN. Endpoint constants live in `constants.dart` (not owned): report as a finding or add the V2 URLs as private constants in the auth file Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.", "Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only)."],
    dod: ["Offline tests on saved responses/pages; checker on the owner's accounts (read-only)."],
  },
  {
    id: "simkl-cdn-feeds", title: "simkl-cdn-feeds", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["home-rows-kinds", "simkl-api-compliance", "tracker-followups"],
    owns: ["lib/services/api/SimKl/simkl_cdn.dart", "lib/services/api/SimKl/simkl_discover_service.dart", "lib/pages/Simkl/simkl_explore_page.dart", "lib/pages/Simkl/simkl_home_page.dart", "lib/widgets/Simkl/simkl_feeds.dart", "lib/widgets/Simkl/simkl_home_plan.dart", "lib/l10n/units/simkl-cdn-feeds/**", "test/units/simkl-cdn-feeds/**"],
    goal: ["Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `simkl-cdn-feeds`: Trending (today/week/month) and airing calendar from `data.simkl.in` (A1, A2); Explore and home rows switch to them; Best anime (B3), Coming soon (B5), genre browse (B4) Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.", "Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only)."],
    dod: ["Offline tests on saved responses/pages; checker on the owner's accounts (read-only)."],
  },
  {
    id: "simkl-media-page", title: "simkl-media-page", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["simkl-api-compliance", "tracker-followups"],
    owns: ["lib/pages/Simkl/simkl_media_page.dart", "lib/services/api/SimKl/simkl_detail_service.dart", "lib/services/api/SimKl/simkl_detail_models.dart", "lib/services/api/SimKl/scrapper/**", "lib/widgets/Simkl/media/**", "lib/widgets/Simkl/simkl_media_widgets.dart", "lib/l10n/units/simkl-media-page/**", "test/units/simkl-media-page/**"],
    goal: ["Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `simkl-media-page`: Native Simkl title page: B1 full record (ratings, rank, drop rate, trailers, air time, recommendations with %, relations, studios), B2 episodes, scraped watcher distribution (C1), counters (C7), reviews with sub-scores (C3), comments (C4), memos (C5), tags and links (C9); HTML parsed off the UI isolate, cached, sections hidden when a selector fails Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.", "Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only)."],
    dod: ["Offline tests on saved responses/pages; checker on the owner's accounts (read-only)."],
  },
  {
    id: "simkl-profile-plus", title: "simkl-profile-plus", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["simkl-cdn-feeds", "simkl-media-page", "simkl-api-compliance", "tracker-followups"],
    owns: ["lib/widgets/Simkl/simkl_profile_view.dart", "lib/pages/Simkl/simkl_user_profile_page.dart", "lib/services/api/SimKl/simkl_user_prof.dart", "lib/services/api/SimKl/simkl_stats_service.dart", "lib/services/api/SimKl/simkl_models.dart", "lib/l10n/units/simkl-profile-plus/**", "test/units/simkl-profile-plus/**"],
    goal: ["From simkl-cdn-feeds PR #238: add watcher count, drop rate and rank to SimklMedia (simkl_models.dart) so cards can show them like DailyAL cards show members/rank.", "From simkl-media-page PR #237: profile favourites (lib/widgets/Simkl/simkl_profile_view.dart:~380) open the native Simkl page via openSimklTitle instead of the MAL screen.", "Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `simkl-profile-plus`: Profile: time watched, left to watch, last week (B6, on open and pull to refresh only), \"now watching\" cover (B11), top rated by me (B9), custom lists for PRO/VIP (B13) Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.", "Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only)."],
    dod: ["Offline tests on saved responses/pages; checker on the owner's accounts (read-only)."],
  },
  {
    id: "simkl-list-sync", title: "simkl-list-sync", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["simkl-cdn-feeds", "simkl-media-page", "simkl-api-compliance", "simkl-profile-plus", "tracker-followups"],
    owns: ["test/units/simkl-pages/service_test.dart", "test/units/simkl-pages/adapter_and_sheet_test.dart", "lib/pages/Simkl/simkl_home_page.dart", "lib/widgets/Simkl/simkl_home_plan.dart", "test/units/simkl-pages/home_plan_test.dart", "lib/widgets/Simkl/media/**", "lib/services/api/SimKl/simkl_client.dart", "lib/services/api/SimKl/simkl_list_service.dart", "lib/services/api/SimKl/simkl_user.dart", "lib/widgets/Simkl/simkl_user_list_adapter.dart", "lib/widgets/Simkl/simkl_edit_sheet.dart", "lib/widgets/Simkl/simkl_states.dart", "lib/pages/Simkl/simkl_user_page.dart", "lib/l10n/units/simkl-list-sync/**", "test/units/simkl-list-sync/**"],
    goal: ["From simkl-cdn-feeds PR #238: a Simkl 'top score' home row shows Best anime (simklHomePlan in lib/widgets/Simkl/simkl_home_plan.dart) \u2014 update test/units/simkl-pages/home_plan_test.dart.", "From simkl-media-page PR #237: My list tile tap (lib/widgets/Simkl/simkl_user_list_adapter.dart:~103) opens the native Simkl page via openSimklTitle(context, simklId:, title:, posterUrl:) instead of the MAL screen; air times on the Simkl title page converted to the user's time zone setting (lib/widgets/Simkl/media/**).", "From simkl-auth-v2 PR #234: make the shared SimklClient default to `() => UserSimklV2.instance.apiClientId` (lib/services/api/SimKl/simkl_client.dart) so V2 tokens use the V2 client id.", "Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `simkl-list-sync`: `/sync/activities` gating + `date_from` incremental pulls (B8), community score badge and sort (B7), continue watching with playback (B10) Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.", "Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only)."],
    dod: ["Offline tests on saved responses/pages; checker on the owner's accounts (read-only)."],
  },
  {
    id: "ux-explore", title: "Explore like DailyAL: tonal buttons, arrow headers, no extra search, no captions", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: ["explore-weekly"],
    owns: ["lib/pages/MAL/mal_explore_page.dart", "lib/screens/explore/**", "test/units/ux-explore/**", "lib/l10n/units/ux-explore/**"],
    goal: ["From PR #223: the seasonal picker's seasons row centres itself with Scrollable.ensureVisible, which also scrolls the whole Explore page back up to the picker whenever it rebuilds \u2014 centre only within the row (ScrollController of the row), never move the page.", "UI comparison report docs/ui-check-report-2026-10-28.md: group A items 2-3 (item 1 is fixed separately in fix/explore-crash \u2014 keep it); re-measure Explore fluidity with tools/perf/measure-scroll.sh numbers in the PR is for the checker. Read those items and the matching screen sections (screenshots under the checker scratchpad shots/).", "Owner rules: replicate DailyAL's UI (dailyal-108 file:line given in the report) where MWL is weaker; remove explanatory captions/helper texts DailyAL lacks; regular-weight titles and tonal controls like DailyAL; theme tokens; English + French."],
    dod: ["Checker: side by side with DailyAL on the same theme."],
  },
  {
    id: "ux-search", title: "Search home and results like DailyAL; one season picker", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: ["small-fixes", "ux-explore"],
    owns: ["test/units/shared-kit/select_test.dart", "lib/screens/search/search_home_view.dart", "lib/screens/search/search_tiles.dart", "lib/screens/search/search_filter_panel.dart", "lib/widgets/common/select/searchable_select.dart", "lib/l10n/units/ux-search/**", "test/units/ux-search/**"],
    goal: ["UI comparison report docs/ui-check-report-2026-10-28.md: group C items 5-8. Read those items and the matching screen sections (screenshots under the checker scratchpad shots/).", "Owner rules: replicate DailyAL's UI (dailyal-108 file:line given in the report) where MWL is weaker; remove explanatory captions/helper texts DailyAL lacks; regular-weight titles and tonal controls like DailyAL; theme tokens; English + French."],
    dod: ["Checker: side by side with DailyAL on the same theme."],
  },
  {
    id: "ux-reviews", title: "Reviewer tap opens the profile directly; Helpful sort by default", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: ["mal-messages", "profile-lists"],
    owns: ["lib/widgets/MAL/review/**", "lib/widgets/user/profile/user_pop_sheet.dart", "lib/l10n/units/ux-reviews/**", "test/units/ux-reviews/**"],
    goal: ["From mal-messages PR #264: the quick profile sheet gets a 'Message' action calling `openComposeMalMessage(context, to: username)` for MAL users other than the owner.", "UI comparison report docs/ui-check-report-2026-10-28.md: group E item 12. Read those items and the matching screen sections (screenshots under the checker scratchpad shots/).", "Owner rules: replicate DailyAL's UI (dailyal-108 file:line given in the report) where MWL is weaker; remove explanatory captions/helper texts DailyAL lacks; regular-weight titles and tonal controls like DailyAL; theme tokens; English + French."],
    dod: ["Checker: side by side with DailyAL on the same theme."],
  },
  {
    id: "ux-detail-content", title: "Detail content like DailyAL: adaptation tiles, empty featured hidden, fixed cast thumbnails", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: [],
    owns: ["test/units/detail-resilience/score_stats_fallback_test.dart", "lib/widgets/MAL/content/scorestatisticswidget.dart", "lib/widgets/MAL/content/show_featured.dart", "lib/widgets/MAL/content/adaptation_widget.dart", "lib/screens/MAL/characters_staff_screen.dart", "lib/l10n/units/ux-detail-content/**", "test/units/ux-detail-content/**"],
    goal: ["UI comparison report docs/ui-check-report-2026-10-28.md: group F items 13-14. Read those items and the matching screen sections (screenshots under the checker scratchpad shots/).", "Owner rules: replicate DailyAL's UI (dailyal-108 file:line given in the report) where MWL is weaker; remove explanatory captions/helper texts DailyAL lacks; regular-weight titles and tonal controls like DailyAL; theme tokens; English + French."],
    dod: ["Checker: side by side with DailyAL on the same theme."],
  },
  {
    id: "ux-edit-sheet", title: "Edit sheet as DailyAL's single compact card; sync panel behind More options", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: [],
    owns: ["lib/widgets/user/edit/**", "lib/widgets/user/contenteditwidget.dart", "lib/widgets/user/sync/**", "lib/widgets/user/cross_tracker_widget.dart", "lib/l10n/units/ux-edit-sheet/**", "test/units/ux-edit-sheet/**"],
    goal: ["UI comparison report docs/ui-check-report-2026-10-28.md: group G item 15 (also: the close FAB covers the Kitsu row's Sync button). Never write to the owner's trackers in tests. Read those items and the matching screen sections (screenshots under the checker scratchpad shots/).", "Owner rules: replicate DailyAL's UI (dailyal-108 file:line given in the report) where MWL is weaker; remove explanatory captions/helper texts DailyAL lacks; regular-weight titles and tonal controls like DailyAL; theme tokens; English + French."],
    dod: ["Checker: side by side with DailyAL on the same theme."],
  },
  {
    id: "ux-calendar", title: "Calendar as DailyAL's week grouped by day; never opens on an empty day", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: [],
    owns: ["lib/screens/calendar/**", "lib/widgets/calendar/**", "lib/l10n/units/ux-calendar/**", "test/units/ux-calendar/**"],
    goal: ["UI comparison report docs/ui-check-report-2026-10-28.md: group H item 16 (today's already-aired episodes must stay visible). Read those items and the matching screen sections (screenshots under the checker scratchpad shots/).", "Owner rules: replicate DailyAL's UI (dailyal-108 file:line given in the report) where MWL is weaker; remove explanatory captions/helper texts DailyAL lacks; regular-weight titles and tonal controls like DailyAL; theme tokens; English + French."],
    dod: ["Checker: side by side with DailyAL on the same theme."],
  },
  {
    id: "ux-seasonal", title: "Seasonal header and list rows like DailyAL", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: ["explore-weekly"],
    owns: ["lib/screens/seasonal/**", "lib/l10n/units/ux-seasonal/**", "test/units/ux-seasonal/**"],
    goal: ["UI comparison report docs/ui-check-report-2026-10-28.md: group I item 17. Read those items and the matching screen sections (screenshots under the checker scratchpad shots/).", "Owner rules: replicate DailyAL's UI (dailyal-108 file:line given in the report) where MWL is weaker; remove explanatory captions/helper texts DailyAL lacks; regular-weight titles and tonal controls like DailyAL; theme tokens; English + French."],
    dod: ["Checker: side by side with DailyAL on the same theme."],
  },
  {
    id: "ux-theme", title: "Theme settings without captions or preview card", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: [],
    owns: ["lib/screens/settings/theme_settings.dart", "lib/l10n/units/ux-theme/**", "test/units/ux-theme/**", "test/units/theme-seasons/theme_seasons_test.dart"],
    goal: ["UI comparison report docs/ui-check-report-2026-10-28.md: group J item 18. Read those items and the matching screen sections (screenshots under the checker scratchpad shots/).", "Owner rules: replicate DailyAL's UI (dailyal-108 file:line given in the report) where MWL is weaker; remove explanatory captions/helper texts DailyAL lacks; regular-weight titles and tonal controls like DailyAL; theme tokens; English + French."],
    dod: ["Checker: side by side with DailyAL on the same theme."],
  },
  {
    id: "ux-home", title: "Home like DailyAL: status badge on cards, plain header icons, Fall row order", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: ["home-rows"],
    owns: ["lib/pages/MAL/mal_home_page.dart", "lib/widgets/home/**", "lib/widgets/MAL/home/homeappbar.dart", "lib/widgets/MAL/home/animegridcard.dart", "lib/l10n/units/ux-home/**", "test/units/ux-home/**"],
    goal: ["UI comparison report docs/ui-check-report-2026-10-28.md: group K item 19 and report section 16 (investigate why the Fall 2026 row starts with Black Clover then Doraemon 2005). Read those items and the matching screen sections (screenshots under the checker scratchpad shots/).", "Owner rules: replicate DailyAL's UI (dailyal-108 file:line given in the report) where MWL is weaker; remove explanatory captions/helper texts DailyAL lacks; regular-weight titles and tonal controls like DailyAL; theme tokens; English + French."],
    dod: ["Checker: side by side with DailyAL on the same theme."],
  },
  {
    id: "ux-stack", title: "Interest stack page: MAL title case, collapsing app bar, single-line tabs", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: ["bookmarks-everywhere"],
    owns: ["lib/screens/MAL/interest_stack_detail_screen.dart", "lib/widgets/MAL/content/intereststackwidget.dart", "lib/l10n/units/ux-stack/**", "test/units/ux-stack/**"],
    goal: ["UI comparison report docs/ui-check-report-2026-10-28.md: group L item 20. Read those items and the matching screen sections (screenshots under the checker scratchpad shots/).", "Owner rules: replicate DailyAL's UI (dailyal-108 file:line given in the report) where MWL is weaker; remove explanatory captions/helper texts DailyAL lacks; regular-weight titles and tonal controls like DailyAL; theme tokens; English + French."],
    dod: ["Checker: side by side with DailyAL on the same theme."],
  },
  {
    id: "ux-forum", title: "Forum topic rows like DailyAL", kind: "unit", priority: "P1", group: "settings", model: "opus", ui: true,
    needs: ["bookmarks-everywhere"],
    owns: ["lib/screens/forum/forum_topics_screen.dart", "lib/widgets/forum/forum_topic_widget.dart", "lib/l10n/units/ux-forum/**", "test/units/ux-forum/**"],
    goal: ["UI comparison report docs/ui-check-report-2026-10-28.md: group M item 21. Read those items and the matching screen sections (screenshots under the checker scratchpad shots/).", "Owner rules: replicate DailyAL's UI (dailyal-108 file:line given in the report) where MWL is weaker; remove explanatory captions/helper texts DailyAL lacks; regular-weight titles and tonal controls like DailyAL; theme tokens; English + French."],
    dod: ["Checker: side by side with DailyAL on the same theme."],
  },
  {
    id: "home-rows-kinds", title: "Home OVA/ONA and manhwa/manhua/novel ranking rows (H3) with tracker cases", kind: "unit", priority: "P1", group: "discovery", model: "sonnet", ui: true,
    needs: ["home-rows"],
    owns: ["lib/services/api/Anilist/anilist_discover_service.dart", "test/units/home-rows-kinds/**", "lib/user/MAL/mal_home_page_preferences.dart", "lib/user/requests/requests_bloc.dart", "lib/screens/settings/mal_home_settings.dart", "lib/widgets/Anilist/anilist_home_sections.dart", "lib/widgets/Kitsu/kitsu_rows.dart", "lib/widgets/Simkl/simkl_home_plan.dart", "lib/l10n/units/home-rows/**", "test/units/home-rows/**"],
    goal: ["home-rows PR #218 held back H3: restore it with `git revert ed2c93e` (commit 4de52f9 added the 10 DailyAL ranking kinds with titles, icons, strings and tests), then add the cases the new SectionType values need in the three tracker files: AniList formats OVA, ONA, ONE_SHOT, NOVEL and country of origin KR/CN for manhwa/manhua; Kitsu matching subtypes; Simkl has no feed — skip/hide them there. Read PR #218's body.", "Owner rules: replicate DailyAL; no explanatory captions; theme tokens; English + French."],
    dod: ["Tests: each new kind renders on MAL and maps (or is hidden) on AniList, Kitsu, Simkl."],
  },
  {
    id: "ux-polish-2", title: "Tonal buttons stay tonal; explicit card hidden with NSFW off like DailyAL", kind: "unit", priority: "P1", group: "settings", model: "sonnet", ui: true,
    needs: ["ux-explore", "ux-theme"],
    owns: ["lib/screens/search/search_results_part.dart", "lib/user/theme/app_themes.dart", "lib/pages/MAL/mal_explore_page.dart", "lib/screens/explore/**", "test/units/explore-polish/**", "test/units/ux-polish-2/**", "lib/l10n/units/explore-polish/**"],
    goal: ["From ux-search PR #276: search_results_part.dart passes the list position (index) to MediaTile so result rows show #1, #2… like DailyAL, and the all-tab result rows use the same MediaTile row.", "From ux-explore PR #235: `filledButtonTheme` in lib/user/theme/app_themes.dart forces the accent colour on every FilledButton, including FilledButton.tonal — tonal buttons must keep their tonal (secondaryContainer) colours everywhere; check other screens using tonal buttons.", "Owner rules (replicate DailyAL, no explanatory captions): with NSFW off, hide the Explicit genres card entirely like DailyAL instead of showing 'Hidden (NSFW off)' (Exp_Nsfw_Hidden); update the explore-polish tests that pin the caption. Theme tokens; English + French."],
    dod: ["Tests: a FilledButton.tonal renders with the tonal container colour; no explicit card when NSFW is off."],
  },
  {
    id: "mal-notifications", title: "MAL notifications in the app: notification hub, mark as read, background polling with Android notifications", kind: "unit", priority: "P0", group: "user", model: "opus", ui: true,
    needs: ["mal-session"],
    owns: ["lib/services/api/MAL/web/mal_notifications_api.dart", "lib/screens/mal_web/notifications_screen.dart", "lib/widgets/mal_web/notification_tiles.dart", "lib/services/notifications/**", "lib/l10n/units/mal-notifications/**", "test/units/mal-notifications/**"],
    goal: ["Reports docs/malclient-report-2026-10-28.md and docs/malclient-fork-report-2026-10-28.md: MAL's notification hub lives on https://myanimelist.net/notification (data = JSON in a window.MAL.notification script) and mark-read is /notification/api/check-items-as-read.json. Read ALL notification types MAL sends (friend requests, profile comments, forum quotes/mentions, friends' list updates such as a friend dropping/completing an anime, related anime added, airing on list, club, blog\u2026), show them in an in-app Notifications screen (reachable from the home header bell / sidebar), unread badge, mark as read (single and all), open the target (profile, anime, forum topic).", "Background: poll the hub periodically with the existing notification service/workmanager setup and raise Android system notifications for new items (grouped, tap opens the target, respects the user's notification settings, battery-friendly interval, no duplicates). Without a website session: the screen shows a one-tap Connect. Owner wants to see e.g. 'a friend dropped an anime' \u2014 if MAL shows friends' list updates outside /notification (profile 'friend updates' block or rss.php?type=rw), include them in the same screen as a Friends activity tab.", "Owner rules: replicate MALClient/DailyAL UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Uses the MAL website session from mal-session (lib/services/api/MAL/web/mal_web_client.dart: cookies + csrf_token, desktop UA). Verify every endpoint/form against the live site with read-only GETs (MAL may have changed since MALClient); offline tests on saved pages. You cannot log in (reCAPTCHA, never handle the owner's password): implement and test offline, then tell the orchestrator exactly what the owner must do on the emulator for a live test."],
    dod: ["Offline tests on saved pages; live test steps handed to the owner."],
  },
  {
    id: "mal-messages", title: "MAL private messages: inbox, sent, thread, compose and reply", kind: "unit", priority: "P0", group: "user", model: "opus", ui: true,
    needs: ["mal-session"],
    owns: ["lib/services/api/MAL/web/mal_messages_api.dart", "lib/screens/mal_web/messages_screen.dart", "lib/screens/mal_web/message_thread_screen.dart", "lib/screens/mal_web/compose_message_screen.dart", "lib/widgets/mal_web/message_tiles.dart", "lib/l10n/units/mal-messages/**", "test/units/mal-messages/**"],
    goal: ["Reports docs/malclient-report-2026-10-28.md and docs/malclient-fork-report-2026-10-28.md: MAL private messages through mymessages.php (inbox, sent, read a message, thread, send, reply, delete). Screens: Messages (Inbox / Sent tabs, unread count), thread view, compose (recipient field with friend suggestions from the friends list, subject, BBCode-safe body), reply. Entry points: sidebar, a 'Message' action on another user's profile and on a friend row.", "Live write test needs the owner's explicit approval per message (a PM is visible to another person): stop before any send and ask the orchestrator.", "Owner rules: replicate MALClient/DailyAL UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Uses the MAL website session from mal-session (lib/services/api/MAL/web/mal_web_client.dart: cookies + csrf_token, desktop UA). Verify every endpoint/form against the live site with read-only GETs (MAL may have changed since MALClient); offline tests on saved pages. You cannot log in (reCAPTCHA, never handle the owner's password): implement and test offline, then tell the orchestrator exactly what the owner must do on the emulator for a live test."],
    dod: ["Offline tests on saved pages; live test steps handed to the owner."],
  },
  {
    id: "anilist-client-limits", title: "anilist-client-limits", kind: "unit", priority: "P1", group: "trackers", model: "sonnet", ui: true,
    needs: [],
    owns: ["lib/services/api/Anilist/anilist_graphql.dart", "lib/services/api/Anilist/anilist_media.dart", "lib/services/api/Anilist/anilist_actions.dart", "test/units/anilist-client-limits/**", "lib/l10n/units/anilist-client-limits/**", "test/units/anilist-client-limits/**"],
    goal: ["Audit docs/anilist-report-2026-10-28.md, unit `anilist-client-limits`: Token bucket 30/min shared by every AniList call (reads `X-RateLimit-Remaining`, waits on `Retry-After`, typed 429), `mutate()` sent with `idempotent: false`, an aliased multi-query helper (`batch({alias: query})`), `weightedScore` with `averageScore` fallback in `AnilistMedia.fields`, shared actions `toggleFavourite`, `toggleLike` (`ToggleLikeV2`), `toggleFollow` Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "anilist-list-fidelity", title: "anilist-list-fidelity", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["anilist-client-limits"],
    owns: ["lib/services/api/Anilist/anilist_user.dart", "lib/services/api/Anilist/anilist_api.dart", "lib/widgets/user/sync/tracker_clients.dart", "lib/services/tracker_sync_service.dart", "lib/services/api/Anilist/anilist_list_service.dart", "lib/services/api/Anilist/anilist_list_write.dart", "lib/widgets/Anilist/anilist_user_list_adapter.dart", "lib/pages/Anilist/anilist_user_page.dart", "lib/widgets/Anilist/list/**", "lib/l10n/units/anilist-list-fidelity/**", "test/units/anilist-list-fidelity/**", "lib/l10n/units/anilist-list-fidelity/**", "test/units/anilist-list-fidelity/**"],
    goal: ["Findings from anilist-client-limits (#270): send SaveMediaListEntry / DeleteMediaListEntry in anilist_user.dart through AnilistGraphql.mutate() (not query()); route the AniList calls of tracker_clients.dart (sync writes) and anilist_api.dart through AnilistGraphql so they share the rate limiter; read the score with AnilistMedia.scoreOf / weightedScore instead of averageScore in tracker_sync_service.dart and anilist_api.dart.", "Audit docs/anilist-report-2026-10-28.md, unit `anilist-list-fidelity`: Findings 3-5 and H1-H12: score in the user's format, +1 keeps the score, Rewatching, notes / repeat / priority / private / hidden / custom lists / advanced scores read, custom list tabs, section order, AniList sorts, bulk edit; an AniList entry editor (`showAnilistEntryEditor`) with its own `SaveMediaListEntry` (all 16 fields) replacing the shared tracker editor for AniList rows; `open` calls `openAnilistMedia` Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "anilist-people-pages", title: "anilist-people-pages", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["anilist-client-limits"],
    owns: ["lib/widgets/Anilist/social/anilist_links.dart", "lib/pages/Anilist/anilist_character_page.dart", "lib/pages/Anilist/anilist_staff_page.dart", "lib/pages/Anilist/anilist_studio_page.dart", "lib/services/api/Anilist/anilist_people_service.dart", "lib/widgets/Anilist/people/**", "lib/l10n/units/anilist-people-pages/**", "test/units/anilist-people-pages/**", "lib/l10n/units/anilist-people-pages/**", "test/units/anilist-people-pages/**"],
    goal: ["From anilist-social (#291): switch character, staff and studio links in openAnilistLink (lib/widgets/Anilist/social/anilist_links.dart) to your native pages (owns it).", "Audit docs/anilist-report-2026-10-28.md, unit `anilist-people-pages`: B1-B7: character, staff (voice / staff roles, on-my-list filter), studio pages with favourite toggle; birthday and top-characters loaders for the home Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "anilist-search-filters", title: "anilist-search-filters", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["anilist-client-limits"],
    owns: ["lib/services/api/Anilist/anilist_discover_service.dart", "lib/services/api/Anilist/anilist_catalog.dart", "lib/widgets/Anilist/anilist_browse_screen.dart", "lib/widgets/Anilist/anilist_chips.dart", "lib/widgets/Anilist/search/**", "lib/l10n/units/anilist-search-filters/**", "test/units/anilist-search-filters/**", "lib/l10n/units/anilist-search-filters/**", "test/units/anilist-search-filters/**"],
    goal: ["From ux-search PR #276: AniList search result rows match the DailyAL row of MediaTile (#rank, star score with members, type and length, regular-weight title, edit pencil).", "Audit docs/anilist-report-2026-10-28.md, unit `anilist-search-filters`: C1-C9: `AnilistMediaQuery` gains every filter, filter sheet, 36 sorts, tabs for characters / staff / studios / users, genres and tags from the API (cached a day), tag explorer, account adult option Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "anilist-social", title: "anilist-social", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["anilist-client-limits"],
    owns: ["lib/pages/Anilist/anilist_forum_page.dart", "lib/widgets/Anilist/anilist_thread_tile.dart", "lib/pages/Anilist/anilist_thread_page.dart", "lib/pages/Anilist/anilist_activity_page.dart", "lib/pages/Anilist/anilist_review_page.dart", "lib/services/api/Anilist/anilist_social_service.dart", "lib/widgets/Anilist/social/**", "lib/l10n/units/anilist-social/**", "test/units/anilist-social/**", "lib/l10n/units/anilist-social/**", "test/units/anilist-social/**"],
    goal: ["Audit docs/anilist-report-2026-10-28.md, unit `anilist-social`: F0-F9: AniList HTML renderer (spoilers, embeds, in-app `anilist.co` links), forum filters, thread page with comment tree, reply / like / subscribe, activity feed page (Following / Global), activity page with replies, status composer with preview, likes sheet, review page with votes and review composer, reviews feed; the Forum tab gets Forum / Activity tabs Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "anilist-notifications", title: "anilist-notifications", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["anilist-client-limits", "anilist-social"],
    owns: ["lib/pages/Anilist/anilist_notifications_page.dart", "lib/services/api/Anilist/anilist_notifications_service.dart", "lib/widgets/Anilist/notifications/**", "lib/l10n/units/anilist-notifications/**", "test/units/anilist-notifications/**", "lib/l10n/units/anilist-notifications/**", "test/units/anilist-notifications/**"],
    goal: ["From anilist-social (#291): open threads and activities with openAnilistThread / openAnilistActivity.", "Audit docs/anilist-report-2026-10-28.md, unit `anilist-notifications`: G1-G3, G5: inbox with group filters, unread count service (on resume, never polled), mark read, in-app routing (titles through `openAnilistMedia`, threads and activities through `anilist-social` pages once merged; the browser before) Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "anilist-settings", title: "anilist-settings", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["anilist-client-limits"],
    owns: ["lib/pages/Anilist/anilist_settings_page.dart", "lib/services/api/Anilist/anilist_settings_service.dart", "lib/widgets/Anilist/settings/**", "lib/l10n/units/anilist-settings/**", "test/units/anilist-settings/**", "lib/l10n/units/anilist-settings/**", "test/units/anilist-settings/**"],
    goal: ["Audit docs/anilist-report-2026-10-28.md, unit `anilist-settings`: I1-I7: AniList account settings page (`Viewer.options`, `mediaListOptions`, `UpdateUser`, `DeleteCustomList`), about editor with `Markdown` preview Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "anilist-media-page", title: "anilist-media-page", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["anilist-list-fidelity", "anilist-people-pages", "anilist-social"],
    owns: ["lib/widgets/Anilist/search/anilist_search_links.dart", "lib/widgets/Anilist/search/anilist_result_tiles.dart", "lib/widgets/Anilist/social/anilist_links.dart", "lib/widgets/Anilist/anilist_user_list_adapter.dart", "lib/pages/Anilist/anilist_media_page.dart", "lib/services/api/Anilist/anilist_media_detail.dart", "lib/widgets/Anilist/media/**", "lib/widgets/Anilist/anilist_media_card.dart", "lib/l10n/units/anilist-media-page/**", "test/units/anilist-media-page/**", "lib/l10n/units/anilist-media-page/**", "test/units/anilist-media-page/**"],
    goal: ["From anilist-search-filters (#297): switch openAnilistSearchTitle (lib/widgets/Anilist/search/anilist_search_links.dart) to your native page; openAnilistMedia in anilist_media_card.dart must stop opening the MAL page; the search edit pencil (editAnilistSearchEntry) uses showAnilistEntryEditor from anilist-list-fidelity instead of the shared tracker editor.", "From anilist-social (#291): make openAnilistTitle (lib/widgets/Anilist/social/anilist_links.dart, owns it) open your native page; reuse AnilistForumPage(mediaId:), AnilistReviewsFeed(mediaId:) and the rateRecommendation service for the recommendation vote buttons.", "Owner bug 2026-10-29: AniList list rows open the MAL detail page (or anilist.co when unmapped). Every AniList entry point (list adapter open(), home cards, search results, related, recommendations, people pages) opens the native AniList title page, mapped to MAL or not; one helper (openAnilistTitle) used everywhere.", "Audit docs/anilist-report-2026-10-28.md, unit `anilist-media-page`: A1-A21: native AniList title page with its own layout from the AniList section of docs/tracker-ui-references.md (banner + cover header, AniList-style score/rank/stats, tags, relations, streaming episodes; do not reuse the MAL detail layout), \"Open on MyAnimeList\", favourite heart, my entry through `showAnilistEntryEditor`, reviews section \u2192 `AnilistReviewPage`, characters / staff / studios \u2192 people pages, recommendation votes and submit; `openAnilistMedia` now always opens this page Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "anilist-profile-plus", title: "anilist-profile-plus", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["anilist-social", "anilist-people-pages", "anilist-settings", "anilist-list-fidelity"],
    owns: ["lib/widgets/Anilist/anilist_profile_view.dart", "lib/services/api/Anilist/anilist_profile_service.dart", "lib/pages/Anilist/anilist_user_profile_page.dart", "lib/pages/Anilist/anilist_other_list_page.dart", "lib/services/api/Anilist/anilist_follow_service.dart", "lib/widgets/Anilist/profile/**", "lib/l10n/units/anilist-profile-plus/**", "test/units/anilist-profile-plus/**", "lib/l10n/units/anilist-profile-plus/**", "test/units/anilist-profile-plus/**"],
    goal: ["From anilist-settings (#301): add an entry to AnilistSettingsPage() from the AniList profile (own profile only); make AniList titles across the AniList screens follow the account's title language (AnilistSettingsService) instead of the app preference.", "From anilist-social (#291): reuse AnilistActivityFeed(userId:) and openAnilistReviews(userId:) for the profile's activity and reviews.", "Audit docs/anilist-report-2026-10-28.md, unit `anilist-profile-plus`: E1-E13: stats sub-tabs and charts, heatmap, Activity tab (social widgets), all favourites with reorder and native pages, followers / following / mutuals with follow, other users' lists (read-only adapter, compare), message a user, user search, badges and profile colour; \"Edit profile\" opens `AnilistSettingsPage` Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "anilist-home-extras", title: "anilist-home-extras", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["anilist-search-filters", "anilist-social", "anilist-people-pages", "anilist-notifications"],
    owns: ["lib/services/notifications/notification_service.dart", "lib/main.dart", "lib/screens/settings/notifications_settings.dart", "lib/pages/Anilist/anilist_home_page.dart", "lib/pages/Anilist/anilist_explore_page.dart", "lib/widgets/Anilist/anilist_home_sections.dart", "lib/services/api/Anilist/anilist_feeds_service.dart", "lib/widgets/Anilist/home/**", "lib/l10n/units/anilist-home-extras/**", "test/units/anilist-home-extras/**", "lib/l10n/units/anilist-home-extras/**", "test/units/anilist-home-extras/**"],
    goal: ["From anilist-notifications (#248): put AnilistNotificationBell (lib/widgets/Anilist/notifications/anilist_notification_bell.dart) in the AniList home app bar; background AniList notifications (G4) through notification_service.dart and the existing worker, behind a settings switch.", "From anilist-search-filters (#297): anilist_explore_page.dart uses the live AniList genre list (AnilistCatalog) and gets a Tags entry (openAnilistTag).", "From anilist-social (#291): the forum row's 'view all' in anilist_home_sections.dart opens the forum in a bare screen with no back button: give it an app bar.", "Audit docs/anilist-report-2026-10-28.md, unit `anilist-home-extras`: D1-D6, D8, D10: home rows batched in one request, recommendations from my list, following activity row, daily trends with episode, birthdays, latest reviews / recommendations, top characters, full season view on Explore; bell with unread badge in the AniList home app bar Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "mal-episodes", title: "mal-episodes", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: [],
    owns: ["lib/services/api/MAL/scrapper/episodes_page.dart", "lib/screens/MAL/episodes/episodes_screen.dart", "lib/screens/MAL/detail/sections/episodes_section.dart", "lib/screens/MAL/detail/detail_sections.dart", "lib/constants/constants.dart", "lib/l10n/units/mal-episodes/**", "lib/l10n/units/mal-episodes/**", "test/units/mal-episodes/**"],
    goal: ["Audit docs/mal-api-report-2026-10-28.md, unit `mal-episodes`: W1 Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); replicate DailyAL's UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "mal-detail-sidebar", title: "mal-detail-sidebar", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["ux-home", "jikan-leftovers", "mal-episodes"],
    owns: ["lib/user/preferences/content_preferences.dart", "test/units/detail-split/detail_sections_test.dart", "lib/widgets/user/contenteditwidget.dart", "mwl-api/mwl_commons/lib/src/model/html/anime_detailed_html.dart", "mwl-api/mwl_commons/lib/src/services/html_parser.dart", "mwl-api/test/fixtures/anime_php.html", "lib/widgets/MAL/content/more_info_widget.dart", "lib/screens/MAL/detail/header/header_meta.dart", "lib/screens/MAL/detail/sections/media_section.dart", "lib/services/api/MAL/mal_anime.dart", "lib/widgets/MAL/home/animegridcard.dart", "lib/l10n/units/mal-detail-sidebar/**", "lib/l10n/units/mal-detail-sidebar/**", "test/units/mal-detail-sidebar/**"],
    goal: ["(mal-episodes) show the next episode to watch (\"Next: ep N\", from the episode list and the user's progress) in the detail header (header_meta.dart).", "Findings: (mal-episodes) add the Episodes section to the default anime detail tabs in content_preferences.dart, right after Related, and update detail_sections_test.dart; existing users who never customised the order also get it. (small-fixes) remove the dead hint computation passed to FieldCaption in contenteditwidget.dart.", "Audit docs/mal-api-report-2026-10-28.md, unit `mal-detail-sidebar`: W2, W7, A3, A8 Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); replicate DailyAL's UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "mal-seasonal-groups", title: "mal-seasonal-groups", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: [],
    owns: ["lib/screens/seasonal/seasonal_data.dart", "lib/screens/seasonal/seasonal_screen.dart", "lib/screens/seasonal/season_utils.dart", "lib/l10n/units/mal-seasonal-groups/**", "lib/l10n/units/mal-seasonal-groups/**", "test/units/mal-seasonal-groups/**"],
    goal: ["Audit docs/mal-api-report-2026-10-28.md, unit `mal-seasonal-groups`: W3, A4 Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); replicate DailyAL's UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "mal-list-time", title: "mal-list-time", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["small-fixes"],
    owns: ["lib/widgets/user/list/mal_user_list_adapter.dart", "lib/widgets/user/list/list_entry_view.dart", "lib/widgets/user/list/user_list_view.dart", "lib/widgets/user/list/card_layout_editor.dart", "lib/l10n/units/mal-list-time/**", "lib/l10n/units/mal-list-time/**", "test/units/mal-list-time/**"],
    goal: ["Audit docs/mal-api-report-2026-10-28.md, unit `mal-list-time`: W5, A5, A9 Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); replicate DailyAL's UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "mal-profile-extras", title: "mal-profile-extras", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["profile-lists"],
    owns: ["lib/services/api/MAL/mal_user_prof.dart", "lib/services/api/MAL/mal_user.dart", "lib/screens/user_profile/user_profile_data.dart", "lib/screens/user_profile/user_profile_view.dart", "lib/screens/user_profile/sections/profile_tabs_source.dart", "lib/screens/user_profile/sections/reviews_section.dart", "lib/widgets/user/profile/profile_header.dart", "lib/l10n/units/mal-profile-extras/**", "lib/l10n/units/mal-profile-extras/**", "test/units/mal-profile-extras/**"],
    goal: ["Audit docs/mal-api-report-2026-10-28.md, unit `mal-profile-extras`: W4, A1, A2, W10 Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); replicate DailyAL's UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "mal-list-xml", title: "mal-list-xml", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: [],
    owns: ["lib/services/list_export/mal_xml.dart", "lib/services/list_export/mal_xml_import.dart", "lib/screens/settings/backup_settings.dart", "lib/l10n/units/mal-list-xml/**", "lib/l10n/units/mal-list-xml/**", "test/units/mal-list-xml/**"],
    goal: ["Audit docs/mal-api-report-2026-10-28.md, unit `mal-list-xml`: W6 Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); replicate DailyAL's UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "mal-web-writes-2", title: "mal-web-writes-2", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["ux-reviews", ],
    owns: ["lib/services/api/MAL/web/forum_poll_api.dart", "lib/services/api/MAL/web/review_write_api.dart", "lib/services/api/MAL/web/recommendation_write_api.dart", "lib/screens/forum/forum_posts_screen.dart", "lib/widgets/MAL/review/reviews_list_screen.dart", "lib/screens/MAL/detail/sections/recommendations_section.dart", "lib/l10n/units/mal-web-writes-2/**", "lib/l10n/units/mal-web-writes-2/**", "test/units/mal-web-writes-2/**"],
    goal: ["Audit docs/mal-api-report-2026-10-28.md, unit `mal-web-writes-2`: W8, W9 Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); replicate DailyAL's UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "mal-api-small", title: "mal-api-small", kind: "unit", priority: "P1", group: "trackers", model: "sonnet", ui: true,
    needs: [],
    owns: ["lib/screens/search/search_queries.dart", "lib/services/api/MAL/mal_api.dart", "lib/enums.dart", "lib/services/api/MAL/scrapper/title_clubs.dart", "lib/screens/explore/explore_sections.dart", "lib/l10n/units/mal-api-small/**", "test/units/mal-api-small/**"],
    goal: ["Audit docs/mal-api-report-2026-10-28.md, unit `mal-api-small`: A6, A7, W11, W12 Read the matching report items (queries/endpoints, samples, file:line) and implement them.", "Owner rules: every tracker gets everything its API allows (never capped at MAL); replicate DailyAL's UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes)."],
    dod: ["Offline tests on saved responses; checker on the owner's account (read-only)."],
  },
  {
    id: "mal-hub-wiring", title: "MAL notifications: bell, sidebar entry, background polling when the app is closed, settings switches", kind: "unit", priority: "P0", group: "user", model: "opus", ui: true,
    needs: ["mal-notifications", "ux-home", "mal-messages"],
    owns: ["lib/screens/user_profile/user_profile_view.dart", "lib/widgets/MAL/home/homeappbar.dart", "lib/pages/side_bar.dart", "pubspec.yaml", "pubspec.lock", "lib/main.dart", "docs/STACK.md", "lib/screens/settings/notifications_settings.dart", "lib/services/api/MAL/web/mal_web_client.dart", "android/app/src/main/AndroidManifest.xml", "lib/l10n/units/mal-hub-wiring/**", "test/units/mal-hub-wiring/**"],
    goal: ["From mal-messages PR #264: add `malMessagesSidebarItem(context)` to the sidebar; a 'Message' action (S.current.Pm_Message) on other users' MAL profiles calling `openComposeMalMessage(context, to: username)` (user_profile_view.dart); a received private message raises a phone notification through MalHubPoller and refreshes the unread count (owner: yes).", "From mal-notifications PR #262 findings: add `const MalNotificationsBell()` to the home header action row (homeappbar.dart `_buildActionButtons`) and `malNotificationsSidebarItem(context)` to the sidebar (side_bar.dart); background polling while the app is closed with a pinned background worker (workmanager or android_alarm_manager_plus \u2014 pick, pin in docs/STACK.md, register in main.dart, manifest bits) calling `MalHubPoller.instance.poll(force: true)` every 30 min (battery-friendly constraints); the MAL hub switches in Settings > Notifications; a `postJson` on MalWebClient and move the notifications API's JSON POSTs onto it. Also add the mal-messages entry points to the sidebar if mal-messages (merged before you) exposes them.", "Owner rules: no explanatory captions; theme tokens; English + French. Never write to the owner's MAL account in tests."],
    dod: ["Tests: bell shows unread count; worker registered; settings switches honoured."],
  },
  {
    id: "mal-hub-followups", title: "MAL hub follow-ups: in-app thread on message tap, JSON posts through postJson, message poller next to the hub poller", kind: "unit", priority: "P1", group: "user", model: "opus", ui: false,
    needs: ["mal-hub-wiring"],
    owns: ["lib/utils/app_routes.dart", "lib/services/notifications/notification_service.dart", "lib/services/notifications/mal_hub_poller.dart", "lib/services/api/MAL/web/mal_notifications_api.dart", "lib/main.dart", "lib/l10n/units/mal-hub-followups/**", "test/units/mal-hub-followups/**"],
    goal: ["Findings from mal-hub-wiring (PR #273): (1) a tapped new-message notification must open the in-app thread screen (mal-messages), not mymessages.php in the browser: route mymessages.php?go=read&id= (and the inbox) in AppRoutes / openMalHubPayload; (2) move the JSON POSTs of mal_notifications_api.dart onto MalWebClient.postJson; (3) move MalHubMessagesPoller and the message watcher out of main.dart into mal_hub_poller.dart (or a sibling file), main.dart keeping only the registration.", "Fakes only in tests: never send anything to MAL."],
    dod: ["Tests: the message payload routes to the thread screen; notification POSTs go through postJson; behaviour of the poller unchanged."],
  },
  {
    id: "list-time-followups", title: "My List: time left card field, season/studio/author/rating filters, rewatch badge, time line for every tracker", kind: "unit", priority: "P1", group: "user", model: "opus", ui: true,
    needs: ["mal-list-time", "anilist-list-fidelity"],
    owns: ["lib/user/preferences/content_card_props.dart", "lib/widgets/user/list/cards/**", "lib/widgets/user/list/list_query.dart", "lib/widgets/user/list/user_list_view.dart", "lib/widgets/user/list/user_list_adapter.dart", "lib/widgets/user/list/card_layout_editor.dart", "lib/widgets/user/list/user_list_tab.dart", "lib/l10n/units/list-time-followups/**", "test/units/list-time-followups/**"],
    goal: ["Findings from mal-list-time (PR #278): (1) a 'time left' field in the card layout editor: a new CustomizableFieldType in content_card_props.dart rendered in cards/custom_entry_card.dart; (2) list filters by season, studio, author and rating in list_query.dart and the list filter sheet, from the ListEntryView fields mal-list-time added; (3) a 'rewatched xN' / 'reread xN' badge on the list cards; (4) count rewatches in 'Time watched'; (5) show the time line for every tracker whose adapter fills the duration (replace the tracker == myanimelist check in user_list_view.dart with a flag on the adapter base class).", "Replicate DailyAL's UI where it has the feature; no captions DailyAL lacks."],
    dod: ["Tests: the time-left field renders; each filter narrows the list; the rewatch badge shows for N > 0; the time line shows for a non-MAL adapter that fills durations."],
  },
  {
    id: "mal-ona-ranking", title: "Top ONA through Jikan/Tenrai (MAL rejects ranking_type=ona); drop the anime_id list sort", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: false,
    needs: ["mal-api-small"],
    owns: ["lib/services/api/MAL/mal_api.dart", "lib/enums.dart", "lib/services/api/Jikan/jikan_api.dart", "test/units/mal-ona-ranking/**"],
    goal: ["A7 check run by the orchestrator on 2026-10-29 with MWL's client id: GET /v2/anime/ranking?ranking_type=ona answers 400 'invalid ranking_type', and /v2/users/{u}/animelist?sort=anime_id answers 400 'invalid sort order' (manga ranking_type=lightnovels answers 200, keep it). Make every RankingType.ONA ranking (home row topAnimeOna, Explore rankings, the detail 'ONA' link, search by ranking) load from Jikan/Tenrai top anime with type=ona through the JikanSource selector (Jikan with Tenrai fallback), mapped to the same SearchResult/Anime shape with paging (offset → page). Remove AnimeListSort.animeId and its mapping (unused, rejected by MAL).", "Offline tests with saved Jikan responses; no write anywhere."],
    dod: ["Tests: the ONA ranking request goes to the Jikan source with type=ona and maps to SearchResult with next-page paging; no MAL ranking request carries ranking_type=ona."],
  },
  {
    id: "simkl-redesign", title: "Simkl screens redesigned from the Simkl UI reference: title page, home, explore/calendar, profile, list rows", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["simkl-list-sync"],
    owns: ["lib/pages/Simkl/simkl_media_page.dart", "lib/pages/Simkl/simkl_home_page.dart", "lib/pages/Simkl/simkl_explore_page.dart", "lib/pages/Simkl/simkl_user_profile_page.dart", "lib/pages/Simkl/simkl_user_page.dart", "lib/widgets/Simkl/**", "lib/l10n/units/simkl-redesign/**", "test/units/simkl-redesign/**"],
    goal: ["Redesign the Simkl screens from the Simkl part of docs/tracker-ui-references.md. Title page: fanart header, rating strip under the title (Simkl, MAL, IMDb, rank, drop rate), next-episode card and the user's status/rating/progress bar near the top, synopsis before the community counters, episodes with images and watched markers, trailers, recommendations with % of users. Home: up next, airing today with exact times, trending with watcher counts (row titles must include 'Simkl' and 'Trending'/'Most Watched'/'Popular'). Calendar: My shows / All anime in local time with premiere and finale badges. Profile: watch time and a now-watching header first (call the user stats endpoint only on open or refresh). List rows: progress, next episode and airing countdown.", "Owner rule 2026-10-29: each tracker is its own app; DailyAL's UI is the reference for MAL only. Follow the matching section of docs/tracker-ui-references.md (recommended block order and the data field behind each block); own files and own layout; every item opens this tracker's native page. No explanatory captions; theme tokens; English + French; fakes only in tests."],
    dod: ["Tests per screen on saved Simkl responses; before/after screenshots at 360 dp in the PR."],
  },
  {
    id: "kitsu-redesign", title: "Kitsu home, explore and library redesigned from the Kitsu UI reference", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["kitsu-home-extras", "kitsu-media-page", "kitsu-profile-plus"],
    owns: ["lib/widgets/Kitsu/profile/kitsu_profile_rows.dart", "lib/pages/Kitsu/kitsu_media_page.dart", "lib/widgets/Kitsu/media/**", "lib/widgets/Kitsu/kitsu_open.dart", "lib/l10n/units/kitsu-pages/**", "lib/pages/Kitsu/kitsu_home_page.dart", "lib/pages/Kitsu/kitsu_explore_page.dart", "lib/pages/Kitsu/kitsu_browse_screen.dart", "lib/pages/Kitsu/kitsu_user_page.dart", "lib/widgets/Kitsu/kitsu_rows.dart", "lib/widgets/Kitsu/kitsu_media_row.dart", "lib/widgets/Kitsu/kitsu_user_list_adapter.dart", "lib/services/api/Kitsu/kitsu_catalog.dart", "lib/l10n/units/kitsu-redesign/**", "test/units/kitsu-redesign/**"],
    goal: ["From kitsu-profile-plus (#303): switch KitsuTitleLinks.opener (lib/widgets/Kitsu/profile/kitsu_profile_rows.dart) to openKitsuTitle so profile titles open the native Kitsu page; add the follow button, groups tab and library count from the Kitsu profile reference.", "From kitsu-media-page (#290): the signed-in parts of the Kitsu title page: library box (status, progress, +1, edit), the user's rating system, watched ticks on episodes, per-episode discussion, favourite heart, next episode line; drop the unused Kitsu_No_Mal_Match strings; rename one of the two KitsuMediaPage classes (kitsu_catalog.dart vs the page).", "Redesign the Kitsu home, explore/search and library from the Kitsu part of docs/tracker-ui-references.md. Home starts with the Quick Update carousel (next-episode thumbnail, '✓ Episode N' button, link to the episode discussion). Library: the five status counts from meta.statusCounts in one call, Kitsu wording ('Want to watch'), the user's rating system (Simple / Regular / Advanced) in every rating display, the user's own reaction on cards. Scores as percentages, never /10. Also from kitsu-home-extras: apply the account rating system to score display; the 'pick from my plan to watch' variant of Surprise me; keep one KitsuCategory type (kitsu_catalog.dart vs kitsu_graphql.dart).", "Owner rule 2026-10-29: each tracker is its own app; DailyAL's UI is the reference for MAL only. Follow the matching section of docs/tracker-ui-references.md (recommended block order and the data field behind each block); own files and own layout; every item opens this tracker's native page. No explanatory captions; theme tokens; English + French; fakes only in tests."],
    dod: ["Tests per screen on saved Kitsu responses; before/after screenshots at 360 dp in the PR."],
  },
  {
    id: "anilist-list-design", title: "AniList list and list rows redesigned from the AniList UI reference", kind: "unit", priority: "P1", group: "trackers", model: "opus", ui: true,
    needs: ["anilist-list-fidelity", "anilist-media-page"],
    owns: ["test/units/mal-list-time/list_time_test.dart", "lib/widgets/user/list/list_entry_view.dart", "lib/pages/Anilist/anilist_user_page.dart", "lib/widgets/Anilist/list/**", "lib/widgets/Anilist/anilist_user_list_adapter.dart", "lib/l10n/units/anilist-list-design/**", "test/units/anilist-list-design/**"],
    goal: ["From tracker-list-hooks (#315): override AnilistUserListAdapter.userScore / communityScore with the account's score format (POINT_100, POINT_10_DECIMAL, POINT_10, POINT_5 stars, POINT_3 faces) and percentages for the community score (checker batch 4: AniList cards always show 0-10); move anilist_list_view.dart:719 and test/units/mal-list-time/list_time_test.dart to listTimeSummary, then delete ListTimeSummary.of.", "Redesign the AniList list (My List and other users' lists) from the AniList part of docs/tracker-ui-references.md, sections 'My List' and 'Score display rules': custom lists, the user's score format everywhere, the label rail (format · 'Ep N in Xd' · 'N behind' · status), title scores as percentages.", "Owner rule 2026-10-29: each tracker is its own app; DailyAL's UI is the reference for MAL only. Follow the matching section of docs/tracker-ui-references.md (recommended block order and the data field behind each block); own files and own layout; every item opens this tracker's native page. No explanatory captions; theme tokens; English + French; fakes only in tests."],
    dod: ["Tests on saved AniList responses; before/after screenshots at 360 dp in the PR."],
  },
  {
    id: "mal-web-recaptcha", title: "MAL writes protected by reCAPTCHA go through an invisible WebView; user pictures in messages", kind: "unit", priority: "P0", group: "user", model: "opus", ui: false,
    needs: ["mal-messages"],
    owns: ["lib/services/api/MAL/web/mal_web_form_submitter.dart", "lib/services/api/MAL/web/mal_web_client.dart", "lib/services/api/MAL/web/mal_messages_api.dart", "lib/services/api/MAL/web/profile_comments_api.dart", "lib/services/api/MAL/web/mal_notifications_api.dart", "lib/screens/mal_web/**", "lib/widgets/forum/forum_common.dart", "lib/l10n/units/mal-web-recaptcha/**", "test/units/mal-web-recaptcha/**", "test/units/mal-messages/**", "test/units/mal-session/**"],
    goal: ["Owner bug 2026-10-29, checked live on the emulator with the owner's session: replying to a private message fails with 'Couldn't reach MyAnimeList'. Cause, read from MAL's real reply form (mymessages.php?go=send&replyid=&threadid=&toname=) and its script all-*.js: the form fields are subject, message, action_type (empty; 'preview' for Preview) and the submit button has class btn-recaptcha-submit; MAL's script (.recaptcha-form / btn-recaptcha-submit, grecaptcha.execute(window.GRECAPTCHA_SITE_KEY,{action})) appends a hidden g-recaptcha-response (reCAPTCHA v3, sitekey 6Ld_1aIZAAAAAF6bNdR67ICKIaeXLKlbhE7t2Qz4) before submitting. A plain HTTP POST from the app has no token, so MAL refuses it; there is no csrf_token field in that form.", "Fix: a MalWebFormSubmitter that loads the real MAL form page in an invisible WebView (webview_flutter, already a dependency; host it offstage or headless) with the MalWebSession cookies set through WebViewCookieManager, fills the fields by JavaScript, clicks MAL's own submit button so MAL's script adds the reCAPTCHA v3 token, then reads the result page (goodresult / badresult / redirect) and reports success or MAL's error text. Use it for MalMessagesApi.send and reply. Then check every other MWL write through MalWebClient (profile comments in profile_comments_api.dart, notifications JSON posts, friend actions) against MAL's all-*.js: route the ones MAL protects with reCAPTCHA (recaptcha-form, grecaptcha.execute: favourites use action 'social') through the submitter; keep plain HTTP for the others. A timeout (20 s) or a page without the form gives a clear error, never a silent failure.", "Also from the owner (same session): the message inbox, sent box and thread show initials ('LO') instead of the users' MAL profile pictures. Read the picture from MAL's markup when present, otherwise from the user's MAL profile (cache per user), shown in ForumAvatar.", "Fakes only in tests (a fake submitter); never send anything to MAL from tests. The orchestrator tests the real send on the emulator with the owner's approval."],
    dod: ["Tests: the submitter fills subject/message and reads goodresult/badresult; send and reply use it; avatars resolved; plain writes unchanged."],
  },
  {
    id: "simkl-data-plus", title: "Simkl: full CDN fields, next_to_watch_info, external ids, title language, calendar route, check-in", kind: "unit", priority: "P1", group: "trackers", model: "sonnet", ui: true,
    needs: ["simkl-redesign"],
    owns: ["lib/services/api/SimKl/**", "lib/pages/Simkl/**", "lib/widgets/Simkl/**", "lib/utils/app_routes.dart", "lib/l10n/units/simkl-data-plus/**", "test/units/simkl-data-plus/**"],
    goal: ["Findings from simkl-redesign (#298): (1) simkl_cdn.dart _media() drops watcher counts, drop rate, rank, fanart, finale flag, network and episode total from the CDN feeds: parse them so the trending watcher counts, carousel fanart and real Premiere/Finale badges show (the UI already renders them when present). (2) SimklListService requests and parses next_to_watch_info and uses it instead of the on-device computation. (3) SimklTitle keeps every external id (AniList, Kitsu, IMDb, TMDB, AniDB…) for a link row on the title page; UserProfSimkl reads anime_title_language and titles follow it. (4) The home app bar's calendar icon routes Simkl accounts to SimklCalendarPage (AppRoutes.openCalendar). (5) Check-in ('Watching now'): /scrobble/checkin service + the title page action, and long-press to mark watched in the calendar.", "Owner rule: each tracker is its own app; design per the Simkl part of docs/tracker-ui-references.md. Respect Simkl's API limits. Never write to the owner's Simkl account from tests: fakes only."],
    dod: ["Tests on saved Simkl responses: CDN fields parsed, next_to_watch_info used, ids row, calendar route, check-in request (fake)."],
  },
  {
    id: "tracker-list-hooks", title: "Shared My List: adapter hooks for status labels, score display, card badges and a rating prompt", kind: "unit", priority: "P1", group: "trackers", model: "sonnet", ui: true,
    needs: ["list-time-followups"],
    owns: ["lib/widgets/user/list/**", "lib/widgets/Kitsu/kitsu_user_list_adapter.dart", "lib/widgets/Simkl/simkl_user_list_adapter.dart", "lib/l10n/units/tracker-list-hooks/**", "test/units/tracker-list-hooks/**"],
    goal: ["From kitsu-redesign (#309): the shared list (lib/widgets/user/list/**) gets adapter hooks so each tracker shows its own wording and scores: status tab labels (Kitsu 'Want to watch', 'Currently reading'…), score display (Kitsu percentage and the account's rating system, Simkl's /10), per-card badges (the user's Kitsu reaction), and a step-completion callback with a BuildContext so the Kitsu adapter can ask for a rating after the last +1. Wire the Kitsu and Simkl adapters to them. From list-time-followups (#308): the MAL adapter sets fillsEpisodeLength => true and the base default becomes false; the old time summary in list_entry_view.dart is retired in favour of listTimeSummary (and anilist_list_view uses it if it is still on the old one).", "Owner rule: each tracker is its own app (docs/tracker-ui-references.md); shared pieces stay shared but every tracker-specific behaviour is a hook on its adapter. Fakes only in tests; writes only on the viewer's tap."],
    dod: ["Tests: each hook changes the rendered tab label / score / badge for a fake adapter; MAL time line unchanged."],
  },
  {
    id: "kitsu-finish", title: "Kitsu: follow, groups and library count on profiles, % on every tile, sync editor in the account's rating system", kind: "unit", priority: "P1", group: "trackers", model: "sonnet", ui: true,
    needs: ["kitsu-redesign"],
    owns: ["lib/services/api/Kitsu/kitsu_profile.dart", "lib/widgets/Kitsu/feed/**", "lib/widgets/Kitsu/profile/**", "lib/widgets/Kitsu/kitsu_profile_view.dart", "lib/widgets/Kitsu/kitsu_media_tile.dart", "lib/services/api/Kitsu/kitsu_http.dart", "lib/services/api/Kitsu/kitsu_graphql.dart", "lib/widgets/user/sync/tracker_entry_editor.dart", "lib/l10n/units/kitsu-pages/**", "test/units/kitsu-pages/**", "lib/l10n/units/kitsu-finish/**", "test/units/kitsu-finish/**"],
    goal: ["Checker batch 4, issue goddivor/mywatchlist#314 (put 'Closes #314' in the PR; reproductions in docs/checks/check-batch4-2026-10-29.md): Kitsu JSON:API text is decoded as Latin-1 (kitsu_http.dart reads response.body; decode UTF-8 from bodyBytes); the time percentile 0.99 shows 'More than 1%' (kitsu_profile.dart:240, fraction read as 0-100); profile Activity titles must open the native page (check after kitsu-redesign #309); double space in feed relative times; empty band under the Groups search field.", "From kitsu-redesign (#309): (1) profile follow button (KitsuHttp gains POST/DELETE for follows), groups tab and library count in kitsu_profile_view.dart, per the Kitsu 'Profile' reference; (2) KitsuMediaTile draws Kitsu's percentage, not a /10 star; (3) the sync dialog's editor (tracker_entry_editor.dart) shows and edits Kitsu ratings in the account's rating system; (4) drop the unused Kitsu_No_Mal_Match strings and update kitsu_browse_test.dart; (5) update KitsuGraphql's doc now that mutations go through execute(auth: true); (6) re-bucket the title page's rating histogram into the user's rating system if simple.", "Owner rule: each tracker is its own app (docs/tracker-ui-references.md); shared pieces stay shared but every tracker-specific behaviour is a hook on its adapter. Fakes only in tests; writes only on the viewer's tap."],
    dod: ["Tests: follow request (fake), tile shows %, editor in Simple/Regular/Advanced, histogram buckets."],
  },
  {
    id: "anilist-polish", title: "AniList polish: standalone forum page, in-app activities, account title language, settings toggles, image placeholder", kind: "unit", priority: "P2", group: "trackers", model: "sonnet", ui: true,
    needs: ["anilist-media-page", "anilist-profile-plus", "anilist-home-extras"],
    owns: ["lib/pages/Anilist/anilist_forum_page.dart", "lib/widgets/Anilist/social/anilist_activity_tile.dart", "lib/services/api/Anilist/anilist_list_service.dart", "lib/widgets/Anilist/settings/notification_types_sheet.dart", "lib/widgets/common/app_image.dart", "lib/l10n/units/anilist-polish/**", "test/units/anilist-polish/**"],
    goal: ["Leftovers routed by the orchestrator (2026-10-29): (1) AnilistForumPage gets a standalone mode with a back button (used by a title's forum in the title page Social tab, and by the home 'view all' instead of the covering app bar); (2) anilist_activity_tile.dart:137 opens some activities on anilist.co: open them in the app (openAnilistActivity); (3) AnilistListService builds titles from the account's title language (AnilistSettingsService), not the app preference; (4) notification_types_sheet.dart:43: two quick toggles drop the second save; (5) app_image.dart: the default placeholder sizes itself from the width when the height is unbounded (the trap behind the thread crash), with a test.", "Owner rule: each tracker is its own app (docs/tracker-ui-references.md). Fakes only in tests."],
    dod: ["Tests per item."],
  },
  {
    id: "kitsu-polish", title: "Kitsu polish: Quick update carousel, exact ratings and reactions in the library, histogram buckets, grid short words, status filter wording", kind: "unit", priority: "P1", group: "user", model: "sonnet", ui: true,
    needs: ["kitsu-finish", "tracker-list-hooks"],
    owns: ["lib/widgets/Kitsu/kitsu_rows.dart", "lib/pages/Kitsu/kitsu_home_page.dart", "lib/widgets/Kitsu/media/**", "lib/services/api/Kitsu/kitsu_library.dart", "lib/widgets/Kitsu/kitsu_user_list_adapter.dart", "lib/widgets/common/list_sort_filter.dart", "lib/l10n/units/kitsu-polish/**", "test/units/kitsu-polish/**"],
    goal: ["Seen on the emulator 2026-10-29 with the owner's Kitsu account: the Kitsu home shows no Quick update carousel although the account has 38 'Currently watching' titles: find why (query, condition or empty mapping) and fix it, with a test on a saved library answer. From tracker-list-hooks (#315): kitsu_library.dart keeps ratingTwenty and the reaction when it parses a page, then drop KitsuExtrasHttp; the list filter sheet's status facet (list_sort_filter.dart) uses the adapter's statusLabel; Kitsu gets its own short words on the grid chip. From kitsu-finish (#317): the title page histogram (kitsu_media_cards.dart) uses KitsuRatingFrequencies.rebucket for the account's rating system.", "Owner rules: each tracker is its own app (docs/tracker-ui-references.md); MAL screens follow DailyAL; no explanatory captions DailyAL lacks. Fakes only in tests; writes only on the viewer's tap."],
    dod: ["Tests: Quick update shows for a library with current entries; exact rating and reaction parsed; histogram rebucketed; status facet wording."],
  },
  {
    id: "mal-polish", title: "MAL polish: Accounts caption, MAL session from its tile, active account after the website login, bell label, Clubs row, Supporter badge for others, time zone in About", kind: "unit", priority: "P1", group: "user", model: "sonnet", ui: true,
    needs: ["mal-hub-followups"],
    owns: ["lib/screens/manage_accounts_page.dart", "lib/user/accounts/**", "lib/widgets/MAL/home/homeappbar.dart", "lib/screens/MAL/detail/sections/forums_section.dart", "lib/services/api/MAL/scrapper/user_profile_page.dart", "lib/screens/user_profile/sections/about_section.dart", "lib/widgets/user/profile/profile_header.dart", "lib/l10n/units/mal-polish/**", "test/units/mal-polish/**"],
    goal: ["Owner-visible leftovers (2026-10-29): (1) Settings > Accounts shows the caption 'The active account decides which tracker the home, your list and your profile show…' that DailyAL lacks: remove it; (2) the MyAnimeList website session page opens from the MyAnimeList account tile (its menu), not from a separate row above the list; (3) seen on the emulator: after the MAL website login and back presses, the home showed the AniList account (no bell) while Accounts said MAL active, tapping MAL restored it: find why the active account and the home disagree after MalSession login and fix it, with a test; (4) the MAL bell's accessibility label is only the count ('25'): 'Notifications, 25 unread'; (5) W11: a 'Clubs' row in the detail Forums section using scrapper/title_clubs.dart (TitleClubs.fetch), DailyAL-style; (6) the Supporter badge for other users from the .icon-supporter marker of their profile page (user_profile_page.dart); (7) the time zone moves from the header line into the About block, labelled.", "Owner rules: each tracker is its own app (docs/tracker-ui-references.md); MAL screens follow DailyAL; no explanatory captions DailyAL lacks. Fakes only in tests; writes only on the viewer's tap."],
    dod: ["Tests per item; the account-state test reproduces the mismatch first."],
  },
  {
    id: "mal-polish-2", title: "MAL polish 2: Settings > Accounts uses the new page, Supporter badge for others, time zone in About, dead TrackerTile, cancelled MAL re-login keeps the session", kind: "unit", priority: "P1", group: "user", model: "sonnet", ui: true,
    needs: ["mal-polish"],
    owns: ["lib/screens/settings/accounts_settings.dart", "lib/utils/app_routes.dart", "lib/screens/user_profile/user_profile_data.dart", "lib/screens/user_profile/user_profile_view.dart", "lib/user/trackers/widgets/tracker_tile.dart", "test/units/accounts-ux/tracker_tile_test.dart", "lib/services/auth/mal_auth_v2.dart", "lib/screens/manage_accounts_page.dart", "lib/l10n/units/mal-polish-2/**", "test/units/mal-polish-2/**"],
    goal: ["Findings from mal-polish (#329): (1) Settings > Accounts still opens lib/screens/settings/accounts_settings.dart (with the caption and the separate MAL session row, app_routes.dart:76): route it to ManageAccountsPage (or make accounts_settings delegate to it) so the fixes are visible, and delete what becomes dead; (2) UserProfileRepository.merge (user_profile_data.dart) reads is_supporter from the MAL profile page and Jikan so other users show the Supporter badge; (3) user_profile_view.dart passes timezone: to AboutSection; (4) TrackerTile (lib/user/trackers/widgets/tracker_tile.dart) is unused since AccountTile: delete it and move its test to AccountTile; (5) mal_auth_v2.dart sets MAL to UNAUTHENTICATED when a second sign-in is cancelled or fails, so a still-signed-in account looks disconnected: keep the previous state on cancel/failure, with a test.", "Never send anything to MAL: fakes only."],
    dod: ["Tests per item; the cancelled re-login test fails on the old code."],
  },
  {
    id: "anilist-polish-2", title: "AniList polish 2: other users' lists in their score format, exact next airing in list rows, drop ListTimeSummary.of", kind: "unit", priority: "P2", group: "trackers", model: "sonnet", ui: true,
    needs: ["anilist-list-design", "anilist-polish"],
    owns: ["lib/widgets/Anilist/profile/other_list_adapter.dart", "lib/pages/Anilist/anilist_other_list_page.dart", "lib/services/api/Anilist/anilist_list_service.dart", "lib/widgets/user/list/list_entry_view.dart", "test/units/tracker-list-hooks/list_hooks_test.dart", "lib/widgets/Anilist/list/**", "lib/l10n/units/anilist-polish-2/**", "test/units/anilist-polish-2/**"],
    goal: ["Findings from anilist-list-design (#331): (1) other users' AniList lists (lib/widgets/Anilist/profile/other_list_adapter.dart, lib/pages/Anilist/anilist_other_list_page.dart) still show 0-10: fetch that user's score format (mediaListOptions.scoreFormat) and use anilistUserScoreText and anilistPercentText; (2) the AniList list service (parseAnilistRows in anilist_list_service.dart) carries the next episode and its exact airing time (nextAiringEpisode { episode airingAt }) into the rows, so 'Ep N in Xd' is exact during broadcast breaks; (3) delete ListTimeSummary.of and its last caller in test/units/tracker-list-hooks/list_hooks_test.dart:247.", "Owner rule: each tracker is its own app. Fakes only in tests."],
    dod: ["Tests per item."],
  },
  {
    id: "mal-friends-feed", title: "MAL home: a Friends activity section (friends' latest list updates)", kind: "unit", priority: "P1", group: "user", model: "sonnet", ui: true,
    needs: ["mal-polish-2"],
    owns: ["lib/user/MAL/mal_home_page_preferences.dart", "lib/screens/settings/mal_home_settings.dart", "lib/pages/MAL/mal_home_page.dart", "lib/widgets/MAL/home/friends_activity_row.dart", "lib/l10n/units/mal-friends-feed/**", "test/units/mal-friends-feed/**"],
    goal: ["Owner request 2026-10-29: a 'Friends activity' section on the MAL home, like a friend feed: the latest list updates of the user's MAL friends (watching / completed / dropped…, episode, time), read from FriendsActivityApi (MAL RSS rss.php?type=rw/rm, already used by the notifications screen's Friends activity tab). A horizontal row of compact cards (friend avatar + title cover + status chip + 'Ep N' + relative time), tap opens the title, long press or the avatar opens the friend's profile; 'View all' opens the Friends activity tab of the notifications screen. Add it as a new home section kind SectionType.friendsActivity (append to the enum: it is the storage order), selectable and reorderable in the MAL home settings, on by default after the news row for signed-in MAL users with friends, hidden when empty or without a MAL session. Respect the existing 3 h friends refresh interval (cache) so the home does not hammer MAL.", "Check DailyAL (/home/thinkpad/.cache/mwl-mab/dailyal-108) for any friends-updates UI to follow; otherwise follow the existing MAL home row style. Never send anything to MAL; fakes only in tests."],
    dod: ["Tests: the row shows friends' updates from a saved RSS answer, hides when empty or signed out, respects the cache interval, and the section can be added/moved in the home settings."],
  },
  {
    id: "mal-pm-composer", title: "MAL messages: WhatsApp-style formatting, photo upload to catbox.moe, BBCode rendering in threads", kind: "unit", priority: "P1", group: "user", model: "opus", ui: true,
    needs: ["mal-web-recaptcha"],
    owns: ["lib/screens/mal_web/compose_message_screen.dart", "lib/screens/mal_web/message_thread_screen.dart", "lib/widgets/mal_web/message_tiles.dart", "lib/widgets/mal_web/message_composer/**", "lib/services/upload/**", "lib/l10n/units/mal-pm-composer/**", "test/units/mal-pm-composer/**"],
    goal: ["Owner request 2026-10-29 (decision in docs/DECISIONS.md): MAL private messages work like a chat app. (1) Composer (compose_message_screen.dart and the reply bar of message_thread_screen.dart): WhatsApp-style formatting: select text, the selection toolbar offers Bold, Italic, Underline, Strikethrough, Spoiler and Link, which wrap the selection in MAL BBCode ([b] [i] [u] [s] [spoiler] [url=…]); a small formatting row above the keyboard does the same for the cursor. (2) Images: an attach button picks a photo (image_picker, already a dependency), uploads it to catbox.moe (POST https://catbox.moe/user/api.php, reqtype=fileupload, fileToUpload; no account, answer is the URL) with a progress indicator and a clear error on failure, then inserts [img]URL[/img]; also 'insert image link' for an existing URL. Before sending, a preview of the formatted message. (3) Rendering: the thread bubbles and the inbox preview render MAL's message HTML/BBCode properly: bold, italic, underline, strike, spoilers (tap to reveal), links (open in app/browser), quotes, and inline images (tap to zoom), without layout errors on unbounded widths. (4) Sending still goes through MalWebFormSubmitter (reCAPTCHA), unchanged.", "Never send a real message or upload a real image from tests: fakes only. MAL screens follow DailyAL conventions; no explanatory captions."],
    dod: ["Tests: selection formatting produces the right BBCode; upload (fake) inserts [img]; rendering shows bold/italic/spoiler/image; sending unchanged."],
  },
  {
    id: "tracker-contracts", title: "Contracts for tracker isolation: tracker-tagged notification payloads, per-tracker preference reads, global notification gate", kind: "unit", priority: "P0", group: "user", model: "opus", ui: true,
    needs: ["mal-hub-followups"],
    owns: ["lib/services/notifications/notification_payload.dart", "lib/user/preferences/tracker_scope.dart", "lib/services/notifications/notification_gate.dart", "test/units/tracker-contracts/**"],
    goal: ["Read docs/tracker-isolation-audit-2026-10-29.md (section F, 'Cross-unit contracts'). Define and freeze, with doc comments and tests, the three shared shapes the next units use: (1) NotificationPayload: a tracker-tagged payload format (e.g. 'tracker:kind:id[:extra]') with build and parse, legacy payloads ('anime:<id>', 'calendar', MAL hub payloads) read as MAL; (2) TrackerScope: the list of tracker-scoped preference keys and PreferencesStore.readFor(AccountType tracker) / writeFor signatures, implemented over SharedPreferences with a key suffix ':<tracker>' and a no-op migration hook (the real split is prefs-per-tracker's job); (3) NotificationGate: a global 'allow notifications' getter/setter (permission + kill switch) separate from airing reminders, plus per-tracker channel ids. Do not wire them anywhere yet beyond what tests need.", "Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts."],
    dod: ["Tests: payload round trip and legacy parsing; readFor/writeFor isolate trackers; the gate's default and persistence."],
  },
  {
    id: "tracker-routes", title: "Routes and app bar per tracker: calendar, search, bookmarks, bell, sidebar, notification taps, startup page", kind: "unit", priority: "P0", group: "user", model: "opus", ui: true,
    needs: ["tracker-contracts", "mal-polish-2", "anilist-calendar", "kitsu-calendar", "simkl-search"],
    owns: ["lib/utils/app_routes.dart", "lib/widgets/MAL/home/homeappbar.dart", "lib/pages/side_bar.dart", "lib/screens/home_screen.dart", "lib/pages/Anilist/anilist_home_page.dart", "lib/pages/Simkl/simkl_user_page.dart", "lib/l10n/units/tracker-routes/**", "test/units/tracker-routes/**"],
    goal: ["Implement unit U1 of docs/tracker-isolation-audit-2026-10-29.md (sections A and F): openCalendar / openSearch / openBookmarks dispatch on the active tracker (AniList calendar from anilist-calendar, Kitsu calendar from kitsu-calendar, Simkl search from simkl-search, Simkl calendar existing); notification taps use NotificationPayload (tracker-contracts) and switch the active account first when the payload is another tracker's; the app bar bell / search / bookmarks / calendar per tracker (AniList bell on every AniList tab, removed from the AniList home title; Kitsu/Simkl get the bell only when they have a notification screen); sidebar entries per tracker (AniList notifications entry); startup page read per tracker.", "Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts."],
    dod: ["Tests: each route opens the active tracker's screen; a payload of another tracker switches account then opens; app bar icons per tracker."],
  },
  {
    id: "anilist-calendar", title: "AniList calendar: the weekly airing schedule from AniList", kind: "unit", priority: "P0", group: "user", model: "sonnet", ui: true,
    needs: ["tracker-contracts"],
    owns: ["lib/widgets/Anilist/calendar/**", "lib/services/api/Anilist/anilist_discover_service.dart", "lib/l10n/units/anilist-calendar/**", "test/units/anilist-calendar/**"],
    goal: ["Unit U2 of docs/tracker-isolation-audit-2026-10-29.md: an AniList weekly calendar page on AnilistDiscoverService.airing (airingSchedules), 7 days with a day strip, paged, 'My list' / 'All' (the signed-in user's Watching/Planning), the app time zone preference, rows open AnilistMediaPage (openAnilistTitle). Design from the AniList part of docs/tracker-ui-references.md.", "Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts."],
    dod: ["Tests on saved AniList responses: days grouping, my-list filter, paging."],
  },
  {
    id: "kitsu-calendar", title: "Kitsu calendar: upcoming episodes of the user's Kitsu library", kind: "unit", priority: "P0", group: "user", model: "sonnet", ui: true,
    needs: ["tracker-contracts"],
    owns: ["lib/widgets/Kitsu/calendar/**", "lib/services/api/Kitsu/kitsu_library.dart", "lib/l10n/units/kitsu-calendar/**", "test/units/kitsu-calendar/**"],
    goal: ["Unit U3 of docs/tracker-isolation-audit-2026-10-29.md: Kitsu has no schedule endpoint; build the calendar from the user's library (Currently watching / Want to watch) with GraphQL Anime.nextRelease (check the field anonymously first), optionally enriched by LiveChart through the MAL id; day strip, local time zone, rows open the native Kitsu page (openKitsuTitle). Design from the Kitsu part of docs/tracker-ui-references.md.", "Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts."],
    dod: ["Tests on saved Kitsu responses."],
  },
  {
    id: "simkl-search", title: "Simkl search screen so the search icon opens Simkl's search on Simkl", kind: "unit", priority: "P0", group: "user", model: "sonnet", ui: true,
    needs: ["tracker-contracts"],
    owns: ["lib/widgets/Simkl/search/**", "lib/pages/Simkl/simkl_explore_page.dart", "lib/l10n/units/simkl-search/**", "test/units/simkl-search/**"],
    goal: ["Unit U9 of docs/tracker-isolation-audit-2026-10-29.md: a standalone Simkl search screen (extract and reuse the Explore search logic), results open the native Simkl page. Design from the Simkl part of docs/tracker-ui-references.md.", "Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts."],
    dod: ["Tests on saved Simkl responses."],
  },
  {
    id: "home-layout-per-tracker", title: "Home layout settings per tracker", kind: "unit", priority: "P0", group: "user", model: "sonnet", ui: true,
    needs: ["tracker-contracts", "mal-friends-feed"],
    owns: ["lib/user/MAL/mal_home_page_preferences.dart", "lib/user/MAL/mal_home_preferences_bloc.dart", "lib/screens/settings/mal_home_settings.dart", "lib/l10n/units/home-layout-per-tracker/**", "test/units/home-layout-per-tracker/**"],
    goal: ["Unit U4 of docs/tracker-isolation-audit-2026-10-29.md: HomePreferencesBloc follows the active tracker and stores home_preferences_v2:<tracker> (TrackerScope from tracker-contracts), migrating mal_home_preferences into each tracker once; the home settings page edits the active tracker's layout, names the tracker, and offers only the sections that tracker can fill. Home pages keep reading state.preferences.", "Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts."],
    dod: ["Tests: editing the AniList layout leaves MAL's unchanged; migration; sections offered per tracker."],
  },
  {
    id: "prefs-per-tracker", title: "Tracker settings per tracker (title language, NSFW, list, cards, detail tabs\u2026)", kind: "unit", priority: "P0", group: "user", model: "opus", ui: true,
    needs: ["tracker-contracts", "home-layout-per-tracker"],
    owns: ["lib/user/preferences/**", "lib/screens/settings/user_prefs_settings.dart", "lib/screens/settings/list_prefs_settings.dart", "lib/screens/settings/anime_manga_settings.dart", "lib/screens/settings/dub_settings.dart", "lib/screens/settings/prefs/**", "lib/widgets/user/list/card_layout_editor.dart", "lib/screens/settings/settings_page.dart", "lib/l10n/units/prefs-per-tracker/**", "test/units/prefs-per-tracker/**"],
    goal: ["Unit U5 of docs/tracker-isolation-audit-2026-10-29.md (section B): split general/content/list preference groups into app scope vs tracker scope (use TrackerScope from tracker-contracts), per-tracker storage with a one-time migration, PreferencesBloc swaps the tracker scope when the active account changes (readers unchanged), tracker-scoped settings pages say which tracker they edit. Exclude notification_preferences.dart (notifications-all-trackers owns it).", "Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts."],
    dod: ["Tests: a tracker setting changed on AniList leaves MAL's; migration keeps current values for every tracker; app-scope settings stay global."],
  },
  {
    id: "bookmarks-per-tracker", title: "Bookmarks per tracker", kind: "unit", priority: "P0", group: "user", model: "sonnet", ui: true,
    needs: ["tracker-contracts"],
    owns: ["lib/screens/bookmarks_screen.dart", "lib/widgets/bookmarks/**", "lib/cache/bookmarks.dart", "lib/pages/Anilist/anilist_media_page.dart", "lib/pages/Kitsu/kitsu_media_page.dart", "lib/pages/Simkl/simkl_media_page.dart", "lib/l10n/units/bookmarks-per-tracker/**", "test/units/bookmarks-per-tracker/**"],
    goal: ["Unit U8 of docs/tracker-isolation-audit-2026-10-29.md: the bookmarks screen shows the active tracker's bookmarks only; bookmark buttons on the AniList, Kitsu and Simkl title pages keyed by their own ids; opening a bookmark opens that tracker's own page.", "Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts."],
    dod: ["Tests: bookmarks isolated per tracker; open goes to the native page."],
  },
  {
    id: "notifications-all-trackers", title: "Notifications from every connected tracker, one group of switches per tracker", kind: "unit", priority: "P0", group: "user", model: "opus", ui: true,
    needs: ["tracker-contracts", "prefs-per-tracker"],
    owns: ["lib/services/notifications/notification_service.dart", "lib/services/notifications/mal_hub.dart", "lib/services/notifications/anilist_*", "lib/services/notifications/kitsu_*", "lib/services/notifications/simkl_*", "lib/main.dart", "lib/screens/settings/notifications_settings.dart", "lib/user/preferences/notification_preferences.dart", "lib/services/api/Anilist/anilist_list_service.dart", "lib/services/api/SimKl/simkl_list_service.dart", "lib/l10n/units/notifications-all-trackers/**", "test/units/notifications-all-trackers/**"],
    goal: ["Unit U6 of docs/tracker-isolation-audit-2026-10-29.md (section C): global 'allow notifications' (NotificationGate) separate from airing; per-tracker airing switches; the airing planner fed by every connected tracker (dedupe by anime, NotificationPayload per tracker), AniList via airingSchedules, Simkl via its calendar file, MAL/Kitsu via LiveChart; drop candidateTracker / replan-on-switch; the WorkManager job runs a round per connected tracker (MAL hub, AniList inbox, Kitsu if its API allows it, Simkl airing) and is registered when any tracker has any switch on; Settings > Notifications shows one group per connected tracker. Do not touch mal_hub_poller.dart (mal-pm-chat-notifications owns it).", "Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts."],
    dod: ["Tests: each tracker notifies when not active; switches per tracker; the job is registered without the airing master."],
  },
  {
    id: "mal-pm-chat-notifications", title: "MAL messages: chat-style phone notifications, fast while the app is open", kind: "unit", priority: "P0", group: "user", model: "opus", ui: true,
    needs: ["tracker-contracts", "mal-pm-composer"],
    owns: ["lib/services/notifications/mal_hub_poller.dart", "lib/widgets/mal_web/message_tiles.dart", "lib/screens/mal_web/message_thread_screen.dart", "lib/l10n/units/mal-pm-chat-notifications/**", "test/units/mal-pm-chat-notifications/**"],
    goal: ["Unit U7 of docs/tracker-isolation-audit-2026-10-29.md (section D): the PM notification path depends only on its own switch and NotificationGate (not the airing master); a high-importance 'mal_messages' channel with MessagingStyle, sender name and avatar, one notification per thread, cancelled when the thread is read; a fast foreground inbox poll (every 2-5 min while the app is resumed); the MAL web session missing/expired state exposed (ValueNotifier) so the settings can show it. Owner: 'quand quelqu'un m'écrit un message, ça doit activer une notification… comme WhatsApp'.", "Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts."],
    dod: ["Tests: a new message raises one notification in the mal_messages channel with the sender; reading the thread cancels it; foreground poll interval; works with the airing switch off."],
  },
  {
    id: "mal-graph-local", title: "MAL relation graph built in the app (no backend needed)", kind: "unit", priority: "P0", group: "trackers", model: "opus", ui: true,
    needs: ["mal-hub-followups"],
    owns: ["lib/widgets/graph/**", "lib/services/api/MAL/anime_graph_builder.dart", "lib/l10n/units/mal-graph-local/**", "test/units/mal-graph-local/**"],
    goal: ["Owner report 2026-10-30: the MAL anime relation graph never works. Cause (checked by the orchestrator): AnimeGraphScreen loads it from the self-hosted mwl-rust-api (GET {API_URL}/anime/{id}/related with API_SECRET) and API_URL is empty in assets/.env, so the request is never sent and the screen fails. Build the graph inside the app instead, with the same algorithm as mwl-rust-api/src/anime_service.rs (get_related_anime_with_graph): start from the title, MAL API v2 /anime/{id}?fields=related_anime,... (MalApi, the app's client id / user token), follow valid relation types (the root also includes 'other' relations, the others do not, as valid_relation does), BFS with 5 requests at a time, skip visited nodes, produce the same nodes/edges JSON shape AnimeGraphData.fromJson reads. Bound it (e.g. 120 nodes, stop politely on 429 with what is loaded), cache per title (session + disk, a few days), show progress while it grows. Keep the Rust API as an optional first source when API_URL is set and answers; otherwise the local builder.", "Fakes only in tests (saved MAL related_anime answers)."],
    dod: ["Tests on saved MAL answers: graph nodes/edges match the Rust algorithm (root other relations, no others after), bounds and 429 stop, cache; the screen loads without API_URL."],
  },
  {
    id: "explore-polish", title: "Explore: DailyAL images on category and genre cards, explicit genres, recommendations/stacks fallbacks, favourites badges", kind: "unit", priority: "P1", group: "discovery", model: "opus", ui: true,
    needs: ["search-sources", "explore-seasonal", "home-wiring", "profile-tabs"],
    owns: ["lib/services/api/MAL/scrapper/html_parsers.dart", "test/units/explore-crash/**", "lib/pages/MAL/mal_explore_page.dart", "lib/screens/explore/**", "assets/images/explore/**", "pubspec.yaml", "lib/cache/top_characters.dart"],
    dal: ["lib/pages/search/all_genre_widget.dart", "lib/pages/search/allrankingwidget.dart", "web_assets/ (category and genre images, MIT)", "lib/pages/explorepage.dart"],
    goal: ["Owner: on the Explore page a ☰ icon sits next to the avatar and does the same as tapping the avatar (opens the sidebar). It is Flutter's automatic endDrawer button (the home shell has an endDrawer, the Explore AppBar does not set `automaticallyImplyActions: false`): set it on every AppBar under the shell that shows the home header (Explore first), so only the avatar opens the sidebar.", 
      "Owner's screenshots of the Explore page: (1) Recommendations 'Couldn't load this section' and Interest Stacks 'Nothing to show right now' — wire the new MwlApi global recommendations / interest stacks methods (profile-tabs PR) as the source when Jikan fails (or first), with clean states; (2) Characters and Seiyuu cards: add a ♥ favourites badge (number of people who favourited the character / person, from the top characters/people data); (3) the Seasonal card's 'Search By Season' button text is truncated ('Search By Se…'): redo the layout so both buttons show their full label in every language and width; (4) Genres: the Explicit genres type is missing — add it (anime and manga, respecting the NSFW pref for visibility/blur as appropriate).",
      "Images like DailyAL (owner request): every category / ranking card and every genre card shows its background picture, as DailyAL does. DailyAL's pictures live in its MIT-licensed repo (`web_assets/`, ~6 MB: `<type>_<category>.jpg` for rankings, `web_assets/genres/<id>_<category>.jpg`); our repo is private, so BUNDLE them as app assets under assets/images/explore/ (copy from /home/thinkpad/.cache/mwl-mab/dailyal-108/web_assets, declare the folders in pubspec.yaml, credit DailyAL via LicenseRegistry with its MIT text). Text on the pictures stays readable through the scrim token; decode at card size (AppImage / ResizeImage) so scrolling stays smooth.",
      "Add a Studios entry on the Explore page opening `StudiosScreen` (lib/screens/studios/studios_screen.dart, from search-sources).",
      "Theme tokens only; full translatability (English + French).",
    ],
    dod: ["Checker: Explore on the owner's network — recommendations and stacks show content, character/seiyuu cards show ♥ counts, seasonal buttons fully readable, genre and category cards with pictures like DailyAL, Explicit genres present."],
  },
  {
    id: "tracker-wiring", title: "AniList / Kitsu / Simkl wiring: notifications, profile routes, remove action, MAL-only notes", kind: "unit", priority: "P1", group: "trackers", model: "sonnet", ui: true,
    needs: ["anilist-pages", "kitsu-pages", "simkl-pages"],
    owns: ["lib/widgets/user/list/user_list_view.dart", "lib/services/notifications/notification_service.dart", "lib/services/notifications/**", "lib/utils/app_routes.dart", "lib/widgets/user/sync/**", "lib/screens/settings/user_prefs_settings.dart", "lib/screens/settings/anime_manga_settings.dart", "lib/screens/settings/list_prefs_settings.dart", "lib/screens/settings/prefs/**", "test/units/app-shell/app_routes_test.dart"],
    goal: [
      "Notifications: when the active tracker is AniList, Kitsu or Simkl, feed the planner with that tracker's Watching / Plan to watch candidates (`AnilistListService.airingCandidates()`, `KitsuLibrary.instance.airingCandidates()`, the Simkl equivalent from simkl-pages) — entries are mapped to MAL ids, so the calendar's AiringSchedule works for them.",
      "Profile routes: `AppRoutes.openUserProfile` / `openUserStats` (`_hasProfileScreen`) open the real AniList / Kitsu / Simkl profile screens (other users included where the tracker allows it) instead of the stub.",
      "Tracker entry editor (lib/widgets/user/sync/**, `showTrackerEntryEditor`): add a confirmed 'Remove from list' action for AniList, Kitsu and Simkl (owner decision).",
      "Preference pages: when the active tracker is not MAL, mark MAL-only options (NSFW, priority, airing info, auto dates, MAL statuses…) with a visible translated note (owner decision).",
      "UserListView gets a `categories` parameter so trackers without manga (Simkl) hide the Anime/Manga switch cleanly (simkl-pages finding).",
      "Never write to the owner's trackers in tests (fakes only).",
    ],
    dod: ["Checker: switch to AniList on the emulator, open a profile link and a list entry editor (cancel); notifications settings show AniList candidates."],
  },
  {
    id: "theme-seasons", title: "Seasonal accents like DailyAL (spring pink, summer deep orange, fall brown, winter light blue)", kind: "unit", priority: "P0", group: "settings", model: "opus", ui: true,
    needs: ["theme-colors"],
    owns: ["test/units/theme-colors/theme_test.dart", "lib/user/theme/**", "lib/widgets/common/app_colors.dart", "lib/screens/settings/theme_settings.dart", "docs/THEME.md"],
    dal: ["lib/theme/themedata.dart:56-70 (season → accent)", "lib/theme/theme.dart (default Brown + Fall background)"],
    goal: [
      "Batch-4 check, owner wish 'DailyAL's pastel tone': MWL's default accent is Blue Grey (#607D8B, app_themes.dart:59) whatever the background, so chips, tabs and the nav pill stay grey-blue on a pink or orange background. DailyAL ties the accent to the season background (spring → pink, summer → deep orange, fall → brown, winter → light blue) and defaults to Brown + the Fall background.",
      "Do the same: each seasonal background picks its DailyAL accent automatically (an 'Auto (season)' accent choice, default), while an explicit accent pick (preset / custom / Material You) still wins. Default for a new install: DailyAL's (Brown + Fall). Keep the pastel recipe, black mode and every contrast test green.",
      "Theme settings: the mode button 'Light' untranslated and 'Sombre' shrunk to a tiny font — fix the labels (no shrinking text) (batch-4 check).",
    ],
    dod: ["Tests: each season maps to DailyAL's accent; explicit picks override; contrast tests pass.", "Checker: Spring / Summer / Fall / Winter screenshots side by side with DailyAL."],
  },
  {
    id: "detail-polish", title: "Detail page polish: News never loads, faster fallbacks, status colours, tabs, numbers", kind: "unit", priority: "P0", group: "detail", model: "opus", ui: true,
    needs: ["detail-resilience", "detail-header", "home-wiring"],
    owns: ["lib/widgets/MAL/home/animecharacterwidget.dart", "lib/screens/MAL/characters_staff_screen.dart", "lib/widgets/MAL/content/show_reviews.dart", "lib/widgets/MAL/review/**", "lib/screens/MAL/detail/**", "lib/widgets/MAL/content/animestatisticswidget.dart", "lib/widgets/MAL/home/show_news.dart", "lib/services/api/Jikan/**"],
    goal: [
      "BLOCKING (batch-4 check): News on detail pages loads forever — lib/widgets/MAL/home/show_news.dart:52-62 `_fetchNews` has no try/catch, `JikanUnavailable` is unhandled and the skeleton never goes. Content, empty state or error + Retry, like every other section (repro: Cowboy Bebop, Shuiro no Kamen).",
      "OWNER REQUEST (anime page): the CHARACTERS, STAFF and REVIEWS sections must have THE SAME UI AS DAILYAL — detail-resilience changed them to 56 dp circles in rows; the owner wants DailyAL's layout back (read DAL lib/pages/animedetailed/animecharacterwidget.dart, lib/widgets/character_va_tile.dart and lib/pages/animedetailed/reviewpage.dart / review list in the detail page; reproduce them in MWL's architecture). Keep the earlier owner rule: NO grey rectangular shadow / box behind character or staff images. Keep the Jikan fallbacks and clean states. Characters & staff full screen (characters_staff_screen.dart) follows the same DailyAL style.",
      "Faster fallbacks (owner target ~12 s): the MAL fallback only starts after Jikan's 12 s timeout and then waits up to 15–20 s (content_stats_source.dart:77-91, jikan_fallbacks.dart:24): start the fallback early (race Jikan against the fallback after a short head start, or skip Jikan immediately while its circuit breaker is open), cap the total at ~12 s.",
      "Status colours: the detail edit FAB (detail_fab.dart:36 → getAnimeStatusColor / constants getStatusColor) and the Stats chart (animestatisticswidget.dart:30-34) must use the theme-colors status tokens (DailyAL's green/blue/orange/red/brown).",
      "Tapping a detail tab while the header is fully expanded highlights the tab but does not scroll — make it scroll. Manga header authors show a leading comma (', Nabana'). Header numbers use the app locale (header_meta.dart:17-19 static NumberFormat without locale: '2,169' → '2 169' in French).",
    ],
    dod: ["Tests with a failing fake Jikan: News ends in a state; fallbacks finish under ~12 s; status colours = tokens; French number formatting.", "Checker: Cowboy Bebop and Shuiro no Kamen on the owner's network."],
  },
  {
    id: "home-fixes", title: "Home: user-list cache per account", kind: "unit", priority: "P1", group: "discovery", model: "sonnet", ui: true,
    needs: ["home-wiring"],
    owns: ["lib/widgets/MAL/home/homeappbar.dart", "lib/widgets/home/**", "lib/pages/MAL/mal_home_page.dart"],
    goal: ["Owner: the ☰ menu icon next to the avatar in the home header does the same as tapping the avatar (both open the sidebar) — REMOVE the ☰ icon (lib/widgets/MAL/home/homeappbar.dart); keep tap avatar = sidebar, long press / swap badge = account switcher sheet.", "The home 'My list' section cache key (lib/widgets/home/home_sections.dart:231) does not include the account: after switching account from the avatar sheet the previous account's list stays until pull-to-refresh. Key every per-user section by tracker + account id and clear on account switch (AccountBloc stream). Maintenance dialog must show at most once even under a race (batch-4 check)."],
    dod: ["Test: switching account invalidates the user-list section."],
  },
  {
    id: "backup-fixes", title: "Backup restore never stops halfway; About closes its HTTP client", kind: "unit", priority: "P1", group: "settings", model: "sonnet",
    needs: ["in-app-update", "settings-theme-about-backup"],
    owns: ["lib/cache/cachemanager.dart", "lib/screens/settings/backup_settings.dart", "lib/screens/settings/about_settings.dart", "lib/screens/settings/storage_settings.dart"],
    goal: [
      "Restore can stop halfway (cachemanager.dart:433-436 does not validate each section's version): validate the whole file first (every section's version, shape), then write all sections or none, then reload; the preview counts must equal what is restored.",
      "Add the theme-seasons pref key `accent_season_v1` to `BackupService.settingsKeys` so a restore keeps Auto (season).",
      "about_settings.dart:44 never closes its http.Client.",
      "Storage page sizes in the app locale ('115,4 Mo' in French, storage_settings.dart:90-100 uses toStringAsFixed).",
    ],
    dod: ["Tests: a file with a bad section restores nothing and reports it; preview counts = restored counts."],
  },
  {
    id: "release-fixes", title: "Release: versionCode bump, launcher label, restricted update provider", kind: "unit", priority: "P2", group: "release", model: "sonnet",
    needs: ["versioning-ci", "in-app-update"],
    owns: [".github/**", "tools/release/**", "android/app/src/main/AndroidManifest.xml", "lib/services/updater/**"],
    goal: [
      "tools/release/version.sh (~62-75) never commits the bump back, so every CI release is built with versionCode +2 of the committed one: make the code monotonic (derive it from the tag date / run number, or commit the bump) — explain the choice.",
      "Launcher label: AndroidManifest.xml:19 `android:label=\"mywatchlist\"` → \"MyWatchList\".",
      "Issue #153: install updates through the app's restricted FileProvider (@xml/updater_paths) instead of open_filex's broad provider.",
    ],
    dod: ["actionlint or line-by-line review of the workflow; tests for the version script; manifest checked by a test."],
  },
  {
    id: "in-app-update", title: "In-app update: check GitHub releases, download and install APK", kind: "unit", priority: "P2", group: "release", model: "sonnet", ui: true,
    needs: ["settings-theme-about-backup", "versioning-ci"],
    owns: ["lib/services/updater/**", "lib/screens/settings/about_settings.dart", "android/app/src/main/res/xml/updater_paths.xml"],
    dal: ["lib/pages/settings/about.dart", "lib/util/download_manager.dart", "commits bd376af, 1871053"],
    goal: ["Check latest release of goddivor/mywatchlist, download the right APK, install through FileProvider content URI (the provider declared by deps-prefs-contract reuses open_filex's broad `@xml/filepaths`: give it a dedicated `res/xml/updater_paths.xml` limited to the download cache, and report the one-line manifest change as a finding); button in About."],
    dod: ["Update check reports correctly on the emulator (no release newer → 'up to date')."],
  },
  {
    id: "deep-links", title: "Open myanimelist.net links in the app", kind: "unit", priority: "P2", group: "release", model: "sonnet",
    needs: ["app-shell", "deps-prefs-contract"],
    owns: ["lib/utils/deep_links.dart"],
    dal: ["lib/util/pathutils.dart", "android/app/src/main/AndroidManifest.xml (intent filters)", "main.dart onGenerateRoute"],
    goal: ["Register `WebLauncher.internalLinkHandler` (shared-kit, lib/utils/web_launcher.dart) from lib/utils/deep_links.dart at startup so in-app MAL links (anime, manga, character, people, forum, profile) open their screen instead of a browser tab; handled MAL links open directly, without a confirmation dialog (owner default). Map myanimelist.net anime/manga/character/people/profile/forum URLs to in-app screens via app_routes. The intent filters go in the manifest (contract's file): report the exact XML as a finding."],
    dod: ["`adb shell am start -d https://myanimelist.net/anime/1` opens Cowboy Bebop in the app."],
  },
];

/* ─── generation ─── */
const by = new Map(UNITS.map((u) => [u.id, u]));
for (const u of UNITS) {
  if (u.id !== "l10n-pipeline" && !u.owns.some((o) => o.startsWith("lib/l10n/units/"))) u.owns = [...u.owns, `lib/l10n/units/${u.id}/**`];
  if (u.id !== "gate-fix") u.owns = [...u.owns, `test/units/${u.id}/**`];
  for (const n of u.needs) if (!by.has(n)) throw new Error(`${u.id}: needs unknown unit ${n}`);
  if (!GROUPS.find((g) => g.id === u.group)) throw new Error(`${u.id}: unknown group ${u.group}`);
}

const INDEX = join(ROOT, "INDEX.md");
const prior = new Map();
if (existsSync(INDEX)) {
  for (const line of readFileSync(INDEX, "utf8").split("\n")) {
    const m = line.match(/handoffs\/([a-z0-9-]+)\.md.*\|\s*([^|]+?)\s*\|\s*$/);
    if (m) prior.set(m[1], m[2]);
  }
}
/* Never downgrade a done status: a regeneration from a stale INDEX must not undo a merge gate's "done". */
const priorJson = new Map();
try { for (const u of JSON.parse(readFileSync(join(ROOT, "units.json"), "utf8")).units) priorJson.set(u.id, u.status); } catch {}
const statusOf = (u) => {
  if (u.dropped) return "⛔ dropped";
  const fromIndex = prior.get(u.id), fromJson = priorJson.get(u.id);
  if (/done/.test(fromIndex ?? "") || /done/.test(fromJson ?? "")) return "✅ done";
  return fromIndex ?? fromJson ?? "⬜ todo";
};
const unitsOf = (g) => UNITS.filter((u) => u.group === g);

const UI_DIRECTIVE = `**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in \`lib/user/theme/\` (accent color, fonts, dark/black modes). Describe the before/after in the PR body. **Strings:** every screen you own must be fully translatable — move its existing hardcoded literals (e.g. settings_page.dart:55,119, mal_home_page.dart:45-47, mal_home_page_preferences.dart:65) to \`S\` through your l10n fragment; the checker switches the app to French and flags any English left on your screens. **Colours:** no hardcoded \`Colors.*\` or \`Color(0x…)\` in your screens: use \`Theme.of(context).colorScheme\` and the semantic tokens of lib/widgets/common/app_colors.dart (theme-colors unit, see docs/THEME.md once merged); move the existing hardcoded colours of your files to them. Every text must stay readable on its background (buttons, chips, badges, text on images) in light, dark and black modes.`;

const PERF_RULES = `**Fluidity rules (owner's rule: MWL must feel as smooth as DailyAL).** See \`docs/PERFORMANCE.md\` once perf-foundation has merged, and \`work/inventory/performance.md\`.
- Network images only through \`AppImage\` (decode at displayed size); no \`Image.network\`.
- Long or unbounded lists: \`ListView.builder\`/slivers, never a \`Column\` of many children in a \`SingleChildScrollView\`; no \`shrinkWrap: true\` list inside another scroll view; no scroll view per list item.
- No \`Opacity\`, \`BackdropFilter\`, \`ImageFilter.blur\`, \`ShaderMask\` or blurred \`BoxShadow\` on repeated items or on whole pages during animations; use alpha colors / FadeTransition.
- No \`setState\` in scroll listeners; listeners added once and removed in dispose; dispose every controller you create.
- BlocBuilder/Consumer as low in the tree as possible, with \`buildWhen\`/\`BlocSelector\`/\`context.select\`; \`const\` constructors wherever possible.
- Heavy JSON/HTML parsing off the UI isolate (\`Isolate.run\`/\`compute\`); no sync storage reads in \`build\`; no \`print\` in hot paths.
- Look at how DAL makes the same screen fluid and do at least as well; the checker compares janky-frame % on a profile build.`;

mkdirSync(join(ROOT, "handoffs"), { recursive: true });
const list = (a) => (a?.length ? a.map((x) => `- ${x}`).join("\n") : "- none");
for (const u of UNITS) {
  const md = `# Handoff — \`${u.id}\`: ${u.title}

**Kind** ${u.kind} · **Priority** ${u.priority} · **Group** ${u.group} · **Model** ${u.model}

## Needs done first
${u.needs.length ? u.needs.map((n) => `- \`${n}\` (${by.get(n).title})`).join("\n") : "- nothing"}

## Owns (may create or edit ONLY these)
${list(u.owns.map((o) => `\`${o}\``))}

Plus \`PROJECT-STATE.md\` (rewrite in place, within its cap) and \`docs/DECISIONS.md\` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
${list(u.goal)}

## Known bugs to fix in scope
${list(u.bugs)}

## DailyAL reference (read, never copy blindly)
Checkout: \`${DAL}\` (DAL \`upstream/2026.2.6+108\`, read-only).
${list((u.dal ?? []).map((d) => `\`${d}\``))}

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (\`lib/services/api/**\`), \`S\` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
\`work/inventory/*.md\` lists, per feature, what MWL has and the bugs found on 2026-10-27.

${u.ui ? UI_DIRECTIVE + "\n\n" + PERF_RULES + "\n\n" : ""}## Definition of Done
${list(u.dod)}
- \`tools/heavy.sh flutter analyze\` clean (the gate runs the full \`tools/heavy.sh tools/verify.sh\`).
- PR against \`dev\` with \`Closes #<issue>\`, gate tail, decisions, findings.
`;
  writeFileSync(join(ROOT, "handoffs", `${u.id}.md`), md, "utf8");
}

const rows = (g) => unitsOf(g.id).map((u) => `| \`${u.id}\` | [${u.title}](handoffs/${u.id}.md) | ${u.kind} | ${u.priority} | ${u.model} | ${u.needs.map((n) => `\`${n}\``).join(", ") || "—"} | ${statusOf(u)} |`).join("\n");
writeFileSync(INDEX, `# Port queue — DailyAL → MyWatchList

Generated by \`work/_generate-units.mjs\`. Only the **Status** column is hand-edited (⬜ todo · 🟡 in progress · ✅ done · ⛔ dropped).

${GROUPS.map((g) => `## ${g.title} (${g.priority})

| Id | Unit | Kind | Prio | Model | Needs | Status |
|---|---|---|---|---|---|---|
${rows(g)}`).join("\n\n")}
`, "utf8");

writeFileSync(join(ROOT, "START-PROMPTS.md"), `# Start prompts

One block per unit, pasted unchanged into the builder brief after the filled \`tools/briefs/builder.md\`.

${UNITS.map((u) => `## ${u.id}

\`\`\`text
Unit ${u.id} — ${u.title}.
Read work/handoffs/${u.id}.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
${u.ui ? "UI directive applies: compare DAL and MWL, keep the better, improve it.\n" : ""}Deliver with the PR procedure of the brief.
\`\`\``).join("\n\n")}
`, "utf8");

writeFileSync(join(ROOT, "units.json"), JSON.stringify({
  groups: GROUPS.map((g) => ({ id: g.id, title: g.title, priority: g.priority, units: unitsOf(g.id).map((u) => u.id) })),
  units: UNITS.map((u) => ({
    id: u.id, title: u.title, kind: u.kind ?? "unit", entry: u.entry ?? "", artifact: u.artifact ?? "",
    priority: u.priority, needs: u.needs ?? [], owns: u.owns ?? [], group: u.group ?? null,
    dropped: u.dropped ?? null, skills: u.skills ?? [], states: u.states ?? [], notes: [`model: ${u.model}`],
    status: statusOf(u),
  })),
}, null, 2) + "\n", "utf8");

console.log(`${UNITS.length} units, ${GROUPS.length} groups → INDEX.md, handoffs/, START-PROMPTS.md, units.json`);
