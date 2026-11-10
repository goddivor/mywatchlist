# Handoff — `notifications`: Airing notifications

**Kind** unit · **Priority** P1 · **Group** settings · **Model** sonnet

## Needs done first
- `perf-foundation` (Fluidity foundation: 120 Hz, image decoding, shimmers, root rebuilds)
- `app-shell` (App shell seams: settings hub, sidebar, home shell, startup)
- `user-list-mal` (MAL user anime/manga list (status tabs, sort/filter, view modes, status cache))

## Owns (may create or edit ONLY these)
- `lib/main.dart`
- `lib/services/notifications/**`
- `lib/screens/settings/notifications_settings.dart`
- `android/app/src/main/res/drawable/ic_stat_notification.xml`
- `android/app/src/main/res/drawable-*/ic_stat_notification.png`
- `lib/l10n/units/notifications/**`
- `test/units/notifications/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Use the calendar unit's `AiringSchedule.instance` (`ensureLoaded()`, `nextEpisode(malId)` → episode number + UTC time) as the source of airing times; fall back to the weekly broadcast slot only when it returns null. Schedule airing notifications for watching / plan-to-watch lists (flutter_local_notifications + timezone), large image pref, permission request, test notification, clear and reschedule all, reschedule after boot, open the detail screen from a notification (cold and warm start) through the app-shell hook: read the payload of the notification that launched the app in main.dart and pass it to `OpenScreen(notificationPayload:)`; payload format `anime:<id>`, `manga:<id>`, `calendar`, `bookmarks` (documented in lib/utils/app_routes.dart). Fill the notification_service stub. Also call `ListStatusCache.instance.ensureLoaded()` at startup in main.dart so status badges show from the first frame (user-list-mal finding).

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/notifservice.dart`
- `lib/pages/settings/notifsettings.dart`
- `commits 820a295, 92cc38d`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body. **Strings:** every screen you own must be fully translatable — move its existing hardcoded literals (e.g. settings_page.dart:55,119, mal_home_page.dart:45-47, mal_home_page_preferences.dart:65) to `S` through your l10n fragment; the checker switches the app to French and flags any English left on your screens. **Colours:** no hardcoded `Colors.*` or `Color(0x…)` in your screens: use `Theme.of(context).colorScheme` and the semantic tokens of lib/widgets/common/app_colors.dart (theme-colors unit, see docs/THEME.md once merged); move the existing hardcoded colours of your files to them. Every text must stay readable on its background (buttons, chips, badges, text on images) in light, dark and black modes.

**Fluidity rules (owner's rule: MWL must feel as smooth as DailyAL).** See `docs/PERFORMANCE.md` once perf-foundation has merged, and `work/inventory/performance.md`.
- Network images only through `AppImage` (decode at displayed size); no `Image.network`.
- Long or unbounded lists: `ListView.builder`/slivers, never a `Column` of many children in a `SingleChildScrollView`; no `shrinkWrap: true` list inside another scroll view; no scroll view per list item.
- No `Opacity`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` or blurred `BoxShadow` on repeated items or on whole pages during animations; use alpha colors / FadeTransition.
- No `setState` in scroll listeners; listeners added once and removed in dispose; dispose every controller you create.
- BlocBuilder/Consumer as low in the tree as possible, with `buildWhen`/`BlocSelector`/`context.select`; `const` constructors wherever possible.
- Heavy JSON/HTML parsing off the UI isolate (`Isolate.run`/`compute`); no sync storage reads in `build`; no `print` in hot paths.
- Look at how DAL makes the same screen fluid and do at least as well; the checker compares janky-frame % on a profile build.

## Definition of Done
- Test notification shows on the emulator and opens the right anime.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
