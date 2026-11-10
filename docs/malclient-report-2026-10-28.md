# MALClient (Drutol) vs MyWatchList: feature audit

- MALClient source: shallow clone of `github.com/Drutol/MALClient`, last commit `37fb71f` (2024-08-06). C#/Xamarin, shared logic in `MALClient.XShared`, Android UI in `MALClient.Android`, UWP in `MALClient.Mobile` / `MALClient.Desktop`.
- MyWatchList: read from `origin/dev` (`8f0d86c`). The working tree was not used and `.wt/*` was ignored.
- File refs below are relative to the MALClient repo root (`XS/` = `MALClient.XShared/`). MWL refs are `lib/...` on `origin/dev`.
- Live checks: anonymous GETs to myanimelist.net on 2026-10-28, one about every 1.3 s, never logged in. "Live: 200" means the page still exists and still has the markup MALClient parses. "Live: login wall" means a 303 to `login.php?from=...`, so the endpoint exists but its content can't be checked without a session. POST endpoints can't be checked without logging in.

---

## 0. How MALClient talks to MAL (the important part)

MALClient runs **two HTTP stacks at the same time**:

| Stack | Used for | How auth works | Refs |
|---|---|---|---|
| **Official API v2** (`api.myanimelist.net/v2`) | List read (own list), list add/update/delete, `users/@me` | OAuth2 PKCE with `code_challenge_method=plain`, public client id `183063f7...`. Token from `POST https://myanimelist.net/v1/oauth2/token` (`grant_type=authorization_code`, then `refresh_token`). Header `Authorization: Bearer`. Refreshed when less than 1 h remains, then cached for 50 min | `XS/ViewModels/Main/LogInViewModel.cs:214-254`, `XS/BL/MalHttpContextProviderBase.cs:52-155` |
| **Website session** ("MagicalRawQueries") | Everything social: comments, PMs, friends, forum posts, clubs, favourites, notifications, "helpful" votes, watched topics, personalised suggestions | **Cookie session plus CSRF token.** Cookies are captured from an embedded WebView login. The CSRF token is scraped from `<meta name='csrf_token' content='...'>` in the `<head>` of `https://myanimelist.net/`. Each write is a form POST with a `csrf_token=<token>` field | `XS/Comm/MagicalRawQueries/CsrfHttpClient.cs:80-102`, `MALClient.Android.Adapters/MalHttpContextProvider.cs:44-94` |
| Jikan v4 (JikanDotNet lib, limited to 3/s and 60/min) | Anime/manga details, episodes, search, seasons, user favourites, friends, reviews | none | `XS/Comm/JikanClient.cs:10-18` |
| Others | Reddit JSON (wallpapers), the author's VPS `mylovelyvps.xyz/malclient/airing.json` (calendar), ANN encyclopedia XML, Hummingbird v1/v2 (dead), MAL RSS | none | see sections |

### 0.1 Login flow (Android): one WebView gives both cookies and the OAuth code
`MALClient.Android/Fragments/LogInPageFragment.cs:95-200`
1. The WebView loads `https://myanimelist.net/login.php` with a mobile Chrome UA and JS enabled. The user logs in on MAL's real page, so MAL's reCAPTCHA v3 and Google/Facebook/Apple/Twitter SNS logins all work (it whitelists `accounts.google`, `m.facebook`, `myanimelist.net/sns/...`, lines 58-73).
2. When the WebView lands on `https://myanimelist.net/` (login done), it reads **all cookies** with `Android.Webkit.CookieManager.Instance.GetCookie("https://myanimelist.net")` (line 128). This native API also returns HttpOnly cookies such as `MALSESSIONID`.
3. The same WebView is then redirected to `https://myanimelist.net/v1/oauth2/authorize?response_type=code&client_id=...&state=signin&code_challenge=<50 random chars>&code_challenge_method=plain` (line 140). The user is already logged in, so it goes straight to consent. The redirect `http://localhost/maloauth?code=...` is caught by the regex `.*maloauth\?code=(.*)\&.*` (line 185).
4. `LogInViewModel.SignIn(cookies, code)` (`XS/ViewModels/Main/LogInViewModel.cs:214`) requires `cookies.Contains("is_logged_in=1")`. It stores the raw cookie string **in the password slot of the credentials vault** (`Credentials.Update("", cookies, ...)`), exchanges the code for tokens, and calls `GET /v2/users/@me` to get id and name.

### 0.2 Building the website session on each launch
`MALClient.Android.Adapters/MalHttpContextProvider.cs:44-94`
- A new `HttpClient` with a `CookieContainer`. Every stored `name=value` pair is added for the domain `myanimelist.net` (`MalHttpContextProviderBase.SetCookies`, lines 33-50). It also adds the cookie `anime_update_advanced=0` and the headers `X-Requested-With: XMLHttpRequest`, `authority`/`Host: myanimelist.net`.
- **Session check:** `GET https://myanimelist.net/editprofile.php?go=myoptions` must give a 2xx with auto-redirect on. A logged-out session redirects to `login.php` (Live today: a logged-out request gives `303 -> login.php?from=...`, so the check still works). If it fails, the user sees "MAL seems to have invalidated your current session" and must log in again.
- **CSRF:** `GET https://myanimelist.net/`, then `head > meta[name=csrf_token]@content` (`CsrfHttpClient.cs:94-101`). The token is fetched once per session and reused in every POST.
- The old user/password POST to `login.php` with a **hard-coded `g-recaptcha-response`** is commented out (`MalHttpContextProviderBase.cs:217-233`, `MalHttpContextProvider.cs:96-191`). It no longer works. **Live today:** `login.php` loads reCAPTCHA v3 (`recaptcha_site_key 6Ld_1aIZ...`), so a headless login is not possible and a WebView login is required.
- **Live today:** the `csrf_token` meta tag is still there (single quotes: `<meta name='csrf_token' content='...'>`), even on logged-out pages.

