# MALClient fork (idarkalex) vs original (Drutol) vs MyWatchList

Sources audited (read only):
- Fork: `scratchpad/malclient/idarkalex` (shallow, single commit `70af9f0`, 2026-08-15, "ci: sign during build, add AAB artifact, version tag guard, smaller APK"; app version 1.2.1 per `RELEASE_NOTES.md`).
- Original: `scratchpad/malclient/drutol`.
- MyWatchList: `/home/thinkpad/Bureau/android-project/mywatchlist` at `origin/dev` (`e9a67f9`).
- Live checks: anonymous GETs on myanimelist.net, about 1 req/s, on 2026-10-28.

Paths below are relative to the fork root unless prefixed `MWL:`.

---

## 1. What the fork changed

`diff -rq` (excluding `.git`) gives 80 entries. `NEWS.json` is identical to the original. Everything new is in `README.md` and `RELEASE_NOTES.md`.

### 1.1 Removed
- Every non-Android target: `MALClient.UWP.*`, `MALClient.Desktop`, `MALClient.Mobile`, `MALClient.Shared`, `MALClient.UrlInterceptor`, `MALClient.CommTest`, `ExpressionBuilder`. The fork is Android (Xamarin) only.
- Jikan: `MALClient.XShared/Comm/JikanClient.cs` and the `JikanDotNet` package are gone. The SSL bypass for `api.jikan.moe` was removed from `MALClient.Android.Adapters/MalHttpContextProvider.cs`.

### 1.2 New data source: Tenrai, a Jikan v4 clone (`https://api.tenrai.org/v1`)
`MALClient.XShared/Comm/TenraiClient.cs:10-153`:
- A single static `HttpClient` with `User-Agent: MALClient/3.0`.
- A global `SemaphoreSlim` keeps **500 ms between requests** (l.13-16, 62-75). Up to 4 attempts. On 429 it honours `Retry-After` (otherwise waits 2 s × attempt, capped at 15 s; l.81-91). On 5xx it backs off 2 s × attempt (l.93-101).
- Helpers: `GetDataAsync` returns `data` (l.118). `GetPaginatedAsync` returns `data[]` plus `pagination.has_next_page` (l.125). `GetAllPagesAsync` reads up to 10 pages (l.142).
- A mirror list exists (`BaseUrls`, l.19) but holds only one entry.

Calls switched from Jikan or scraping to Tenrai:

| Feature | Tenrai endpoint | file:line |
|---|---|---|
| Anime details | `anime/{id}` | `Comm/Anime/AnimeDetailsMalQuery.cs:40` |
| OP/ED themes | `anime/{id}/themes` | `AnimeDetailsMalQuery.cs:117` |
| General details, anime and manga (second choice after MAL v2) | `anime/{id}`, `manga/{id}` | `Comm/Anime/AnimeGeneralDetailsQuery.cs:40` |
| Episodes | `anime/{id}/episodes?page=N` | `Comm/Anime/AnimeEpisodesQuery.cs:27` |
| Anime by genre / studio | `anime?genres={id}&page=&order_by=score&sort=desc`, `anime?producers={id}…` | `Comm/Anime/AnimeGenreStudioQuery.cs:45-49` |
| Anime search | `anime?q=…&sfw` | `Comm/Anime/AnimeSearchQuery.cs:28` |
| Manga search | `manga?q=…&sfw` | `Comm/Manga/MangaSearchQuery.cs:27` |
| Seasonal (second choice after MAL v2) | `seasons/{year}/{season}?page=N` | `Comm/Anime/AnimeSeasonalQuery.cs:60` |
| Season list for the picker | `seasons` | `ViewModels/Main/AnimeListViewModel.cs:1097-1108` |
| Reviews (second choice after the MAL scrape) | `{anime\|manga}/{id}/reviews?page=1..3` | `Comm/Anime/AnimeReviewsQuery.cs:214` |
| Profile favourites | `users/{name}/favorites` | `Comm/Profile/ProfileQuery.cs:114` |
| Profile friends | `users/{name}/friends` | `Comm/Profile/FriendsQuery.cs:28` |

**Finding:** the Tenrai OpenAPI (103 paths, `scratchpad/tenrai/openapi.json`) has **no `/users/*` path**. The fork's favourites and friends calls therefore fail, and the `catch {}` blocks hide the failure (`ProfileQuery.cs:145`, `FriendsQuery.cs:47`), so these sections come back empty. MWL's `tenrai-client` handoff already says Tenrai lacks `/users` and `/clubs`. Do not copy this part.

