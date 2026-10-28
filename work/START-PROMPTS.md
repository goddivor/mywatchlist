# Start prompts

One block per unit, pasted unchanged into the builder brief after the filled `tools/briefs/builder.md`.

## gate-fix

```text
Unit gate-fix — Make the merge gate meaningful.
Read work/handoffs/gate-fix.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## auth-refresh

```text
Unit auth-refresh — Token refresh and retry for all trackers.
Read work/handoffs/auth-refresh.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## backend-parsers

```text
Unit backend-parsers — mwl-api: port DAL's missing routes and HTML parsers.
Read work/handoffs/backend-parsers.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## mal-auth-calls

```text
Unit mal-auth-calls — Route every MAL request through the token-refresh path.
Read work/handoffs/mal-auth-calls.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## l10n-pipeline

```text
Unit l10n-pipeline — Restore the localization pipeline (ARB sources, per-unit fragments, working language picker).
Read work/handoffs/l10n-pipeline.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## deps-prefs-contract

```text
Unit deps-prefs-contract — Dependencies, Android permissions and the preferences contract.
Read work/handoffs/deps-prefs-contract.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## app-shell

```text
Unit app-shell — App shell seams: settings hub, sidebar, home shell, startup.
Read work/handoffs/app-shell.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## detail-split

```text
Unit detail-split — Split the 1852-line detail screen into sections with seams.
Read work/handoffs/detail-split.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## shared-kit

```text
Unit shared-kit — Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher.
Read work/handoffs/shared-kit.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## perf-foundation

```text
Unit perf-foundation — Fluidity foundation: 120 Hz, image decoding, shimmers, root rebuilds.
Read work/handoffs/perf-foundation.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## accounts-ux

```text
Unit accounts-ux — Redesign the account picker, account switcher and account management.
Read work/handoffs/accounts-ux.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## edit-sheet

```text
Unit edit-sheet — Edit-entry sheet: fix pre-fill, dates, episodes, private notes.
Read work/handoffs/edit-sheet.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## user-list-mal

```text
Unit user-list-mal — MAL user anime/manga list (status tabs, sort/filter, view modes, status cache).
Read work/handoffs/user-list-mal.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## list-cards-dal

```text
Unit list-cards-dal — My List grid display: the same visual as DailyAL's grid (the rest of MWL's My List stays).
Read work/handoffs/list-cards-dal.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## user-profile-mal

```text
Unit user-profile-mal — MAL user profile, stats charts and user pop-up.
Read work/handoffs/user-profile-mal.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## profile-polish

```text
Unit profile-polish — Profile screen: readable themed header, chart colours from status tokens, lighter surfaces, no Jikan wait.
Read work/handoffs/profile-polish.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## profile-tabs

```text
Unit profile-tabs — Profile tabs (Friends, Clubs, History) never hang: timeout + MAL page fallback.
Read work/handoffs/profile-tabs.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## sync-dialog

```text
Unit sync-dialog — Cross-tracker sync: two-way dialog, cancel, lazy load, decimal scores.
Read work/handoffs/sync-dialog.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## detail-header

```text
Unit detail-header — Detail header and actions: share, browser, bookmark, More Info, hide score, custom tabs, countdown.
Read work/handoffs/detail-header.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## detail-related-graph

```text
Unit detail-related-graph — Related: view-all grid with statuses and the relation graph (share as PNG).
Read work/handoffs/detail-related-graph.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## detail-synopsis-media

```text
Unit detail-synopsis-media — Synopsis translation, streaming links, videos fallback.
Read work/handoffs/detail-synopsis-media.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## detail-social

```text
Unit detail-social — Reviews AI summary + share, interest stacks and user updates linking to profiles.
Read work/handoffs/detail-social.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## detail-resilience

```text
Unit detail-resilience — Detail sections: no endless skeletons, MAL fallbacks when Jikan fails, round avatars without box shadows.
Read work/handoffs/detail-resilience.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## detail-more-info

```text
Unit detail-more-info — More-info links: studios, magazines, authors, genres, season, media type.
Read work/handoffs/detail-more-info.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## bookmarks

```text
Unit bookmarks — Bookmarks: store, screen, add/remove.
Read work/handoffs/bookmarks.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## calendar

```text
Unit calendar — Anime calendar, weekly schedule, .ics export, add to device calendar.
Read work/handoffs/calendar.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## explore-seasonal

