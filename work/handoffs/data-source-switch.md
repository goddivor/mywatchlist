# Handoff — `data-source-switch`: One data source at a time: probe Jikan at launch, mute it (1 month, configurable) and use Tenrai only

**Kind** unit · **Priority** P0 · **Group** foundation · **Model** opus

## Needs done first
- `tracker-contracts` (Contracts for tracker isolation: tracker-tagged notification payloads, per-tracker preference reads, global notification gate)

## Owns (may create or edit ONLY these)
- `lib/services/api/jikan_source.dart`
- `lib/services/api/Jikan/jikan_client.dart`
- `lib/services/api/Jikan/jikan_fallbacks.dart`
- `lib/services/api/mwl_api.dart`
- `lib/services/api/Tenrai/**`
- `lib/screens/settings/data_source_settings.dart`
- `lib/screens/settings/settings_page.dart`
- `lib/main.dart`
- `lib/widgets/MAL/review/reviews_feed.dart`
- `lib/l10n/units/data-source-switch/**`
- `test/units/data-source-switch/**`
- `test/units/tenrai-client/**`
- `test/units/data-source-switch/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner decision 2026-10-30: Jikan and Tenrai serve the same data, so the app must NEVER use both at the same time (today JikanSource hedges: after 2.5 s the same request also goes to Tenrai, and a 5-minute circuit breaker re-probes Jikan). Replace that with ONE active source chosen at launch.
- At app start (non-blocking, before the first Jikan-shaped request is sent; requests wait for the probe, bounded ~5 s): if Jikan is muted (mute-until date stored in prefs) use Tenrai without probing Jikan. Otherwise probe Jikan with one light request (short timeout, e.g. 4 s): answers → Jikan is the source for the session; fails (timeout, network, 5xx) → Tenrai is the source and Jikan is muted for the configured duration (default 1 month).
- During the session, every Jikan-shaped request goes only to the active source (JikanClient keeps rewriting api.jikan.moe URLs). If the active source fails at the network level during the session, switch the active source to the other one sequentially (never both in flight for the same request), and if Jikan was the one failing, mute it. Endpoints Tenrai lacks (/users, /clubs, /watch, /userupdates, /random/users, forum topics) never call Jikan while it is muted: their callers go straight to their existing MyAnimeList-page / mwl-api fallbacks.
- Settings (in the settings hub, an existing page that fits such as user prefs or a small 'Data sources' page reached from it): Jikan mute duration (1 week / 2 weeks / 1 month (default) / 3 months), the current source with the date until which Jikan is muted, and a 'Test again now' action that re-probes and updates. No explanatory captions (owner rule).
- Also fix #361 in the same layer: a fallback that has no answer (mwl-api unreachable → null) must fail instead of returning an empty list, so JikanFallbacks.race never lets an empty fallback win (reviews, user updates, characters and the other JikanFallbacks routes). Reference #361 in the PR (Closes #361).
- Fakes only in tests (fake clients for Jikan/Tenrai, fake clock).

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
- Tests: launch probe chooses Jikan or Tenrai; muted Jikan is never called until the date; no request ever reaches both servers; mid-session switch; settings duration and Test again; an unreachable mwl-api fallback no longer wins the race with an empty list (#361).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