### 1.3 New: official MAL API v2 used without a user token
- `AnimeGeneralDetailsQuery.cs:105-135`: `GET https://api.myanimelist.net/v2/{anime|manga}/{id}?fields=id,title,main_picture,alternative_titles,start_date,end_date,synopsis,mean,media_type,status,num_episodes` (manga: `num_chapters,num_volumes`). It tries the user Bearer client first, then an **anonymous client with header `X-MAL-CLIENT-ID: 183063f74126e7551b00c3b4de66986c`** (Drutol's hard-coded client id, l.127).
- `AnimeSeasonalQuery.cs:120-180`: `GET /v2/anime/season/{year}/{season}?sort=anime_num_list_users&limit=100&fields=id,title,main_picture,mean,media_type,num_episodes,genres,broadcast,start_date&offset=N`. Same order: user client, then the anonymous `X-MAL-CLIENT-ID` client (l.138). Tenrai is only the fallback.
- The order is MAL v2 first, Tenrai second, with a per-type disk cache (`Utils/DataCache.cs`, +56 lines, keys versioned `_v2` to drop stale caches).

### 1.4 New features
1. **Top manga with real MAL categories**: `Comm/Anime/AnimeTopQuery.cs:26-38` (enum `MangaTopType`), `100-127` (URLs). Scrapes `https://myanimelist.net/topmanga.php?type={manga|novels|lightnovels|oneshots|doujin|manhwa|manhua|bypopularity|favorite}&limit={page*50}` and parses `tr.ranking-list` (l.169). Release 1.2.1 fixed `type=novel` to `novels` and `lightnovel` to `lightnovels`. Live check: `type=novels` gives 200 with 50 `ranking-list` rows.
2. **"Adapted to anime" manga section**: `Comm/Anime/AnimeAdaptedToAnimeQuery.cs:48-141`. Scrapes `https://myanimelist.net/manga/adapted` (Airing Now), `?type=all` and `?type=upcoming`. Selectors: `div[class*=js-seasonal-anime]`, then `a.link-title` (title, plus the id taken from `/manga/{id}/`), `img[data-src]` (cover with the `?…` suffix stripped), and `div[class*="scormem-item score"]` (score without the "★"). Results are cached and empty results are never cached. New menu entry `HamburgerButtons.MangaAdapted` and `PageIndex.PageMangaAdapted`. **Live check: 200, 69 cards (Airing Now) and 100 cards (upcoming); the selectors still match.**
3. **Seasonal season picker**: `AnimeListViewModel.cs:1097+`. Builds a year/season selection from Tenrai `seasons`, marks the current season, orders by date, and makes MAL score (descending) the default seasonal sort.
4. **Reviews scraped from MAL first**: `AnimeReviewsQuery.cs:58-200`. Reads `https://myanimelist.net/{anime|manga}/{id}/whatever/reviews` for up to 10 pages, following the "more reviews" link. XPath `//div[contains(@class,'review-element') and contains(@class,'js-review-element')]`. Inside each review: `.username a`, `.thumb img`, `.update_at`, `.tag.btn-label` (Recommended, Mixed Feelings, Not Recommended, Preliminary), `.text`, and `.icon-reaction[data-id]` (review id). The **`data-reactions` attribute** of the review node gives the counts for overall, nice, love it, funny, confusing, informative and well written. **Live check: `/anime/1/x/reviews` has 20 `js-review-element`, 20 `data-reactions` and 20 `icon-reaction`; the selectors still match.**
5. **In-app updater from GitHub Releases**: `Comm/AppUpdateQuery.cs` reads `GET https://api.github.com/repos/idarkalex/MALClient/releases/latest` (`Accept: application/vnd.github+json`), takes `tag_name` (without the `v`) and the first `.apk` asset's `browser_download_url`. `MALClient.Android/Utilities/UpdateInstaller.cs:17-50` downloads the file, then runs `FileProvider.GetUriForFile` and `Intent.ActionView` (new `Resources/xml/file_paths.xml`). `ViewModels/MainViewModelBase.cs` exposes `CheckForUpdatesAsync`.
6. CI: `.github/workflows/build-android.yml` builds a signed APK and AAB on windows-2022 with Xamarin and JDK 17, and publishes a Release on `v*` tags.
7. Cosmetic: `MALClient.Android/AoLibsCompat/ObservableRecyclerAdapter.cs`, new layouts for the changelog and About pages, character/staff/person tab fragments adapted to the Tenrai models.

### 1.5 Not changed: inherited from Drutol without edits
Everything "social" and every write action: profile comments, forum, messages, friends, clubs, favourites, notifications, history, articles and news, recommendations, personalized suggestions, list updates and login. The fork **does not touch any of these files** (none appears in `diff -rq`). The README still lists them ("Profile comments, you can add new ones too!", "Mal messaging", "Forums", "notification hub"). **No commit or release note in the fork confirms that they work in 2026.** Their state below comes from my own live checks.

---

## 2. Authentication (unchanged from Drutol, but this is what makes writing possible)

The fork runs **two sessions in parallel**:

1. **MAL website session (cookies), used for scraping and every write action.**
   - `MALClient.Android/Fragments/LogInPageFragment.cs:97-107`: an Android WebView with JS on and a mobile Chrome UA loads `https://myanimelist.net/login.php`. The user logs in (password, Google or Facebook).
   - l.120-130: when the WebView reaches `https://myanimelist.net/` (or `/#…`), the app reads **`CookieManager.Instance.GetCookie("https://myanimelist.net")`**, which includes the HttpOnly cookies (`MALSESSIONID`, `is_logged_in=1`).
   - `MALClient.XShared/ViewModels/Main/LogInViewModel.cs:216-221`: checks `is_logged_in=1` and stores the cookie string (in `Credentials.Password`).
   - `MALClient.Android.Adapters/MalHttpContextProvider.cs:44-94`: builds a `CsrfHttpClient` with that cookie jar plus the headers `authority: myanimelist.net`, `Host`, `X-Requested-With: XMLHttpRequest` and the cookie `anime_update_advanced=0`. It validates the session with `GET /editprofile.php?go=myoptions` (no 2xx means "MAL invalidated your session"), then calls `GetToken()`.
   - **CSRF**: `Comm/MagicalRawQueries/CsrfHttpClient.cs:80-101` runs `GET https://myanimelist.net/` and reads `<head>` → `meta[name=csrf_token]@content`. Every POST then sends `csrf_token=<value>` as a form field. Live check: the meta is still there, now written with single quotes (`<meta name='csrf_token' content='…'>`), so a regex must accept both quote styles.
2. **Official MAL API v2 (OAuth2 PKCE), used for lists, scores and `@me`.**
   - In the same WebView, after the cookies are captured, l.138-144 redirects to `https://myanimelist.net/v1/oauth2/authorize?response_type=code&client_id=…&state=signin&code_challenge={verifier}&code_challenge_method=plain`. Because the user is already logged in, they only see the consent screen.
   - `LogInViewModel.cs:224-242`: `POST https://myanimelist.net/v1/oauth2/token` with `client_id`, `grant_type=authorization_code`, `code` and `code_verifier`. Stores the access and refresh tokens, then calls `GET https://api.myanimelist.net/v2/users/@me` (l.245).

**MWL today:** OAuth2 PKCE only (`MWL: lib/constants/constants.dart:66`, `lib/services/auth/auth_webview.dart`), through `webview_flutter ^4.10.0`. MWL has **no MAL website session and no csrf handling** (`git grep csrf_token|cookie` finds nothing). That is the only reason MWL cannot post comments: **the official API v2 has no endpoint for comments, forum posts, messages, friends, clubs or favourites.**

**Feasibility in Flutter:** `webview_flutter`'s `WebViewCookieManager` can only set and clear cookies; it cannot read the HttpOnly `MALSESSIONID`. Options:
- `flutter_inappwebview`: `CookieManager.instance().getCookies(url:)` reads the native Android CookieManager, HttpOnly cookies included.
- A small `MethodChannel` that calls `android.webkit.CookieManager.getInstance().getCookie("https://myanimelist.net")`, about 15 lines of Kotlin.

Then store the cookie in `FlutterSecureStorage`, use a `dio` instance with that `Cookie` header, cache the csrf token from the meta tag, and refresh it on a 403 or on a login redirect.

---

## 3. Feature catalogue: data source, method, status in 2026, MWL status

Legend for "Live": OK means checked today and the selectors or form still match. LOGIN means it redirects anonymously to `login.php` (expected for a write or private page), so the endpoint exists but the body was not checked. ? means not checked.
"Session" means it needs the MAL cookies plus `csrf_token` (section 2).

### 3.1 Profile and social: writing

| Feature | Method | file:line | Live | MWL |
|---|---|---|---|---|
| **Post a profile comment** | `POST https://myanimelist.net/addcomment.php` form `profileMemId`, `commentText`, `profileUsername`, `csrf_token`, `commentSubmit=Submit Comment`. Success = 2xx or 303. | `Comm/MagicalRawQueries/Profile/ProfileCommentQueries.cs:15-42` | `addcomment.php` answers 200. The profile page has `div.comment-form` ("Please login…" when anonymous). | **No** |
| Reply in a comment-to-comment thread | same POST with `area=2`, `commentSubmit=1` (`profileMemId` = the other user) | `ProfileCommentQueries.cs:44-76` | as above | No |
| Delete a profile comment | `POST /includes/ajax.inc.php?t=78` form `id`, `csrf_token` | `ProfileCommentQueries.cs:78-101` | ? | No |
| Read a comment-to-comment conversation | `GET /comtocom.php?{id1=…&id2=…}`, parse `#content > div` (skip the first), `.spaceit` (text), `small` (date), the 2nd `a` (sender), `img` | `ProfileCommentQueries.cs:103-140` | 200 | No |
| **Read profile comments** | Scrape `/profile/{name}`: `div.user-comments.mt24.pt24`, then `div.comment.clearfix` (`data-id`), the first `img` (avatar), the first inner `div` (author and date), `a.ml8` (delete or conversation links) | `Comm/Profile/ProfileQuery.cs:394-443`, `502-573` | **OK**: 15 `comment clearfix` and 1 `user-comments mt24 pt24` on `/profile/Xinil`. Current markup: `a.image > img[data-src]`, `.text .pb8 a.fw-b` (user), `span.fn-grey1` (date), `.comment-text`. Full list: `/comments.php?id={userId}` (classes `comment bgColor1/bgNone`, `spaceit comment-text`). | **No** (MWL profile shows about, stats, favourites, friends, clubs and history, but no comments) |
| **Send a friend request** | `POST /myfriends.php?go=add&id={userId}` form `attachedMsg`, `confirm=1`, `go=add`, `csrf_token` | `Comm/MagicalRawQueries/Profile/MalFriendsQueries.cs:54-85` | ? | No |
| Pending requests | `GET /myfriends.php?go=pending` (scrape) | `MalFriendsQueries.cs:17-52` | LOGIN | No |
| Accept or deny a request | `POST /myfriends.php?go=confirm` or `go=deny` form `id`, `csrf_token` | `MalFriendsQueries.cs:87-112` | ? | No |
| Remove a friend | `GET /myfriends.php?go=remove&id={id}` | `MalFriendsQueries.cs:114-125` | ? | No |
| **Add or remove a favourite** (anime, manga, character, person) | `POST /includes/ajax.inc.php?s=1&t={13/14 anime, 38/39 manga, 42/43 char, 47/48 person}` form `aid`, `mid`, `cid` or `vaid` (by type) plus `csrf_token` | `Comm/MagicalRawQueries/MalFavouriteQuery.cs:13-55` | ? | No (MWL only reads favourites: `MWL: lib/screens/user_profile/sections/favorites_section.dart`) |

### 3.2 Messages and notifications

| Feature | Method | file:line | Live | MWL |
|---|---|---|---|---|
| Inbox | `GET /mymessages.php?go=&show={(page-1)*20}` (scrape) | `Comm/MagicalRawQueries/Messages/MalMessagesQuery.cs:18` | LOGIN (page title "My Messages") | No |
| Sent box | `GET /mymessages.php?go=sent` | `MalMessagesQuery.cs:47,79` | LOGIN | No |
| Read a message or thread | `GET /mymessages.php?go=read&id={id}[&f=1 sent]`, `…&threadid=` | `Messages/MalMessageDetailsQuery.cs:20,67` | LOGIN | No |
| **Send a PM** | `POST /mymessages.php?go=send&toname={user}` form `subject`, `message`, `csrf_token`, `sendmessage=Send Message` | `Messages/SendMessageQuery.cs:15-42` | ? | No |
| Reply to a PM | `POST /mymessages.php?go=send&replyid=&threadid=&toname=`, same form | `SendMessageQuery.cs:48-78` | ? | No |
| **Notification hub** | `GET /notification`, then find `\nwindow.MAL.notification = {…};` in the HTML and deserialise the JSON (`items[]`, `typeIdentifier` such as `on_air`, `friend_request`, `profile_comment`, `forum_quote`…) | `Comm/MagicalRawQueries/MalNotificationsQuery.cs:23-70` | LOGIN | **No** (MWL `notifications` = local airing reminders only) |
| Mark notifications as read | `POST /notification/api/check-items-as-read.json`, JSON body `{notification_ids:[…], csrf_token}` | `MalNotificationsQuery.cs:74-90` | ? | No |

### 3.3 Forum

| Feature | Method | file:line | Live | MWL |
|---|---|---|---|---|
| **Reply in a topic** | `POST /forum/?action=message&topic_id={id}` form `msg_text`, `csrf_token`, `action_type=submit` | `Comm/MagicalRawQueries/Forums/ForumTopicQueries.cs:118-139` | **OK**: the topic page still has `<form id="replyform" action="/forum/?action=message&topic_id=…">` with `action_type` (preview or submit), **`parent_id` (new: threaded replies)** and `msg_text`. | No (MWL forum is read only: `MWL: lib/services/api/MAL/mal_forum_api.dart`, API v2 `/forum/*` plus HTML fallback) |
| **New topic** (with optional poll) | `POST /forum/?action=post&{anime_id\|manga_id\|boardid\|club_id}={id}` form `topic_title`, `msg_text`, `csrf_token`, `submit=Submit` (+ `pollQuestion`, `pollOption[]`). The new topic id is read from the redirect. | `ForumTopicQueries.cs:34-92` | ? | No |
| Edit a post | `POST /includes/ajax.inc.php?t=86` form `msg_id`, `msg`, `topic_id`, `csrf_token` | `ForumTopicQueries.cs:141-185` | ? | No |
| Get a post's raw BBCode (for editing) | `POST /includes/ajax.inc.php?t=85` form `msg_id`, `csrf_token` | `ForumTopicQueries.cs:187-220` | ? | No |
| Delete a post | `POST /includes/ajax.inc.php?t=84` form `msgId`, `csrf_token` | `ForumTopicQueries.cs:222-260` | ? | No |
| Quote | `POST /includes/quotetext.php` form `msgid`, `csrf_token` | `ForumTopicQueries.cs:566-600` | ? | No |
| Watch or unwatch a topic | `POST /includes/ajax.inc.php?t=69` form `topic_id`, `timestamp`, `csrf_token` | `ForumTopicQueries.cs:526-560` | ? | No |
| Read a topic | Scrape `/forum/?topicid={id}&show={(p-1)*50}` (also `goto=lastpost`, `/forum/message/{id}?goto=topic`). Selectors: `div.fl-r.pb4` (pager), `h1.forum_locheader`, `div[class*=forum-topic-message]` with `id="forumMsg{id}"`, `.username`, `.custom-forum-title` | `ForumTopicQueries.cs:265-420` | **Broken**: the page now uses `div.forum-topic-message.message#msg{id}[data-id][data-user]`, `.message-header .date[data-time]`, `.postnum` and `.pages`. There are 0 `forumMsg` and 0 `fl-r pb4`. The fork did not fix this. | MWL reads topics (API v2 plus HTML) |

### 3.4 Clubs

| Feature | Method | file:line | Live | MWL |
|---|---|---|---|---|
| Club list, search, my clubs | `GET /clubs.php?catid=…[&q=]`, `/clubs.php?action=myclubs` | `Comm/MagicalRawQueries/Clubs/MalClubQueries.cs:46-140` | `clubs.php?cid=1` 200 | MWL has club pages (`MWL: lib/screens/forum/club_screen.dart`, members, comments, forum) |
| Join, request access, leave | `POST /clubs.php?action=join&id=` (`submitjoin=Join Club`), `action=request` (`submitjoin=Request Access`), `action=leave` (`submitleave=Leave Club`), each with `csrf_token` | `MalClubQueries.cs:170-195, 241-295` | ? | No |
| Accept or deny an invitation | `POST /clubs.php?action=invchoice` form `choice=1\|2`, `id`, `inviter_user_id=0`, `csrf_token` | `MalClubQueries.cs:141-168` | ? | No |
| **Post a club comment** | `POST /clubs.php?cid={clubId}` form `commentText`, `commentSubmit=Submit Comment`, `csrf_token` | `MalClubQueries.cs:196-221` | ? | No (MWL reads club comments only: `club_comments_screen.dart`) |
| Delete a club comment | `GET /includes/ajax.inc.php?t=10&comid={id}&cid={clubId}` | `MalClubQueries.cs:223-239` | ? | No |
| Club details, comments, members | scrape `/clubs.php?cid=`, `?id=…&action=view&t=comments&show=`, `t=members` | `Clubs/MalClubDetailsQuery.cs:25,228,301` | 200 | Yes |

### 3.5 Reviews and recommendations

| Feature | Method | file:line | Live | MWL |
|---|---|---|---|---|
| Reviews with reaction counts | MAL page scrape (fork, section 1.4.4), then Tenrai | `AnimeReviewsQuery.cs:58-240` | **OK** | Partial: Jikan reviews with `reactions`, plus an HTML fallback (`MWL: lib/services/api/Jikan/jikan_fallbacks.dart:238`) |
| Mark a review helpful | `POST /includes/ajax.inc.php?t=72` form `id`, `val=1`, `csrf_token` | `Comm/MagicalRawQueries/MalHelpfulReviewQuery.cs:14-35` | ? Likely **obsolete**: MAL replaced "helpful" with 7 reactions, and this new endpoint has not been reverse-engineered here. | No |
| **Personalized suggestions** (MAL's "Suggestions for you") | `GET /auto_recommendation/personalized_suggestions.json?placement={id}`, with the placement id first scraped from the home page (`InitPlacements`). Returns a JSON list. Needs the session. | `Comm/Anime/AnimePersonalizedRecommendationsQuery.cs:60-92` | LOGIN (303 to login, so the endpoint exists) | **No** |
| Global recent recommendations | scrape `/recommendations.php?s=recentrecs&t={anime\|manga}` | `Comm/Anime/AnimeRecomendationsQuery.cs:19` | 200 | Yes (`MWL: lib/screens/explore/explore_data.dart`) |

### 3.6 Lists, history, feeds and the rest

| Feature | Method | file:line | Live | MWL |
|---|---|---|---|---|
| List read | API v2 `GET /v2/users/{name}/animelist`, `/mangalist` (plus legacy `malappinfo.php` and an `/animelist/{u}` scrape) | `Comm/LibraryListQuery.cs:110,224,354,489` | — | Yes |
| List add, update, delete | API v2 `PUT /v2/{anime\|manga}/{id}/my_list_status` (form), `DELETE` the same path | `Comm/Anime/AnimeUpdateQuery.cs:105`, `AnimeAddQuery.cs:85`, `AnimeRemoveQuery.cs:50`, `Manga*Query.cs` | — | Yes (`MWL: lib/services/api/MAL/mal_api.dart:418-560`, with tags, comments, priority and rewatch) |
| History | scrape `/history/{name}[/anime\|manga]` | `Comm/Profile/ProfileHistoryQuery.cs:30` | 200 | Yes (`MWL: lib/screens/user_profile/sections/profile_tabs_source.dart:269`) |
| **Friends feed** | RSS `https://myanimelist.net/rss.php?type=rw&u={friend}` per friend, merged | `Comm/MalSpecific/MalFriendsFeedsQuery.cs:29` | 200 (5 KB XML) | **No** |
| MAL articles and news | scrape `/featured`, `/news` | `Comm/Articles/MalArticlesIndexQuery.cs:27-28` | — | Yes (`MWL: lib/screens/MAL/featured_screen.dart`) |
| Calendar countdowns | `https://mylovelyvps.xyz/malclient/airing.json` (Drutol's own server, not migrated by the fork) | `Comm/Anime/AnimeAiringDataQuery.cs:19` | not checked (not MAL) | MWL has its own calendar (`calendar` unit) |
| Wallpapers | Reddit `/r/…` JSON | `Comm/Anime/AnimeWallpapersQuery.cs` | — | No (low value) |
| Top manga categories | scrape `topmanga.php?type=…` (section 1.4.1) | `AnimeTopQuery.cs:100-127` | OK | Yes, through API v2 ranking (`MWL: lib/enums.dart:115-135` has novels, lightnovels, oneshots, doujin, manhwa, manhua) |
| **Manga adapted to anime** | scrape `/manga/adapted[?type=all\|upcoming]` (section 1.4.2) | `AnimeAdaptedToAnimeQuery.cs` | **OK** | **No** |
| Seasonal season picker | Tenrai `seasons` plus MAL v2 `anime/season/{y}/{s}` | section 1.4.3 | — | Yes (`MWL: lib/screens/search/search_home_view.dart:369` `SeasonPicker`, Jikan `seasons/{y}/{s}`) |
| In-app update | GitHub releases plus a FileProvider intent | section 1.4.5 | — | Yes (`MWL: lib/services/updater/release_service.dart:59`, `update_controller.dart:106`) |
| Deep-link protocol | `malclient://<MAL url>` (`Utils/MalLinkParser.cs`) | — | — | Yes (`MWL: lib/utils/deep_links.dart`) |

---

## 4. What the fork has that MWL lacks

1. **A MAL website session (cookies plus csrf).** This is the enabler for everything below. MWL has none.
2. **Profile comments**: read, post, reply, delete and comment-to-comment threads.
3. **Forum writing**: reply, new topic (with poll), edit, delete, quote, watch.
4. **Private messages**: inbox, sent, read, send, reply.
5. **MAL notification hub** with "mark as read".
6. **Friend management**: send, accept, deny, remove, plus the pending list.
7. **Club actions**: join, request, leave, invitations, post and delete club comments.
8. **Favourite toggles** for anime, manga, characters and people. API v2 cannot do this.
9. **Personalized suggestions** (`auto_recommendation/personalized_suggestions.json`).
10. **Friends activity feed** from RSS.
11. **"Manga adapted to anime"** section (anonymous scrape, verified).
12. Review "helpful" vote (likely obsolete; the reaction endpoint would need fresh reverse engineering).
13. Anonymous MAL v2 calls with `X-MAL-CLIENT-ID` as a fallback when no user is logged in. MWL could use its own client id the same way if it doesn't already.

Things the fork has that MWL **should not copy**:
- Tenrai `users/*/favorites|friends`: those endpoints do not exist.
- Drutol's client id `183063f7…` and the `mylovelyvps.xyz` dependency.
- The forum topic parser: it no longer matches MAL's markup.
- The plain PKCE method: MWL should keep its own; MAL only supports `plain`, which is fine.

---

## 5. Top 15 additions for MWL, with a suggested implementation

All write features share one foundation, so do unit 1 first. Every write call should go through a `MalWebSession` service in `lib/services/api/MAL/web/` that:
- holds the cookie string;
- runs `GET https://myanimelist.net/` and extracts the csrf token with a regex that accepts both quote styles: `<meta name=['"]csrf_token['"] content=['"]([0-9a-f]+)['"]`;
- sends `application/x-www-form-urlencoded` POSTs with `csrf_token` appended, a browser UA, `X-Requested-With: XMLHttpRequest` and `Referer` = the page;
- treats a 303 to `/login.php` as "session expired". It then clears the cookie, shows a "sign in to MAL website" prompt, and refreshes the csrf token once on a 400 or 403.

Gate every write UI on `UserMal` having a web session, which is separate from OAuth.

| # | Addition | Suggested MWL approach |
|---|---|---|
| 1 | **MAL web session** (foundation) | Add the cookie capture to the existing MAL OAuth flow, as the fork does: either open `login.php` first and then `oauth2/authorize` in the same WebView, or capture the cookies when the authorize page loads with the user logged in. Read the HttpOnly cookies with `flutter_inappwebview`'s `CookieManager.getCookies` or a 15-line Kotlin `MethodChannel` around `android.webkit.CookieManager`. Store them in `FlutterSecureStorage` (`mal_web_cookies`). Validate with `GET /editprofile.php?go=myoptions` (200 vs 303). Provide a "Reconnect MAL website" button in the account settings. |
| 2 | **Post a profile comment** | `MalWebSession.post('/addcomment.php', {profileMemId, commentText, profileUsername, commentSubmit:'Submit Comment'})`. Get `profileMemId` from the profile page (`/profile/{name}`: the report link or `comments.php?id=`). Success = 200 or 303; then reload the comments. Add a composer at the bottom of a new "Comments" tab on `user_profile_screen.dart`. |
| 3 | **Read profile comments** (anonymous) | Parse `/profile/{name}` `div.user-comments div.comment.clearfix` (`data-id`, `a.image img[data-src]`, `.text .pb8 a.fw-b`, `span.fn-grey1`, `.comment-text` as BBCode/HTML). For "view all", use `/comments.php?id={uid}` (`.comment`, `.comment-text`). Add the parser to `MWL: lib/services/api/MAL/scrapper/html_parsers.dart`. |
| 4 | **Forum reply** | `POST /forum/?action=message&topic_id={id}` with `msg_text`, `action_type=submit` and `parent_id` (empty, or the message id for a threaded reply), plus csrf. Add a reply box and a per-post "Reply" and "Quote" (quote via `POST /includes/quotetext.php {msgid}`) to `MWL: lib/screens/forum/forum_posts_screen.dart`. Check the live response once with a test account, because MAL added `parent_id` after the fork's code was written. |
| 5 | **MAL notifications hub** | `GET /notification`, regex `window\.MAL\.notification\s*=\s*(\{.*?\});`, then JSON (`items[]` with `typeIdentifier`, `isRead`, `createdAt`, `url`…). Mark as read with `POST /notification/api/check-items-as-read.json` (JSON body with ids and `csrf_token`). Poll it in the existing background or notification unit and show a bell badge on the home app bar. |
| 6 | **Private messages** | Inbox and sent: scrape `/mymessages.php?go=&show=` and `?go=sent`. Read: `?go=read&id=`. Send: `POST /mymessages.php?go=send&toname=` {`subject`, `message`, `sendmessage`}. Reply: add `replyid` and `threadid`. Add a "Send message" entry on other users' profiles. Re-derive the inbox selectors from the live logged-in page (not checked here). |
| 7 | **Favourite toggle** | `POST /includes/ajax.inc.php?s=1&t={13\|14\|38\|39\|42\|43\|47\|48}` with `aid`, `mid`, `cid` or `vaid`. Add a heart in the detail header and on character and person pages, with an optimistic update and a revert on failure. |
| 8 | **Friend requests** | Send: `POST /myfriends.php?go=add&id={uid}` {`attachedMsg`, `confirm=1`, `go=add`}. Pending: scrape `?go=pending`. Accept or deny: `POST ?go=confirm` or `?go=deny` {`id`}. Remove: `GET ?go=remove&id=`. Add buttons on the profile header and a "Requests" list inside `friends_section.dart`. |
| 9 | **Manga "Adapted to anime"** (anonymous, verified today) | Scraper for `/manga/adapted`, `?type=all` and `?type=upcoming`: `.js-seasonal-anime`, `a.link-title` (id from `/manga/(\d+)`), `img[data-src]` (strip `?…`), `.scormem-item.score`. Show it as a home row or a tab on the manga explore page, cached for a few hours. Small and low risk. |
| 10 | **Club actions and club comments** | Join, request or leave: `POST /clubs.php?action=join\|request\|leave&id=` with `submitjoin` or `submitleave`. Comment: `POST /clubs.php?cid=` {`commentText`, `commentSubmit`}. Delete: `GET /includes/ajax.inc.php?t=10&comid=&cid=`. Wire it into `club_screen.dart` and `club_comments_screen.dart`, which already exist and are read only. |
| 11 | **Personalized suggestions** | Read the placement ids from the logged-in home page (the fork's `InitPlacements`), then `GET /auto_recommendation/personalized_suggestions.json?placement=`. Show a "Suggested for you" home row when the web session exists. |
| 12 | **New forum topic (+ poll)** | `POST /forum/?action=post&{anime_id\|manga_id\|boardid\|club_id}=` {`topic_title`, `msg_text`, `submit`, optional `pollQuestion`, `pollOption[]`}, then follow the redirect to get the topic id. Add a floating action button on the board and anime-forum lists. |
| 13 | **Edit, delete and watch forum posts** | `t=85` (fetch BBCode), then `t=86` (save the edit), `t=84` (delete), `t=69` (watch). Only show these on the user's own posts (`data-user` == the logged-in username). |
| 14 | **Friends activity feed** (anonymous) | For each friend (from MWL's friends parser), `GET /rss.php?type=rw&u={name}` (list updates). Parse the RSS with `package:xml`, merge and sort by `pubDate`, and limit to about 1 req/s. Add a "Friends activity" tab on the own-profile or home screen. |
| 15 | **Profile comment-to-comment thread and delete** | Thread: `GET /comtocom.php?id1=&id2=`, then `#content > div:not(:first-child)` with `.spaceit`, `small` and links. Reply: `addcomment.php` with `area=2`. Delete: `POST /includes/ajax.inc.php?t=78 {id}`. These extend unit 2. |

Notes:
- **Risk and terms:** these are undocumented website endpoints. Keep write calls user-initiated only (no batching or automation) to stay below MAL's anti-spam limits. Escape or encode BBCode, and show a preview (`action_type=preview` is still in the forum form).
- **Verification:** before building units 4 to 8, record one real logged-in request per action with a test account. Use Chrome devtools on myanimelist.net, or MWL's `chrome-perso` MCP. The fork's code proves these forms existed. This audit only confirmed anonymously that the endpoints and form markup are still there (`addcomment.php` and `comtocom.php` give 200; `/notification`, `/mymessages.php`, `/myfriends.php?go=pending` and `personalized_suggestions.json` redirect to login; the forum `replyform` is unchanged apart from the new `parent_id`).
