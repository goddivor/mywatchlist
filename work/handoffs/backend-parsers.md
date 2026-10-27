# Handoff — `backend-parsers`: mwl-api: port DAL's missing routes and HTML parsers

**Kind** shared · **Priority** P1 · **Group** foundation · **Model** opus

## Needs done first
- `gate-fix` (Make the merge gate meaningful)

## Owns (may create or edit ONLY these)
- `mwl-api/**`
- `mwl-rust-api/**`
- `lib/services/api/mwl_api.dart`
- `lib/l10n/units/backend-parsers/**`
- `test/units/backend-parsers/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Port into mwl-api / mwl_commons the parsers DAL has and MWL lacks: parseCharacterAllPage, parseCharacterPage, parseCharacterPeopleHome, parseMagazines, parseClubPage/_getClubDetails, parseClubPageViewAll, parseLiveChartSchedule, parseUserAboutPage, allSearchResultFromHtml, forumHtmlFromHtml, animeReviewHtmlfromHtml.
- Add the routes: `content/characters`, `character/*id/pics`, `people/*id/pics`, `characters` and `people` (top lists), `magazines`, `studios`, `clubs/type`; give `reviews` and `users/about` real parsers instead of raw text.
- Expose each new route in the app client `lib/services/api/mwl_api.dart` (typed methods + models). Keep the MWL-only routes (`users/search`, `stacks/*`, `content/featured`).
- This is a shared shape: later units (explore, profile, reviews, characters, calendar) build on these client methods. Document each method's return type in the PR body.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `dal-api/`
- `dal-api/dal_commons/ (or wherever dal_commons lives)`
- `dal-rust-api/`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- `dart analyze` clean in mwl-api.
- Parser tests with saved HTML fixtures under mwl-api/test/ (no live network).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
