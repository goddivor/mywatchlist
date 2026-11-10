# Handoff — `api-prefs`: API layer: NSFW, timezone, Jikan rate limits, MAL maintenance

**Kind** unit · **Priority** P1 · **Group** settings · **Model** sonnet

## Needs done first
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)
- `mal-auth-calls` (Route every MAL request through the token-refresh path)

## Owns (may create or edit ONLY these)
- `lib/services/api/MAL/mal_api.dart`
- `lib/services/api/MAL/mal_user.dart`
- `lib/services/api/Jikan/**`
- `lib/services/api/MAL/mal_anime.dart`
- `lib/l10n/units/api-prefs/**`
- `test/units/api-prefs/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Send `nsfw=` from the pref; use the timezone pref (mal_api.dart:827, :884); handle Jikan 429 with backoff + caching; expose a `isUnderMaintenance()` helper for home-wiring.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/api/malapi.dart`
- `commit 1d1f930 (rate limit)`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Rapid navigation on the emulator no longer produces Jikan 429 errors.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