> Bottom line for MWL: every "we can't" item (post comments, PMs, forum replies, friend requests, favourites, club join, MAL notifications) is **impossible with the official API v2**. MALClient does them all through the **website cookie session plus `csrf_token`**. MWL logs in to MAL with `flutter_web_auth_2` / Custom Tabs (`lib/services/auth/mal_auth_v2.dart:90,126,163`), which **cannot see the browser's cookies**, and nothing in `lib/` uses `csrf` or a cookie (`git grep csrf origin/dev -- lib` finds nothing). So MWL needs one new thing first: a session login.

---

## 1. Features MWL lacks

Auth legend: **S** = website cookie session plus `csrf_token` (needs the new session login), **O** = official OAuth API, **–** = anonymous.

### 1.1 Profile comments (the owner's example)

| Feature | MALClient method | Auth | Refs | Live check | MWL |
|---|---|---|---|---|---|
| **Read profile comments** | Scrapes `GET /profile/{name}`. Selectors: `div.user-comments.mt24.pt24` > `div.comment.clearfix`. Avatar is the first `img`, author and date are in the header `div`, text is the second inner `div`. Action links `a.ml8`: "Conversation" `href` gives the comtocom query, "Delete" `onclick` gives the comment id (`...(12345)`). The page's hidden `input[name=profileMemId]` gives the numeric user id needed to post | – | `XS/Comm/Profile/ProfileQuery.cs:399-458`, `507-578` | **200**. `div.user-comments mt24 pt24` and `div.comment clearfix data-id="48975422"` are still present. The text is now in `div.lh16.comment-text` and the date in `span.fn-grey1`. "All comments" links to `/comments.php?id={memId}`. Logged out, the `a.ml8` action links and `profileMemId` are missing (they only appear with a session) | **No.** `lib/services/api/MAL/scrapper/user_profile_page.dart` parses about, stats, favourites and last online, but not comments |
| **Post a comment on a profile** | `POST /addcomment.php`, form `profileMemId={id}&commentText=...&profileUsername={name}&csrf_token=...&commentSubmit=Submit Comment`. Success = 2xx or 303 | S | `XS/Comm/MagicalRawQueries/Profile/ProfileCommentQueries.cs:16-42` | POST not checkable | No |
| **Reply in a comment-to-comment conversation** | Same endpoint, form `profileMemId, commentText, area=2, csrf_token, commentSubmit=1` | S | `ProfileCommentQueries.cs:44-76` | not checkable | No |
| **Delete own or received comment** | `POST /includes/ajax.inc.php?t=78`, form `id={commentId}&csrf_token=...` | S | `ProfileCommentQueries.cs:78-101` | not checkable | No |
| **Conversation view (comtocom)** | `GET /comtocom.php?{id1=..&id2=..}`. `div#content` > child `div`s (skip 1). Text in `div.spaceit`, date in `small`, sender is the 2nd `a` | – | `ProfileCommentQueries.cs:103-148` | **200** (page body has class `comtocom profile-comment`) | No |
| Edit comment (noted only) | `POST /includes/ajax.inc.php?t=73` `id, csrf_token` (commented out, author unsure) | S | `ProfileCommentQueries.cs:63-67` | – | No |
| VM / UI | `ProfilePageViewModel` (`SendCommentCommand`, `DeleteCommentCommand`, `NavigateConversationCommand`) | | `XS/ViewModels/Main/ProfilePageViewModel.cs` | | |

### 1.2 Private messages (MAL inbox)

| Feature | MALClient method | Auth | Refs | Live | MWL |
|---|---|---|---|---|---|
| Inbox list (20 per page) | `GET /mymessages.php?go=&show={(page-1)*20}`. Rows are `div.message.unread.spot1.clearfix` and `div.message.read.spot1.clearfix`. Sender in `div.mym.mym_user`, subject and preview in `div.mym.mym_subject` (`a` / `span`), id from the `a.subject-link` href (`...=id`), date in `span.mym_date`. `threadid` / `replyid` come from the `span.mym_actions a` href split on `=`. "You have 0 messages" means empty | S | `XS/Comm/MagicalRawQueries/Messages/MalMessagesQuery.cs:6-31`, `119-147` | **login wall** (303) | No |
| Sent box | `GET /mymessages.php?go=sent`, rows `div.message.read.spot2.clearfix` | S | `MalMessagesQuery.cs:33-59` | login wall | No |
| Read a message | `GET /mymessages.php?go=read&id={id}[&f=1 for sent]`. Body is the text nodes of `td.dialog-text` after the 3rd child. Thread and reply ids come from the `onclick` of `input.inputButton.btn-middle.flat` | S | `MalMessageDetailsQuery.cs:6-51` | login wall | No |
| Thread history | `GET /mymessages.php?go=read&id={id}&threadid={tid}`, `table.pmessage-message-history tr`: td0 date, td1 sender, td2 text | S | `MalMessageDetailsQuery.cs:53-105` | login wall | No |
| **Send a new PM** | `POST /mymessages.php?go=send&toname={user}`, form `subject, message, csrf_token, sendmessage=Send Message` | S | `XS/Comm/MagicalRawQueries/Messages/SendMessageQuery.cs:10-36` | not checkable | No |
| Reply to a PM | `POST /mymessages.php?go=send&replyid={rid}&threadid={tid}&toname={user}`, same form | S | `SendMessageQuery.cs:42-72` | not checkable | No |
| Get the id of the message just sent | Re-reads the sent box and takes the 2nd `a` href of the first row | S | `MalMessagesQuery.cs:65-96` | | No |
| VM / UI | `MalMessagingViewModel`, `MalMessageDetailsViewModel` (compose, reply, thread) | | `XS/ViewModels/Main/MalMessag*.cs` | | |

### 1.3 Friends: requests and management

