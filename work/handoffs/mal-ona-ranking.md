# Handoff — `mal-ona-ranking`: Top ONA through Jikan/Tenrai (MAL rejects ranking_type=ona); drop the anime_id list sort

**Kind** unit · **Priority** P1 · **Group** trackers · **Model** opus

## Needs done first
- `mal-api-small` (mal-api-small)

## Owns (may create or edit ONLY these)
- `lib/services/api/MAL/mal_api.dart`
- `lib/enums.dart`
- `lib/services/api/Jikan/jikan_api.dart`
- `test/units/mal-ona-ranking/**`
- `lib/l10n/units/mal-ona-ranking/**`
- `test/units/mal-ona-ranking/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- A7 check run by the orchestrator on 2026-10-29 with MWL's client id: GET /v2/anime/ranking?ranking_type=ona answers 400 'invalid ranking_type', and /v2/users/{u}/animelist?sort=anime_id answers 400 'invalid sort order' (manga ranking_type=lightnovels answers 200, keep it). Make every RankingType.ONA ranking (home row topAnimeOna, Explore rankings, the detail 'ONA' link, search by ranking) load from Jikan/Tenrai top anime with type=ona through the JikanSource selector (Jikan with Tenrai fallback), mapped to the same SearchResult/Anime shape with paging (offset → page). Remove AnimeListSort.animeId and its mapping (unused, rejected by MAL).
- Offline tests with saved Jikan responses; no write anywhere.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Tests: the ONA ranking request goes to the Jikan source with type=ona and maps to SearchResult with next-page paging; no MAL ranking request carries ranking_type=ona.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
