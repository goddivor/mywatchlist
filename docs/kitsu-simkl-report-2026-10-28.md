# Kitsu and Simkl: what more MyWatchList can get (official APIs, site JSON, HTML)

Audit date 2026-10-28, read-only. MWL read at `origin/dev` (3e2f0ae). Every network call was an anonymous GET (one GraphQL introspection and read queries sent as POST, which is how GraphQL reads work), at most about one request per second, with a desktop Chrome User-Agent. Nothing was logged in, nothing was written. Raw samples are in `scratchpad/net/` and `scratchpad/web/`.

Owner rule this report serves (DECISIONS 2026-10-28): Kitsu and Simkl accounts show only data from their own tracker; scraping the tracker's own site is welcome.

---

## 0. What MWL uses today

### Kitsu (`lib/services/api/Kitsu/**`, base `https://kitsu.io/api/edge`, JSON:API only, no GraphQL)

| Feature | Endpoint |
|---|---|
| Catalogue rows, search, browse | `GET /anime`, `/manga` (`filter[text]`, `filter[status|subtype|categories]`, sort, `include=mappings`), `GET /trending/{anime,manga}`, `GET /categories`, `GET /genres` (legacy `kitsu_api.dart`) |
| Library (My list) | `GET /users?filter[self]=true`, `GET /library-entries` (filters userId/kind/status, `include=mappings`), status counts with `page[limit]=1`, `PATCH /library-entries/{id}` |
| Profile | `GET /users/{id}` with `include=stats,waifu` (stats `kind,statsData`), `GET /favorites` (anime/manga only) |
| Auth | `POST https://kitsu.io/api/oauth/token` (password grant) |
| Detail | none: a tap opens the **MyAnimeList** detail screen through the `myanimelist/anime|manga` mapping; titles without a MAL mapping are dropped from home rows |
| Forum tab | a message plus a link to kitsu.app (`kitsu_forum_page.dart`: "Kitsu's community has no public API that fits") |

### Simkl (`lib/services/api/SimKl/**`, base `https://api.simkl.com`, header `simkl-api-key`)

| Feature | Endpoint |
|---|---|
| Explore and home rows | `GET /anime/trending`, `/anime/premieres/new`, `/anime/airing?date=&sort=time`, `/search/anime` |
| Detail | none: `GET /anime/{id}` is only used to read `ids.mal`, then the MAL detail screen opens |
| My list | `GET /sync/all-items/anime`, `POST /sync/add-to-list`, `/sync/remove-from-list`, `/sync/ratings/remove`, `/sync/history`, `/sync/history/remove`; `simkl_user.dart` also has watchlist/history getters |
| Profile | `GET /users/settings` plus stats computed locally from the whole list (the code comment says the stats endpoint "needs the account id and answers in minutes only") |
| Auth | **AUTH V1**: `https://simkl.com/oauth/authorize` + `https://api.simkl.com/oauth/token` (the class is named `SimklAuthV2`, but it uses the V1 endpoints) |
| Forum tab | "Simkl has no forum" message |

### Findings outside the feature scope (risks, to fix first)

1. **Simkl AUTH V1 is retired around April 2027** (api.simkl.org: rate-limits page and "AUTH V1 overview"). MWL's `simkl_auth_v2.dart` uses V1 `/oauth/authorize` and `/oauth/token`. V2 is `/oauth2/authorize`, `/oauth2/token` (PKCE S256 mandatory, refresh tokens, scopes `media:read media:write`). **Under V2, the endpoints MWL calls anonymously (`/anime/airing`, `/anime/premieres`, `/anime/best`) return `401 user_token_required` without a user token.** The migration has to move these calls to the token or to the `data.simkl.in` CDN (section 2.2).
2. **Simkl now documents `app-name` and `app-version` (query) and a descriptive `User-Agent` (`name/version`) as required on every request.** `simkl_client.dart` sends none of them (only `Content-Type`, `simkl-api-key`, and `client_id` on public calls). They are not enforced today, but this is a cheap compliance fix.
3. **Simkl Apiary docs are frozen (2026-05-22) and will disappear when Oracle shuts Apiary down (October 2026).** The new reference is `https://api.simkl.org` with a full OpenAPI 3.1 spec (`https://api.simkl.org/openapi.json`, 48 endpoints) and `llms.txt`. Any MWL doc that points to `simkl.docs.apiary.io` should point there instead.
4. Simkl AUTH V1 quota is **per `client_id`** (one daily allowance shared by every MWL user); V2 is per user (Free 500/day, PRO 1,000, VIP 10,000). Per-second limits for both: 10 GET/s, 1 POST/s. Cloudflare-cached endpoints (`/anime/{id}`, `/anime/episodes/{id}`, `data.simkl.in`) are not counted.
5. Kitsu: `kitsu.io/api/edge` still answers and `kitsu.app/api/edge` answers too (the website uses `kitsu.app`; both are behind Cloudflare and the same backend). Not urgent, but `kitsu.app` is the current domain.

---

## 1. Kitsu

### 1.1 Platform facts

- **robots.txt** (kitsu.app and kitsu.io, unchanged since 2018): `User-agent: * / Disallow: /api/` and a sitemap. That is a crawler rule: the API is the documented public API for third-party apps (hummingbird-me api-docs) and MWL already depends on it. No rule on the HTML pages, but they carry no data (below).
- **Website = Ember SPA.** `https://kitsu.app/anime/sousou-no-frieren` returns a 14 KB HTML shell (no server-rendered data, no JSON-LD, only `og:site_name`). Everything comes from the same public APIs: the bundle config (`client/config/environment` meta) shows `kitsu.APIHost: ""` (so `https://kitsu.app/api/edge`, JSON:API through ember-data), `apollo.apiURL: "/api/graphql"` (GraphQL), and Algolia search (`algolia.appId AWQO5J657S`, keys from `GET /api/edge/algolia-keys`). **There is no HTML to scrape; "scraping the site" means calling the same JSON:API, feed and GraphQL endpoints the site calls.**
- **Cloudflare** in front (`server: cloudflare`, `cf-ray`), with no challenge on API calls from curl.
- **Rate limits**: no `X-RateLimit-*` or `Retry-After` header seen, none documented. Responses are `cache-control: private, max-age=0`. Assume fair use: 20 items per JSON:API page, keep GraphQL queries small (connections require `first`/`last`, see the error below).
- **GraphQL** `POST https://kitsu.io/api/graphql` (also `kitsu.app/api/graphql`): introspection is open; the anonymous read queries below all worked. Connections must have `first` or `last` (`"Connection 'likes' requires the argument 'first' or 'last' to be supplied."`).
- **Data freshness**: characters and staff exist for older titles (Cowboy Bebop: 125 characters, 62 staff, 74 quotes) but are **empty for recent ones** (Frieren: 0 characters, 0 staff). Kitsu reviews are legacy: 13,006 reviews in total, the newest created in 2019; reactions (short reviews, 140 characters) replaced them. Episodes, streaming links, relations, reactions, posts, library events and stats are live.

