# Handoff — `settings-prefs-pages`: Settings pages: user prefs, anime/manga, list prefs

**Kind** screen · **Priority** P1 · **Group** settings · **Model** sonnet

## Needs done first
- `app-shell` (App shell seams: settings hub, sidebar, home shell, startup)

## Owns (may create or edit ONLY these)
- `lib/screens/settings/user_prefs_settings.dart`
- `lib/screens/settings/anime_manga_settings.dart`
- `lib/screens/settings/list_prefs_settings.dart`
- `lib/screens/settings/prefs/**`
- `lib/l10n/units/settings-prefs-pages/**`
- `test/units/settings-prefs-pages/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Fill the three stubs with every preference of the contract (UI only: values come from PreferencesBloc). Redesign per UI directive.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/settings/userprefsetting.dart`
- `lib/pages/settings/anime_manga_settings.dart`
- `lib/pages/settings/list_pref_settings.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Each toggle persists across restart.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
