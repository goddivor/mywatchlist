# Handoff — `splash-screen`: Launch splash like DailyAL: MWL logo centred on a dark background

**Kind** unit · **Priority** P1 · **Group** release · **Model** sonnet

## Needs done first
- `app-icon` (Circular adaptive launcher icon like DailyAL)
- `release-fixes` (Release: versionCode bump, launcher label, restricted update provider)

## Owns (may create or edit ONLY these)
- `android/app/src/main/res/values/**`
- `android/app/src/main/res/values-night/**`
- `android/app/src/main/res/values-v31/**`
- `android/app/src/main/res/values-night-v31/**`
- `android/app/src/main/res/drawable/**`
- `android/app/src/main/res/drawable-v21/**`
- `android/app/src/main/res/drawable-*/splash*`
- `lib/main.dart`
- `lib/l10n/units/splash-screen/**`
- `test/units/splash-screen/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner (screenshot of DailyAL starting): when the app launches, show what DailyAL shows — the app logo centred on a dark navy background — but with MyWatchList's own logo (the round launcher icon from app-icon / assets/images/mywatchlist-logo.png).
- Android 12+ system splash (values-v31 / values-night-v31: windowSplashScreenBackground dark, windowSplashScreenAnimatedIcon = the MWL adaptive icon foreground, icon background if needed) and the pre-12 launch_background.xml with the same dark colour and centred logo; NormalTheme background matches so there is no white flash between the splash and Flutter's first frame. Same look in light and dark system modes, like DailyAL.
- No new dependency unless needed (flutter_native_splash only if hand-written resources cannot do it; justify).

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `android/app/src/main/res (system splash = launcher icon on a dark window background)`

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
- Test that the v31 styles reference the splash background and icon; checker: cold start on the emulator shows the MWL logo on dark, no white flash.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
