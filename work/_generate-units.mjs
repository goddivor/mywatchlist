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
    owns: ["test/units/app-shell/app_routes_test.dart", "lib/utils/app_routes.dart", "lib/pages/MAL/mal_user_profile_page.dart", "lib/screens/user_profile/**", "lib/widgets/user/profile/**", "lib/widgets/charts/**", "lib/services/api/MAL/scrapper/user_anime_statistics.dart", "lib/services/api/MAL/scrapper/user_friends.dart", "lib/services/api/MAL/scrapper/user_history.dart", "lib/services/api/MAL/user_anime_statistics.dart", "lib/services/api/MAL/mal_user_prof.dart", "lib/cache/cached_user_profile.dart"],
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
    owns: ["lib/screens/user_profile/sections/**", "lib/services/api/mwl_api.dart", "mwl-api/**", "lib/services/api/MAL/scrapper/user_friends.dart", "lib/services/api/MAL/scrapper/user_history.dart"],
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
    owns: ["lib/screens/MAL/featured_screen.dart", "lib/widgets/MAL/content/show_featured.dart", "lib/widgets/MAL/content/show_forum.dart", "lib/widgets/MAL/content/show_news.dart", "lib/screens/MAL/character_screen.dart", "lib/screens/MAL/characters_staff_screen.dart"],
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
    needs: ["splash-screen", "stack-polish", "color-sweep", "backup-fixes", "release-fixes", "explore-polish", "tracker-wiring", "gate-fix", "auth-refresh", "backend-parsers", "mal-auth-calls", "l10n-pipeline", "deps-prefs-contract", "app-shell", "detail-split", "shared-kit", "perf-foundation", "accounts-ux", "edit-sheet", "user-list-mal", "user-profile-mal", "sync-dialog", "detail-header", "detail-related-graph", "detail-synopsis-media", "detail-social", "detail-more-info", "bookmarks", "calendar", "explore-seasonal", "search-upgrade", "home-wiring", "cards-upgrade", "settings-prefs-pages", "settings-theme-about-backup", "notifications", "dub-info", "api-prefs", "forum-clubs", "featured-characters", "anilist-pages", "kitsu-pages", "simkl-pages", "versioning-ci", "in-app-update", "deep-links"],
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
    owns: ["lib/widgets/Anilist/**/anilist_user_list_adapter.dart", "lib/widgets/Kitsu/**/kitsu_user_list_adapter.dart", "lib/widgets/user/cross_tracker_widget.dart", "lib/pages/Simkl/**/simkl_user_page.dart", "lib/screens/settings/notifications_settings.dart", "lib/services/notifications/**"],
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
    id: "explore-polish", title: "Explore: DailyAL images on category and genre cards, explicit genres, recommendations/stacks fallbacks, favourites badges", kind: "unit", priority: "P1", group: "discovery", model: "opus", ui: true,
    needs: ["search-sources", "explore-seasonal", "home-wiring", "profile-tabs"],
    owns: ["lib/pages/MAL/mal_explore_page.dart", "lib/screens/explore/**", "assets/images/explore/**", "pubspec.yaml", "lib/cache/top_characters.dart"],
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
