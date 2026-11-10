# Handoff — `auth-refresh`: Token refresh and retry for all trackers

**Kind** unit · **Priority** P0 · **Group** foundation · **Model** sonnet

## Needs done first
- `gate-fix` (Make the merge gate meaningful)

## Owns (may create or edit ONLY these)
- `lib/user/base_user.dart`
- `lib/user/user_manager.dart`
- `lib/user/user_mal_v2.dart`
- `lib/user/user_anilist_v2.dart`
- `lib/user/user_kitsu_v2.dart`
- `lib/user/user_simkl_v2.dart`
- `lib/services/auth/**`
- `lib/services/api/MAL/mal_connect.dart`
- `lib/l10n/units/auth-refresh/**`
- `test/units/auth-refresh/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Refresh tokens before expiry and on HTTP 401 for MAL, AniList and Kitsu (Simkl has no refresh token: on 401, mark the account as needing re-login).
- Make every authenticated MAL request go through the refreshing path (today `makeAuthenticatedRequest` / `refreshCurrentToken` in base_user.dart are never called and only Kitsu checks expiry).
- Retry transient network errors with backoff (DAL: RetryOptions, 8 attempts). Never retry 4xx except 401-after-refresh once.

## Known bugs to fix in scope
- MAL token (~31 days) expires silently: no 401 handling anywhere in lib/services.

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/api/auth/auth.dart`
- `lib/api/malconnect.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Unit tests (in test/units/auth-refresh/) cover: expired token refreshed before call, 401 → refresh → retry once, refresh failure → logged-out state.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
