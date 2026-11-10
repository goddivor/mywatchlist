# Independent check: batch 4 (dev @ 02ec678)

Setup: a detached worktree `.wt/check-batch4` of origin/dev 02ec678, with assets/.env copied. Built a debug APK, then a profile APK, both under the heavy lock, installed with `install -r` on emulator-5554. The emulator runs `-gpu host` (SurfaceFlinger GLES = Mesa Intel Iris Xe). The worktree is removed. Port 9900 was used for one VM-service forward, now removed. No PIDs are left. The active account is back to MAL. The installed MWL is now the 02ec678 **profile** build. Nothing was written to any account: no send, comment, vote or mark-read.

Gate: `tools/heavy.sh tools/verify.sh` = **VERIFY OK** (analyze clean; flutter test +1668, all passed; mwl-api analyze clean). `mwl-api` has no `package:test`, so `dart test` there cannot run; its fixtures are exercised by `test/units/backend-parsers`.

Legend: **[RUN]** = reproduced on the emulator, by curl or by command. **[READ]** = from reading the diff only (three read-only review passes, not re-run).

## Verdicts
| unit | verdict |
|---|---|
| mal-notifications #262 | works with defects |
| mal-messages #264 | works with defects |
| mal-hub-wiring #273 | works with defects |
| mal-hub-followups #289 | works |
| mal-web-recaptcha #302 | works with defects (send path not exercised live) |
| mal-profile-extras #300 | works with defects |
| mal-episodes #272 | works with defects |
| mal-detail-sidebar #284 | works |
| mal-list-time #278 | works with defects |
| mal-seasonal-groups #271 | **broken** (stuck state) |
| mal-ona-ranking #296 | works with defects |
| ux-home #229 | works |
| ux-search #276 | works with defects |
| ux-reviews #277 | works |
| ux-theme #265 | works |
| ux-polish-2 #283 | works with defects (one goal not delivered) |
| small-fixes #267 | works |
| kitsu-graphql #266 | works |
| kitsu-community #275 | works with defects |
| kitsu-home-extras #288 | works with defects |
| kitsu-media-page #290 | works with defects |
| kitsu-profile-plus #303 | works with defects |
| simkl-profile-plus #269 | works (tests and read only) |
| simkl-list-sync #282 | works with defects [READ] |
| simkl-redesign #298 | works with defects [READ] |
| anilist-client-limits #270 | works |
| anilist-social #291 | **broken** (thread page) |
| anilist-settings #301 | **broken** (unreachable) |
| anilist-list-fidelity #293 | works with defects |

## Blocking
1. **anilist-social: the forum thread page breaks the widget tree. [RUN]**
   - Steps: active account AniList, Forum tab, tap "[Spoilers] The Apothecary Diaries Season 3 - Episode 3 Discussion" (or Ep 2).
   - Observed: the page paints the header pieces piled up at the top over an empty body. Taps go nowhere, because the semantics still show the forum list. Back then gives red screens: `_dependents.isEmpty` (framework.dart:6171) and `_owner != null` (object.dart:2370). Reproduced on 2 cold starts.
   - First error, captured through the VM service: "RenderConstrainedBox / _RenderScaledInlineWidget object was given an infinite size during layout". It is thrown in the header Column (`lib/pages/Anilist/anilist_thread_page.dart:266-330`), under BoxConstraints(w=379.4, h<=Infinity).
   - Suspected cause [READ]: an inline image in `AnilistHtml` (`lib/widgets/Anilist/social/anilist_html.dart:95-110`). It is an `InlineCustomWidget` holding a `SizedBox(width:)` with an `AppImage` that has a width and no height, inside unbounded height.
   - The unit tests pass, so their fixtures do not include such a body.
2. **mal-seasonal-groups: a stuck empty state. [RUN]** `lib/screens/seasonal/seasonal_screen.dart:397,403`.
   - Steps: Explore, Search By Season, pick "Continuing", switch to Spring 2027 or Winter 2027.
   - Observed: "No anime matches these filters". The All/New/Continuing chips are hidden (they render only when `_continuing.isNotEmpty`), and "Clear filters" does nothing (it does not reset `_group`).
   - The choice is global (`seasonal_group_v1`), so every season without leftovers is empty until the user goes back to a current season. I reset it to All afterwards.
3. **anilist-list-fidelity: an AniList list tap opens the MAL detail screen. [RUN]** `lib/widgets/Anilist/anilist_user_list_adapter.dart:175` calls `openAnilistMedia`, which opens MAL when the title has `idMal`.
   - Steps: AniList active, My List, tap "Fujimoto Tatsuki 17-26". It opens the MAL detail page (16 MAL tabs).
   - Required: the tracker never opens the MAL page. Until anilist-media-page merges, use `openAnilistTitle`, the stopgap the other AniList screens use.
