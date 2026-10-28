# Handoff — `backup-fixes`: Backup restore never stops halfway; About closes its HTTP client

**Kind** unit · **Priority** P1 · **Group** settings · **Model** sonnet

## Needs done first
- `in-app-update` (In-app update: check GitHub releases, download and install APK)
- `settings-theme-about-backup` (About, backup & restore, clear storage)

## Owns (may create or edit ONLY these)
- `lib/cache/cachemanager.dart`
- `lib/screens/settings/backup_settings.dart`
- `lib/screens/settings/about_settings.dart`
- `lib/screens/settings/storage_settings.dart`
- `lib/l10n/units/backup-fixes/**`
- `test/units/backup-fixes/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Restore can stop halfway (cachemanager.dart:433-436 does not validate each section's version): validate the whole file first (every section's version, shape), then write all sections or none, then reload; the preview counts must equal what is restored.
- Add the theme-seasons pref key `accent_season_v1` to `BackupService.settingsKeys` so a restore keeps Auto (season).
- about_settings.dart:44 never closes its http.Client.
- Storage page sizes in the app locale ('115,4 Mo' in French, storage_settings.dart:90-100 uses toStringAsFixed).

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Tests: a file with a bad section restores nothing and reports it; preview counts = restored counts.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
