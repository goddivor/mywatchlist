# Handoff — `gate-fix`: Make the merge gate meaningful

**Kind** foundation · **Priority** P0 · **Group** foundation · **Model** opus

## Needs done first
- nothing

## Owns (may create or edit ONLY these)
- `test/widget_test.dart`
- `test/smoke/**`
- `test/helpers/**`
- `android/app/src/main/AndroidManifest.xml`
- `lib/l10n/units/gate-fix/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Set the test layout: `test/smoke/` (yours), `test/helpers/` (shared fakes, yours), `test/units/<unit-id>/` (one folder per later unit). Replace the default Flutter counter test `test/widget_test.dart` (it fails on `dev`) with real, fast smoke tests: pure-Dart tests of enums/parsers/helpers that need no network, and at least one widget test that pumps a small MWL widget. No test may hit the network.
- Add `<uses-permission android:name="android.permission.INTERNET"/>` to the MAIN manifest (today it is only in the debug manifest, so a release APK has no network).

## Known bugs to fix in scope
- test/widget_test.dart pumps a counter app that does not exist → `flutter test` red on dev.
- INTERNET permission missing from android/app/src/main/AndroidManifest.xml.

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- `tools/heavy.sh tools/verify.sh` exits 0 on the branch.
- Tests run in under 30 s alone.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
