# Handoff — `tracker-contracts`: Contracts for tracker isolation: tracker-tagged notification payloads, per-tracker preference reads, global notification gate

**Kind** unit · **Priority** P0 · **Group** user · **Model** opus

## Needs done first
- `mal-hub-followups` (MAL hub follow-ups: in-app thread on message tap, JSON posts through postJson, message poller next to the hub poller)

## Owns (may create or edit ONLY these)
- `lib/services/notifications/notification_payload.dart`
- `lib/user/preferences/tracker_scope.dart`
- `lib/services/notifications/notification_gate.dart`
- `test/units/tracker-contracts/**`
- `lib/l10n/units/tracker-contracts/**`
- `test/units/tracker-contracts/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Read docs/tracker-isolation-audit-2026-10-29.md (section F, 'Cross-unit contracts'). Define and freeze, with doc comments and tests, the three shared shapes the next units use: (1) NotificationPayload: a tracker-tagged payload format (e.g. 'tracker:kind:id[:extra]') with build and parse, legacy payloads ('anime:<id>', 'calendar', MAL hub payloads) read as MAL; (2) TrackerScope: the list of tracker-scoped preference keys and PreferencesStore.readFor(AccountType tracker) / writeFor signatures, implemented over SharedPreferences with a key suffix ':<tracker>' and a no-op migration hook (the real split is prefs-per-tracker's job); (3) NotificationGate: a global 'allow notifications' getter/setter (permission + kill switch) separate from airing reminders, plus per-tracker channel ids. Do not wire them anywhere yet beyond what tests need.
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
- Tests: payload round trip and legacy parsing; readFor/writeFor isolate trackers; the gate's default and persistence.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
