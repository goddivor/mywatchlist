# Handoff — `mal-hub-wiring`: MAL notifications: bell, sidebar entry, background polling when the app is closed, settings switches

**Kind** unit · **Priority** P0 · **Group** user · **Model** opus

## Needs done first
- `mal-notifications` (MAL notifications in the app: notification hub, mark as read, background polling with Android notifications)
- `ux-home` (Home like DailyAL: status badge on cards, plain header icons, Fall row order)
- `mal-messages` (MAL private messages: inbox, sent, thread, compose and reply)

## Owns (may create or edit ONLY these)
- `lib/screens/user_profile/user_profile_view.dart`
- `lib/widgets/MAL/home/homeappbar.dart`
- `lib/pages/side_bar.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `lib/main.dart`
- `docs/STACK.md`
- `lib/screens/settings/notifications_settings.dart`
- `lib/services/api/MAL/web/mal_web_client.dart`
- `android/app/src/main/AndroidManifest.xml`
- `lib/l10n/units/mal-hub-wiring/**`
- `test/units/mal-hub-wiring/**`
- `test/units/mal-hub-wiring/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- From mal-messages PR #264: add `malMessagesSidebarItem(context)` to the sidebar; a 'Message' action (S.current.Pm_Message) on other users' MAL profiles calling `openComposeMalMessage(context, to: username)` (user_profile_view.dart); a received private message raises a phone notification through MalHubPoller and refreshes the unread count (owner: yes).
- From mal-notifications PR #262 findings: add `const MalNotificationsBell()` to the home header action row (homeappbar.dart `_buildActionButtons`) and `malNotificationsSidebarItem(context)` to the sidebar (side_bar.dart); background polling while the app is closed with a pinned background worker (workmanager or android_alarm_manager_plus — pick, pin in docs/STACK.md, register in main.dart, manifest bits) calling `MalHubPoller.instance.poll(force: true)` every 30 min (battery-friendly constraints); the MAL hub switches in Settings > Notifications; a `postJson` on MalWebClient and move the notifications API's JSON POSTs onto it. Also add the mal-messages entry points to the sidebar if mal-messages (merged before you) exposes them.
- Owner rules: no explanatory captions; theme tokens; English + French. Never write to the owner's MAL account in tests.

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
- Tests: bell shows unread count; worker registered; settings switches honoured.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
