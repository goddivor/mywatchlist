# AniList: everything MyWatchList does not use yet (GraphQL API and site)

Audit of `origin/dev` at `9b7aba7` (read only) against the live AniList GraphQL schema (anonymous introspection, 2026-10-28: 30 query fields, 37 mutations, 197 types). Every read example below was run anonymously against `https://graphql.anilist.co`; responses are trimmed. No mutation was run and no account was used.

Owner's rule applied: whatever AniList lets an AniList account fetch, show or do is a candidate, even when MAL has no equivalent.

## 0. What MWL uses today

### Files and what they do

| File | Role today |
|---|---|
| `lib/services/api/Anilist/anilist_graphql.dart` | The client every new page uses: `POST https://graphql.anilist.co`, anonymous or through `UserAnilistV2.sendAuthenticated` (replay once on 401, `idempotent: true` for every call), maps errors to `AnilistError` / `AnilistSessionExpired`, decodes bodies over 32 KB off the UI isolate. No rate-limit handling (no `X-RateLimit-Remaining`, no `Retry-After`). |
| `lib/services/api/Anilist/anilist_media.dart` | `AnilistMedia` card model: id, `idMal`, titles, cover, banner, `averageScore`, format, status, episodes, chapters, genres, season year, popularity, next airing episode. |
| `lib/services/api/Anilist/anilist_discover_service.dart` | `Page.media` with sort, season, status, `format_in`, country, one genre, search, `isAdult`; `airingSchedules` between two dates; forum `threads` (list only). Genres are a hard-coded list of 18 (no `GenreCollection`, no tags). |
| `lib/services/api/Anilist/anilist_list_service.dart` | `MediaListCollection` in chunks of 500 (`forceSingleCompletedList: true`), custom lists merged away by media id; maps to the shared `ListEntryView` (score `POINT_10_DECIMAL` then **rounded to an int**). Feeds airing notifications through `idMal`. |
| `lib/services/api/Anilist/anilist_profile_service.dart` | `Viewer` / `User(name)`: about (HTML), banner, avatar, created date, statistics (count, mean, statuses, scores, formats, top 15 genres, minutes, episodes, chapters, volumes) and 12 favourites of each kind. |
| `lib/services/api/Anilist/anilist_api.dart` | Legacy static client (no session, no error mapping). Only `searchMedia` is still used (by `tracker_sync_service.dart`); `getMediaDetails`, `getCharacterDetails`, `getStaffDetails`, `getStudioDetails`, `getRecommendations`, `getTrending`, `getAiringSchedule` are dead code. |
| `lib/services/api/Anilist/anilist_user.dart`, `anilist_user_prof.dart` | Legacy `Viewer` read used at sign-in (`anilist_auth_v2.dart`); its `saveMediaListEntry` / `deleteMediaListEntry` / `getUserStatistics` are unused. |
| `lib/widgets/user/sync/tracker_clients.dart` (not an AniList-owned file) | The only list write path: `SaveMediaListEntry(mediaId, status, scoreRaw, progress, progressVolumes, repeat, notes, startedAt, completedAt)` and `DeleteMediaListEntry`. |
| `lib/pages/Anilist/anilist_home_page.dart`, `widgets/Anilist/anilist_home_sections.dart`, `anilist_chips.dart` | Home driven by the shared home preferences: ranking rows mapped to `Page.media` sorts, "suggested" = trending, user list row, forum row (6 threads). News, features, doujin: hidden. |
| `lib/pages/Anilist/anilist_explore_page.dart`, `widgets/Anilist/anilist_browse_screen.dart` | Explore: search tile, Anime/Manga switch, airing soon (24 h), trending, this season, upcoming, top, popular, genre chips. Browse grid: one query, text search, no filter sheet. |
| `lib/pages/Anilist/anilist_forum_page.dart`, `widgets/Anilist/anilist_thread_tile.dart` | Thread list with 4 sorts. **A tap opens anilist.co in the browser**: no thread page, no comments. |
| `lib/pages/Anilist/anilist_user_page.dart`, `widgets/Anilist/anilist_user_list_adapter.dart` | The signed-in user's list through the shared `UserListView`; +1 step and the shared tracker editor (status, score, progress, volumes, dates; repeat and notes only through sync). |
| `lib/pages/Anilist/anilist_user_profile_page.dart`, `widgets/Anilist/anilist_profile_view.dart` | Profile tabs Stats, About, Favorites. "Edit profile" opens anilist.co settings. |
| `lib/services/auth/anilist_auth_v2.dart`, `lib/user/user_anilist_v2.dart` | Authorization-code flow (`response_type=code`, client secret), token kept in secure storage. |

### How AniList titles open

`openAnilistMedia` (`anilist_media_card.dart`), `AnilistUserListAdapter.open` and the favourites tab all do the same: **with an `idMal` the MAL detail screen opens (`AppRoutes.openContent`), without one the anilist.co page opens in the browser.** Characters, staff and studios in favourites always open the browser. So an AniList user never sees AniList's own title data (AniList score, rankings, score and status distributions, streaming episodes, external links, tags, AniList reviews and recommendations, their own advanced scores or custom lists). Titles without a MAL id (many manhwa, donghua, recent ONAs) have no page in the app at all.

### Findings outside the feature scope (fix first)