```text
Unit explore-seasonal — Explore page and seasonal screen.
Read work/handoffs/explore-seasonal.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## search-upgrade

```text
Unit search-upgrade — Search: user results, search by id, autocomplete, searchable filters.
Read work/handoffs/search-upgrade.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## home-wiring

```text
Unit home-wiring — Home: working chips, bookmarks/calendar buttons, maintenance dialog, user-list and forum sections.
Read work/handoffs/home-wiring.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## cards-upgrade

```text
Unit cards-upgrade — Anime cards: quick edit, status badges, score reveal, real airing progress.
Read work/handoffs/cards-upgrade.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## settings-prefs-pages

```text
Unit settings-prefs-pages — Settings pages: user prefs, anime/manga, list prefs.
Read work/handoffs/settings-prefs-pages.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## theme-colors

```text
Unit theme-colors — Theme colours: status bar, coherent accents per theme, colour tokens, contrast.
Read work/handoffs/theme-colors.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## settings-theme-about-backup

```text
Unit settings-theme-about-backup — About, backup & restore, clear storage.
Read work/handoffs/settings-theme-about-backup.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## notifications

```text
Unit notifications — Airing notifications.
Read work/handoffs/notifications.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## dub-info

```text
Unit dub-info — Dub info (MyDubList): icons, languages, settings.
Read work/handoffs/dub-info.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## api-prefs

```text
Unit api-prefs — API layer: NSFW, timezone, Jikan rate limits, MAL maintenance.
Read work/handoffs/api-prefs.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## forum-clubs

```text
Unit forum-clubs — Forum posting, profile links, club members in-app.
Read work/handoffs/forum-clubs.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## featured-characters

```text
Unit featured-characters — Featured tags search, character screen sort/dedupe/bookmark/share.
Read work/handoffs/featured-characters.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## anilist-pages

```text
Unit anilist-pages — AniList: home, explore, user list, profile (replace placeholders).
Read work/handoffs/anilist-pages.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## kitsu-pages

```text
Unit kitsu-pages — Kitsu: home, explore, user list, profile (replace placeholders).
Read work/handoffs/kitsu-pages.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## simkl-pages

```text
Unit simkl-pages — Simkl: home, explore, user list, profile (replace placeholders).
Read work/handoffs/simkl-pages.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## versioning-ci

```text
Unit versioning-ci — yyyy.m.n versioning and a release workflow that passes.
Read work/handoffs/versioning-ci.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## l10n-quality

```text
Unit l10n-quality — Final translation pass: French (and Arabic) wording of the base and of every unit.
Read work/handoffs/l10n-quality.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## color-sweep

```text
Unit color-sweep — Colour sweep: hardcoded colours of already-merged screens onto the theme tokens.
Read work/handoffs/color-sweep.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## app-icon

```text
Unit app-icon — Circular adaptive launcher icon like DailyAL.
Read work/handoffs/app-icon.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## search-sources

```text
Unit search-sources — Search: every filter returns data without Jikan (MAL search page fallback, live-verified) + studios directory with logos.
Read work/handoffs/search-sources.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## tracker-followups

```text
Unit tracker-followups — Tracker follow-ups: removed rows disappear, Simkl list categories, notifications for every tracker.
Read work/handoffs/tracker-followups.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## stack-polish

```text
Unit stack-polish — Interest stack page: squeezed covers, localized date, readable tabs (DailyAL layout).
Read work/handoffs/stack-polish.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## splash-screen

```text
Unit splash-screen — Launch splash like DailyAL: MWL logo centred on a dark background.
Read work/handoffs/splash-screen.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## tenrai-client

```text
Unit tenrai-client — Tenrai API client (all endpoints) and automatic Jikan → Tenrai failover.
Read work/handoffs/tenrai-client.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## profile-lists

```text
Unit profile-lists — Other users' anime/manga lists, weekly tab and sidebar shortcuts like DailyAL.
Read work/handoffs/profile-lists.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## explore-weekly

```text
Unit explore-weekly — Weekly anime per season (MAL broadcast weekday) and Random without Jikan.
Read work/handoffs/explore-weekly.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## jikan-leftovers

```text
Unit jikan-leftovers — Videos, user updates and user probe without Jikan.
Read work/handoffs/jikan-leftovers.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## bookmarks-everywhere

```text
Unit bookmarks-everywhere — Bookmarks on forum topics, clubs, articles and stacks.
Read work/handoffs/bookmarks-everywhere.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## home-rows

