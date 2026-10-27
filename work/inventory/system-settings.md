# Inventory — system / settings layer (DAL `upstream/2026.2.6+108` vs MWL `dev`, 2026-10-27)

Status: PORTED / PARTIAL / MISSING. Read from code, not docs. Bugs found on MWL side are marked **BUG**.

## Settings hub
| Feature | DAL | Status | MWL | Notes |
|---|---|---|---|---|
| Settings page | pages/settings_page.dart | PARTIAL | screens/settings/settings_page.dart | Empty `onTap` stubs: MAL Account (l.147), Connected Services (l.158), About (l.174), Help (l.185). Missing: Notifications, User prefs, List prefs, Anime/Manga, Dub, Backup, Clear storage. Strings hardcoded English. |
| Accounts screen | settings/accounts_settings.dart | PARTIAL | user/accounts/account_bloc.dart, user/trackers/** | **BUG** main.dart:60-75 builds and listens to an `AccountBloc` never provided; the provided one is a new instance (l.91) → `AccountManagerSingleton` sync listener dead. |
| Clear app storage | settings_page `_clearAppStorage` | MISSING | cache/cachemanager.dart `resetData` | |
| About (version, changelog, licence, rate) | settings/about.dart | MISSING | — | no `package_info_plus` |
| In-app update (APK) | about.dart, util/download_manager.dart | MISSING | — | |

## Theme
| Feature | Status | MWL | Notes |
|---|---|---|---|
| Mode Auto/Light/Dark/Black | PORTED | user/theme/** , screens/settings/theme_settings.dart | |
| Accent presets | PARTIAL | app_themes.dart | 19 presets; missing Material You "Auto" (`dynamic_color`) and custom colors (`flex_color_picker`) |
| Background image presets / gallery | PORTED | theme_bloc, utils/sidebar_bg_manager.dart | |
| 6 fonts | PORTED | app_themes `availableFonts` | |

## Language / l10n
| Feature | Status | Notes |
|---|---|---|
| Locales | PARTIAL | generated messages for 11 locales copied, but **no .arb sources, no l10n.yaml/intl_utils** → strings cannot be regenerated; CI `flutter gen-l10n` fails |
| Language picker | PARTIAL, **BROKEN** | (1) codes in supported_languages.dart (`fr`,`es`…) ≠ generated (`fr_FR`…) → only en/ja load; `it`,`zh` have no translations; ar/id/tr missing. (2) language_bloc.dart:27 `void … async` + emit after await → assertion. (3) `LanguageLoadStarted` never calls `S.load`. (4) main.dart:203 hardcodes `en_US`; MaterialApp ignores LanguageBloc. (5) two storage keys. |
| RTL | MISSING | |

## User preferences (DAL settings/userprefsetting.dart, user/userpref.dart)
| Pref | Status | Notes |
|---|---|---|
| Preferred title EN/JA/Romaji | PARTIAL | per-screen toggle in MAL detail only, not saved, not applied to lists |
| Startup page | MISSING | |
| NSFW | MISSING | `showMatureContent` field unused, no `nsfw=` param |
| Show anime/manga card, allow YouTube player, keep pages in memory, show priority, auto-translate synopsis, only last quote, auto start/end date, airing info in list, stats chart colors | MISSING | |
| Preferred link type | PARTIAL | hardcoded `streaming` in widgets/MAL/content/media_platforms.dart:55 |
| Prefer AniList | PORTED (different) | replaced by active tracker switch |

## Anime/Manga settings (DAL user/anime_manga_pref.dart)
Countdown on detail, detail background, show private notes, hide score, global seasonal filter, default add-to-list status, custom list tabs: all MISSING (fields dropped / `anime_manga_tab_pref.dart` unused). Timezone pref: plumbing only (user_preference.dart:85-98, never called; `TimezonePref` declared twice).

## List preferences
Default list tab, custom card view (`lib/user/list_pref.dart`, 422 lines, unused): MISSING.

## Home page settings
Reorder/enable/reset, tile size, items per category, cache frequency: PORTED **MAL only** (AniList/Kitsu/Simkl home ignore HomePreferencesBloc). Custom items (forum boards, user list, season/year): PARTIAL.

## Notifications
Airing notifications, large image, permission/test/reschedule, open from notification: all MISSING (no `flutter_local_notifications`, `timezone`, no manifest permissions/receivers).

## Dub info
MISSING (asset `MyDubListIcons.ttf` present, unused).

## Backup / storage / caches
| Feature | Status | Notes |
|---|---|---|
| Backup & restore | PARTIAL | cachemanager.dart:127,145 exist, never called, no UI |
| Cross-tracker sync | PORTED (extended) | services/tracker_sync_service.dart — MAL → others only |
| Cached user profile, bookmarks, top characters cache, user list status cache, insights | MISSING | bookmarks action commented in screens/plainscreen.dart:31 |
| History | PARTIAL | search history only |
| Error reporting | MISSING | CI writes `ERROR_REPORT_URL`, unused |
| Deep links myanimelist.net | MISSING | |

## Auth
| Feature | Status | Notes |
|---|---|---|
| Token refresh | PARTIAL, **BUG** | base_user.dart:79-196 `makeAuthenticatedRequest`/`refreshCurrentToken` never called; no 401 handling → MAL token (~31 d) expires silently. Only Kitsu checks expiry. |
| HTTP retry | PORTED | mwl-api/lib/client/http_connect.dart |

## Startup / platform / build
| Feature | Status | Notes |
|---|---|---|
| High refresh rate | MISSING | |
| Linux desktop tray/window | MISSING | |
| Versioning yyyy.m.n | MISSING | pubspec `1.0.0+1` |
| Android permissions | **BUG** | INTERNET only in debug manifest → release APK likely without network. Calendar/notifications/install missing. |
| Release workflow | PARTIAL | gen-l10n and build_runner steps fail (no l10n.yaml, no build_runner dev dep) |
| Deps missing | — | flutter_local_notifications, timezone, dynamic_color, flex_color_picker, translator_plus, package_info_plus, device_info_plus, add_2_calendar, open_filex, android_intent_plus, intl_utils, build_runner; `json_serializable` should be dev dep |