1. **Rate limit is 30 requests/minute right now, not 90.** Every anonymous answer carries `x-ratelimit-limit: 30` (AniList's "degraded mode", in place since 2024 and still on today). MWL has no limiter: the AniList home fires one request per enabled section (up to ~20 at once) plus the user list; a pull to refresh can hit 429. Add a shared token bucket in `anilist_graphql.dart` (30/min, read `X-RateLimit-Remaining`, honour `Retry-After` on 429, surface `AnilistError.isRateLimited`), and batch home rows with GraphQL aliases (one request can carry several `Page` blocks, see 4.1).
2. **`Media.averageScore` is deprecated** in the live schema (as are its filters `averageScore_greater/lesser/not`); the replacement is `weightedScore` (same 0-100 scale; `averageScore` still answers). `AnilistMedia.fields`, `anilist_api.dart` and the profile code read `averageScore`; switch to `weightedScore` with a fallback before it disappears.
3. **Decimal scores are destroyed by the +1 button.** `parseAnilistEntries` reads `score(format: POINT_10_DECIMAL)` then `score.round()` into the int `ListEntryView.score`; `AnilistUserListAdapter.step` sends that rounded score back with every +1 (`score: entry.score.toDouble()` → `scoreRaw`). A 7.5 becomes 8.0 (`scoreRaw` 80) the first time the user taps +1; POINT_100 users lose their unit digit (73 → 70). The editor has the same problem: `_syncEntryOf` hands it the rounded score, so any save (even a progress change) writes the rounded value. Fix: do not send the score from `step` (a null field is not sent), and keep the raw score for display in the user's format (see 9.1).
4. **Repeat, notes, priority and private are not read into the editor** (`_syncEntryOf` drops them; the list query does not even select `notes` / `private` / `hiddenFromStatusLists` / `customLists` / `advancedScores`), so the editor shows them empty for an AniList entry.
5. **`REPEATING` is folded into Watching** on read and never written back: re-watching titles silently become `CURRENT` after an edit.
6. **The token has no refresh**: AniList issues 1-year tokens with no refresh token for the code grant; the "renew" path of `sendAuthenticated` can only fail. Already decided (DECISIONS 2026-10-27, "no early warning"), so just a note: expiry = sign in again.
7. `isAdult: false` is the only adult filter; the account's own `options.displayAdultContent` is ignored (see 10).
8. Genres are hard-coded (18): `GenreCollection` answers 19 today (`Hentai` is the 19th, hidden when adult content is off). Tags (`MediaTagCollection`, 400+) are not used anywhere.

9. **Every call is sent as idempotent** (`AnilistGraphql._send` passes `idempotent: true`): fine for reads, wrong for the mutations this report proposes (a replay after a 401 could post a comment or an activity twice). The client needs a `mutate()` path with `idempotent: false`.
10. `anilist_api.dart` (legacy, no session, no error mapping) is dead except `searchMedia` used by `tracker_sync_service.dart`; the sync's AniList search could move to `AnilistDiscoverService.media` (finding for the sync owner).

## 1. Platform facts

| Fact | Value (checked 2026-10-28) |
|---|---|
| Endpoint | `POST https://graphql.anilist.co`, JSON `{query, variables}`; anonymous for every public read |
| Auth | `Authorization: Bearer <token>`; needed for `Viewer`, `Notification`, `mediaListEntry`, `isFavourite`, `isLiked`, `isFollowing`, `onList`, `compareWithAuthList`, private lists and every mutation. Anonymous `Page.notifications` answers `401 Unauthorized`. Tokens last one year, no refresh token. |
| Rate limit | **`x-ratelimit-limit: 30` per minute today** (normal value 90; AniList is still in its degraded mode). Headers `X-RateLimit-Remaining`, `X-RateLimit-Reset`, `Retry-After` on 429. The limit counts requests, not fields: one request with aliases (`a: Page {…} b: Page {…}`) costs 1. |
| Size caps | `perPage` max 50; `pageInfo.total` is capped (5000 for media, 500 for connections such as reviews or a character's media): rely on `hasNextPage`, never on `total`. Over-complex queries are rejected: keep nested connections small. `Page.threadComments` ignored `perPage: 2` and returned 201 rows (whole comment trees in `childComments` JSON): paginate defensively. |
| Text formats | `description`, `about`, `text`, `comment`, `body`, `message` take `asHtml`. HTML keeps AniList's own markup: `<span class='markdown_spoiler'>`, `img220(url)` → `<img width='220'>`, `youtube(id)` → `<div class='youtube' id='…'>`, `webm(url)`; links to `anilist.co/anime/…`, `/character/…`, `/user/…` (deep-linkable). `Markdown(markdown:)` renders a draft (preview before posting). |
| Deprecated now | `Media.averageScore` (use `weightedScore`), `Staff.language` (use `languageV2`), `User.stats` (still answers: `activityHistory` heatmap), `ToggleLike` (use `ToggleLikeV2`), `relationType` without `version: 2`. |
| Schema size | 30 root queries, 37 mutations, 20 notification types, 5 activity types (`TEXT`, `ANIME_LIST`, `MANGA_LIST`, `MESSAGE`, `MEDIA_LIST`), 430 tags in 24 categories, 19 genres, 36 streaming sources for `licensedBy`. |

Conventions that apply to every screen below (from MEMORY and DECISIONS): DailyAL's UI is the reference where it is better (the MAL detail screen already copies DAL's sections: reuse its section frame, header and card widgets for the AniList page rather than inventing a layout); no caption or hint text DailyAL does not have; every string through `S`; requests batched with aliases and cached like `AnilistDiscoverService.row`.

## 2. Title page (MWL opens the MAL detail screen instead)

One request (aliases, cost 1, anonymous; with the token the same request also returns `mediaListEntry`, `isFavourite`). Example run on Frieren (`id 154587`):

```graphql
query ($id: Int) { Media(id: $id) {
  id idMal siteUrl title { romaji english native userPreferred } synonyms hashtag
  weightedScore meanScore popularity favourites trending source countryOfOrigin isLicensed
  trailer { id site thumbnail } bannerImage coverImage { extraLarge color }
  rankings { rank type format year season allTime context }
  stats { scoreDistribution { score amount } statusDistribution { status amount } }
  tags { name rank category isGeneralSpoiler isMediaSpoiler isAdult description }
  externalLinks { site url type language color icon }
  streamingEpisodes { title thumbnail url site }
  studios { edges { isMain node { id name isAnimationStudio } } }
  staff(perPage: 25, sort: RELEVANCE) { edges { role node { id name { full } image { medium } } } }
  characters(perPage: 25, sort: [ROLE, RELEVANCE]) { edges { role node { id name { full } image { medium } }
     voiceActorRoles(sort: [RELEVANCE]) { roleNotes dubGroup voiceActor { id name { full } languageV2 image { medium } } } } }
  relations { edges { relationType(version: 2) node { id type format status title { userPreferred } coverImage { large } } } }
  recommendations(perPage: 10, sort: RATING_DESC) { nodes { id rating userRating mediaRecommendation { id title { userPreferred } coverImage { large } } } }
  reviews(perPage: 5, sort: RATING_DESC) { nodes { id summary score rating ratingAmount user { name avatar { medium } } } }
  trends(perPage: 30, sort: DATE_DESC) { nodes { date trending popularity inProgress averageScore episode } }
  airingSchedule(notYetAired: true, perPage: 5) { nodes { episode airingAt } }
  nextAiringEpisode { episode airingAt timeUntilAiring }
  mediaListEntry { id status score progress repeat notes private customLists advancedScores }   # token
  isFavourite                                                                                     # token
} }
```

```json
{"weightedScore":91,"meanScore":91,"popularity":494191,"favourites":56450,"trending":33,"source":"MANGA",
 "trailer":{"id":"tR8YH0G67Rk","site":"youtube"},"coverImage":{"color":"#bbf1a1"},
 "rankings":[{"rank":1,"type":"RATED","format":"TV","allTime":true,"context":"highest rated all time"},
             {"rank":50,"type":"POPULAR","allTime":true,"context":"most popular all time"},
             {"rank":1,"type":"RATED","year":2023,"context":"highest rated"}],
 "stats":{"scoreDistribution":[{"score":10,"amount":1159},…,{"score":90,"amount":70658},{"score":100,"amount":106581}],
          "statusDistribution":[{"status":"CURRENT","amount":74149},{"status":"PLANNING","amount":93903},
                                {"status":"COMPLETED","amount":305628},{"status":"DROPPED","amount":7573},{"status":"PAUSED","amount":12938}]},
 "tags":[{"name":"Travel","rank":96,"category":"Theme-Other","isMediaSpoiler":false},…28 tags, 1 spoiler ("Time Skip")],
 "externalLinks":[["Official Site","INFO","Japanese"],["Crunchyroll","STREAMING"],["Netflix","STREAMING"],["Hulu","STREAMING"],["Twitter","SOCIAL"],…],
 "streamingEpisodes":[{"title":"Episode 1 - The Journey's End","thumbnail":"https://img1.ak.crunchyroll.com/…","url":"http://www.crunchyroll.com/watch/G2XU04E88/…","site":"Crunchyroll"}, …28],
 "studios":[{"isMain":true,"node":{"id":11,"name":"MADHOUSE"}},{"isMain":false,"node":{"name":"Toho"}}],
 "characters":[{"role":"MAIN","node":{"name":{"full":"Frieren"}},"voiceActorRoles":[
     {"voiceActor":{"name":{"full":"Atsumi Tanezaki"},"languageV2":"Japanese"}},{"…":"English"},{"…":"French"}, … 10 languages]}],
 "recommendations":[{"rating":1208,"mediaRecommendation":{"title":{"userPreferred":"Violet Evergarden"}}},{"rating":771,"…":"Dungeon Meshi"}],
 "reviews":{"nodes":[{"id":23847,"summary":"Fascinating, fulfilling, and full of feelings…","score":100,"rating":334,"ratingAmount":383}]},
 "trends":[{"date":1793199600,"trending":303,"popularity":494191,"inProgress":74149}, …]}
```

| # | Candidate | Fields / call | Auth | MWL screen it adds or enriches | UI convention |
|---|---|---|---|---|---|
| A1 | Native AniList title page; titles without `idMal` become openable in the app | `Media(id)` above | no (token adds A13-A15) | New `AnilistMediaPage` pushed by `openAnilistMedia`, list `open`, favourites, search, people pages | Same section order and widgets as the MAL detail screen (DAL layout); "Open on MyAnimeList" action when `idMal` exists |
| A2 | AniList score, mean, popularity, favourites, trending rank | `weightedScore meanScore popularity favourites trending` | no | Header meta | DAL header chips |
| A3 | Rankings ("#1 highest rated all time", "#2 most popular 2023") | `rankings` | no | Header ranking chips, tap → browse with the same sort and year | DAL has rank chips for MAL |
| A4 | Score distribution (10 bars) and status distribution (watching / planning / completed / dropped / paused counts) | `stats` | no | "Stats" section, reuse `scorestatisticswidget.dart` / `animestatisticswidget.dart` | DAL stats section |
| A5 | Where to watch: official streaming links with site colour and icon, plus info and social links | `externalLinks` (type, language, color, icon) | no | "Platforms" section (same widget family as `media_platforms.dart`) | Icon row, no caption |
| A6 | Episode list with thumbnails and direct links (Crunchyroll episodes) | `streamingEpisodes` | no | "Episodes" section, horizontal thumbnails, tap opens the episode | Like DAL's episode videos row |
| A7 | Tags with rank %, category and spoiler hiding (tap reveals), description on long press; tap → browse by tag | `tags` | no | Chips under the synopsis | Spoiler tags hidden by default (AniList's own behaviour) |
| A8 | Characters with voice actors **per language** (10 languages for Frieren), role, dub group, role notes | `characters { voiceActorRoles }` | no | Characters section with a language picker (default from the app language) | DAL characters row |
| A9 | Staff with roles, studios (main vs producer) | `staff`, `studios { isMain }` | no | Staff section, studio chips → studio page (B3) | |
| A10 | Relations with 14 relation types (source, sequel, side story, spin-off, character, compilation, contains…) for anime **and** manga | `relations { relationType(version: 2) }` | no | Related section | DAL related row |
| A11 | Recommendations with community rating (+1208) and my vote | `recommendations { rating userRating }` | no / token for `userRating` | Recommendations row, "view all" page | DAL row; add the rating badge |
| A12 | Reviews: summary, score /100, helpful ratio (334/383), full review page | `reviews`, `Review(id) { body(asHtml: true) }` | no | Reviews section reusing `widgets/MAL/review/*` layout, review page (F7) | DAL reviews |
| A13 | My entry on this title, edited in place (AniList editor, H) | `mediaListEntry` | token | Edit panel / FAB | Same FAB as MAL |
| A14 | Favourite toggle | `ToggleFavourite(animeId: / mangaId:)` mutation | token | Heart in the header | |
| A15 | Write a review, add a recommendation, vote on a recommendation | `SaveReview(mediaId, body, summary, score, private)`, `SaveRecommendation(mediaId, mediaRecommendationId, rating: RATE_UP/RATE_DOWN)` | token | Review composer, "Recommend a title" picker, vote arrows on A11 | Behind an overflow action |
| A16 | Popularity / score / watching trend over time (with episode markers) | `trends` (`MediaTrend`: trending, popularity, inProgress, averageScore, episode per day) | no | "Trends" chart in the stats section | `dataviz`-style line chart, no legend text beyond axes |
| A17 | Next episode countdown and upcoming episodes for titles without MAL id | `nextAiringEpisode`, `airingSchedule(notYetAired: true)` | no | Header countdown (reuse `countdown_chip.dart`) | |
| A18 | Trailer | `trailer { id site thumbnail }` | no | Media section (reuse `videowidget.dart`) | |
| A19 | Discussion threads of this title | `Page.threads(mediaCategoryId: $id)` (Frieren: "[Spoilers] … Episode 10 Discussion", 76 replies) | no | "Forum" section → thread page (F2) | DAL forums section |
| A20 | Synonyms in all languages, hashtag, source, country, licensed flag, cover colour for theming the header | `synonyms hashtag source countryOfOrigin isLicensed coverImage.color` | no | "More info" modal | |
| A21 | Who of the people I follow has it, with their status and score | `Page.mediaList(mediaId: $id, isFollowing: true) { status score user { name avatar } }` | token | "Following" section (AniList site shows it on every title) | Avatars row |

Rate cost: 1 request for the whole page (A1-A20); A21 is a second aliased block in the same request when signed in. Cache like `HomeAsync` (10 min).

## 3. Characters, staff, studios (today: browser only)

The MAL `character_screen.dart` / `characters_staff_screen.dart` / `studios_screen.dart` are fed by Jikan and MAL ids; AniList ids cannot reach them. One request per page, anonymous.

```graphql
query ($c: Int, $s: Int, $st: Int) {
 c: Character(id: $c) { id name { full native alternative alternativeSpoiler } image { large } gender age bloodType
    dateOfBirth { month day } favourites isFavourite description(asHtml: true)
    media(perPage: 25, sort: POPULARITY_DESC) { pageInfo { hasNextPage } edges { characterRole
       node { id type format title { userPreferred } coverImage { large } }
       voiceActorRoles(sort: [RELEVANCE]) { voiceActor { id name { full } languageV2 } } } } }
 s: Staff(id: $s) { id name { full native } languageV2 primaryOccupations gender age yearsActive homeTown
    dateOfBirth { year month day } dateOfDeath { year } favourites isFavourite description(asHtml: true)
    characterMedia(perPage: 25, sort: START_DATE_DESC) { edges { characterRole node { id title { userPreferred } } characters { id name { full } image { medium } } } }
    staffMedia(perPage: 25, sort: START_DATE_DESC) { edges { staffRole node { id title { userPreferred } } } } }
 st: Studio(id: $st) { id name isAnimationStudio favourites isFavourite
    media(perPage: 25, sort: POPULARITY_DESC, isMain: true) { edges { isMainStudio node { id title { userPreferred } startDate { year } } } } }
}
```

```json
{"c":{"name":{"full":"Frieren","native":"フリーレン"},"gender":"Female","age":"1000+","favourites":22564,
      "description":"Frieren is the protagonist of _Sousou no Frieren_ and [Fern](https://anilist.co/character/183965)'s master…",
      "media":{"edges":[{"characterRole":"MAIN","node":{"id":154587,"type":"ANIME","title":{"userPreferred":"Sousou no Frieren"}},
                          "voiceActorRoles":[{"voiceActor":{"name":{"full":"Atsumi Tanezaki"}}}]},
                         {"characterRole":"MAIN","node":{"id":118586,"type":"MANGA"},"voiceActorRoles":[]}]}},
 "s":{"name":{"full":"Atsumi Tanezaki","native":"種﨑敦美"},"languageV2":"Japanese","primaryOccupations":["Voice Actor","Vocalist"],
      "age":36,"yearsActive":[2008],"homeTown":"Oita Prefecture, Japan","dateOfBirth":{"year":1990,"month":9,"day":27},"favourites":3920,
      "characterMedia":{"edges":[{"characterRole":"SUPPORTING","node":{"title":{"userPreferred":"Mob Psycho 100"}},"characters":[{"name":{"full":"Tome Kurata"}}]}]},
      "staffMedia":{"edges":[{"staffRole":"Theme Song Performance (ED1, ED4)","node":{"title":{"userPreferred":"Seishun Buta Yarou…"}}}]}},
 "st":{"name":"MADHOUSE","isAnimationStudio":true,"favourites":20002}}
```

| # | Candidate | Call | Auth | MWL screen | Notes |
|---|---|---|---|---|---|
| B1 | AniList character page: names (incl. spoiler alternatives, hidden), age, gender, blood type, birthday, favourites, description with spoilers, appearances in anime **and** manga with role, VA per language | `Character(id)` | no | New `AnilistCharacterPage` | Same layout as MAL `character_screen.dart`; description HTML through the AniList renderer (F0) |
| B2 | Staff page: occupations, language, years active, hometown, birth/death, roles as voice actor (character + title) and as staff (role text), "on my list" filter | `Staff(id)`; `characterMedia(onList: true)` with token | no / token | New `AnilistStaffPage` with tabs Voice roles / Staff roles | DAL people page |
| B3 | Studio page: all productions sorted by date or popularity, main-studio filter | `Studio(id)` | no | New `AnilistStudioPage` (MWL studios screen is MAL-only) | Sort `START_DATE_DESC` puts undated titles first: filter or sort client side |
| B4 | Favourite toggle on character, staff, studio | `ToggleFavourite(characterId: / staffId: / studioId:)` | token | Heart in each header | |
| B5 | Birthdays today (characters and staff) | `Page.characters(isBirthday: true, sort: FAVOURITES_DESC)`, `Page.staff(isBirthday: true)` (today: Shinra Kusakabe 5815 favs, Kuririn…) | no | Home row (D4) | |
| B6 | Most favourited characters / staff (all time) | `Page.characters(sort: FAVOURITES_DESC)` | no | Explore row "Top characters", like MAL `top_characters.dart` | |
| B7 | Search characters, staff, studios, users | `Page.characters(search:)`, `staff(search:)`, `studios(search:)`, `users(search:)` | no | Search tabs (C5) | |

## 4. Search and browse (today: text + sort, no filter sheet)

`Page.media` accepts 75 arguments. MWL passes 10 (type, sort, season, seasonYear, status, format_in, country, one genre, search, isAdult).

```graphql
query { Page(perPage: 3) { pageInfo { hasNextPage } media(type: ANIME, tag_in: ["Time Skip"], genre_not_in: ["Romance"],
   source_in: [MANGA], format_in: [TV], weightedScore_greater: 80, popularity_greater: 50000, episodes_lesser: 30,
   startDate_greater: 20150000, licensedBy_in: ["Netflix"], minimumTagRank: 60, sort: SCORE_DESC) { id title { userPreferred } weightedScore } } }
```
```json
{"media":[{"id":154587,"title":{"userPreferred":"Sousou no Frieren"},"weightedScore":91},
          {"id":136430,"title":{"userPreferred":"VINLAND SAGA SEASON 2"},"weightedScore":88},
          {"id":101348,"title":{"userPreferred":"VINLAND SAGA"},"weightedScore":87}]}
```

| # | Candidate | Filter args | Auth | MWL screen |
|---|---|---|---|---|
| C1 | Filter sheet: genres include **and** exclude (from `GenreCollection`, 19), tags include / exclude (from `MediaTagCollection`, 430 in 24 categories, with `minimumTagRank`, `tagCategory_in`) | `genre_in genre_not_in tag_in tag_not_in tagCategory_in minimumTagRank` | no | `AnilistBrowseScreen` filter button + sheet (DAL advanced search layout) |
| C2 | Format, status, source (15 values: web novel, video game…), country (JP/KR/CN/TW), licensed flag | `format_in status_in source_in countryOfOrigin isLicensed` | no | same |
| C3 | Year range, season, start/end date ranges, episodes / duration / chapters / volumes ranges | `startDate_greater/lesser seasonYear season episodes_greater/lesser duration_* chapters_* volumes_*` | no | same, range sliders |
| C4 | Score and popularity ranges; "streaming on" (36 sources from `ExternalLinkSourceCollection(type: STREAMING)`) | `weightedScore_greater/lesser popularity_greater/lesser licensedBy_in licensedById_in` | no | same |
| C5 | Hide titles on my list / only on my list | `onList: false/true` | token | toggle in the sheet |
| C6 | All 36 sorts (title per language, start date, episodes, duration, updated, favourites…) | `sort` | no | sort menu |
| C7 | Search other kinds: characters, staff, studios, users | B7 | no | tabs in the search screen |
| C8 | Adult content follows the account (`Viewer.options.displayAdultContent`) instead of only the app NSFW switch | `isAdult` | token | discover service |
| C9 | Tag explorer: browse a tag (description, category) | `MediaTagCollection`, `Page.media(tag: $name)` | no | tag chip tap from A7, Explore "Tags" grid |

Cost: a filtered page is one request; the collections (genres, tags, link sources) are one aliased request cached for a day.

## 5. Home and explore

| # | Candidate | Call (trimmed) | Auth | MWL screen |
|---|---|---|---|---|
| D1 | Recommendations from my list ("because you have X") | `Page.recommendations(onList: true, sort: RATING_DESC) { media { title } mediaRecommendation { … mediaListEntry { status } } }` | token | Home row "Recommended for you" (replaces "suggested = trending") |
| D2 | Following activity row (what my follows watched, latest first) | `Page.activities(isFollowing: true, type_in: [ANIME_LIST, MANGA_LIST, TEXT], sort: ID_DESC)` | token | Home row of activity cards (F3) |
| D3 | Daily trends with the episode that drove them | `Page.mediaTrends(date_greater: $yesterday, releasing: true, sort: TRENDING_DESC) { trending episode media {…} }` (today: #1 trending 9354, episode 4) | no | Explore "Trending today" row with an "Ep 4" badge |
| D4 | Birthdays today | B5 | no | Home row |
| D5 | Latest reviews, latest recommendations | `Page.reviews(sort: ID_DESC, mediaType: ANIME)`, `Page.recommendations(sort: ID_DESC)` | no | Explore rows → review page / title |
| D6 | Top characters / staff | B6 | no | Explore rows |
| D7 | Airing for titles without MAL id (manhwa adaptations, donghua): the calendar is MAL-keyed, so they are missing | `Page.airingSchedules(mediaId_in: [my list ids without idMal])` | no | **Finding for the calendar owner** (DECISIONS 2026-10-28 keeps one calendar); the AniList units can expose `AnilistDiscoverService.airing` for it |
| D8 | Home rows in one request: N `Page` blocks with aliases instead of N requests (the home fires one per section today) | aliases | no | `anilist_home_sections.dart` loader (needed for the 30/min limit) |
| D9 | Site statistics (users +2307 today, 22 660 anime, 20 229 reviews) | `SiteStatistics { users anime manga characters staff studios reviews }` | no | Low value: skip or a small card at the bottom of Explore |
| D10 | "This season" with all formats and the "leftovers" (still airing from last season) | `season seasonYear` + `status: RELEASING, startDate_lesser` | no | Explore seasonal tabs (TV, TV short, movie, OVA/ONA/special, leftovers), as AniList's and AniChart's season pages |

## 6. Profile and statistics (today: Stats, About, Favorites tabs; 12 favourites per kind; top 15 genres)

```graphql
query ($name: String) { User(name: $name) { id name siteUrl donatorTier donatorBadge moderatorRoles createdAt previousNames { name }
  options { profileColor titleLanguage }
  mediaListOptions { scoreFormat animeList { customLists sectionOrder advancedScoringEnabled advancedScoring } }
  stats { activityHistory { date amount level } }
  statistics { anime { count meanScore standardDeviation minutesWatched
    tags(limit: 10, sort: COUNT_DESC) { tag { name } count meanScore minutesWatched mediaIds }
    voiceActors(limit: 10, sort: COUNT_DESC) { voiceActor { id name { full } image { medium } } count meanScore characterIds }
    staff(limit: 10) { staff { name { full } } count }  studios(limit: 10) { studio { name } count meanScore minutesWatched }
    releaseYears { releaseYear count meanScore }  startYears { startYear count }  lengths { length count meanScore }  countries { country count } } } } }
```
```json
{"name":"befalt","donatorBadge":"Donator","createdAt":1557698301,"options":{"profileColor":"green","titleLanguage":"ENGLISH"},
 "mediaListOptions":{"scoreFormat":"POINT_10","animeList":{"customLists":["Watching (Non-Seasonals)","Watching (Seasonals)","Rewatch required",…],
   "advancedScoringEnabled":false,"advancedScoring":["Story","Characters","Visuals","Audio","Enjoyment"]}},
 "stats":{"activityHistory":[… 31 days …,{"date":1793059200,"amount":2,"level":7}]},
 "statistics":{"anime":{"count":798,"meanScore":44.29,"standardDeviation":22.6,"minutesWatched":162163,
   "tags":[{"tag":{"name":"Male Protagonist"},"count":494,"meanScore":44.28,"minutesWatched":130376,"mediaIds":[20607,151514,…]}],
   "voiceActors":[{"voiceActor":{"name":{"full":"Yuuki Kaji"}},"count":38,"meanScore":37.08,"characterIds":[24496,…]}],
   "studios":[{"studio":{"name":"MADHOUSE"},"count":56,"meanScore":63.64,"minutesWatched":22093}],
   "releaseYears":[{"releaseYear":2025,"count":116,"meanScore":32.73}],"lengths":[{"length":"7-16","count":414,"meanScore":38.92}],
   "countries":[{"country":"JP","count":787},{"country":"CN","count":7}]}}}
```

| # | Candidate | Call | Auth | MWL screen |
|---|---|---|---|---|
| E1 | Stats by tag, voice actor, staff, studio (count, mean, time; tap → the titles `mediaIds` / characters) | `statistics.{tags,voiceActors,staff,studios}` | no (public profiles) | Profile Stats tab: new sub-tabs "Genres / Tags / Voice actors / Staff / Studios", as on anilist.co/user/x/stats |
| E2 | By release year, by start (watch) year, by length bucket, by country; standard deviation | `releaseYears startYears lengths countries standardDeviation` | no | Stats tab charts (bar charts, existing `dataviz` style) |
| E3 | Genres beyond 15 with time spent and mean, sortable by count / mean / time | `genres(sort: MEAN_SCORE_DESC)` | no | Stats tab |
| E4 | Activity heatmap (last weeks, GitHub-style) | `stats.activityHistory` (deprecated block, still answers) | no | Profile header or Overview tab |
| E5 | Profile activity tab (list updates and statuses with likes and replies) | `Page.activities(userId:, sort: [PINNED, ID_DESC])` | no | New "Activity" tab (F3 widgets) |
| E6 | All favourites with paging (not only 12), favourite order, reorder my own | `favourites { anime(page:) … }`, `UpdateFavouriteOrder` | no / token | Favorites tab: "view all" per kind; drag to reorder on my profile |
| E7 | Favourites open native pages (title A1, character B1, staff B2, studio B3) instead of the browser | — | no | Favorites tab |
| E8 | Followers, following, mutuals, follow / unfollow, remove follower | `Page.followers(userId:)`, `following`, `mutualFollowers`; `ToggleFollow(userId)`, `DeleteFollower` | no / token | Profile header counters (539 followers, 100 following for befalt) → user list page |
| E9 | Another user's list (read only), with "compare with mine" | `MediaListCollection(userName:, type:)` with `compareWithAuthList: true` on `Page.mediaList` | no / token | New page from a profile: same `UserListView`, read-only adapter |
| E10 | Profile colour, donator badge, moderator roles, previous names | `options.profileColor donatorBadge moderatorRoles previousNames` | no | Profile header accent and badges |
| E11 | Send a message to a user (profile message activity) | `SaveMessageActivity(recipientId, message, private)` | token | "Message" action on another user's profile |
| E12 | User search | `Page.users(search:)` | no | Search tab (C7) and "find a user" in the profile |
| E13 | Score distribution in the user's own format (POINT_5 stars, POINT_3 smileys) | `mediaListOptions.scoreFormat` + `scores` | no | Stats tab (today folded to tens) |

## 7. Social: activity, forum, reviews (today: thread list only, tap = browser)

F0, a prerequisite: an AniList HTML renderer. Bodies come as HTML (`asHtml: true`) with AniList specifics: spoiler spans, `img`, YouTube and webm embeds, `@mentions`, links to `anilist.co/...`. MWL already renders HTML in the About tab (`onTapUrl`, `zoomInImage`); one shared widget should add spoiler reveal, embedded YouTube thumbnails and in-app routing of `anilist.co` links (title, character, staff, studio, user, thread).

```graphql
query { Page(perPage: 2) { threadComments(threadId: 4446, sort: ID) { id comment(asHtml: false) likeCount isLiked createdAt user { name avatar { medium } } childComments } } }
```
```json
{"threadComments":[{"id":692832,"comment":"Oohhh! So sorry! Fixed!","likeCount":1,"createdAt":1614373656,"user":{"name":"Allys"},"childComments":null},
  {"id":674590,"comment":"[February 2021 Monthly - Easy](https://anilist.co/forum/thread/23941/comment/627142)","user":{"name":"Panaino"},
   "childComments":[{"id":683257,"comment":"Congratulations! February 2021 Monthly Challenge completed on Easy Mode!","user":{"name":"Muffaroo"},"childComments":null}]}]}
```
```graphql
query { Page(perPage: 20) { activities(sort: ID_DESC, type_in: [TEXT, ANIME_LIST, MANGA_LIST]) { __typename
  ... on TextActivity { id text(asHtml: true) likeCount replyCount isLiked createdAt user { name avatar { medium } } }
  ... on ListActivity { id status progress likeCount replyCount isLiked createdAt user { name } media { id title { userPreferred } coverImage { medium } } } } } }
```
```json
{"activities":[{"__typename":"ListActivity","status":"read chapter","progress":"1 - 84","user":{"name":"Bdotbandz"},"media":{"title":{"userPreferred":"Byeongariban Hunter-neun Hyodo Jung!"}}},
  {"__typename":"ListActivity","status":"watched episode","progress":"872","user":{"name":"noronhinha"},"media":{"title":{"userPreferred":"ONE PIECE"}}}]}
```

| # | Candidate | Call | Auth | MWL screen |
|---|---|---|---|---|
| F1 | Forum categories (fixed ids on anilist.co, no collection query: hard-code them like the genres) and filters: by category, by title, subscribed, search | `threads(categoryId:, mediaCategoryId:, subscribed: true, search:)`; sorts incl. `IS_STICKY`, `CREATED_AT_DESC` | no / token for subscribed | Forum page chips |
| F2 | Thread page: body (HTML), categories and linked titles, comments as a tree with likes; reply, reply to a comment, like thread or comment, subscribe; edit / delete my own | `Thread(id)`, `Page.threadComments(threadId:)`; `SaveThreadComment(threadId, parentCommentId, comment)`, `ToggleLikeV2(id, type: THREAD/THREAD_COMMENT)`, `ToggleThreadSubscription`, `DeleteThreadComment` | no / token | New `AnilistThreadPage` (MWL's MAL forum topic page layout, `widgets/forum/*`) |
| F3 | Activity feed: Following / Global, filter by kind (status, list updates, messages); like, reply, subscribe; pinned | `Page.activities(isFollowing:, type_in:, hasRepliesOrTypeText:)`, `Activity(id) { replies }`, `SaveActivityReply`, `ToggleLikeV2(type: ACTIVITY/ACTIVITY_REPLY)`, `ToggleActivitySubscription` | no for Global / token for Following | New "Activity" tab next to Forum on the AniList Forum tab (AniList's home page is this feed) |
| F4 | Post a status (text activity), edit, delete; pin to my profile | `SaveTextActivity(text)`, `DeleteActivity`, `ToggleActivityPin` | token | Composer FAB on the Activity tab, with `Markdown` preview |
| F5 | Who liked (thread, comment, activity) | `Page.likes(likeableId:, type:)` | no | Bottom sheet from the like count |
| F6 | Create a thread (title, body, categories, linked titles) | `SaveThread(title, body, categories, mediaCategories)` | token | Low priority: overflow action on the forum page |
| F7 | Review page: full body (HTML), score, helpful ratio; vote up / down; write, edit, delete my review (private option) | `Review(id) { body(asHtml: true) userRating }`, `RateReview(reviewId, rating: UP_VOTE/DOWN_VOTE/NO_VOTE)`, `SaveReview`, `DeleteReview` | no / token | New `AnilistReviewPage` (reuse `widgets/MAL/review/review_detail_page.dart` layout) |
| F8 | Reviews feed: latest, by title, by user, sorted by rating / score / date | `Page.reviews(mediaId:, userId:, mediaType:, sort:)` | no | Reviews list (title page "view all", profile tab, explore) |
| F9 | Recommendation vote and submit | `SaveRecommendation(mediaId, mediaRecommendationId, rating)` | token | A11 / A15 |

## 8. Notifications (today: none; MWL only schedules its own airing reminders from MAL ids)

```graphql
query { Viewer { unreadNotificationCount }
  Page(perPage: 25) { notifications(resetNotificationCount: true, type_in: [AIRING, ACTIVITY_REPLY, FOLLOWING, ACTIVITY_LIKE, THREAD_COMMENT_REPLY, RELATED_MEDIA_ADDITION]) {
    __typename
    ... on AiringNotification { episode contexts createdAt media { id title { userPreferred } coverImage { medium } } }
    ... on FollowingNotification { context createdAt user { name avatar { medium } } }
    ... on ActivityReplyNotification { context activityId createdAt user { name } }
    ... on RelatedMediaAdditionNotification { context createdAt media { id title { userPreferred } } }
    ... on MediaDataChangeNotification { context reason createdAt media { id } } } } }
```
Anonymous answer: `{"errors":[{"message":"Unauthorized.","status":401}],"data":{"Page":null}}` (token required; not run with a token).

| # | Candidate | Call | Auth | MWL screen |
|---|---|---|---|---|
| G1 | Inbox of the 20 types: airing, follows, messages, mentions, replies, likes, thread replies / subscriptions, related media added, data changed / merged / deleted, submission updates; filter chips by group (Airing, Activity, Forum, Follows, Media) as anilist.co does | `Page.notifications(type_in:)` | token | New `AnilistNotificationsPage` |
| G2 | Unread badge | `Viewer.unreadNotificationCount` (1 cheap request; refresh on resume, not polled) | token | Bell with count in the AniList home app bar |
| G3 | Mark as read | `resetNotificationCount: true` on the first page read | token | inbox |
| G4 | Background "you have N new AniList notifications" system notification (WorkManager, at most every 30 min) | G2 | token | **Finding for the notifications owner** (`notification_service.dart` is not an AniList file) |
| G5 | Tap routes in app: airing → title page, reply → activity, thread → thread page, follow → profile | — | — | inbox |

## 9. List editing (today: status, score, progress, volumes, dates; repeat and notes only through sync)

`SaveMediaListEntry` takes 16 arguments; MWL sends 9. `UpdateMediaListEntries(ids:)` edits many entries at once.

```graphql
mutation ($mediaId: Int, $status: MediaListStatus, $scoreRaw: Int, $progress: Int, $progressVolumes: Int, $repeat: Int,
          $priority: Int, $private: Boolean, $notes: String, $hiddenFromStatusLists: Boolean, $customLists: [String],
          $advancedScores: [Float], $startedAt: FuzzyDateInput, $completedAt: FuzzyDateInput) {
  SaveMediaListEntry(mediaId: $mediaId, status: $status, scoreRaw: $scoreRaw, progress: $progress, progressVolumes: $progressVolumes,
     repeat: $repeat, priority: $priority, private: $private, notes: $notes, hiddenFromStatusLists: $hiddenFromStatusLists,
     customLists: $customLists, advancedScores: $advancedScores, startedAt: $startedAt, completedAt: $completedAt) {
   id status score(format: POINT_10_DECIMAL) customLists(asArray: true) advancedScores private hiddenFromStatusLists } }
```
(Not run: no mutation in this audit.)

| # | Candidate | Fields | Auth | MWL screen |
|---|---|---|---|---|
| H1 | Score in the user's format: POINT_100 (0-100), POINT_10_DECIMAL (7.5), POINT_10, POINT_5 (stars), POINT_3 (smileys) for display **and** input | `Viewer.mediaListOptions.scoreFormat`; read `score` without `format:` (= user format) or keep `POINT_100` raw; write `scoreRaw` | token | List cards, editor score control (slider 0-100, decimal stepper, 5 stars, 3 faces) |
| H2 | Fix: +1 must not rewrite the score (finding 3) | omit `score` in `step` | token | `AnilistUserListAdapter.step` |
| H3 | `REPEATING` status (Rewatching / Rereading) read and written; repeat count | `status: REPEATING`, `repeat` | token | Status picker gains "Rewatching", list shows it in Watching with a badge (AniList's own "Rewatching" section) |
| H4 | Custom lists: show them as extra tabs (befalt has 4), add / remove an entry to a custom list, hide from status lists | `MediaListCollection.lists { name isCustomList }`, `customLists`, `hiddenFromStatusLists` | token | `UserListView` tabs after the status tabs; editor checkboxes |
| H5 | Advanced scores (Story, Characters, Visuals, Audio, Enjoyment, or the user's own categories) | `mediaListOptions.animeList.advancedScoring`, `advancedScores: [Float]` | token | Editor section shown when `advancedScoringEnabled` |
| H6 | Private entry | `private` | token | Editor switch, lock icon on the card |
| H7 | Priority 0-5 (AniList stores it; MWL folds it to 3 levels when reading and never writes it) | `priority` | token | Editor |
| H8 | Notes, repeat count, read into the editor (finding 4) | `notes repeat` | token | Editor |
| H9 | Bulk edit selected entries (status, score, private, custom list) | `UpdateMediaListEntries(ids:, …)` | token | Long-press multi-select in `UserListView` (MWL has no multi-select yet: AniList-only action menu) |
| H10 | Section order and "split completed by format" as on anilist.co | `sectionOrder splitCompletedSectionByFormat`, `forceSingleCompletedList: false` | token | Tab order of the AniList list |
| H11 | Sort by AniList's sorts server side (added time, started, finished, priority, repeat) | `MediaListCollection(sort:)` | token | Sort menu additions (today `standardSortOptions` only) |
| H12 | `createdAt` (added to list) and `updatedAt` shown and sortable | `createdAt updatedAt` | token | List card detail / sort |

## 10. Settings (today: "Edit profile" opens anilist.co)

`UpdateUser` covers almost every AniList account setting; `Viewer { options mediaListOptions }` reads them (token).

| # | Candidate | `UpdateUser` args | MWL screen |
|---|---|---|---|
| I1 | Title language (romaji / English / native, stylised variants) and staff name language, used by MWL too instead of the app-only `preferredTitle` when the AniList account is active | `titleLanguage staffNameLanguage` | New AniList account settings page (from the profile or Manage accounts) |
| I2 | Score format and advanced scoring categories, custom lists create / rename / delete | `scoreFormat animeListOptions mangaListOptions`, `DeleteCustomList(customList, type)` | same, "Lists" group |
| I3 | Adult content (display, in search, in quick search, adult activities) | `displayAdultContent includeAdultContentInSearch includeAdultContentInQuickSearch displayAdultActivities` | same; also feeds C8 |
| I4 | AniList airing notifications on/off and one switch per notification type (20) | `airingNotifications notificationOptions: [{type, enabled}]` | same, "Notifications" group |
| I5 | Timezone, activity merge time, restrict messages to people I follow, disable list activity per status | `timezone activityMergeTime restrictMessagesToFollowing disabledListActivity` | same, "Activity" group |
| I6 | About text (markdown with preview), profile colour, donator badge text | `about profileColor donatorBadge`, `Markdown` for the preview | Profile "Edit" sheet |
| I7 | Row order of the list | `rowOrder` (score, title, updatedAt, id) | same |

## 11. Website-only (not in the API)

| Site feature | Worth it? |
|---|---|
| Data submissions (add/edit anime, characters, staff) and moderation queues | No: web forms, moderated; keep "Open on AniList" |
| List import from MAL XML / export (Settings > Lists) | No: site-only, file based; MWL already syncs MAL ⇄ AniList through the API |
| Custom profile CSS / list themes (`theme` in list options is still readable) | No |
| AniChart (anichart.net) season charts and highlights | Its data is the same API (`AniChartUser`, `UpdateAniChartHighlights` need a token); D10 covers the seasonal view. No scraping needed |
| Recent "Social" sidebar (online users, top reviewers) | No public endpoint; low value |
| Everything else seen on anilist.co (feed, forum, reviews, stats, favourites, notifications, settings, followers, messages) | In the API: covered above, no scraping needed |

## 12. Top 15 by user value

| Rank | Item | Why |
|---|---|---|
| 1 | A1-A12 native AniList title page | Every AniList tap today leaves AniList's data (or the app); titles without `idMal` have no page at all |
| 2 | H1-H3, H8 + findings 3-5: list fidelity (score format, the +1 score bug, Rewatching, notes / repeat / priority read) | Data loss today on the user's own list |
| 3 | H4-H7: custom lists, advanced scores, private, hidden (AniList editor) | Core AniList list features with no MAL equivalent |
| 4 | Finding 1 + D8: 30/min limiter and aliased batching | The home can hit 429 today; every new screen adds requests |
| 5 | G1-G3, G5: notifications inbox and unread badge | The main reason AniList users open the site daily |
| 6 | C1-C6: filter sheet (genres incl./excl., tags, source, years, score, streaming service, on my list) | Search is the weakest AniList screen |
| 7 | F3-F5: activity feed (Following / Global) with likes and replies, post a status | AniList's home page; nothing of it in MWL |
| 8 | F1-F2: forum thread page with comment tree, reply, like, subscribe | The Forum tab is a list of browser links today |
| 9 | B1-B4: character, staff, studio pages (VA roles per language) | Linked from A8/A9 and favourites |
| 10 | E1-E4, E13: full statistics (tags, VAs, staff, studios, years, lengths, countries, heatmap) | AniList's best-known feature after the list |
| 11 | A14, B4, E6-E7: favourites everywhere (toggle, full lists, reorder, native pages) | Cheap once the pages exist |
| 12 | E8-E9, A21: followers / following, follow, others' lists with compare, "following" on the title page | Social core |
| 13 | F7-F9, A15: reviews (read, vote, write) and recommendation votes | Content and contribution |
| 14 | I1-I7: AniList settings in the app (title language, score format, adult, notification options, list options, about) | Removes the last "open anilist.co" buttons |
| 15 | D1-D4, D10: home extras (recommendations from my list, following activity, daily trends with episode, birthdays, full season view) | Personalised home with data MAL cannot give |

## 13. Proposed units (disjoint MWL file sets)

Shared rule, as in the Kitsu / Simkl report: today a tap on an AniList title opens `lib/screens/MAL/detail/` (owned by other units) or the browser. The native pages below are new pages; "Open on MyAnimeList" stays when `idMal` exists. The single entry point is `openAnilistMedia` in `lib/widgets/Anilist/anilist_media_card.dart` (owned by `anilist-media-page`); the other units call it instead of their own copies (`AnilistUserListAdapter.open`, the favourites `_open`), so no MAL file changes. Each page file exposes its own `open…` function, which is why the units that link to a page run after it.

| Unit | Delivers | Owns (create or edit only these) | Needs done first |
|---|---|---|---|
| `anilist-client-limits` (fix, P1, small) | Token bucket 30/min shared by every AniList call (reads `X-RateLimit-Remaining`, waits on `Retry-After`, typed 429), `mutate()` sent with `idempotent: false`, an aliased multi-query helper (`batch({alias: query})`), `weightedScore` with `averageScore` fallback in `AnilistMedia.fields`, shared actions `toggleFavourite`, `toggleLike` (`ToggleLikeV2`), `toggleFollow` | `lib/services/api/Anilist/anilist_graphql.dart`, `lib/services/api/Anilist/anilist_media.dart`, `lib/services/api/Anilist/anilist_actions.dart` (new), `test/units/anilist-client-limits/**` | none |
| `anilist-list-fidelity` (fix, P1) | Findings 3-5 and H1-H12: score in the user's format, +1 keeps the score, Rewatching, notes / repeat / priority / private / hidden / custom lists / advanced scores read, custom list tabs, section order, AniList sorts, bulk edit; an AniList entry editor (`showAnilistEntryEditor`) with its own `SaveMediaListEntry` (all 16 fields) replacing the shared tracker editor for AniList rows; `open` calls `openAnilistMedia` | `lib/services/api/Anilist/anilist_list_service.dart`, `lib/services/api/Anilist/anilist_list_write.dart` (new), `lib/widgets/Anilist/anilist_user_list_adapter.dart`, `lib/pages/Anilist/anilist_user_page.dart`, `lib/widgets/Anilist/list/**` (new), `lib/l10n/units/anilist-list-fidelity/**`, `test/units/anilist-list-fidelity/**` | `anilist-client-limits` |
| `anilist-people-pages` | B1-B7: character, staff (voice / staff roles, on-my-list filter), studio pages with favourite toggle; birthday and top-characters loaders for the home | `lib/pages/Anilist/anilist_character_page.dart`, `lib/pages/Anilist/anilist_staff_page.dart`, `lib/pages/Anilist/anilist_studio_page.dart` (all new), `lib/services/api/Anilist/anilist_people_service.dart` (new), `lib/widgets/Anilist/people/**` (new), `lib/l10n/units/anilist-people-pages/**`, `test/units/anilist-people-pages/**` | `anilist-client-limits` |
| `anilist-search-filters` | C1-C9: `AnilistMediaQuery` gains every filter, filter sheet, 36 sorts, tabs for characters / staff / studios / users, genres and tags from the API (cached a day), tag explorer, account adult option | `lib/services/api/Anilist/anilist_discover_service.dart`, `lib/services/api/Anilist/anilist_catalog.dart` (new), `lib/widgets/Anilist/anilist_browse_screen.dart`, `lib/widgets/Anilist/anilist_chips.dart`, `lib/widgets/Anilist/search/**` (new), `lib/l10n/units/anilist-search-filters/**`, `test/units/anilist-search-filters/**` | `anilist-client-limits` |
| `anilist-social` | F0-F9: AniList HTML renderer (spoilers, embeds, in-app `anilist.co` links), forum filters, thread page with comment tree, reply / like / subscribe, activity feed page (Following / Global), activity page with replies, status composer with preview, likes sheet, review page with votes and review composer, reviews feed; the Forum tab gets Forum / Activity tabs | `lib/pages/Anilist/anilist_forum_page.dart`, `lib/widgets/Anilist/anilist_thread_tile.dart`, `lib/pages/Anilist/anilist_thread_page.dart`, `lib/pages/Anilist/anilist_activity_page.dart`, `lib/pages/Anilist/anilist_review_page.dart` (new), `lib/services/api/Anilist/anilist_social_service.dart` (new), `lib/widgets/Anilist/social/**` (new, incl. `anilist_html.dart`), `lib/l10n/units/anilist-social/**`, `test/units/anilist-social/**` | `anilist-client-limits` |
| `anilist-notifications` | G1-G3, G5: inbox with group filters, unread count service (on resume, never polled), mark read, in-app routing (titles through `openAnilistMedia`, threads and activities through `anilist-social` pages once merged; the browser before) | `lib/pages/Anilist/anilist_notifications_page.dart` (new), `lib/services/api/Anilist/anilist_notifications_service.dart` (new), `lib/widgets/Anilist/notifications/**` (new), `lib/l10n/units/anilist-notifications/**`, `test/units/anilist-notifications/**` | `anilist-client-limits`; `anilist-social` for in-app routing of replies |
| `anilist-settings` | I1-I7: AniList account settings page (`Viewer.options`, `mediaListOptions`, `UpdateUser`, `DeleteCustomList`), about editor with `Markdown` preview | `lib/pages/Anilist/anilist_settings_page.dart` (new), `lib/services/api/Anilist/anilist_settings_service.dart` (new), `lib/widgets/Anilist/settings/**` (new), `lib/l10n/units/anilist-settings/**`, `test/units/anilist-settings/**` | `anilist-client-limits` |
| `anilist-media-page` | A1-A21: native title page reusing the MAL detail layout and widgets by import only (section frame, header, stats widgets), "Open on MyAnimeList", favourite heart, my entry through `showAnilistEntryEditor`, reviews section → `AnilistReviewPage`, characters / staff / studios → people pages, recommendation votes and submit; `openAnilistMedia` now always opens this page | `lib/pages/Anilist/anilist_media_page.dart` (new), `lib/services/api/Anilist/anilist_media_detail.dart` (new), `lib/widgets/Anilist/media/**` (new), `lib/widgets/Anilist/anilist_media_card.dart`, `lib/l10n/units/anilist-media-page/**`, `test/units/anilist-media-page/**` | `anilist-list-fidelity`, `anilist-people-pages`, `anilist-social` |
| `anilist-profile-plus` | E1-E13: stats sub-tabs and charts, heatmap, Activity tab (social widgets), all favourites with reorder and native pages, followers / following / mutuals with follow, other users' lists (read-only adapter, compare), message a user, user search, badges and profile colour; "Edit profile" opens `AnilistSettingsPage` | `lib/widgets/Anilist/anilist_profile_view.dart`, `lib/services/api/Anilist/anilist_profile_service.dart`, `lib/pages/Anilist/anilist_user_profile_page.dart`, `lib/pages/Anilist/anilist_other_list_page.dart` (new), `lib/services/api/Anilist/anilist_follow_service.dart` (new), `lib/widgets/Anilist/profile/**` (new), `lib/l10n/units/anilist-profile-plus/**`, `test/units/anilist-profile-plus/**` | `anilist-social`, `anilist-people-pages`, `anilist-settings`, `anilist-list-fidelity` (reuses its row parsing for the read-only adapter) |
| `anilist-home-extras` | D1-D6, D8, D10: home rows batched in one request, recommendations from my list, following activity row, daily trends with episode, birthdays, latest reviews / recommendations, top characters, full season view on Explore; bell with unread badge in the AniList home app bar | `lib/pages/Anilist/anilist_home_page.dart`, `lib/pages/Anilist/anilist_explore_page.dart`, `lib/widgets/Anilist/anilist_home_sections.dart`, `lib/services/api/Anilist/anilist_feeds_service.dart` (new), `lib/widgets/Anilist/home/**` (new), `lib/l10n/units/anilist-home-extras/**`, `test/units/anilist-home-extras/**` | `anilist-search-filters` (query model), `anilist-social` (activity tiles), `anilist-people-pages` (birthday loaders), `anilist-notifications` (badge) |

Parallel waves: `anilist-client-limits` → (`anilist-list-fidelity` ∥ `anilist-people-pages` ∥ `anilist-search-filters` ∥ `anilist-social` ∥ `anilist-settings`) → (`anilist-notifications` ∥ `anilist-media-page` ∥ `anilist-profile-plus`) → `anilist-home-extras`.

Untouched by all: `lib/services/api/Anilist/anilist_api.dart`, `anilist_user.dart`, `anilist_user_prof.dart`, `lib/services/auth/anilist_*`, `lib/user/user_anilist_v2.dart`, `lib/widgets/Anilist/anilist_sign_in_prompt.dart`, the l10n unit `anilist-pages`.

Out of every unit (findings for their owners, not edits here):
- `lib/widgets/user/sync/tracker_clients.dart` (sync dialog): keep `scoreRaw`, but stop sending a rounded score from the AniList list (fixed on the AniList side by `anilist-list-fidelity`); optionally pass `private` / `customLists` untouched.
- `lib/services/tracker_sync_service.dart`: move the AniList search from the legacy `AnilistApi.searchMedia` to `AnilistDiscoverService.media` (then `anilist_api.dart` can go).
- Calendar (`lib/widgets/calendar/*`): AniList titles without `idMal` are missing (D7); `AnilistDiscoverService.airing` can feed them.
- Notifications (`lib/services/notifications/notification_service.dart`): optional background unread check for AniList (G4).
- `lib/screens/home_screen.dart`: no change needed (the AniList tabs keep their page classes); the Forum tab grows its Activity sub-tab inside `AnilistForumPage`.
