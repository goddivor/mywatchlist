# Handoff — `mal-notifications`: MAL notifications in the app: notification hub, mark as read, background polling with Android notifications

**Kind** unit · **Priority** P0 · **Group** user · **Model** opus

## Needs done first
- `mal-session` (Optional MAL website session (WebView login, native cookies, CSRF client) + profile comments)

## Owns (may create or edit ONLY these)
- `lib/services/api/MAL/web/mal_notifications_api.dart`
- `lib/screens/mal_web/notifications_screen.dart`
- `lib/widgets/mal_web/notification_tiles.dart`
- `lib/services/notifications/**`
- `lib/l10n/units/mal-notifications/**`
- `test/units/mal-notifications/**`
- `test/units/mal-notifications/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Reports docs/malclient-report-2026-10-28.md and docs/malclient-fork-report-2026-10-28.md: MAL's notification hub lives on https://myanimelist.net/notification (data = JSON in a window.MAL.notification script) and mark-read is /notification/api/check-items-as-read.json. Read ALL notification types MAL sends (friend requests, profile comments, forum quotes/mentions, friends' list updates such as a friend dropping/completing an anime, related anime added, airing on list, club, blog…), show them in an in-app Notifications screen (reachable from the home header bell / sidebar), unread badge, mark as read (single and all), open the target (profile, anime, forum topic).
- Background: poll the hub periodically with the existing notification service/workmanager setup and raise Android system notifications for new items (grouped, tap opens the target, respects the user's notification settings, battery-friendly interval, no duplicates). Without a website session: the screen shows a one-tap Connect. Owner wants to see e.g. 'a friend dropped an anime' — if MAL shows friends' list updates outside /notification (profile 'friend updates' block or rss.php?type=rw), include them in the same screen as a Friends activity tab.
- Owner rules: replicate MALClient/DailyAL UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Uses the MAL website session from mal-session (lib/services/api/MAL/web/mal_web_client.dart: cookies + csrf_token, desktop UA). Verify every endpoint/form against the live site with read-only GETs (MAL may have changed since MALClient); offline tests on saved pages. You cannot log in (reCAPTCHA, never handle the owner's password): implement and test offline, then tell the orchestrator exactly what the owner must do on the emulator for a live test.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

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
- Offline tests on saved pages; live test steps handed to the owner.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
