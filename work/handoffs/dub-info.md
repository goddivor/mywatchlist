# Handoff — `dub-info`: Dub info (MyDubList): icons, languages, settings

**Kind** unit · **Priority** P2 · **Group** settings · **Model** sonnet

## Needs done first
- `cards-upgrade` (Anime cards: quick edit, status badges, score reveal, real airing progress)
- `app-shell` (App shell seams: settings hub, sidebar, home shell, startup)

## Owns (may create or edit ONLY these)
- `lib/cache/dub_info.dart`
- `lib/screens/settings/dub_settings.dart`
- `lib/widgets/MAL/home/animegridcard.dart`
- `lib/widgets/common/dub_icon.dart`
- `lib/l10n/units/dub-info/**`
- `test/units/dub-info/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Dub status icon on cards (asset MyDubListIcons.ttf is already present), dub languages, min source count, icon style, report/support links; fill the dub settings stub.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/settings/dubsettings.dart`
- `lib/cache/dubinfomanager.dart`
- `commits 17dd437, 6f75ed3`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Dub icon visible on dubbed anime cards on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
