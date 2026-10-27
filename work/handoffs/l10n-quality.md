# Handoff — `l10n-quality`: Translation quality: French (and Arabic) wording inherited from DailyAL

**Kind** unit · **Priority** P2 · **Group** release · **Model** sonnet

## Needs done first
- `l10n-pipeline` (Restore the localization pipeline (ARB sources, per-unit fragments, working language picker))

## Owns (may create or edit ONLY these)
- `lib/l10n/intl_fr_FR.arb`
- `lib/l10n/intl_ar_EG.arb`
- `lib/l10n/units/l10n-pipeline/**`
- `test/units/l10n-quality/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- The base ARB files are DailyAL's machine-quality translations. Review intl_fr_FR.arb entirely: fix mistranslations (e.g. `About` = « Sur » → « À propos »), untranslated entries (Spanish, German, Indonesian at :595-598), capitalisation (« turc » next to « Portugais », :856), French typography (non-breaking space before : ; ! ?, « » quotes, no em dash). The French must be flawless: follow the redaction-francais rules if available to you.
- Add the Arabic translations missing for the l10n-pipeline unit's own strings (language picker: 'Use system language', its description, 'Available languages').
- Never rename or remove a key; only values change. Run tools/heavy.sh tools/l10n/build.sh.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Checker: switch to French, no English left on the language picker; About tile reads « À propos ».
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