| Feature | MALClient method | Auth | Refs | Live | MWL |
|---|---|---|---|---|---|
| Pending friend requests | `GET /myfriends.php?go=pending`. First `table`, rows in pairs: avatar `img@data-src`, name in `strong`, attached message in `div.spaceit` (`Substring(17)`), request id from the first `td` id (`Substring(3)`) | S | `XS/Comm/MagicalRawQueries/Profile/MalFriendsQueries.cs:17-51` | **login wall** | No |
| **Send a friend request** | `POST /myfriends.php?go=add&id={userId}`, form `attachedMsg, confirm=..., go=add, confirm=1, csrf_token` | S | `MalFriendsQueries.cs:54-85` | not checkable | No |
| Accept / deny | `POST /myfriends.php?go=confirm` or `?go=deny`, form `id, csrf_token` | S | `MalFriendsQueries.cs:87-112` | not checkable | No |
| Remove a friend | `GET /myfriends.php?go=remove&id={id}` (a GET that changes state, no token) | S | `MalFriendsQueries.cs:114-130` | not checkable | No |
| "Is friend / can add" state | Profile page `a.icon-user-function.icon-remove.js-user-function` (already a friend) and `a.icon-user-function.icon-request.js-user-function` (can add) | S for real state | `ProfileQuery.cs:487-491` | **200**. Logged out, `icon-request disabled`, `icon-message`, `icon-comment disabled` are present, so the classes still exist | No (MWL lists friends read-only: `lib/screens/user_profile/sections/friends_section.dart`, from `friends/api/list/{id}.json` and `/profile/<name>/friends`) |

### 1.4 Forums: writing

MWL reads forums already. The reply button only opens the website (`lib/widgets/forum/forum_common.dart:17` `ForumUrls.reply`).

| Feature | MALClient method | Auth | Refs | MWL |
|---|---|---|---|---|
| **Reply to a topic** | `POST /forum/?action=message&topic_id={id}`, form `msg_text={bbcode}&csrf_token&action_type=submit` | S | `XS/Comm/MagicalRawQueries/Forums/ForumTopicQueries.cs:118-148` | No (web link only) |
| **New topic** (board, club, anime, manga), **with optional poll** | `POST /forum/?action=post&boardid={id}` / `&club_id=` / `&anime_id=` / `&manga_id=`, form `topic_title, msg_text, csrf_token, submit=Submit`, plus `pollQuestion` and repeated `pollOption[]`. An error page contains `badresult`. The new topic id comes from `topicid=(\d+)` in `div#contentWrapper` | S | `ForumTopicQueries.cs:34-108` | No |
| Edit own post | `POST /includes/ajax.inc.php?t=86`, form `msg_id, msg={bbcode}, topic_id, csrf_token`. The JSON reply has `message_html` | S | `ForumTopicQueries.cs:165-199` | No |
| Get a post's BBCode (to pre-fill the editor) | `POST /includes/ajax.inc.php?t=85`, `msg_id, csrf_token`, JSON reply | S | `ForumTopicQueries.cs:211-240` | No |
| Delete own post | `POST /includes/ajax.inc.php?t=84`, `msgId, csrf_token` | S | `ForumTopicQueries.cs:246-270` | No |
| Quote a post | `POST /includes/quotetext.php`, `msgid, csrf_token`. Returns quoted BBCode | S | `ForumTopicQueries.cs:566-595` | No |
| **Watch / unwatch a topic** | `POST /includes/ajax.inc.php?t=69`, `topic_id, timestamp="ddd MMM dd yyyy hh:mm:ss GMT+zz (TZ)", csrf_token`. The reply tells which state it toggled to | S | `ForumTopicQueries.cs:526-560` | No |
| **Watched topics list** | `GET /forum/?action=viewstarred`, `table#forumTopics tr` (skip header) | S | `XS/Comm/Forums/ForumSearchQuery.cs:90-122` | No. **Live: login wall** |
| Can edit / delete flags | Per post, `div.postActions` children contain "Edit" / "Delete" | S | `ForumTopicQueries.cs:463-468` | No |
| BBCode editor and renderer | Own BBCode parser project | – | `MALClient.Utilities.BBCode/BBCode/*` | MWL renders BBCode (`lib/widgets/forum/bbcode_widget.dart`) but has no editor |

### 1.5 Forums: reading features MWL doesn't have

| Feature | MALClient method | Auth | Refs | Live | MWL |
|---|---|---|---|---|---|
| **Forum search** (with scope) | `GET /forum/search?q={q}&u=&uloc=1&loc={scope}`, `table#forumTopics` rows | – | `ForumSearchQuery.cs:20-55` | **200**. `table#forumTopics` and `forum_boardrow1/2` rows still present | No (`git grep forum/search` finds nothing) |
| Posts by a user | `GET /forum/search?u={user}&q=&uloc=1&loc=-1` | – | `ForumSearchQuery.cs:57-88` | same page, 200 | No |
| Jump to last post / message permalink | `/forum/?topicid={id}&goto=lastpost`, `/forum/message/{msgId}?goto=topic` | – | `ForumTopicQueries.cs:300-305`, `XS/Comm/Forums/ForumTopicMessageCountQuery.cs:17-30` | not checked | Partial (MWL has paging. A last-post jump was not found) |
| Local pinned boards / topics, starred-post "leaderboard" | Stored on the device | – | `XS/ViewModels/Forums/ForumsMainViewModel.cs:21`, `ForumsStarredMessagesViewModel.cs` | – | Partial: MWL has generic bookmarks (`lib/cache/bookmarks.dart`) |

### 1.6 Clubs: actions

MWL reads clubs, club comments, members and the club forum (`lib/screens/forum/club_*.dart`). "Join" opens the web (`forum_common.dart:19`).

