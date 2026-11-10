# Handoff — `release-fixes`: Release: versionCode bump, launcher label, restricted update provider

**Kind** unit · **Priority** P2 · **Group** release · **Model** sonnet

## Needs done first
- `versioning-ci` (yyyy.m.n versioning and a release workflow that passes)
- `in-app-update` (In-app update: check GitHub releases, download and install APK)

## Owns (may create or edit ONLY these)
- `.github/**`
- `tools/release/**`
- `android/app/src/main/AndroidManifest.xml`
- `lib/services/updater/**`
- `lib/l10n/units/release-fixes/**`
- `test/units/release-fixes/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- tools/release/version.sh (~62-75) never commits the bump back, so every CI release is built with versionCode +2 of the committed one: make the code monotonic (derive it from the tag date / run number, or commit the bump) — explain the choice.
- Launcher label: AndroidManifest.xml:19 `android:label="mywatchlist"` → "MyWatchList".
- Issue #153: install updates through the app's restricted FileProvider (@xml/updater_paths) instead of open_filex's broad provider.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- actionlint or line-by-line review of the workflow; tests for the version script; manifest checked by a test.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
