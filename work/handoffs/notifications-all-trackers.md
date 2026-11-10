# Handoff — `notifications-all-trackers`: Notifications from every connected tracker, one group of switches per tracker

**Kind** unit · **Priority** P0 · **Group** user · **Model** opus

## Needs done first
- `tracker-contracts` (Contracts for tracker isolation: tracker-tagged notification payloads, per-tracker preference reads, global notification gate)
- `prefs-per-tracker` (Tracker settings per tracker (title language, NSFW, list, cards, detail tabs…))

## Owns (may create or edit ONLY these)
- `lib/services/notifications/notification_service.dart`
- `lib/services/notifications/mal_hub.dart`
- `lib/services/notifications/anilist_*`
- `lib/services/notifications/kitsu_*`
- `lib/services/notifications/simkl_*`
- `lib/main.dart`
- `lib/screens/settings/notifications_settings.dart`
- `lib/user/preferences/notification_preferences.dart`
- `lib/services/api/Anilist/anilist_list_service.dart`
- `lib/services/api/SimKl/simkl_list_service.dart`
- `lib/l10n/units/notifications-all-trackers/**`
- `test/units/notifications-all-trackers/**`
- `test/units/notifications-all-trackers/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Unit U6 of docs/tracker-isolation-audit-2026-10-29.md (section C): global 'allow notifications' (NotificationGate) separate from airing; per-tracker airing switches; the airing planner fed by every connected tracker (dedupe by anime, NotificationPayload per tracker), AniList via airingSchedules, Simkl via its calendar file, MAL/Kitsu via LiveChart; drop candidateTracker / replan-on-switch; the WorkManager job runs a round per connected tracker (MAL hub, AniList inbox, Kitsu if its API allows it, Simkl airing) and is registered when any tracker has any switch on; Settings > Notifications shows one group per connected tracker. Do not touch mal_hub_poller.dart (mal-pm-chat-notifications owns it).
- Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts.

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
- Tests: each tracker notifies when not active; switches per tracker; the job is registered without the airing master.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