| Feature | MALClient method | Auth | Refs | MWL |
|---|---|---|---|---|
| **Join a club** | `POST /clubs.php?action=join&id={id}`, `submitjoin=Join Club&csrf_token` | S | `XS/Comm/MagicalRawQueries/Clubs/MalClubQueries.cs:170-194` | Web link only |
| Request access (private club) | `POST /clubs.php?action=request&id={id}`, `submitjoin=Request Access&csrf_token` | S | `MalClubQueries.cs:241-266` | No |
| Leave a club | `POST /clubs.php?action=leave&id={id}`, `submitleave=Leave Club&csrf_token` | S | `MalClubQueries.cs:268-293` | No |
| Accept / deny an invitation | `POST /clubs.php?action=invchoice`, `choice=1|2, id, inviter_user_id=0, csrf_token`. The invitation id is read from the `input[name=id]` next to an "Accept" button in the club list | S | `MalClubQueries.cs:113-118`, `141-168` | No |
| **Post a club comment** | `POST /clubs.php?cid={id}`, `commentText, commentSubmit=Submit Comment, csrf_token` | S | `MalClubQueries.cs:196-221` | No |
| Delete a club comment | `GET /includes/ajax.inc.php?t=10&comid={cid}&cid={clubId}` | S | `MalClubQueries.cs:223-239` | No |
| "My clubs" | `GET /clubs.php?action=myclubs` (with a session), `tr.table-data` rows | S | `MalClubQueries.cs:54-58` | MWL shows the clubs a user is in on their profile (`clubs_section.dart`). Logged out, **live** `action=myclubs` gives a generic list (200, 104 KB), so a session is needed to get *my* clubs |
| Club search by category | `GET /clubs.php?catid={cat}&cn={q}&action=find&p={page}` (13 categories: enum `MalClubQueries.cs:20-38`) | – | `MalClubQueries.cs:46-58` | Partial: MWL searches by name (`lib/services/api/MAL/scrapper/mal_scrapper.dart:250`), with no category filter |

### 1.7 Favourites toggle (anime, manga, character, person)

| Feature | MALClient method | Auth | Refs | MWL |
|---|---|---|---|---|
| **Add / remove favourite** | `POST /includes/ajax.inc.php?s=1&t={13 add / 14 remove anime, 38/39 manga, 42/43 character, 47/48 person}`, form `{aid|mid|cid|vaid}={id}&csrf_token` | S | `XS/Comm/MagicalRawQueries/MalFavouriteQuery.cs:12-55` | **No.** MWL only shows favourites (`favorites_section.dart`). No add, toggle or `favorites/add` code exists |
| "Is favourite" state | Takes the favourites from your own profile (Jikan `GetUserFavoritesAsync`) and keeps a local set | – | `ProfileQuery.cs:114-115`, `474-484` | – |

### 1.8 Reviews: voting

| Feature | MALClient method | Auth | Refs | MWL |
|---|---|---|---|---|
| Mark a review helpful | `POST /includes/ajax.inc.php?t=72`, `id, val=1, csrf_token` | S | `XS/Comm/MagicalRawQueries/MalHelpfulReviewQuery.cs:12-33` | No. MWL shows reaction counts (`lib/widgets/MAL/review/review_reactions.dart`) but can't vote. **Caveat:** MAL replaced "helpful" with 7 reaction types in 2022. `t=72` is probably dead or remapped, and the new reaction endpoint is unknown (it needs a logged-in capture) |

### 1.9 MAL site notifications

| Feature | MALClient method | Auth | Refs | Live | MWL |
|---|---|---|---|---|---|
| **Notification hub** (friend requests and results, profile comments, blog comments, forum quotes, @mentions, watched-topic replies, club messages, new related anime, now on air, payments, plus PMs) | `GET /notification`, then find `\nwindow.MAL.notification` in the HTML and cut from the first `=` to `};`. That is a **JSON blob** (`items[]` with `typeIdentifier`, `animes`...), parsed with Newtonsoft | S | `XS/Comm/MagicalRawQueries/MalNotificationsQuery.cs:23-67`; types `MALClient.Models/Enums/MalNotificationsTypesEnum.cs:6-31` | **login wall** (303). The JSON blob can't be checked without a session | **No.** MWL's notifications are local airing alerts (`lib/services/notifications/*`) |
| Mark as read | `POST /notification/api/check-items-as-read.json`, **JSON** body `{"csrf_token": "...", "notification_ids": [..]}`. Success if the reply contains `true` | S | `MalNotificationsQuery.cs:74-105` | not checkable | No |
| Background polling to system notifications | An Android alarm receiver polls `/notification` and the inbox page 1, filters by the enabled types, and posts system notifications | S | `MALClient.Android/BackgroundTasks/NotificationCheckBroadcastReceiver.cs:107-140`; UWP `MALClient.UWP.BGTaskNotifications/NotificationsBackgroundTask.cs` | – | No (MWL already has local notification code and settings to reuse: `lib/services/notifications/notification_service.dart`, `lib/screens/settings/notifications_settings.dart`) |

### 1.10 Other features MWL lacks (read-only, no session needed unless marked)