4. **anilist-settings: the page cannot be reached. [RUN by grep]** Nothing outside its own files constructs `AnilistSettingsPage`: `grep -rn "AnilistSettingsPage(" lib` matches only the page file. It needs an entry point (Settings, or AniList account options).
5. **kitsu-profile-plus: profile titles open the website. [RUN]**
   - `lib/widgets/Kitsu/profile/kitsu_profile_rows.dart:12-23`: `KitsuTitleLinks.opener` still defaults to the web view.
   - Steps: Kitsu active, Profile, Activity, tap "Temppal: Item no Chikara". A Chrome custom tab opens on kitsu.app. Required: the native Kitsu title page.
   - Per the reader, the same opener serves reactions, list rows and favourites (`kitsu_favourites_tab.dart:146`), and the Posts tab opens the web view although `KitsuPostPage` exists (`kitsu_posts_tab.dart:91`). [READ]

## Should fix
- **kitsu-media-page: the title page offers "Open on MyAnimeList". [RUN]** `lib/pages/Kitsu/kitsu_media_page.dart:161-180`. The item is present in the ⋮ menu, against the rule that a tracker title never opens the MAL page. simkl-redesign keeps the same item at `lib/pages/Simkl/simkl_media_page.dart:254` [READ]. The orchestrator decides whether an explicit menu item is allowed.
- **Kitsu JSON:API text is decoded as Latin-1 (mojibake). [RUN]**
  - Steps: Kitsu home, row "Popular with people you follow". The title reads "Jujutsu Kaisen: Shimetsu KaiyÅ« Zenpen"; the native page, read over GraphQL, shows it correctly.
  - Cause [RUN by curl]: Kitsu sends `content-type: application/vnd.api+json` without a charset, and `lib/services/api/Kitsu/kitsu_http.dart:106-107` decodes `response.body`. It should use `utf8.decode(response.bodyBytes)`, as `kitsu_graphql.dart:1341` does.
  - The code dates from kitsu-pages #151 but shows up in kitsu-home-extras' rows and in every JSON:API Kitsu screen.
- **kitsu-profile-plus: the time percentile is wrong. [RUN + curl]** The profile says "More than 1% of users", while the API answers `percentiles.time = 0.99`. `kitsu_profile.dart:240` with `kitsu_profile_view.dart:~402` treats a 0-1 fraction as 0-100.
- **List rows overflow on two-line titles (shared list row). [RUN]** "BOTTOM OVERFLOWED BY 11/12 PIXELS" on Kitsu My List ("Re:Zero … 4th Season") and on AniList Completed (every two-line title). The list-mode row has a fixed cover height (`lib/widgets/user/list/cards/entry_cards.dart:~132`). It probably predates this batch (#96), but it is visible on every tracker list.
- **mal-profile-extras: the Blog tab shows the sidebar as a post. [RUN]**
  - Steps: open `https://myanimelist.net/profile/Stark700` (deep link), Blog tab. The first card is "Categories / Anime CardsAnime Cards #2Charts…No categories / No comments".
  - Cause: `parseProfileBlogPage`, `lib/screens/user_profile/sections/profile_tabs_source.dart:618`, takes every `#content .normal_header`, including the categories block.
  - Reviews and Recommendations render correctly against live counts (curl: 20 `review-element`, 30 recs). The owner's empty states are genuine (MAL says "No reviews").
- **mal-episodes: page chips skip most pages. [RUN]**
  - One Piece episodes screen: the chips read 1-100, 101-200, 201-300, 1101-1200. MAL's pager only links nearby offsets (curl: offset 0, 100, 200, 1100), so reaching ep 1001 (the user's next episode) takes about 8 taps through the sliding window.
  - Build the chips from the total or the last offset (`episodes_screen.dart:55-65`, `episodes_page.dart`).
  - Also [RUN]: the reply count is a bare number ("Oct 20, 1999 · 414") with no icon (`episodes_screen.dart:~105`).
  - [READ]: the Jikan fallback has no page chips.
- **mal-notifications / mal-hub-wiring: no unread count on the bell after a cold start. [RUN]**
  - 50 s after a cold start, the home bell shows no badge (content-desc "Notifications"), although MAL has 25 unread. The count appears only after the Notifications screen is opened.
  - [READ] cause: the poller's first run waits `firstDelay` 30 s, then up to `interval - since` (30 min) when it polled recently, and the count is not restored at startup.
- **mal-notifications / mal-hub-wiring: duplicate alerts are possible. [READ]**
  - The foreground poller never calls `SharedPreferences.reload()` (`mal_hub_poller.dart:254,514,600`). Only the worker does (`main.dart:367`).
  - So items the worker notified while the app was alive get notified again, and the seen lists get overwritten.
  - The worker also polls with `force: true` every 30 min, which bypasses the 3 h friends interval (`main.dart:377`): the friends page plus up to 40 RSS feeds each time.
- **mal-messages. [READ]**
  - The thread decrements the unread badge on every refresh of an initially unread message (`mal_messages_api.dart:621`).
  - The Send button's enabled state is cached in a `ListenableBuilder` child (`compose_message_screen.dart:161`), so it may stay disabled after the session gate connects.
  - A markup change shows "Inbox empty" instead of an error (`mal_messages_api.dart:288`).
