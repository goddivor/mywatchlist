# Handoff — `tenrai-client`: Tenrai API client (all endpoints) and automatic Jikan → Tenrai failover

**Kind** unit · **Priority** P0 · **Group** foundation · **Model** opus

## Needs done first
- `detail-polish` (Detail page polish: News never loads, faster fallbacks, status colours, tabs, numbers)
- `search-sources` (Search: every filter returns data without Jikan (MAL search page fallback, live-verified) + studios directory with logos)

## Owns (may create or edit ONLY these)
- `lib/services/api/Jikan/**`
- `lib/services/api/Tenrai/**`
- `lib/services/api/jikan_source.dart`
- `lib/screens/search/search_service.dart`
- `lib/widgets/user/list/mal_user_list_adapter.dart`
- `mwl-api/mwl_commons/lib/src/constants/constant.dart`
- `mwl-api/lib/**`
- `test/units/tenrai-client/**`
- `tools/tenrai-live/**`
- `lib/l10n/units/tenrai-client/**`
- `test/units/tenrai-client/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner: Jikan is down (confirmed); Tenrai (https://api.tenrai.org/v1, docs https://api.tenrai.org/documentation, OpenAPI https://api.tenrai.org/documentation/openapi.json, 103 GET paths) is a free unofficial MAL API that follows the Jikan v4 schema. 'Like the big class that handles the whole Jikan API, implement Tenrai too (every endpoint), and switch to Tenrai when Jikan is unavailable.'
- Build `TenraiApi` / `TenraiClient` in lib/services/api/Tenrai/ covering EVERY endpoint of the OpenAPI spec (anime, manga, characters, people, producers, genres, magazines, random, recommendations, top, seasons, reviews, schedules, news, articles, stacks, ids, unapproved/denied/deleted…) with typed query parameters, reusing the existing Jikan models where the schema matches (same envelope `data` / `pagination`). Public tier: 120 req/min, 4 req/s, 429 + Retry-After → client-side throttle and back-off. No server key (never ship a key in the app).
- Failover: a shared source selector (e.g. `JikanSource`) used by JikanClient/JikanApi and every direct Jikan URL in the app (constants.dart jikanV4*, search_service.dart _jikanBase, mal_user_list_adapter.dart): try Jikan; when Jikan times out / 5xx / DNS-fails, mark it down (circuit breaker, re-probe after a few minutes) and send the same request to Tenrai; endpoints Tenrai lacks (/users, /clubs, /watch, /userupdates, random/users) keep Jikan + the existing MAL-page fallbacks. JikanFallbacks.race keeps working, with Tenrai as the second fast source before the MAL scrape. Also switch mwl-api's Jikan base the same way.
- Live verification: tools/tenrai-live/ script calls each Tenrai endpoint once (≤ 2 req/s) and prints path → status/count; paste the output in the PR. Unit tests offline with fixtures; a test where Jikan is dead shows Tenrai answering.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Every OpenAPI path has a client method (generated table in the PR body).
- With Jikan unreachable, detail sections, characters, people, top, seasons, search filters answer from Tenrai (checker on the owner's network).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
