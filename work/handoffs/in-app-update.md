# Handoff — `in-app-update`: In-app update: check GitHub releases, download and install APK

**Kind** unit · **Priority** P2 · **Group** release · **Model** sonnet

## Needs done first
- `settings-theme-about-backup` (Theme additions, About, backup & restore, clear storage)
- `versioning-ci` (yyyy.m.n versioning and a release workflow that passes)

## Owns (may create or edit ONLY these)
- `lib/services/updater/**`
- `lib/screens/settings/about_settings.dart`
- `lib/l10n/units/in-app-update/**`
- `test/units/in-app-update/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Check latest release of goddivor/mywatchlist, download the right APK, install through FileProvider content URI; button in About.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/settings/about.dart`
- `lib/util/download_manager.dart`
- `commits bd376af, 1871053`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Update check reports correctly on the emulator (no release newer → 'up to date').
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