- **mal-web-recaptcha. [READ]** "Sent" is assumed whenever the result page has no `.badresult` and no textarea (`mal_messages_api.dart:473-482`), and the outcome is read from the next `onPageFinished` without checking the URL. The result can be a false "sent" or a false "refused", and a refused send invites a duplicate PM. Not exercised live (no send allowed).
- **mal-seasonal-groups: fluidity. [RUN]** The seasonal grid scrolling into new content is clearly jankier than DAL. Profile build, `measure-scroll.sh --no-restart`:
  - MWL: 14.3 %, 39.7 % and 20.0 % janky (17-23 severe) on fresh content; 4.0 % warm.
  - DAL: 0.0 %, 0.0 %, 11.1 % and 0.0 %, plus one 91 % outlier that did not repeat.
- **mal-ona-ranking. [READ]** The Jikan route sends no `sfw`, so Rx ONAs show with NSFW off; it is capped at 25 per page and carries no `my_list_status`.
- **ux-polish-2 / ux-search: goal not delivered. [READ]** `search_results_part.dart:112,190` still passes no `index` to `MediaTile`, so rows show the overall MAL rank and not #1, #2…
- **mal-list-time. [READ]** Airing shows with `num_episodes = 0` are silently left out of "Time left", with no "+" (`list_entry_view.dart:319`).
- **kitsu-community / kitsu-home-extras / kitsu-media-page / simkl / anilist. [READ]**
  - The feed keeps only posts and never fetches the next page when a page has no post (`kitsu_feed.dart:68-73`). Forum News showed posts live, so this was not reproduced.
  - Reactions, cast and staff are asked without `pageInfo`, so they are capped and have no "View all" (`kitsu_graphql.dart:1430-1439`).
  - A paged tab spins forever on an empty page with `hasNextPage` true (`kitsu_paged_tab.dart:123-132`).
  - Favourites stop after 200 (`kitsu_social.dart`).
  - "Surprise me" accepts only MAL-mapped titles (`kitsu_catalog.dart:231`).
  - Simkl: a refresh overwrites the stale marks of edits made during it (`simkl_list_service.dart:178,199-205`); "Up next" keeps a local copy across refreshes; the next air date is reduced to a weekday.
  - AniList: list cards always show 0-10, even for the owner's POINT_5 account (`anilist_list_service.dart:266`). This contradicts a DECISIONS entry, so it needs a decision. The scores visible on device were mean scores, so it was not seen on cards.
  - The thread page's `_loadingMore` can stick on refresh (`anilist_thread_page.dart:87`).
  - Two quick settings toggles drop the second save (`notification_types_sheet.dart:43`).

## Minor
- **Merge tooling. [RUN]** Squash subjects are broken: 7ebc8c6 is " (#302)" (empty), and 1351274 is a GitHub 422 JSON error. Cause: `tools/mab/merge-unit.sh:171` `TITLE=$(gh api …)` has no failure check under `set -uo pipefail` without `-e`.
- **Profile header. [RUN]** The raw IANA time zone is shown with no label ("America/Los_Angeles").
- **Profile tab strip. [RUN]** Its uiautomator bounds don't match the painted chips: every tab reports a 105 px box while the selected chip is wider. This is an accessibility mismatch.
- **Messages inbox. [RUN]** A message with an empty subject leaves a blank line (NaTsu879).
- **Kitsu feed. [RUN]** Relative times carry a double space ("2  minutes ago"). The Groups tab has a large empty band under the search field.
- **[READ]**
  - The notifications screen's own push toggles don't call `MalBackgroundPolling.sync()`.
  - `ForumAvatar` keeps one `ValueNotifier` per name, never removed (`forum_common.dart:51,94`).
  - Episode synopsis errors show "No synopsis".
  - Reviews sorted by "Helpful" re-sort when more pages load.
  - The Message action shows without a MAL account.
  - The Kitsu followed-trending cache key leaves out the user.

## Verified working [RUN]
- Bell → Notifications: 25 items, filters, per-item mark buttons (not tapped).
- Friends activity: statuses and progress.
- Sidebar Notifications (with the count) and Messages.
- Messages: Inbox and Sent with pictures; thread with bubbles and the reply bar (nothing typed).
- Profile Comments, with images.
- Other users' Reviews and Recommendations.
- Detail: Episodes tab and section, "Next episode Ep 1002", More info rows (producers, licensors, demographic, added to MAL).
- Top ONA: Jikan, paging, 18+ marks.
- My List "Time left".
- Kitsu: home rows, native title page from a list tap and from a home row, profile stats and activity, forum Latest/News/Groups.
- AniList: list (1166 entries), forum list.
- Fluidity, profile build:
  - Home: MWL 4.0 % / 3.2 % vs DAL 0.8 % / 5.6 %.
  - Notifications: 4.0 %. Friends activity: 0.0 %.
- Logcat had no Flutter errors outside the AniList thread crash, whose errors reach only the VM service.

## Not covered
- Simkl on device (not connected).
- Any write path (send, reply, mark-read, likes, AniList settings saves).
- 18+ marks on the detail page.
- Kitsu reactions and followers tabs.
- AniList Activity and Reviews screens: the app wedged on the thread page first.