| Feature | MALClient method | Auth | Refs | Live | MWL |
|---|---|---|---|---|---|
| **Friends' activity feed** | Fetches `GET /rss.php?type=rw&u={friend}` for every friend in parallel (at most 2 at once) and merges them by date | – | `XS/Comm/MalSpecific/MalFriendsFeedsQuery.cs:20-97`, VM `XS/ViewModels/Main/FriendsFeedsViewModel.cs` | **200**, valid RSS with 15 `<item>` | No (`rss.php` not used. MWL has a Simkl feed only: `lib/widgets/Simkl/simkl_feeds.dart`) |
| **List comparison with another user** | Loads the other user's list from `GET /animelist/{user}/load.json?offset={n}&status=7&order=5` (300 per page) or `/mangalist/...`, joins it with your list by id, filters by status (mine / theirs / both) and sorts by score difference | – | `XS/Comm/LibraryListQuery.cs:340-365`, `489`; `XS/ViewModels/Main/ListComparisonViewModel.cs:58-250` | **200** (377 KB JSON for Xinil) | No (no compare screen. A user's list can be read through API v2 `users/{name}/animelist` when public) |
| **Popular promotional videos** (site-wide) | `GET /watch/promotion`, `div.video-list-outer-vertical`. YouTube id from the last segment of the `a@href`, text in `div.info-container`, anime title in the last `a` | – | `XS/Comm/MalSpecific/PopularVideosQuery.cs:20-58` | **200**, 30 `video-list-outer-vertical` blocks | No (MWL only has per-title videos from Jikan: `lib/services/api/Jikan/jikan_anime_videos.dart`) |
| **Wallpapers browser** | Reddit `GET https://www.reddit.com/r/{sub}/hot.json?limit=..&count=..&after=..`, image URLs filtered by the regex `(http:|https:)\/\/(i.imgur.com|cdn.awwni.me|i.redd.it|i.reddituploads.com)\/(?!a\/).*`. Subs: Animewallpaper, awwnime, pixiv, ZettaiRyouiki, Moescape, Moestash, Patchuu. Save image, optional waifu2x link | – | `XS/Comm/Anime/AnimeWallpapersQuery.cs:110-160`, `MALClient.Models/Enums/WallpaperSources.cs`, `XS/ViewModels/Items/WallpaperItemViewModel.cs:80` | not checked. Reddit's unauthenticated JSON is now heavily rate-limited and needs a UA | No (out of scope for a tracker, low value) |
| **Personalised suggestions (website widget)** | Scrapes the `data-placement` of `div#v-auto-recommendation-personalized_anime` / `_manga` on the logged-in home page, then `GET /auto_recommendation/personalized_suggestions.json?placement=...` | S | `XS/Comm/Anime/AnimePersonalizedRecommendationsQuery.cs:28-94` | needs a session | Partial: MWL uses the official `GET /v2/anime/suggestions` and `/v2/manga/suggestions` (`lib/constants/constants.dart:81-83`). This is a different algorithm, and API v2 has no manga suggestions in practice |
| Character search (website) | `GET /character.php?q={q}`, first `table tr` (skip 1): td0 `img@data-src` (strip `/r/\d+x\d+`), td1 `a` and `small` | – | `XS/Comm/Search/CharactersSearchQuery.cs:19-60` | **200** | Has it (Jikan character search: `lib/screens/search/search_service.dart`) |
| ANN encyclopedia extra details | `GET http://cdn.animenewsnetwork.com/encyclopedia/api.xml?title=~{title}` | – | `XS/Comm/Anime/AnimeDetailsAnnQuery.cs:21` | not checked | No (low value) |
| Offline update queue | When a PUT fails and `EnableOfflineSync` is set, it saves `AnimeSyncRequired` and replays on the next launch | O | `XS/Comm/Anime/AnimeUpdateQuery.cs:~208-214` | – | Not found in MWL (`offline` only appears in caches) |
| Home-screen widgets / live tiles | UWP live tiles, an Android `Widgets/` folder | – | `MALClient.UWP.BGTaskLiveTilesNotifications`, `MALClient.Android/Widgets` | – | No (no `home_widget`) |
| App news / changelog from GitHub | `GET raw.githubusercontent.com/.../NEWS.json` | – | `XS/Comm/NewsQuery.cs:12` | – | n/a |

---

## 2. Features MWL already has (fully or partly), and how MALClient did them