### 1.2 Candidate features

Legend. Auth: **none** = anonymous; **token** = Kitsu OAuth access token MWL already holds.

#### K-A. Title page data that MWL throws away (MWL opens the MAL detail screen instead)

| # | Feature | Source and request | Auth | Sample (trimmed) | Risk | MWL screen |
|---|---|---|---|---|---|---|
| A1 | **Rating distribution** (20-step histogram) | JSON:API `GET /anime/46474?fields[anime]=ratingFrequencies` | none | `"ratingFrequencies":{"2":"201","8":"278","14":"767","16":"705","18":"1573","19":"457","20":"5461"}` (keys = rating out of 20) | low (stable attribute) | new Kitsu title page; score chart |
| A2 | **Average rating, rank, users, favourites, popularity rank** | already in the fields MWL requests except `favoritesCount`; GraphQL `averageRating averageRatingRank userCount userCountRank favoritesCount` | none | `"averageRating":88.85,"averageRatingRank":2,"userCount":21409,"favoritesCount":731` | low | title page header |
| A3 | **Where to watch** (legal streaming links with sub/dub languages and regions) | GraphQL `streamingLinks(first:10){nodes{url subs dubs regions streamer{siteName}}}`; JSON:API `GET /anime/{id}/streaming-links?include=streamer` | none | `{"url":"https://www.crunchyroll.com/series/GG5H5XQX4/...","subs":["en"],"dubs":["ja"],"regions":["US"],"streamer":{"siteName":"Crunchyroll"}}` | low | title page "Where to watch" |
| A4 | **Episode list with titles, air dates, length, thumbnails, synopsis** | GraphQL `episodes(first:50){totalCount nodes{number titles{canonical} releasedAt length thumbnail{original{url}} description}}`; JSON:API `GET /anime/{id}/episodes?sort=number&page[limit]=20` | none | `{"number":1,"titles":{"canonical":"The Journey's End"},"releasedAt":"2023-09-29T00:00:00+00:00","length":1440,"thumbnail":{"original":{"url":"https://media.kitsu.app/episode/353471/thumbnail/...png"}}}`, `totalCount: 28` | low | title page episodes; list "+1" sheet could show the next episode title |
| A5 | Manga chapters / volumes | GraphQL `Manga.chapters`, `volumes` (type `Unit` = Chapter/Episode/Volume) | none | same shape as episodes | low; sparse data | manga title page |
| A6 | **Relations** (sequel, prequel, side story, adaptation…) | GraphQL `relationships(first:20){nodes{kind destination{__typename slug titles{canonical} posterImage{...}}}}`; JSON:API `/media-relationships?filter[source_id]=&filter[source_type]=Anime&include=destination` (what the site calls) | none | `{"kind":"SEQUEL","destination":{"__typename":"Anime","slug":"sousou-no-frieren-season-2"}}`, `{"kind":"ADAPTATION","destination":{"__typename":"Manga",...}}` | low | title page "Related" |
| A7 | **Reactions** (Kitsu's short reviews, with likes and the episode the author was at) | GraphQL `reactions(first:6, sort:[{on:UP_VOTES_COUNT,direction:DESCENDING}]){totalCount nodes{reaction progress createdAt author{name slug avatarImage{original{url}}} likes(first:1){totalCount}}}`; JSON:API `GET /media-reactions?filter[animeId]=46474&sort=-upVotesCount&include=user` (exactly what the site calls) | none to read | `"totalCount":219`, `{"reaction":"An elf deals with the fragile concept of mortality.\nSafe to say a must watch!","progress":2,"author":{"name":"Tamaya"},"likes":{"totalCount":97}}` | low | title page "Reactions" (Kitsu's equivalent of MAL reviews) |
| A8 | **Discussion posts about the title** (with spoiler/NSFW flags, likes, comments) | GraphQL `posts(first:10, sort:[{on:CREATED_AT,direction:DESCENDING}]){totalCount nodes{content contentFormatted isSpoiler isNsfw createdAt author{name} likes(first:1){totalCount} comments(first:1){totalCount}}}`; JSON:API feed `GET /feeds/media_aggr/Anime-46474?include=subject&filter[kind]=posts` (the site's call; note `media_aggregated` answers 403, the name is `media_aggr`) | none to read | `"totalCount":967`, `{"content":"rewatching (again) the best media to ever media...","isSpoiler":false,"likes":{"totalCount":5}}` | low/medium (feeds are Stream-backed, ids are UUIDs) | title page "Discussion"; this is the Kitsu replacement for the MAL forum topics of a title |
| A9 | Characters with voice actors, staff, studios/producers | GraphQL `characters(first:10, sort:[{on:ROLE,direction:ASCENDING}]){nodes{role character{names{canonical} image{original{url}}} voices(first:1, locale:"ja_jp"){nodes{person{name}}}}}`, `staff(first:10){nodes{role person{name}}}`, `productions(first:10){nodes{role company{name}}}`; JSON:API `/castings?filter[media_id]=&filter[media_type]=Anime&filter[is_character]=true&include=character,person` | none | Frieren: `productions` → `TOHO animation`, `Shogakukan`; characters empty (stale for recent titles) | medium (data gaps) | title page "Characters / Staff" with a hidden section when empty |
| A10 | Trailer, banner/cover image, next release, total length, origin language/country, age rating guide | GraphQL `youtubeTrailerVideoId bannerImage{original{url}} nextRelease totalLength originLanguages ageRatingGuide`; JSON:API `youtubeVideoId coverImage nextRelease` | none | `"youtubeTrailerVideoId":"qgQunxD0qCk"`, `coverImage.original` URL | low | title page header and trailer button |
| A11 | Categories of a title (Kitsu tags: "elf", "fantasy"…) | GraphQL `categories(first:20){nodes{slug title}}` | none | `slug: fantasy, elf, adventure` | low | title page chips → `KitsuBrowseScreen` by category |
| A12 | Quotes | GraphQL `quotes(first:5){nodes{lines(first:5){nodes{content character{names{canonical}}}}}}` | none | Bebop 74 quotes, Frieren 0 | medium (stale) | title page, optional |
| A13 | **All external ids of a title** and reverse lookup | GraphQL `mappings(first:20){nodes{externalSite externalId}}` (MAL, AniList, AniDB, TVDB, ANN, MangaUpdates, Trakt…); `lookupMapping(externalId:"52991", externalSite:MYANIMELIST_ANIME){... on Anime{id slug}}` | none | `MYANIMELIST_ANIME 52991`, `ANILIST_ANIME 154587` | low | lets the Kitsu page exist **without** a MAL mapping (titles currently dropped from home rows) and lets the sync dialog resolve a link in one call |

Single-call recipe for a native Kitsu title page (tested, about 5 KB): `findAnimeBySlug(slug)` or `findAnimeById(id)` with A2, A3, A4 (first 12), A6, A7 (first 6), A8 (first 3), A10, A13. Sample: `scratchpad/net/anime.json`.

#### K-B. Community (the Forum tab, today a dead end)

| # | Feature | Source and request | Auth | Sample | Risk | MWL screen |
|---|---|---|---|---|---|---|
| B1 | **Global feed** (latest posts, reactions, comments of the site) | `GET /feeds/global/global?page[limit]=20&include=activities.subject,activities.subject.user` | none | `activityGroups` → `activities` (`verb: post|comment|media_reaction`, `foreignId: "Post:9920750"`) → `posts` | medium (aggregated feed format; paginate with the `meta.feed` cursor / `page[cursor]`) | Kitsu Forum tab "Latest" |
| B2 | **Kitsu news** via the official group *Kitsu News Network* (id 596, 6,346 members, active 2026-10-27) | `GET /feeds/group/596?include=subject,subject.user&page[limit]=20` (site feed type `group_aggr`) | none | `{"verb":"post","foreignId":"Post:9920640","time":"2026-10-27T03:25:57Z"}` | medium (depends on a community group staying active) | Kitsu home "News" section (today skipped as "no Kitsu source"), Forum tab |
| B3 | **Groups directory and group feeds** | `GET /groups?sort=-membersCount&fields[groups]=name,slug,membersCount,tagline,lastActivityAt,nsfw` (3,422 groups); `GET /group-categories`; feed `GET /feeds/group/{id}` | none | `{"name":"Kitsu News Network","membersCount":6346,"tagline":"For all the latest anime industry news.","lastActivityAt":"2026-10-27T17:06:43Z"}` | low/medium (most groups are dormant: sort by `lastActivityAt`) | Forum tab "Groups" (closest to MAL clubs/boards) |
| B4 | **Post with its comment thread** | GraphQL `findPostById(id){content contentFormatted isSpoiler author{name avatarImage{original{url}}} media{titles{canonical}} comments(first:20, sort:[...]){nodes{content author{name} likes(first:1){totalCount} replies(first:5){nodes{content author{name}}}}}}`; JSON:API `GET /posts/{id}?include=user,media`, `GET /comments?filter[postId]=&include=user` | none | see A8 | low | post detail page opened from feeds |
| B5 | Episode discussion | posts carry `spoiledUnit` and the site shows per-episode feeds (`unitNumber`); query via `feeds/media_aggr` filtered client-side or GraphQL posts | none | — | medium | episode row → "Discussion" |
| B6 | User timeline (people the user follows) | `GET /feeds/timeline/{userId}` | token | — | medium | Forum tab "Following" for the signed-in user |
| B7 | Notifications | `GET /feeds/notifications/{userId}` | token | — | medium | optional; the app has its own notifications |
| B8 | Trending inside the user's network | GraphQL `localTrending(mediaType:ANIME, first:20)` | token | — | low | Kitsu home row "Popular with people you follow" |

Write actions (like, post, comment, react, follow) exist on the same APIs with the token, but this audit never tried them; they are a later decision.

#### K-C. Profile (MWL shows Stats, About, Favorites anime/manga)

| # | Feature | Source and request | Auth | Sample | Risk | MWL screen |
|---|---|---|---|---|---|---|
| C1 | **Activity history** (progress, status changes, ratings, reactions, with old → new values) | GraphQL `findProfileBySlug(slug){libraryEvents(first:20, sort:[{on:CREATED_AT,direction:DESCENDING}]){totalCount nodes{kind changedData createdAt media{__typename titles{canonical} posterImage{...}}}}}`; JSON:API `GET /library-events?filter[userId]=286143&sort=-createdAt&include=anime,manga` | none for public users | `{"kind":"UPDATED","changedData":{"status":["current","planned"]},"media":{"titles":{"canonical":"Skip to Loafer"}}}`, `totalCount: 1979` | low | profile "Activity" tab; home "Recently updated" |
| C2 | **The user's reactions** | GraphQL `mediaReactions(first:20){nodes{reaction progress media{...}}}`; JSON:API `/media-reactions?filter[userId]=` | none | `{"reaction":"Surprisingly good","progress":27,"media":{"titles":{"canonical":"Shoujo Fujuubun"}}}` | low | profile "Reactions" tab |
| C3 | **The user's posts / feed** | GraphQL `posts(first:20)`, `pinnedPost`; JSON:API `GET /feeds/user_aggr/{userId}` | none | `posts.totalCount: 147` | low | profile "Posts" tab |
| C4 | **Followers / following lists** | GraphQL `followers(first:20){totalCount nodes{name slug avatarImage{...}}}`, `following(...)`; JSON:API `/follows?filter[follower]=&include=followed` | none | `followers 94, following 53` | low | profile counts become tappable lists; opens `KitsuProfileView(userId)` |
| C5 | **Full anime/manga time and category breakdown** | GraphQL `stats{animeAmountConsumed{completed media time units} animeCategoryBreakdown{total categories} mangaAmountConsumed{...}}` (categories = map category id → count; resolve names with `/categories`) | none | `"animeAmountConsumed":{"completed":510,"media":836,"time":7710351,"units":6548}` (time in seconds) | low | profile Stats (MWL already reads `statsData`; GraphQL gives the same in one typed call) |
| C6 | Favourite **characters and people** (MWL shows anime and manga only) | `GET /favorites?filter[userId]=&filter[itemType]=Character` (and `Person`); GraphQL `favorites(first:50){nodes{item{__typename ... on Character{names{canonical} image{...}}}}}` | none | Tamaya: 19 favourites, first three are characters | low | profile Favorites tab, new "Characters" and "People" chips |
| C7 | Social links, pro tier, extra counters | GraphQL `siteLinks(first:10){nodes{url site{name}}}`, `proTier`; JSON:API users fields `commentsCount postsCount mediaReactionsCount likesReceivedCount` | none | `{"url":"Tamaya#6274","site":{"name":"Discord"}}`, `commentsCount 316` | low | profile About |
| C8 | User search (to open any Kitsu profile) | GraphQL `searchProfileByUsername(username:"tam", first:10)` | none | — | low | Kitsu search screen "Users" tab |
| C9 | Another user's library | GraphQL `findProfileBySlug{library{current(first:20, mediaType:ANIME){nodes{progress rating status media{...}}}}}` (also `completed`, `planned`…, `randomMedia`) | none (public libraries) | `library.current.totalCount: 2` | low | profile of another user → "List" tab |
| C10 | Account preferences: title language, rating system (simple/regular/advanced), SFW filter, time zone | GraphQL `currentAccount{titleLanguagePreference ratingSystem sfwFilterPreference timeZone}` | token | — | low | default the Kitsu title language and score display to the user's Kitsu setting |

#### K-D. Catalogue extras

| # | Feature | Source | Auth | Note |
|---|---|---|---|---|
| D1 | Trending in a category | `GET /trending/anime?limit=20&in_category=true&category={id}` (what the site calls) | none | Explore category page header row |
| D2 | Random pick | GraphQL `randomMedia(mediaType:ANIME, ageRatings:[G,PG,R])` (tested: `tsubasa-chronicle`); user library `library{randomMedia(mediaType:ANIME, status:PLANNED)}` | none / public | "Surprise me" button; "pick from my plan to watch" |
| D3 | Algolia search (faster, typo-tolerant; indexes media, users, groups, characters) | `GET /api/edge/algolia-keys` returns scoped search keys per index (`production_media`, `production_users`, `production_groups`, `production_characters`); GraphQL `searchMediaByTitle` already uses Algolia server-side | none | prefer GraphQL `searchMediaByTitle` / `searchProfileByUsername` (no third-party key handling) |
| D4 | Franchises | GraphQL `franchises` | none | low value |

### 1.3 Kitsu top 10 by user value

1. **Native Kitsu title page** (A1 to A4, A6, A10, A13): stops depending on MAL for Kitsu accounts and keeps titles that have no MAL mapping.
2. **Reactions on the title page** (A7): the community voice of Kitsu, sorted by likes.
3. **Where to watch** (A3): legal streaming links with sub/dub languages.
4. **Forum tab = Kitsu community** (B1, B3, B4): latest posts, groups, post threads.
5. **Title discussion** (A8, B4): posts about the title with spoiler flags.
6. **Profile Activity tab** (C1): what the user did, when, with old and new values.
7. **Kitsu News on the home** (B2): fills the "News" section that is skipped today.
8. **Episode list with thumbnails and air dates** (A4): also feeds the next-episode title in the list.
9. **Followers / following and other users' profiles** (C4, C8, C9).
10. **Profile Reactions, Posts and favourite characters/people** (C2, C3, C6).

---

## 2. Simkl

### 2.1 Platform facts

- **robots.txt** (`https://simkl.com/robots.txt`, last modified 2026-02-25): for `*`, disallows `/cdn-cgi/`, `/search/`, `/register/`, `/oauth/authorize`, `/settings`, favourite-list pages, `/*/list/*/*?`, `/*/tags/*/`, **`/*/history/`, `/*/calendar/`, `/*/recommendations/`** (user-scoped pages), `/*/*/?tags=`, `/*/lists/?list_tags=`, `/list/new/`, `/apps/download/`, `/app/news/`, `/*/*/t/`, `/*/*/*/news/`, NSFW/18+ lists. Fully blocks SemrushBot-BA, AhrefsBot, Awario, SeekportBot, **GPTBot**, Baiduspider. **Title pages, their `reviews/`, `comments/`, `memos/` sub-pages and episode pages are allowed.** `api.simkl.com/robots.txt` answers `412 client_id_failed` (the API host wants a client id on every path).
- **Website = server-rendered PHP + jQuery** (no SPA, no JSON in the page, only an Organization JSON-LD). Partial reloads use `pageLoader` (HTML fragments) and `POST /ajax/full/detail.php` (`action=loadEpsTitles`, `youtube`, `addComment`…) / `/ajax/full/my_list.php` (writes). **No anonymous JSON endpoint behind the site except `data.simkl.in`.**
- **Cloudflare**: title, reviews, comments, memos and episode pages answered `200` to curl (with Cloudflare's passive `challenge-platform` script). **User profile pages (`https://simkl.com/{userId}/`, `/{userId}/stats/`) answered `403 cf-mitigated: challenge` ("Just a moment...")**, twice, while title pages kept answering 200: profiles are behind a managed challenge and cannot be fetched with a plain HTTP client. A WebView could pass it, but the API covers the same data (2.2, `/users/{id}/stats`).
- Pages are heavy (430 to 870 KB of HTML per title page), so scraping must stay on explicit user action and be cached.
- **Official API**: `https://api.simkl.com`, docs moved to `https://api.simkl.org` (OpenAPI 3.1 at `/openapi.json`). Every call needs `client_id` (query) or `simkl-api-key` (header), plus `app-name`, `app-version` and `User-Agent` per the new docs. I did not call `api.simkl.com` beyond robots.txt: there is no anonymous key, and I did not reuse MWL's client id (it lives in `assets/.env`). API samples below come from the OpenAPI examples ("every response shape verified against the live API", per the docs).
- **Public CDN `https://data.simkl.in`**: no auth, no quota, Cloudflare-cached. Tested live.

### 2.2 Candidate features

Legend. Auth: **none** = anonymous; **cid** = `client_id` only (AUTH V1; under V2 the same calls need the user token); **token** = user access token.

#### S-A. Free CDN data (`data.simkl.in`)

| # | Feature | Request | Auth | Sample (live, trimmed) | Limits / risk | MWL screen |
|---|---|---|---|---|---|---|
| A1 | **Anime calendar, rolling 33 days, with full metadata** (ids incl. MAL/AniList/Kitsu, rating, votes, rank, drop rate, watcher counts, network, genres, trailer, runtime) | `GET https://data.simkl.in/calendar/v2/anime.json`; monthly archive `/calendar/v2/{year}/{month}/anime.json` | none | 263 KB, 590 episodes: `{"simkl_id":3198578,"date":"2026-10-26T15:00:00Z","finale_type":null,"episode":{"episode":15,"title":"Episode 15","runtime":25,"url":"https://simkl.com/anime/3198578/yi-zhan-cangqiong/episode-15/"}}` + `metadata["3198578"]={"title":"GuAn","ids":{"mal":"62789","anilist":"206273",...},"rank":5831,"drop_rate":"7.1%","watching":90,"plan_to_watch":20,"ratings":{"simkl":{"rating":8.88,"votes":8},"mal":{"rating":7.2,"votes":166}},"anime_type":"ona","network":"Youku"}` | `cache-control: max-age=18000` (5 h); not counted against the quota | Simkl home "Airing today", a **Simkl calendar** (the app's calendar is MAL-fed today), airing notifications without per-title calls |
| A2 | **Trending anime** today / week / month, with watcher counts and ratings | `GET https://data.simkl.in/discover/trending/anime/{today|week|month}_{100|500}.json` (tested `today_500`, `week_100`); combined `/discover/trending/{file}.json` | none | `{"title":"Cyberpunk: Edgerunners 2","ids":{"simkl_id":2830474,"mal":"61990","kitsu":"50016",...},"rank":382,"drop_rate":"0.7%","watched":2522,"plan_to_watch":2302,"watching":1899,"completed":1433,"ratings":{"simkl":{"rating":7.9,"votes":288},"mal":{"rating":8.2,"votes":51527}},"status":"premiere","anime_type":"ona","total_episodes":10,"overview":"..."}` | `max-age=3600`; 160 KB (week_100) to 890 KB (today_500) | Explore and home "Trending" (replaces `/anime/trending`, survives the V2 migration, no quota) |

#### S-B. Official API endpoints MWL does not use

| # | Feature | Request | Auth | Sample (OpenAPI example, trimmed) | Limits / risk | MWL screen |
|---|---|---|---|---|---|---|
| B1 | **Full title record**: Simkl + MAL ratings with votes, rank, drop rate, trailers, **users' recommendations (with % and count)**, relations, studios, network, air day/time/time zone, alt titles, certification, all external ids | `GET /anime/{simkl_id}?client_id=…` (MWL already calls it, only to read `ids.mal`) | cid | `"rank":14,"droprate":"0.8%","ratings":{"simkl":{"rating":8.7,"votes":1850},"mal":{"rating":8.6,"votes":1620000}},"airs":{"day":"Sunday","time":"23:15","timezone":"Asia/Tokyo"},"trailers":[{"youtube":"VQGCKyvzIM4"}],"users_recommendations":[{"title":"Jujutsu Kaisen","users_percent":"24%","users_count":75,"ids":{"simkl":…}}]` | Cloudflare-cached, parallel allowed, not counted | **native Simkl title page** |
| B2 | **Episode list** with titles, descriptions, images, air dates, specials | `GET /anime/episodes/{simkl_id}` | cid | `{"title":"To You, in 2000 Years","episode":1,"type":"episode","aired":true,"img":"https://wsrv.nl/?url=https://simkl.in/episodes/...","date":"2013-04-07T00:00:00+09:00","tvdb":{"season":1,"episode":1}}` | cached, not counted | title page episodes; "mark episode watched" through `/sync/history` (already used) |
| B3 | **Best anime** (all, year, month, most voted, most watched), by format | `GET /anime/best/{all|year|month|voted|watched}?type=tv` | cid (V2: token) | `{"title":"Sousou no Frieren","ratings":{"simkl":{"rating":9.2,"votes":4636},"mal":{"rating":9.3,"votes":886825}}}` | counted | Explore "Top rated" rows (MAL-like ranking, Simkl-sourced) |
| B4 | **Browse by genre / type / network / year / sort** | `GET /anime/genres/{genre}/{type}/{network}/{year}/{sort}` (e.g. `/anime/genres/fantasy/tv/all-networks/2023/rank`) | cid (V2: token) | `{"title":"Shingeki no Kyojin","anime_type":"tv","rank":120,"ratings":{...}}` | counted | Explore browse grid with filters (the Kitsu tab has one, Simkl has none) |
| B5 | Premieres upcoming (MWL uses `new` only) | `GET /anime/premieres/soon` | cid (V2: token) | — | counted | Explore "Coming soon" |
| B6 | **User watch statistics**: total minutes, per status counts, episodes watched / left, minutes left, **watched last week**, for anime, TV and movies | `GET /users/{user_id}/stats` (user id from `/users/settings`) | cid (+ token for private) | `{"total_mins":908554,"anime":{"total_mins":494025,"watching":{"watched_episodes_count":1747,"count":21,"left_to_watch_episodes":410,"left_to_watch_mins":10250},"completed":{"watched_episodes_count":17255,"count":1291}},"watched_last_week":{"total_mins":130,"anime_mins":0}}` | **"the most expensive call": only on explicit user action** (open profile / pull to refresh), never on launch | Simkl profile: "Time spent", "Left to watch", "Last week" (today computed locally without time) |
| B7 | Community ratings for every title in the user's list | `GET /ratings/anime?user_watchlist=watching,plantowatch&fields=simkl` | token | `[{"id":…,"simkl":{"rating":8.4,"votes":120,"droprate":"1.2%"}}]` | one call for the whole list | My list: community score badge, "sort by Simkl score" |
| B8 | **Incremental sync** | `GET /sync/activities` then `GET /sync/all-items/anime/{status}?date_from=…` | token | per-list timestamps | "the cheapest call"; avoids re-downloading the whole list (MWL does today) | My list refresh, home "Continue watching" |
| B9 | User ratings by score | `GET /sync/ratings/anime/{9,10}` | token | — | counted | profile "Top rated by me" |
| B10 | Paused playback sessions (from media-server scrobblers) | `GET /sync/playback/anime` | token | — | counted | home "Continue watching" with resume position |
| B11 | "Now watching" card / profile background | `GET /users/recently-watched-background/{user_id}` (JSON or `?image=fanart` 302) | cid (V2: token) | `{"id":…,"url":…,"title":…,"poster":…,"fanart":…}` | counted | Simkl profile header cover |
| B12 | Resolve any external id | `GET /search/id?mal=52991` / `?kitsu=` / `?anilist=`; `GET /redirect?to=simkl&mal=…` | cid | — | counted | sync dialog link resolution (already by `mal:`), opening Simkl from a MAL title |
| B13 | Custom lists | `GET /lists/user/{userId}`, `GET /lists/{id}` | token, **PRO/VIP only** (free accounts get `200 premium_only`) | — | beta | profile "Lists" (only when the user is PRO/VIP) |
| B14 | Random pick | `POST /search/random` (genre, rating range, year range) | cid | — | POST = 1/s | "Surprise me" |
| B15 | Rewatches | `POST /sync/history?allow_rewatch=yes` (PRO/VIP) | token | — | write | later |

#### S-C. Website scraping (HTML, anonymous, allowed by robots.txt)

Title page `https://simkl.com/anime/{simkl_id}/{slug}` (tested on Frieren 1990194 and Mashle 2475640; the trailing-slash form redirects).

| # | Data | Selectors (from the live HTML) | Sample | Also in API? | Risk |
|---|---|---|---|---|---|
| C1 | **Watcher distribution by status** | `.simkltvdetailssummarystatsitem` → `.simkltvdetailssummarystatsitemtitle` (Watching / Plan to Watch / Completed / On Hold / Dropped) + `.simkltvdetailssummarystatsitemusers` (count, then `.simkltvdetailssummarystatsitemuserstext` "(16.6%)") | Frieren: Watching 5,727 (16.6%), Plan to Watch 6,500 (18.9%), Completed 21,255 (61.7%), On Hold 487 (1.4%), Dropped 463 (1.3%), Total 34,432 | partly: `watching`, `plan_to_watch`, `completed`, `watched` in A1/A2 CDN files (no hold/dropped) | medium (class names are long-lived but undocumented) |
| C2 | Simkl rating, votes, MAL rating, rank, drop rate | `td.simkl-rating .SimklTVRatingAverage` (`itemprop=ratingValue`), `.SimklTVRatingTotal[content]` (votes), `td.mal-rating …`, `.SimklTVRatingRankedStat` ("# 1", then "1.7%") | 9.2/10, 6529 votes; MAL 9.2, 948,572 votes; ranked #1; drop rate 1.7% | **yes, B1** (use the API) | — |
| C3 | **Reviews** (structured: overall + Story / Animation / Sound / Character / Enjoyment, positive/neutral/negative, helpful votes) | list on the title page and on `/anime/{id}/{slug}/reviews/`: `.SimklTVDetailReviewItem` (+ class `Positive|Neutral|Negative`), `.SimklTVDetailReviewItemAboutDate` (date and author link `/{userId}/`), `.SimklTVDetailReviewItemTitle a` (`/anime/1990194/sousou-no-frieren/review/181260`), `.SimklTVDetailReviewItemRatingNumber`, `.SimklTVDetailReviewItemStoryRating span` (5 sub-scores), `.SimklTVDetailReviewItemText` (excerpt, full text on the review URL); summary "100% positive reviews 6 Positive 0 Neutral 0 Negative" | "March 13, 2024 - by CapnBlaze", title "One of the best anime there are.", overall 9, Story 10, Animation 8, Sound 8, Character 8, Enjoyment 10 | **no** | medium |
| C4 | **Comments** (threaded, likes, spoiler flag) | `/anime/{id}/{slug}/comments/`: `.SimklTVCommentsItem` → `td.SimklTVCommentsItemTd[id=comment17264]`, `.SimklTVCommentsItemName`, `.SimklTVCommentsItemDate[title]` (exact time "23:49 July 1, 2024"), `.SimklTVCommentsItemHeart` (likes), `.SimklTVCommentsItemCommentTXT` (text), spoiler wrapper `.spoilerMark` | "RecycledDoom", 1 like, 2 years ago | **no** | medium |
| C5 | **Memos** (one-line public notes from members, with stars bucket) | `/anime/{id}/{slug}/memos/`: `.detailmemostabcontentcolumnitem` → `.detailmemostabcontentcolumnitemleftnumber` (likes), `.detailmemostabcontentcolumnitemrightnametext` (user), `.dmemoetailmemostabcontentcolumnitemright` (memo text); grouped by "memos with 6-10 stars ratings" | 236 memos: "Rivka: Watched 2023-24" | **no** | medium |
| C6 | Member ratings with memo (sidebar) | `.SimklTVRightBlockFriendsRatingsItem` → `…ItemName`, `…ItemVote`, `…ItemMemo` | "Twokeiki 10: themes: passage of time…" | no | medium |
| C7 | Counters: reactions, reviews, comments, memos, lists | `.SimklTVCommentsHeaderMenu` (`#CommentTabReviews`, `#CommentTabComments`, `#CommentTabMemos`) text | "245 Reactions, 6 Reviews, 3 Comments, 236 Memos" | no | low |
| C8 | Recommendations with % of users | `.tvdetailrelationsitem` → `.tvdetailrelationsitemrighttype` ("20%"), `.tvdetailrelationsitemrighttitle`, `href=/anime/{id}/{slug}` | Violet Evergarden 20%, To Your Eternity 13% | **yes, B1 `users_recommendations`** | — |
| C9 | Tags (AniDB-style, 80+ per title), licensors, "Links" to 15+ sites (Crunchyroll, LiveChart, JustWatch…) | text block "Tags:", "Licensors:", "Links:" in the About table | "magic circles, spellcasting… 61 more"; Licensors: Crunchyroll | tags: not in the API example | medium |
| C10 | Where to watch per episode | episode page `/anime/{id}/{slug}/episode-{n}/` ("info and links where to watch") | title "Sousou no Frieren Episode 1 info and links where to watch" | no | medium |
| C11 | Site-wide "Best anime top 250" and "Best of last aired" sidebars | sidebar text | "1. Frieren 9.2, 2. Re:Zero 9.1…" | yes, B3 | — |
| C12 | User profile, stats, history, calendar, recommendations | `/{userId}/…` | — | **blocked: Cloudflare managed challenge (403) and robots.txt disallows `/*/history/`, `/*/calendar/`, `/*/recommendations/`** | use B6, B8, B9, B11 |

Parsing note: these are classic `table` layouts with very long class names. Use `package:html` (already used by the MAL scraper in `lib/services/api/MAL/scrapper/`), parse off the UI isolate (pages are 0.4 to 0.9 MB), cache per title, and fail soft (hide the section) when a selector stops matching.

### 2.3 Simkl top 10 by user value

1. **Native Simkl title page** from `GET /anime/{id}` (B1) + episodes (B2): Simkl and MAL ratings, rank, drop rate, trailers, air time, users' recommendations, relations; cached and free of quota.
2. **Trending and calendar from `data.simkl.in`** (A1, A2): no quota, survives the V2 migration, carries watcher counts and all ids.
3. **Simkl calendar / airing schedule** (A1) for the Simkl account, with finale markers (`finale_type`).
4. **Reviews with sub-scores** (C3) on the title page.
5. **Watcher distribution** (C1) and counters (C7) on the title page.
6. **Profile watch time, left to watch, last week** (B6), on explicit open only.
7. **Best anime and genre browse** (B3, B4) in Explore.
8. **Incremental list sync** (B8) and community score badges in My list (B7).
9. **Comments and memos** (C4, C5) on the title page.
10. **Continue watching with playback position** (B10) and the "now watching" profile cover (B11).

---

## 3. Proposed units (disjoint MWL file sets)

Shared prerequisite for every native title page: today a tap on a Kitsu or Simkl title opens `lib/screens/MAL/detail/` (owned by other units). The native pages below are new pages pushed instead; the "open on MyAnimeList" button stays available when a MAL id exists. Wiring the tap is done inside each unit's own `*_open.dart` / media widget file, so no MAL file changes.

### Kitsu

| Unit | Delivers | Owns (create or edit only these) | Needs done first |
|---|---|---|---|
| `kitsu-graphql` (small, fast) | Read-only GraphQL client (`POST /api/graphql`, anonymous or with the token through `sendAuthenticated`), error mapping to `KitsuHttpError` / `KitsuSessionExpired`, `page`/`first` helpers, fixtures | `lib/services/api/Kitsu/kitsu_graphql.dart`, `test/units/kitsu-graphql/**` | none |
| `kitsu-media-page` | Native Kitsu title page: header (cover, banner, rating, rank, users, favourites), rating histogram (A1), where to watch (A3), episodes (A4) or chapters (A5), related (A6), top reactions (A7), latest posts preview (A8), characters/staff/studios when present (A9), trailer (A10), category chips (A11), external ids; titles without MAL mapping become openable | `lib/pages/Kitsu/kitsu_media_page.dart`, `lib/services/api/Kitsu/kitsu_media_detail.dart`, `lib/widgets/Kitsu/media/**`, `lib/widgets/Kitsu/kitsu_open.dart`, `lib/widgets/Kitsu/kitsu_media_tile.dart`, `lib/l10n/units/kitsu-media-page/**`, `test/units/kitsu-media-page/**` | `kitsu-graphql` |
| `kitsu-community` | Forum tab: Latest (global feed B1), News (group 596, B2), Groups (B3) with group feed, post page with comment thread (B4), media discussion page reused by the title page link | `lib/pages/Kitsu/kitsu_forum_page.dart`, `lib/pages/Kitsu/kitsu_post_page.dart`, `lib/pages/Kitsu/kitsu_group_page.dart`, `lib/services/api/Kitsu/kitsu_feed.dart`, `lib/widgets/Kitsu/feed/**`, `lib/l10n/units/kitsu-community/**`, `test/units/kitsu-community/**` | `kitsu-graphql` |
| `kitsu-profile-plus` | Profile tabs Activity (C1), Reactions (C2), Posts (C3), followers/following lists (C4), favourite characters/people (C6), social links and counters (C7), other users' list (C9), user search (C8) | `lib/widgets/Kitsu/kitsu_profile_view.dart`, `lib/widgets/Kitsu/profile/**`, `lib/services/api/Kitsu/kitsu_profile.dart`, `lib/services/api/Kitsu/kitsu_social.dart`, `lib/pages/Kitsu/kitsu_user_profile_page.dart`, `lib/l10n/units/kitsu-profile-plus/**`, `test/units/kitsu-profile-plus/**` | `kitsu-graphql` |
| `kitsu-home-extras` | Home "News" row from group 596 (reads `kitsu_feed.dart`), "Popular with people you follow" (B8, token), random pick (D2), trending in a category (D1), account title-language / rating-system defaults (C10) | `lib/pages/Kitsu/kitsu_home_page.dart`, `lib/pages/Kitsu/kitsu_explore_page.dart`, `lib/pages/Kitsu/kitsu_browse_screen.dart`, `lib/widgets/Kitsu/kitsu_rows.dart`, `lib/widgets/Kitsu/kitsu_media_row.dart`, `lib/services/api/Kitsu/kitsu_catalog.dart`, `lib/l10n/units/kitsu-home-extras/**`, `test/units/kitsu-home-extras/**` | `kitsu-community` (imports `kitsu_feed.dart`) |

Parallel waves: `kitsu-graphql` → (`kitsu-media-page` ∥ `kitsu-community` ∥ `kitsu-profile-plus`) → `kitsu-home-extras`. Untouched by all: `kitsu_http.dart`, `kitsu_library.dart`, `kitsu_user*.dart`, `kitsu_user_page.dart`, `kitsu_user_list_adapter.dart`, `kitsu_login_dialog.dart`, auth files.

### Simkl

| Unit | Delivers | Owns | Needs done first |
|---|---|---|---|
| `simkl-api-compliance` (fix, P1) | `app-name`, `app-version` and `User-Agent: MyWatchList/<version>` on every call; reads `X-RateLimit-Remaining` / `Retry-After` (429 → typed error); doc links to api.simkl.org | `lib/services/api/SimKl/simkl_client.dart`, `test/units/simkl-api-compliance/**` | none |
| `simkl-auth-v2` (fix, before April 2027) | Real AUTH V2: `/oauth2/authorize` with PKCE S256, `/oauth2/token` with refresh, scopes `media:read media:write`, refresh through auth-refresh; anonymous catalogue calls moved to the token or the CDN. Endpoint constants live in `constants.dart` (not owned): report as a finding or add the V2 URLs as private constants in the auth file | `lib/services/auth/simkl_auth.dart`, `lib/services/auth/simkl_auth_v2.dart`, `lib/services/auth/simkl_authresp.dart`, `lib/user/user_simkl_v2.dart`, `test/units/simkl-auth-v2/**` | `simkl-api-compliance` |
| `simkl-cdn-feeds` | Trending (today/week/month) and airing calendar from `data.simkl.in` (A1, A2); Explore and home rows switch to them; Best anime (B3), Coming soon (B5), genre browse (B4) | `lib/services/api/SimKl/simkl_cdn.dart`, `lib/services/api/SimKl/simkl_discover_service.dart`, `lib/pages/Simkl/simkl_explore_page.dart`, `lib/pages/Simkl/simkl_home_page.dart`, `lib/widgets/Simkl/simkl_feeds.dart`, `lib/widgets/Simkl/simkl_home_plan.dart`, `lib/l10n/units/simkl-cdn-feeds/**`, `test/units/simkl-cdn-feeds/**` | `simkl-api-compliance` |
| `simkl-media-page` | Native Simkl title page: B1 full record (ratings, rank, drop rate, trailers, air time, recommendations with %, relations, studios), B2 episodes, scraped watcher distribution (C1), counters (C7), reviews with sub-scores (C3), comments (C4), memos (C5), tags and links (C9); HTML parsed off the UI isolate, cached, sections hidden when a selector fails | `lib/pages/Simkl/simkl_media_page.dart`, `lib/services/api/SimKl/simkl_detail_service.dart`, `lib/services/api/SimKl/simkl_detail_models.dart`, `lib/services/api/SimKl/scrapper/**`, `lib/widgets/Simkl/media/**`, `lib/widgets/Simkl/simkl_media_widgets.dart`, `lib/l10n/units/simkl-media-page/**`, `test/units/simkl-media-page/**` | `simkl-api-compliance` |
| `simkl-profile-plus` | Profile: time watched, left to watch, last week (B6, on open and pull to refresh only), "now watching" cover (B11), top rated by me (B9), custom lists for PRO/VIP (B13) | `lib/widgets/Simkl/simkl_profile_view.dart`, `lib/pages/Simkl/simkl_user_profile_page.dart`, `lib/services/api/SimKl/simkl_user_prof.dart`, `lib/services/api/SimKl/simkl_stats_service.dart`, `lib/services/api/SimKl/simkl_models.dart`, `lib/l10n/units/simkl-profile-plus/**`, `test/units/simkl-profile-plus/**` | `simkl-api-compliance` |
| `simkl-list-sync` | `/sync/activities` gating + `date_from` incremental pulls (B8), community score badge and sort (B7), continue watching with playback (B10) | `lib/services/api/SimKl/simkl_list_service.dart`, `lib/services/api/SimKl/simkl_user.dart`, `lib/widgets/Simkl/simkl_user_list_adapter.dart`, `lib/widgets/Simkl/simkl_edit_sheet.dart`, `lib/widgets/Simkl/simkl_states.dart`, `lib/pages/Simkl/simkl_user_page.dart`, `lib/l10n/units/simkl-list-sync/**`, `test/units/simkl-list-sync/**` | `simkl-api-compliance`; touches the same model only through its own types (if it needs `simkl_models.dart`, run after `simkl-profile-plus`) |

Parallel waves: `simkl-api-compliance` → (`simkl-auth-v2` ∥ `simkl-cdn-feeds` ∥ `simkl-media-page` ∥ `simkl-profile-plus`) → `simkl-list-sync`. The Simkl Forum tab stays as it is: Simkl has no forum and no public site-wide comment feed; per-title comments live on the title page.

Out of every unit: the calendar/notifications units that are MAL-fed could later consume `simkl_cdn.dart` (A1) and Kitsu's episode `releasedAt`; that is a finding for their owners, not an edit here.
