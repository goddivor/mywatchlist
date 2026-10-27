# Handoff — `l10n-quality`: Final translation pass: French (and Arabic) wording of the base and of every unit

**Kind** unit · **Priority** P2 · **Group** release · **Model** sonnet

## Needs done first
- `gate-fix` (Make the merge gate meaningful)
- `auth-refresh` (Token refresh and retry for all trackers)
- `backend-parsers` (mwl-api: port DAL's missing routes and HTML parsers)
- `mal-auth-calls` (Route every MAL request through the token-refresh path)
- `l10n-pipeline` (Restore the localization pipeline (ARB sources, per-unit fragments, working language picker))
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)
- `app-shell` (App shell seams: settings hub, sidebar, home shell, startup)
- `detail-split` (Split the 1852-line detail screen into sections with seams)
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)
- `perf-foundation` (Fluidity foundation: 120 Hz, image decoding, shimmers, root rebuilds)
- `accounts-ux` (Redesign the account picker, account switcher and account management)
- `edit-sheet` (Edit-entry sheet: fix pre-fill, dates, episodes, private notes)
- `user-list-mal` (MAL user anime/manga list (status tabs, sort/filter, view modes, status cache))
- `user-profile-mal` (MAL user profile, stats charts and user pop-up)
- `sync-dialog` (Cross-tracker sync: two-way dialog, cancel, lazy load, decimal scores)
- `detail-header` (Detail header and actions: share, browser, bookmark, More Info, hide score, custom tabs, countdown)
- `detail-related-graph` (Related: view-all grid with statuses and the relation graph (share as PNG))
- `detail-synopsis-media` (Synopsis translation, streaming links, videos fallback)
- `detail-social` (Reviews AI summary + share, interest stacks and user updates linking to profiles)
- `detail-more-info` (More-info links: studios, magazines, authors, genres, season, media type)
- `bookmarks` (Bookmarks: store, screen, add/remove)
- `calendar` (Anime calendar, weekly schedule, .ics export, add to device calendar)
- `explore-seasonal` (Explore page and seasonal screen)
- `search-upgrade` (Search: user results, search by id, autocomplete, searchable filters)
- `home-wiring` (Home: working chips, bookmarks/calendar buttons, maintenance dialog, user-list and forum sections)
- `cards-upgrade` (Anime cards: quick edit, status badges, score reveal, real airing progress)
- `settings-prefs-pages` (Settings pages: user prefs, anime/manga, list prefs)
- `settings-theme-about-backup` (Theme additions, About, backup & restore, clear storage)
- `notifications` (Airing notifications)
- `dub-info` (Dub info (MyDubList): icons, languages, settings)
- `api-prefs` (API layer: NSFW, timezone, Jikan rate limits, MAL maintenance)
- `forum-clubs` (Forum posting, profile links, club members in-app)
- `featured-characters` (Featured tags search, character screen sort/dedupe/bookmark/share)
- `anilist-pages` (AniList: home, explore, user list, profile (replace placeholders))
- `kitsu-pages` (Kitsu: home, explore, user list, profile (replace placeholders))
- `simkl-pages` (Simkl: home, explore, user list, profile (replace placeholders))
- `versioning-ci` (yyyy.m.n versioning and a release workflow that passes)
- `in-app-update` (In-app update: check GitHub releases, download and install APK)
- `deep-links` (Open myanimelist.net links in the app)

## Owns (may create or edit ONLY these)
- `lib/l10n/units/*/intl_fr_FR.arb`
- `lib/l10n/intl_fr_FR.arb`
- `lib/l10n/intl_ar_EG.arb`
- `lib/l10n/units/l10n-pipeline/**`
- `test/units/l10n-quality/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- The base ARB files are DailyAL's machine-quality translations. Review intl_fr_FR.arb entirely: fix mistranslations (e.g. `About` = « Sur » → « À propos »), untranslated entries (Spanish, German, Indonesian at :595-598), capitalisation (« turc » next to « Portugais », :856), French typography (non-breaking space before : ; ! ?, « » quotes, no em dash). The French must be flawless: follow the redaction-francais rules if available to you.
- Base French (detail-header finding): `Close` = « proche » → « Fermer », `Pictures` = « Des photos » → « Images », `Aired` and `Users` untranslated. Base French: `Streaming_Platforms` has a stray trailing comma (« Plateformes de streaming, »). Base French fixes seen on the settings hub (batch-2 check): `About` = « Sur » (intl_fr_FR.arb:154) → « À propos »; `Dub_Settings` = « Signaler les doublages inexacts » (:685) → « Doublage ». Add the missing French fragments of merged units that shipped English only (e.g. lib/l10n/units/perf-foundation/: Image_Saved, Image_Save_Failed, Image_Share_Failed, Image_Share_Text) — scan every lib/l10n/units/*/ for keys without intl_fr_FR.
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
