# Handoff — `app-shell`: App shell seams: settings hub, sidebar, home shell, startup

**Kind** foundation · **Priority** P0 · **Group** foundation · **Model** opus

## Needs done first
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)

## Owns (may create or edit ONLY these)
- `lib/screens/settings/settings_page.dart`
- `lib/screens/settings/accounts_settings.dart`
- `lib/screens/settings/about_settings.dart`
- `lib/screens/settings/notifications_settings.dart`
- `lib/screens/settings/user_prefs_settings.dart`
- `lib/screens/settings/anime_manga_settings.dart`
- `lib/screens/settings/list_prefs_settings.dart`
- `lib/screens/settings/backup_settings.dart`
- `lib/screens/settings/storage_settings.dart`
- `lib/screens/settings/dub_settings.dart`
- `lib/pages/settings/**`
- `lib/pages/side_bar.dart`
- `lib/utils/sidebar_extension.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/open_screen.dart`
- `lib/screens/bookmarks_screen.dart`
- `lib/screens/calendar/calendar_screen.dart`
- `lib/utils/app_routes.dart`
- `lib/l10n/units/app-shell/**`
- `test/units/app-shell/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Rebuild the settings hub (UI directive applies) with one tile per settings page. Create each settings page file listed in Owns as a STUB (title + 'coming soon') — later units own and fill them. Remove the empty `onTap` stubs (MAL Account :147, Connected Services :158, About :174, Help :185).
- Create stub screens `lib/screens/bookmarks_screen.dart` and `lib/screens/calendar/calendar_screen.dart`, and a tiny route helper `lib/utils/app_routes.dart` (openBookmarks, openCalendar, openUserProfile(tracker, username), openSettingsPage(...)) so feature units can link to each other without touching each other's files. openUserProfile may push a stub until the profile unit fills it.
- Make the sidebar actually reachable (today `AppSidebar` is only built by `SidebarBuilder`, which nothing calls) and wire: profile, stats, bookmarks, calendar, settings, login/logout. About must open the About page.
- Home shell: honor the startup-page preference from the contract; open screen shows a loader instead of `loadingError()` while loading (open_screen.dart:45); hook for routing from a notification payload (calls into notification_service).

## Known bugs to fix in scope
- settings_page.dart empty onTaps.
- Sidebar never shown.
- open_screen.dart:45 shows an error widget while loading.

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/settings_page.dart`
- `lib/pages/side_bar.dart`
- `lib/screens/homescreen.dart`
- `lib/screens/openscreen.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Every settings tile opens its page (stub or real).
- Sidebar opens from the home shell on the emulator.
- app_routes.dart helpers are documented with a one-line comment each.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