| Area | MALClient method (refs) | MWL status |
|---|---|---|
| List read (own) | API v2 `GET /v2/users/{u}/animelist?fields=...list_status{start_date,tags,finish_date,comments,priority,num_episodes_rewatched,num_watched_times,list_updated_at}&limit=1000&nsfw=true` (`XS/Comm/LibraryListQuery.cs:110-124`, manga `:224`). Other users through `load.json` (`:354`, `:489`) | **Has.** `lib/services/api/MAL/mal_api.dart:371` (same fields) |
| List update / add / delete: score, status, eps, vols, dates, **tags, priority, rewatching, rewatch count** | API v2 `PUT /v2/{anime|manga}/{id}/my_list_status` form (`XS/Comm/Anime/AnimeUpdateQuery.cs:~72-110`, `XS/Comm/Manga/MangaUpdateQuery.cs:63-95`), `DELETE` (`AnimeRemoveQuery.cs:50`, `MangaRemoveQuery.cs:33`). It does **not** send `comments`, and it puts user notes in `tags`. The old website `/ownlist/anime/{id}/edit` form (storage type, rewatch value, `is_asked_to_discuss`, `sns_post_type`) is commented out (`AnimeUpdateQuery.cs:~112-203`) | **Has, and more:** `mal_api.dart:414-557` also sends `comments`, `rewatch_value` and `reread_value`. Not covered: the website-only fields (storage type and value, "ask to discuss", SNS post). **Live:** `/ownlist/anime/1/edit?hideLayout=1` now 303s to `/ownlist/anime/add?selected_series_id=1`, so the website edit form has moved |
| Anime / manga details | Jikan `GetAnimeAsync` / `GetMangaAsync` (`XS/Comm/Anime/AnimeGeneralDetailsQuery.cs:32-71`) plus a scrape of `/anime/{id}` for theme songs (`div.theme-songs.js-theme-songs.opnening/ending`) and sidebar info (`AnimeDetailsMalQuery.cs:49-112`) | **Has** (`lib/screens/MAL/detail/*`, themes in `media_section.dart`) |
| Episodes | Jikan `GetAnimeEpisodesAsync` (`AnimeEpisodesQuery.cs:27-33`) | Has (Jikan `episodes`, `lib/services/api/Jikan/jikan_api.dart`) |
| Characters and staff list | Scrape `/anime/{id}/whatever/characters` (`AnimeCharactersStaffQuery.cs:25-35`) | Has (`characters_section.dart`, `staff_section.dart`, `characters_staff_screen.dart`) |
| Character / person page | Scrape `/character/{id}`, `/people/{id}` (`XS/Comm/Details/CharacterDetailsQuery.cs:23`, `StaffDetailsQuery.cs:24`) | Has (`lib/screens/MAL/character_screen.dart`, Jikan plus scraper fallback `scrapper/character_page.dart`) |
| Pictures | Scrape `/{anime|manga}/{id}/what/pics` (`AnimeImageQuery.cs:133`) | Has (`pictures_section.dart`) |
| Related | Scrape `/anime/{id}` related table (`AnimeRelatedQuery.cs:23`) | Has (`related_section.dart`) |
| Per-title recommendations | Scrape `/{type}/{id}/whatever/userrecs` (`AnimeDirectRecommendationsQuery.cs:23-75`) | Has (`recommendations_section.dart`, `full_recommendations_page.dart`) |
| Global recent recommendations | Scrape `/recommendations.php?s=recentrecs&t=anime|manga` (`AnimeRecomendationsQuery.cs:19-54`) | Has (`lib/screens/explore/explore_data.dart:269-272`) |
| Reviews read | Jikan `/v4/{anime|manga}/{id}/reviews` (`AnimeReviewsQuery.cs:52,70`), plus a scraping path at `:27` | Has, richer (`lib/widgets/MAL/review/*`) |
| Per-title videos | Scrape `/anime/{id}/whatever/video`, `div.video-block.promotional-video.mt16` > `div.video-list-outer.po-r.pv` (`AnimeVideosQuery.cs:23-62`) | Has (Jikan videos) |
| Top lists (8 anime and 1 manga category) | Scrape `topanime.php?type=airing|upcoming|tv|movie|ova|bypopularity|favorite&limit=` (`AnimeTopQuery.cs:36-64`) | Has (rankings, `lib/enums.dart`) |
| Seasonal, any season | Jikan `/v4/seasons/{y}/{s}` (`AnimeSeasonalQuery.cs:60-62`), season archive (`AnimeListViewModel.cs:1077`) | Has (`lib/screens/seasonal/*`) |
| Browse by genre / studio | Scrape `/anime/genre/{id}?page=`, `/anime/producer/{id}?page=` (`AnimeGenreStudioQuery.cs:29,40`) | Has (`lib/screens/studios/*`, `search/data/anime_genres.dart`) |
| Search anime / manga | Jikan search (`AnimeSearchQuery.cs:53`, `MangaSearchQuery.cs:36`). The old `/api/anime/search.xml` is dead | Has |
| "Search everywhere" (anime, manga, characters, people, news, users) | `GET /search/prefix.json?type=all&keyword=..&v=1` and `type=user` (`XS/Comm/Search/EverywhereSearchQuery.cs:18-24`) | Has (`lib/screens/search/*`, `mal_user_search.dart`). **Live:** `prefix.json` gives 200 JSON |
| Profile (stats, about, favourites, friends preview, recent updates) | Scrape `/profile/{u}`: `div.stats.anime/manga`, `ul.stats-status.fl-l li`, `ul.stats-data.fl-r li`, `div.user-image.mb8 img`, `div.profile-about-user.js-truncate-inner` (`ProfileQuery.cs:160-467`); favourites through Jikan (`:114`) | Has (`lib/services/api/MAL/scrapper/user_profile_page.dart`, `lib/screens/user_profile/*`), **except comments (1.1) and friend actions (1.3)** |
| History | Scrape `/history/{u}`: `tr` rows, skip `div.normal_header`, `strong` = episode, last `td` = date (`XS/Comm/Profile/ProfileHistoryQuery.cs:30-54`) | Has (`history_section.dart`, `/history/<name>/<type>` in `profile_tabs_source.dart:269`) |
| Friends list | Jikan `GetUserFriendsAsync` (`XS/Comm/Profile/FriendsQuery.cs:30`) | Has (from MAL's JSON and pages, `profile_tabs_source.dart:76,220`) |
| Forum read: index, boards, sub-boards, anime/manga/club boards, topic posts | Scrape `/forum/` (`ul.topics`, `div.forum-side-block`), `/forum/?board=` / `?subboard=` / `?animeid=` / `?clubid=` (`ForumBoardIndexContentQuery.cs`, `ForumBoardTopicsQuery.cs:37-62`), posts `div.forum-topic-message` with `div.username`, `div.userstatus`, `div.content`, `div.sig`, `div.modified` (`ForumTopicQueries.cs:289-468`) | Has (`lib/services/api/MAL/mal_forum_api.dart`, `lib/screens/forum/*`). Read only |
| Club details, comments, members | Scrape `/clubs.php?cid=`, `?id=&action=view&t=comments&show=`, `t=members` (`MalClubDetailsQuery.cs:25,228,301`) | Has, read only (`club_screen.dart`, `club_comments_screen.dart`, `club_members_screen.dart`) |
| MAL news / featured articles | Scrape `/news` (`div.news-unit.clearfix`), `/featured` (`div.featured-pickup-unit`), article body `div.news-container` (`MalArticlesIndexQuery.cs:27-124`, `MalArticleQuery.cs:38`) | Has (`lib/screens/MAL/featured_screen.dart`, news widgets) |
| Calendar with countdowns | The author's VPS `mylovelyvps.xyz/malclient/airing.json`, matched with the user's list by weekday (`AnimeAiringDataQuery.cs:19`, `CalendarPageViewModel.cs:169-240`), export to the system calendar | Has, better (AniList airing schedule, `lib/widgets/calendar/*`, ICS export `calendar_ics.dart`) |
| Random pick from the list | `SelectAtRandomCommand` | Has (`lib/screens/explore/random_picker.dart`) |
| Other trackers | Hummingbird v1/v2 (dead since 2017) | MWL has AniList, Kitsu and Simkl |
| Deep links from MAL URLs | `XS/Utils/MalLinkParser.cs` | Has (`lib/utils/deep_links.dart`) |

---

## 3. What I could and couldn't check (MAL may have changed since 2024)

**Checked live, anonymous, 2026-10-28:** `/profile/{u}` comment markup (changed slightly: `div.comment.clearfix[data-id]` > `div.text` > `div.lh16.comment-text`), `meta[name=csrf_token]`, `/comtocom.php`, `/comments.php?id=` link, `/search/prefix.json`, `/rss.php?type=rw`, `/watch/promotion`, `/forum/search` (`table#forumTopics`), `/history/{u}`, `/animelist/{u}/load.json`, `/character.php?q=`, `/clubs.php?cid=`. The login wall exists on `/notification`, `/mymessages.php`, `/myfriends.php?go=pending`, `/forum/?action=viewstarred`, `/editprofile.php?go=myoptions`. `/login.php` uses **reCAPTCHA v3**. The website list edit `/ownlist/anime/{id}/edit` has **moved** (303 to `/ownlist/anime/add?selected_series_id=`).

**Can't check without a logged-in session (every POST):** `addcomment.php`, `includes/ajax.inc.php?t=10|69|72|73|78|84|85|86`, `ajax.inc.php?s=1&t=13/14/38/39/42/43/47/48` (favourites), `includes/quotetext.php`, `forum/?action=message|post`, `mymessages.php?go=send|read`, `myfriends.php?go=add|confirm|deny|remove`, `clubs.php?action=join|request|leave|invchoice` and the club comment POST, `notification/api/check-items-as-read.json`, the `window.MAL.notification` JSON blob, `auto_recommendation/personalized_suggestions.json`. MAL often renumbers the `ajax.inc.php?t=` ids. **Before building any of these, capture the real request once** from a logged-in desktop browser (DevTools, Network tab, perform the action, "Copy as cURL"), and treat MALClient's parameters as a starting point only. **Review "helpful" (`t=72`) is almost certainly gone:** MAL now uses 7 reaction types.

**Risks that apply to everything marked S:**
- MAL's Terms of Use forbid automated access to the website outside the API. MALClient did it for years, but MAL can break or block it at any time. Keep every S feature optional, behind a "Connect website session" switch, and fail softly (MALClient shows "implementation is pretty hacky" errors: `MalHttpContextProviderBase.cs:159-162`).
- **Google sign-in does not work in an embedded WebView** (Google blocks it with `disallowed_useragent`). Users who log in to MAL with Google must set a MAL password or use another SNS provider. MALClient hit the same problem (`LogInViewModel.cs:113-116`).
- `MALSESSIONID` is very likely HttpOnly, so `document.cookie` from JS won't return it. Read cookies natively (see below).
- Send the same UA as the login WebView, keep requests slow (MALClient waits 150-300 ms between calls: `Query.cs:56`, `AnimeUpdateQuery.cs:~103`), and fetch the CSRF token again whenever a POST answers with `badresult` or a 4xx.

---

## 4. Top 15 to add to MWL, with how to build each

### Step 0 (required by items 1-10): a MAL website session in MWL
Keep the current OAuth login (`mal_auth_v2.dart`) for API v2. Add an **optional second login**:
1. **WebView:** `webview_flutter` is already a dependency. Load `https://myanimelist.net/login.php` with a normal mobile Chrome UA and JS on. When the navigation reaches `https://myanimelist.net/` (or `/#...`), read the cookies **natively**. On Android: a small `MethodChannel` to `android.webkit.CookieManager.getInstance().getCookie("https://myanimelist.net")`. `webview_flutter` uses the system WebView, so it shares that jar and HttpOnly cookies are included. On iOS: `WKWebsiteDataStore.httpCookieStore.getAllCookies`. (Alternative: switch this screen to `flutter_inappwebview`, whose `CookieManager.getCookies` does both platforms. That is a new dependency.) Require `is_logged_in=1` in the jar, like MALClient (`LogInViewModel.cs:217`).
   - Optional, MALClient's trick (`LogInPageFragment.cs:128-145`): in the same WebView, go next to `/v1/oauth2/authorize?...`. The user is already logged in, so this gets the OAuth code at the same time, with a single login for both.
2. **Storage:** the cookie string goes in `FlutterSecureStorage` under its own key, next to the MAL tokens.
3. **HTTP client** (`lib/services/api/MAL/mal_session.dart`, new): `dio` (already a dependency) with a fixed `Cookie` header (or `cookie_jar`), the WebView's UA, `X-Requested-With: XMLHttpRequest` for the ajax endpoints, and `followRedirects: false`.
   - **Validate** on first use: `GET /editprofile.php?go=myoptions`. 200 = valid. 303 to `login.php` = expired, so ask the user to log in again.
   - **CSRF:** read `meta[name=csrf_token]@content` from that response or any page (`package:html`, already used). Cache it for the session and read it again after any `badresult` or 4xx.
   - Every S write is `application/x-www-form-urlencoded` with `csrf_token` added. The only exception is notifications mark-read, which is a JSON body.
4. **UI:** Settings > Accounts > MyAnimeList > "Website features (comments, messages, forum)" with connect and disconnect. Every write button is hidden or disabled when no session exists, and falls back to today's "open on the website" links.

### The 15

| # | Feature | Value | MALClient endpoint | Auth | Suggested MWL build |
|---|---|---|---|---|---|
| 1 | **Profile comments: read, post, reply, delete, conversation** | The owner's example, and the most visible social gap | read: `/profile/{u}` and `/comments.php?id={memId}` (full list, live). Post: `POST /addcomment.php` (`profileMemId, commentText, profileUsername, csrf_token, commentSubmit`). Delete: `POST ajax.inc.php?t=78`. Conversation: `/comtocom.php` | read –, write S | Reading needs no session. Add a "Comments" tab to `lib/screens/user_profile/` that parses `div.comment.clearfix` (`data-id`, `a.fw-b`, `span.fn-grey1`, `div.comment-text`) in the existing scraper `user_profile_page.dart`, with paging through `comments.php`. `profileMemId` comes from the hidden input (only present with a session) or from the `comments.php?id=` link (live). Compose box with BBCode preview using `bbcode_widget.dart`. Delete only when the session page shows the action |
| 2 | **Forum reply and quote** | MWL already reads every topic. Replying is the natural next step | `POST /forum/?action=message&topic_id=` (`msg_text, csrf_token, action_type=submit`); quote `POST /includes/quotetext.php` | S | Swap the `ForumUrls.reply` web link in `forum_posts_screen.dart` for a native composer. On success, reload the last page (`&goto=lastpost`) |
| 3 | **MAL notification hub, mark read, system notifications** | Turns MWL into a place to come back to | `GET /notification`, parse the `window.MAL.notification = {...};` JSON. Mark read: `POST /notification/api/check-items-as-read.json` JSON `{csrf_token, notification_ids}` | S | New `notifications_hub_screen.dart`. Poll from the existing background and notification stack (`lib/services/notifications/*`) at the interval set in `notifications_settings.dart`, with per-type toggles (types in `MalNotificationsTypesEnum.cs`). The JSON shape needs a logged-in capture |
| 4 | **Private messages** (inbox, sent, read, thread, send, reply) | Core MAL social feature, missing everywhere in MWL | `mymessages.php?go=&show=`, `?go=sent`, `?go=read&id=[&threadid=]`, `POST ?go=send&toname=[&replyid=&threadid=]` | S | A messages screen from the profile and home drawer, plus a "Message" button on user profiles (today `icon-message`). Selectors from 1.2. Check the HTML first: `mymessages.php` probably got a new layout |
| 5 | **Favourites toggle** (anime, manga, character, person) | One tap, high use. API v2 can't do it | `POST /includes/ajax.inc.php?s=1&t={13/14, 38/39, 42/43, 47/48}`, `{aid|mid|cid|vaid}, csrf_token` | S | A heart in `detail_header.dart` and `character_screen.dart`. State from the user's own profile favourites, which MWL already parses (`user_profile_page.dart`), cached locally. Check the `t` ids with a capture |
| 6 | **Friend requests** (send with message, pending list, accept, deny, remove) | Completes the friends section | `myfriends.php?go=add&id=`, `?go=pending`, `?go=confirm|deny`, `?go=remove&id=` | S | Buttons in `user_profile_view.dart` driven by the `icon-request` / `icon-remove` classes. A "Requests" sub-tab in `friends_section.dart` |
| 7 | **New forum topic, with poll** (board, club, anime, manga) | Lets the user start discussions from a title's forum tab | `POST /forum/?action=post&boardid=|club_id=|anime_id=|manga_id=` (`topic_title, msg_text, pollQuestion, pollOption[]`) | S | A FAB on `forum_topics_screen.dart` and `club_forum_screen.dart`, and an entry from `forums_section.dart`. Parse `topicid=(\d+)` from the reply to open the new topic |
| 8 | **Watch / unwatch topic, and a "Watched topics" list** | Pairs with #3 (notifications for watched-topic replies) | toggle `POST ajax.inc.php?t=69` (`topic_id, timestamp, csrf_token`); list `GET /forum/?action=viewstarred` (`table#forumTopics`) | S | A bell toggle in the topic app bar. A "Watched" entry on `mal_forum_page.dart`, reusing the topic-row parser in `mal_forum_api.dart` |
| 9 | **Club actions:** join, request access, leave, accept/deny invites, post and delete a club comment, "my clubs" | MWL shows clubs but can't act on them | `clubs.php?action=join|request|leave&id=`, `?action=invchoice`, `POST clubs.php?cid=` (`commentText`), `ajax.inc.php?t=10`, `?action=myclubs` | S | Swap `ForumUrls.joinClub` for a native action in `club_screen.dart`. A composer in `club_comments_screen.dart`. "My clubs" in `clubs_section.dart` for the signed-in user |
| 10 | **Edit / delete own forum post** | Needed once #2 and #7 exist | BBCode `t=85`, edit `t=86` (returns `message_html`), delete `t=84` | S | A post overflow menu in `forum_posts_screen.dart`, shown only when the session page has "Edit" / "Delete" in `div.postActions` |
| 11 | **Friends' activity feed** | Social feed with **no session needed** | `GET /rss.php?type=rw&u={friend}` per friend (live 200, RSS) | – | Fetch the friends from `profile_tabs_source.dart`, then their RSS with at most 2 at once (MALClient's limit, `MalFriendsFeedsQuery.cs:20`), merge by `pubDate`. Show as a home row or a tab. Cache for 15 min |
| 12 | **Compare my list with another user's** | Popular, read only, no session | other list: API v2 `GET /v2/users/{u}/animelist` (public lists) or `/animelist/{u}/load.json?offset=&status=7` (live 200) | O / – | A "Compare lists" button on other users' profiles. Join by id with the local list. Filters mine / theirs / both / status, sort by score difference (copy `ListComparisonViewModel.cs:171-250`) |
| 13 | **Forum search, and posts by user** | Simple, read only | `GET /forum/search?q=&u=&uloc=1&loc={scope}`, `?u={user}&q=&uloc=1&loc=-1` (live 200, `table#forumTopics`) | – | A search action in `mal_forum_page.dart`. A "Forum posts" link on profiles. Reuse the topic-row parsing |
| 14 | **Review reactions (vote)** | MWL already shows the 7 reaction counts | old `POST ajax.inc.php?t=72` (`id, val=1`) is out of date. The new reaction endpoint is unknown | S | Capture the request a reaction makes on the website first. Then make the chips in `review_reactions.dart` tappable |
| 15 | **Popular promotional videos page** | Cheap, content-rich, no session | `GET /watch/promotion`, `div.video-list-outer-vertical` (live 200, 30 items) | – | An explore section (`lib/screens/explore/explore_sections.dart`). Each card opens YouTube with the id from the last href segment. Reuse `videowidget.dart` |

**Also worth noting, lower priority:** an offline update queue for failed list PUTs (MALClient `Settings.AnimeSyncRequired`), the MAL website personalised suggestions (`personalized_suggestions.json`, S), a category filter for club search (`clubs.php?catid=`), Android home-screen widgets, and the Reddit wallpaper browser (low fit for a tracker).

**Order:** step 0 is the gate. Items 11, 12, 13 and 15 need no session and can be built in parallel now. Item 1 can ship its read part now and its write part after step 0. After step 0, build 2, 3, 5 and 4 first: they share the composer, the session client and the CSRF handling.