```text
Unit home-rows — Home rows honour the 30-item slider; OVA/ONA and manhwa/manhua/novel rows.
Read work/handoffs/home-rows.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## launch-update-check

```text
Unit launch-update-check — Check for an app update at launch like DailyAL.
Read work/handoffs/launch-update-check.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## small-fixes

```text
Unit small-fixes — Dead settings switches, dub icon on cards and tiles, report recommendation, backup keys.
Read work/handoffs/small-fixes.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-session

```text
Unit mal-session — Optional MAL website session (WebView login, native cookies, CSRF client) + profile comments.
Read work/handoffs/mal-session.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## kitsu-graphql

```text
Unit kitsu-graphql — kitsu-graphql.
Read work/handoffs/kitsu-graphql.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## kitsu-media-page

```text
Unit kitsu-media-page — kitsu-media-page.
Read work/handoffs/kitsu-media-page.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## kitsu-community

```text
Unit kitsu-community — kitsu-community.
Read work/handoffs/kitsu-community.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## kitsu-profile-plus

```text
Unit kitsu-profile-plus — kitsu-profile-plus.
Read work/handoffs/kitsu-profile-plus.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## kitsu-home-extras

```text
Unit kitsu-home-extras — kitsu-home-extras.
Read work/handoffs/kitsu-home-extras.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## simkl-api-compliance

```text
Unit simkl-api-compliance — simkl-api-compliance.
Read work/handoffs/simkl-api-compliance.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## simkl-auth-v2

```text
Unit simkl-auth-v2 — simkl-auth-v2.
Read work/handoffs/simkl-auth-v2.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## simkl-cdn-feeds

```text
Unit simkl-cdn-feeds — simkl-cdn-feeds.
Read work/handoffs/simkl-cdn-feeds.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## simkl-media-page

```text
Unit simkl-media-page — simkl-media-page.
Read work/handoffs/simkl-media-page.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## simkl-profile-plus

```text
Unit simkl-profile-plus — simkl-profile-plus.
Read work/handoffs/simkl-profile-plus.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## simkl-list-sync

```text
Unit simkl-list-sync — simkl-list-sync.
Read work/handoffs/simkl-list-sync.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-explore

```text
Unit ux-explore — Explore like DailyAL: tonal buttons, arrow headers, no extra search, no captions.
Read work/handoffs/ux-explore.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-search

```text
Unit ux-search — Search home and results like DailyAL; one season picker.
Read work/handoffs/ux-search.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-reviews

```text
Unit ux-reviews — Reviewer tap opens the profile directly; Helpful sort by default.
Read work/handoffs/ux-reviews.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-detail-content

```text
Unit ux-detail-content — Detail content like DailyAL: adaptation tiles, empty featured hidden, fixed cast thumbnails.
Read work/handoffs/ux-detail-content.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-edit-sheet

```text
Unit ux-edit-sheet — Edit sheet as DailyAL's single compact card; sync panel behind More options.
Read work/handoffs/ux-edit-sheet.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-calendar

```text
Unit ux-calendar — Calendar as DailyAL's week grouped by day; never opens on an empty day.
Read work/handoffs/ux-calendar.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-seasonal

```text
Unit ux-seasonal — Seasonal header and list rows like DailyAL.
Read work/handoffs/ux-seasonal.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-theme

```text
Unit ux-theme — Theme settings without captions or preview card.
Read work/handoffs/ux-theme.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-home

```text
Unit ux-home — Home like DailyAL: status badge on cards, plain header icons, Fall row order.
Read work/handoffs/ux-home.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-stack

```text
Unit ux-stack — Interest stack page: MAL title case, collapsing app bar, single-line tabs.
Read work/handoffs/ux-stack.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-forum

```text
Unit ux-forum — Forum topic rows like DailyAL.
Read work/handoffs/ux-forum.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## home-rows-kinds

```text
Unit home-rows-kinds — Home OVA/ONA and manhwa/manhua/novel ranking rows (H3) with tracker cases.
Read work/handoffs/home-rows-kinds.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## ux-polish-2

```text
Unit ux-polish-2 — Tonal buttons stay tonal; explicit card hidden with NSFW off like DailyAL.
Read work/handoffs/ux-polish-2.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-notifications

```text
Unit mal-notifications — MAL notifications in the app: notification hub, mark as read, background polling with Android notifications.
Read work/handoffs/mal-notifications.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-messages

```text
Unit mal-messages — MAL private messages: inbox, sent, thread, compose and reply.
Read work/handoffs/mal-messages.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## anilist-client-limits

