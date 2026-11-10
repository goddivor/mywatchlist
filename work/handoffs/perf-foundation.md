# Handoff — `perf-foundation`: Fluidity foundation: 120 Hz, image decoding, shimmers, root rebuilds

**Kind** foundation · **Priority** P0 · **Group** foundation · **Model** opus

## Needs done first
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)

## Owns (may create or edit ONLY these)
- `lib/main.dart`
- `lib/widgets/common/app_image.dart`
- `lib/widgets/common/avatar_widget.dart`
- `lib/widgets/common/image_preview.dart`
- `lib/widgets/loading/**`
- `lib/utils/page_transitions.dart`
- `android/app/src/main/AndroidManifest.xml`
- `docs/PERFORMANCE.md`
- `lib/l10n/units/perf-foundation/**`
- `test/units/perf-foundation/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- The owner says MWL lags on scroll and page changes while DAL is fluid. Read work/inventory/performance.md first; you own the global fixes (#1, #3 helper, #5 main.dart, #8, #10, #11, #13, #14 preview, #15).
- High refresh rate: `FlutterDisplayMode.setHighRefreshRate()` before runApp (dependency added by deps-prefs-contract).
- Shared image widget `lib/widgets/common/app_image.dart` wrapping CachedNetworkImage: decode at displayed size (memCacheWidth/Height = logical size × devicePixelRatio, maxWidthDiskCache), short or zero fade, cheap placeholder. Use it in avatar_widget.dart (zero fade, no blur BoxShadow on repeated avatars) and image_preview.dart (also replace Image.network; replace the BackdropFilter blur over PhotoView by a static scrim).
- Shimmers: one shared animation ticker inside the shimmer widget (lib/widgets/loading/) so 38 call sites stop running 38 tickers — callers unchanged.
- main.dart: scope the ThemeBloc builder around MaterialApp (:192) with buildWhen so only theme changes rebuild it.
- Impeller vs Skia: do NOT flip blindly. Leave the manifest flag configurable and write in docs/PERFORMANCE.md the A/B procedure the checker runs (profile build, gfxinfo janky %, same gesture, MWL vs DAL).
- Write docs/PERFORMANCE.md: the project's fluidity rules (the list in every UI handoff) + how to measure.

## Known bugs to fix in scope
- 60 Hz only
- full-resolution image decode
- 38 shimmer tickers
- blur re-rendered every frame in the image viewer

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/main.dart:62 (FlutterDisplayMode.setHighRefreshRate)`
- `lib/widgets/avatarwidget.dart:219 (fadeInDuration zero)`
- `lib/screens/homescreen.dart:293-297`
- `android/app/src/main/AndroidManifest.xml:59-61 (EnableImpeller=false)`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Checker measures home scroll + detail open on a --profile build: janky frames % no worse than DAL's on the same gesture.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
