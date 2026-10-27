# Handoff — `versioning-ci`: yyyy.m.n versioning and a release workflow that passes

**Kind** unit · **Priority** P2 · **Group** release · **Model** sonnet

## Needs done first
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)

## Owns (may create or edit ONLY these)
- `.github/**`
- `analysis_options.yaml`
- `tools/release/**`
- `lib/l10n/units/versioning-ci/**`
- `test/units/versioning-ci/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Version scheme yyyy.m.n+code (DAL style) — pubspec is the contract's file: put the version bump script in tools/release/ and report the one-line pubspec change as a finding; release workflow: run tools/l10n/build.sh instead of `flutter gen-l10n` (generated l10n files are no longer in git), create an empty placeholder `assets/.env` before analyze when the secrets are absent, build_runner from dev deps, APK split + universal, sha1.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `.github/workflows/`
- `update_gradle.sh`
- `pubspec.yaml version`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Workflow YAML validated with `actionlint` if available, else reviewed line by line in the PR body.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