```text
Unit anilist-client-limits — anilist-client-limits.
Read work/handoffs/anilist-client-limits.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## anilist-list-fidelity

```text
Unit anilist-list-fidelity — anilist-list-fidelity.
Read work/handoffs/anilist-list-fidelity.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## anilist-people-pages

```text
Unit anilist-people-pages — anilist-people-pages.
Read work/handoffs/anilist-people-pages.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## anilist-search-filters

```text
Unit anilist-search-filters — anilist-search-filters.
Read work/handoffs/anilist-search-filters.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## anilist-social

```text
Unit anilist-social — anilist-social.
Read work/handoffs/anilist-social.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## anilist-notifications

```text
Unit anilist-notifications — anilist-notifications.
Read work/handoffs/anilist-notifications.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## anilist-settings

```text
Unit anilist-settings — anilist-settings.
Read work/handoffs/anilist-settings.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## anilist-media-page

```text
Unit anilist-media-page — anilist-media-page.
Read work/handoffs/anilist-media-page.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## anilist-profile-plus

```text
Unit anilist-profile-plus — anilist-profile-plus.
Read work/handoffs/anilist-profile-plus.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## anilist-home-extras

```text
Unit anilist-home-extras — anilist-home-extras.
Read work/handoffs/anilist-home-extras.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-episodes

```text
Unit mal-episodes — mal-episodes.
Read work/handoffs/mal-episodes.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-detail-sidebar

```text
Unit mal-detail-sidebar — mal-detail-sidebar.
Read work/handoffs/mal-detail-sidebar.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-seasonal-groups

```text
Unit mal-seasonal-groups — mal-seasonal-groups.
Read work/handoffs/mal-seasonal-groups.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-list-time

```text
Unit mal-list-time — mal-list-time.
Read work/handoffs/mal-list-time.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-profile-extras

```text
Unit mal-profile-extras — mal-profile-extras.
Read work/handoffs/mal-profile-extras.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-list-xml

```text
Unit mal-list-xml — mal-list-xml.
Read work/handoffs/mal-list-xml.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-web-writes-2

```text
Unit mal-web-writes-2 — mal-web-writes-2.
Read work/handoffs/mal-web-writes-2.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-api-small

```text
Unit mal-api-small — mal-api-small.
Read work/handoffs/mal-api-small.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## mal-hub-wiring

```text
Unit mal-hub-wiring — MAL notifications: bell, sidebar entry, background polling when the app is closed, settings switches.
Read work/handoffs/mal-hub-wiring.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## explore-polish

```text
Unit explore-polish — Explore: DailyAL images on category and genre cards, explicit genres, recommendations/stacks fallbacks, favourites badges.
Read work/handoffs/explore-polish.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## tracker-wiring

```text
Unit tracker-wiring — AniList / Kitsu / Simkl wiring: notifications, profile routes, remove action, MAL-only notes.
Read work/handoffs/tracker-wiring.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## theme-seasons

```text
Unit theme-seasons — Seasonal accents like DailyAL (spring pink, summer deep orange, fall brown, winter light blue).
Read work/handoffs/theme-seasons.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## detail-polish

```text
Unit detail-polish — Detail page polish: News never loads, faster fallbacks, status colours, tabs, numbers.
Read work/handoffs/detail-polish.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## home-fixes

```text
Unit home-fixes — Home: user-list cache per account.
Read work/handoffs/home-fixes.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## backup-fixes

```text
Unit backup-fixes — Backup restore never stops halfway; About closes its HTTP client.
Read work/handoffs/backup-fixes.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## release-fixes

```text
Unit release-fixes — Release: versionCode bump, launcher label, restricted update provider.
Read work/handoffs/release-fixes.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```

## in-app-update

```text
Unit in-app-update — In-app update: check GitHub releases, download and install APK.
Read work/handoffs/in-app-update.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
UI directive applies: compare DAL and MWL, keep the better, improve it.
Deliver with the PR procedure of the brief.
```

## deep-links

```text
Unit deep-links — Open myanimelist.net links in the app.
Read work/handoffs/deep-links.md fully, then the DAL reference files it lists, then the MWL files you own.
Build exactly the Goal, inside the Owns list. Heavy commands only through tools/heavy.sh; never run flutter build or touch the emulator.
Deliver with the PR procedure of the brief.
```
