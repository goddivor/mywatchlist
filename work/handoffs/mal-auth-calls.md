# Handoff — `mal-auth-calls`: Route every MAL request through the token-refresh path

**Kind** unit · **Priority** P0 · **Group** foundation · **Model** sonnet

## Needs done first
- `auth-refresh` (Token refresh and retry for all trackers)

## Owns (may create or edit ONLY these)
- `lib/services/api/MAL/mal_api.dart`
- `lib/services/api/MAL/mal_user.dart`
- `lib/services/api/MAL/mal_user_prof.dart`
- `lib/services/api/MAL/mal_forum_api.dart`
- `lib/services/api/MAL/mal_clubs_api.dart`
- `lib/services/api/MAL/user_anime_statistics.dart`
- `lib/l10n/units/mal-auth-calls/**`
- `test/units/mal-auth-calls/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- The owner's phone: after months without opening the app, MAL no longer works — the token expired and nothing refreshes it. auth-refresh added the mechanism (`MalConnect.authGet/authPut/authDelete`, `BaseUser.sendAuthenticated`, `MalSessionExpired`) but the 22 call sites in mal_api.dart / mal_user.dart (and any other authenticated MAL call in the files you own) still use raw `http.*` with a hand-built Bearer header.
- Move EVERY authenticated MAL call onto that path, so: token near expiry → refreshed first; 401 → refresh + one replay; refresh refused → the account enters `needsReLogin` (no crash, no silent empty screens). Public (client-id only) calls stay as they are.
- Where a caller would get an exception, make sure `MalSessionExpired` surfaces as a clear error state the UI can show (no infinite spinner); the visible 'sign in again' prompt itself belongs to accounts-ux.
- Do not change behaviour otherwise: same endpoints, same parameters, same models.

## Known bugs to fix in scope
- MAL token never refreshed in real calls → app stops working after ~1 month (owner's phone).

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- `grep -nE "Bearer|http\.(get|put|post|delete|patch)\(" lib/services/api/MAL/*.dart` shows no authenticated raw call left (list any public call kept, with why, in the PR body).
- Offline tests in test/units/mal-auth-calls/ with a fake client: expired token → refresh then the MAL call succeeds; refresh rejected → MalSessionExpired / needsReLogin.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
