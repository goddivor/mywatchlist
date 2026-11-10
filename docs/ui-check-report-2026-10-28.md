# UI check batch 5 — MWL vs DailyAL (emulator-5554, gpu host Intel Iris Xe)

Build: origin/dev 2a91650 (PR #181 character pages NOT merged: character page not in this build).
Screenshots: /tmp/claude-1000/-home-thinkpad-Bureau-android-project-mywatchlist/8d2dea9f-b783-45d3-8428-97ab92059dee/scratchpad/shots/

## 0. Theme
DailyAL current: color = brown swatch, mode = auto (light on emulator), background image = autumn leaves.
MWL before: Black mode, orange accent, background image on (winter snowflakes).
MWL set to (Settings > Theme Settings, app setting only): color = brown swatch (row 3, last), mode = Auto, background = autumn leaves (first picture). Result matches DAL closely (shots/trio-home.png).

## 1. Splash / cold start (shots/trio-mwl-start.png)
- Works: dark navy screen with white "mwL" logo, then home. No white flash. Launcher activity resolves (com.teen.mywatchlist/.MainActivity).

## 2. Home (shots/trio-home.png: MWL middle, DAL right)
- Section title "Anime News" (DAL: "News"); news card title in heavy ExtraBold white-ish, DAL uses regular weight: MWL reads louder and denser.
- Header icons sit in a grey pill container + extra account avatar with a switch badge at top right (DAL: plain icons, the avatar is in the bottom bar). Two avatars/profile entry points on one screen (top avatar + bottom "profile" tab).
- Seasonal cards carry an extra date banner on top ("Oct 3, 2026", "Apr 22, 2005") that DAL does not show; DAL shows "8.72 | 2.74M" small and the user's status/score badge (green "★10") at the corner. MWL does not show the user's list status on home cards.
- "Fall 2026 Anime" content differs: MWL starts with Black Clover 2nd Season then Doraemon (2005); DAL starts with One Piece, Meitantei Conan (sorted by members). Ordering looks unsorted in MWL.
- Bottom bar order: MWL home/forum/list/profile/explore, DAL home/forum/list/explore/avatar. MWL profile tab is a generic person icon.

## 3. Search (shots/trio-search-home.png, shots/trio-search.png, shots/pair-search-res.png)
- DEFECT (verified, should fix): default "All" search shows WRONG data for anime/manga rows: "Sousou no Frieren 2nd Season · 884 members" (real: 630,307 members, score 8.84, 10 eps), "Sousou no Frieren · 924 members" (real 1.54M). No score, no episode count shown. Cause: lib/services/api/MAL/scrapper/html_parsers.dart:76-90 assumes the fn-grey4 block is [type+eps, "Scored x", "n members"], but MAL now prints ["TV", "(10 eps)", "Scored 8.84", "630,307 members"]: eps parsed from "TV" (null), score from "(10 eps)" (null), members from "Scored 8.84" (=884). Repro: curl -A Mozilla "https://myanimelist.net/search/all?q=frieren&cat=all", or search "frieren" in MWL. Fix: parse each line by content (regex "(\d+) eps", "Scored ([\d.]+)", "([\d,]+) members"), not by index.
- First result took > 7 s (spinner) on "All"; DAL answers in ~2 s with per-category tabs.
- Result row: no rank, no score (see defect), no edit button; DAL row shows #rank, score (users), type (eps) and a pencil.
- Search home: MWL shows "Recently opened anime" + "Recently opened manga" as big 2-column posters, a chip season picker + year dropdown + Search button (DAL's picker = year row + season row + "Search By Season"/"Weekly Anime", which Explore now uses since #182: two different season pickers in the app), 22 ranking chips, then an icon + "Search anime, manga, characters, users and more" + "Start with # for special searches..." tip. DAL shows History, Recent Anime, Search By Season, Anime Categories. MWL is much denser (wall of small chips).
- Filter panel opens inline (not a sheet) with chips for categories, Reset / Close / Apply; DAL: radio list with Reset / Save / Close. OK.

## 4. My List (shots/pair-mylist.png, shots/pair-listfilter.png)
- Grid cards match DAL (works). Toolbar has 4 controls (search icon, "Last updated" sort button, filter, view toggle) + Anime/Manga toggle + search circle + account avatar on top: more controls than DAL (search pill, refresh, filter). The top search circle and the toolbar search icon look like the same action twice.
- Filter sheet: useless hint "Tap a value to keep only matching entries; tap it again to exclude them." (UserList_Filter_Hint, lib/widgets/common/list_sort_filter.dart:565). DAL has none.

## 5. Profile (own) (shots/trio-mwl-profile.png, trio-mwl-prof2.png, trio-mwl-prof3.png vs pair-dal-profile.png, trio-dal-prof.png)
- Stats/Friends/Clubs/History/Favorites all load (works). MWL stats page is richer than DAL's (DAL's score distribution shows zeros); keep MWL here.
- Useless text: "Based on scored entries only" under Genres and Media types cards (subtitle), "Source: MyAnimeList" under score stats on detail. DAL shows none.
- Friends rows add a third line "Friends since Feb 28, 4:14 AM" (DAL: name + last seen only): denser, adds little. Time-of-day in "friends since" is noise.
- Clubs: "2026 Challenge" listed twice (17 clubs; DAL lists different/fewer). Suspected duplicate rows (not proven; may be two clubs with same name). Rows have trailing chevrons DAL lacks.
- Tabs are plain text and the strip scrolls (6 tabs do not fit; History is off-screen); DAL uses an icon row where all 6 fit and the selected one shows its label.

## 6. Another user's profile from a reviewer (shots/trio-other.png, pair-other.png)
- Works: tapping the reviewer opens a preview sheet (avatar, mean, entries) with "Open full profile", "Open in Browser", "Report user", then the full profile loads (Stats etc.).
- Extra step vs DAL: DAL opens the user directly (a sheet with the list). MWL needs tap avatar -> sheet -> "Open full profile".
- GAP (should fix): no "List" tab on another user's profile (UserProfileTab = stats, friends, clubs, about, favorites, history: lib/screens/user_profile/user_profile_view.dart:24). DAL prepends a List tab for other users and opens on it (dailyal-108 lib/screens/user_profile.dart:124-129, 368-380). You cannot browse a reviewer's/friend's list in MWL.
- Unlabeled icon facts "Aug 22, 1959" (birthday) and "Oct 26, 4:08 PM" (clock = last online?) are ambiguous; DAL uses labelled tiles (Location / BirthDay).

## 7. Anime detail (Sousou no Frieren 2nd Season; shots/mwl-detail*.png, t1.png t2.png t3.png vs trio-dal-detail-*.png)
- Header and section order match DAL (works). Title is ExtraBold (DAL regular); FAB uses the status colour (bright blue "Completed") where DAL uses a tonal button: the FAB is the loudest thing on the page and covers content on every scroll position.
- Characters section = DAL layout (character left, VA right, role/language) (works). Staff: rows with placeholder person icon for missing pictures (ok).
- Reviews: DAL-like cards (works); default sort "Newest first" (DAL "Helpful"); MWL adds a bar-chart button opening a "Score distribution" dialog of the loaded reviews (extra control, low value); DAL's AI-summary sparkle is not in the section header.
- Adaptations: MWL big card with "Adaptation" chip + chevron; DAL small picture tile with title + "manga". The chip repeats the section title (useless).
- Featured Articles empty: MWL renders an empty state "No featured articles yet" with an icon (section kept); DAL just shows the section only with content. Useless block.
- News (detail): loads (works).
- User Updates: skeleton forever in both apps (Jikan down), same as DAL.
- Score stats: extra caption "Source: MyAnimeList".
- Characters & staff "view all" page (shots/pair-chars.png): list of characters with heart counts and a "6 voice actors" chip that expands VAs inline (works). Thumbnails are not a fixed size: Flamme's picture is taller/wider than the others and pushes her text right (misaligned column). DAL's "all characters" list is the same character/VA row as the detail section.
- Character page: "Could not load this page" + Try again (expected: PR #181 is not merged, so this build has no MAL fallback for characters).
- Edit sheet (opened only, closed with X, nothing saved; shots/trio-edit.png, pair-edit-close.png): MWL = Status dropdown, Episodes chip row + grid-picker icon, Score chip row, Delete from List, More options, then a second floating panel "Other trackers" (AniList, Kitsu rows with spinners, then status chip, Edit, Sync). DAL = one compact card: Status button, Episodes -/+ stepper, Score chips, Delete. MWL is two stacked panels, heavier and slower (spinners each open). The close FAB (X) covers the Kitsu row's "Sync" button (cut to "S"), verified on screen. "Other trackers" caption "MyAnimeList · Completed · 10 · Ep. 10" repeats what the sheet already shows.

## 8. Explore (shots/trio-explore.png, trio-explore2.png vs pair-dal-explore.png)
- REGRESSION, BLOCKING (verified): below "Seasonal", every strip (Recommendations, Reviews, Interest Stacks, Characters, Seiyuu) renders as a big flat grey box (Flutter's release ErrorWidget) and stays grey. Logcat on first open of Explore: "type 'ItemPosition' is not a subtype of type 'double?' in type cast  #0 ScrollPosition.restoreScrollOffset (scroll_position.dart:538)" then "Another exception was thrown" xN. Cause: #182 (d718462) put DailyAL's HeaderWidget (ScrollablePositionedList, lib/widgets/MAL/search/headerwidget.dart:58) in the Explore seasonal picker (lib/screens/explore/explore_sections.dart:422) inside CustomScrollView(key: PageStorageKey('explore-$category')) (lib/pages/MAL/mal_explore_page.dart:45); it writes an ItemPosition into PageStorage under the same identifier the unkeyed horizontal ListViews of the following strips read as their scroll offset. Repro: install, tap Explore, scroll down. Fix: give the HeaderWidget list (or each strip ListView) its own PageStorageKey, or wrap HeaderWidget in its own PageStorage(bucket: PageStorageBucket()).
- Top of page (shots/trio-explore2.png): MWL adds a search field ("Search anime, manga, characters and m...") under the app bar that already has a search icon (two search entries), Anime/Manga segmented button with icons, then Random / Watching / Plan To Watch as FILLED dark-brown buttons. DAL: tonal pill buttons with coloured icons. MWL's filled buttons are the heaviest element on the screen.
- Rankings/Genres picture cards: bold white title + count caption ("18 genres", "3 genres", "52 genres"); DAL shows the title only, faded picture. Counts are useless text (Exp_Genre_Count, lib/screens/explore/explore_sections.dart:177).
- Studios entry: card with icon + "Studios" + caption "Every anime studio, with its logo and its anime" + chevron (Exp_Studios_Caption, lib/screens/explore/explore_sections.dart:383). Useless caption.
- Section headers: "View All >" text buttons (DAL: an arrow icon), bold titles (DAL regular).
- Initial scroll restore: opening Explore the first time landed mid-page with the cards drawn under the status bar (shots/mwl-explore.s.png); suspect linked to the same PageStorage confusion.
- Content scrolls under a transparent status bar once the floating app bar hides ("Rankings" drawn under the clock, shots/pair-tmp.png right). DAL tints the status bar.
- Studios directory (shots/pair-studios.png): works (logos, JP names, counts). Rows carry "142 anime · 40,454 favorites" + chevron. Tapping a studio opens search with the studio chip: works, but the list is alphabetical ("48x61", "A-Girl" first); a popularity/members order would surface known titles first.
- Search filter by studio "Arch" (verified): Filters > Studio > search "Arch" > pick > Apply returns Arch's 7 anime (I Like U, Journey, Madoromi no Vevara, Monster Strike x2, Sekiro, Shinsei Galverse). Works.
  Useless text in the filter panel: 'Pick "Order by" first' under Direction (shown as a disabled hint; hide the Direction row until an order is picked), "857 options" count at the top of the studio picker (Kit_Options_Count). The studio picker does not show the current selection (Madhouse) as selected.
  Trap: pressing Back/Escape in the studio picker with the keyboard open closes the picker without keeping the typed search.

## 9. Seasonal (shots/quad-season-cal.png, 1st vs 2nd)
- MWL: app bar "Seasonal · Fall ..." (truncated) with 3 round icon buttons (filters, search, calendar) over a saturated leaves picture, then a big "Fall 2026" title with a leaf icon, then "< Fall v  2026 v >" pickers, then "196 anime", then a 3-column grid. The season is stated three times. DAL: "Seasonal" + season tabs (Winter 2027 / Fall 2026 / Summer 2026), a search/refresh/filter row and a list with score, users, status, eps, countdown, +/edit/- buttons. DAL's list shows the user's progress and quick +/-; MWL's grid shows only score and status chip.
- Works (loads 196 anime without Jikan).

## 10. Calendar (shots/quad-season-cal.png 3rd vs 4th, shots/pair-tmp.png left)
- MWL opens on "Today" with "Nothing airs on this day" (Today = 0) at 18:40 UTC although two shows of the user's list (Sekai Saikyou no Majo 13:00, Kikansha no Mahou 15:45) air on Wednesdays: MWL only keeps upcoming episodes (lib/widgets/calendar/airing_schedule.dart:87), so today's already-aired ones vanish and the first screen is empty. DAL opens on the whole week grouped by day (Wednesday (2), Thursday (1)...) with the user's Plan To Watch + Watching filter on. Proposal: replicate DAL's week list (dailyal-108 lib/widgets/home/anime_calendar.dart) or at least show today's aired episodes and open on the first non-empty day.
- Day view with cards works (Tue: 10 entries, status chip "Watching"). Extra caption "95 episodes this week" (Cal_Week_Count) DAL does not show.
- Explore, second visit (shots/trio-explore-b.png): now the TOP of the page (search field, Anime/Manga, Random/Watching, Rankings, Genres, years row) and everything below Recommendations are grey boxes; only Seasons/Studios/Recommendations draw. The page is unusable after the first visit. Blocking.

## 11. Forum (shots/pair-forum.png)
- Works. MWL rows: bold title (2 lines) + author line + "Last post by X, date" line + reply-count pill; DAL: regular-weight title + one "author · date ... N Posts" line. MWL is 3 text lines per topic with bold titles: denser and louder. Board cards use an up-chevron (expand) that reads as "collapse"; DAL shows a list icon. "Anime discussions" chip is filled dark brown (DAL: tonal pill).

## 12. Sidebar (shots/pair-sidebar.png)
- Works (opens from the header avatar). Items: Profile, Stats (both open the profile), Bookmarks, Anime Calendar, Settings (all three duplicate header icons), About, Add an account, Log Out (red, one tap away from Add an account), "MyWatchList · Version 2026.10.1". DAL's AppSideBar (dailyal-108 lib/pages/side_bar.dart:110-126) lists the profile sub-pages (Stats, About, Friends, Clubs, Favorites, History, Calendar, Bookmarks): more useful targets. Proposal: replicate DAL's item list; drop "Profile"+"Stats" duplicates.

## 13. Settings + Theme (shots/trio-settings.png, trio-theme.png, pair-theme-set.png)
- Settings: grouped cards with section headers (Account / Appearance / Content / Data and storage / Information), icon tiles and chevrons; DAL: flat list, big centred title. MWL grouping is clearer for 15 entries: keep MWL. Footer "Made with Flutter" (also in DAL, keep or drop).
- Theme settings: useless text "Your color stays, whatever the background" with a pin icon under the swatches (Theme_Accent_Now_Fixed, lib/screens/settings/theme_settings.dart:501) and a whole "Preview" card (Button / Tonal / Filter / status chips) DAL does not have (lib/screens/settings/theme_settings.dart:433). "Select a background image" title wraps on 3 lines next to the (i) and the switch (row too narrow). Mode buttons are 2x2 outlined tiles with icons (DAL: one row of text pills) - fine.

## 14. Interest stack page (shots/pair-stack.png)
- Works (description, Entries / Similar stacks / MyAnimeList stacks tabs, 100x150 covers, score, users, type, genres, info + edit buttons).
- Title lower-cased: "Animes in which koeda animation has participated (part 2)" while the card says "Koeda Animation ... (Part 2)": lib/screens/MAL/interest_stack_detail_screen.dart:110-111 calls standardize() (= capitalize(), lower-cases the rest, lib/constants/constants.dart:437-440, 477). DAL has the same bug (dailyal-108 lib/pages/animedetailed/intereststackwidget.dart:213); improve: show the title as MAL gives it. Minor.
- The floating round back and menu buttons stay on top while scrolling and cover the first entry's title and its info button. "MyAnimeList stacks" tab label wraps on two lines.

## 15. Fluidity (tools/perf/measure-scroll.sh, profile build, gpu host)
| screen | MWL janky % (severe) | DAL janky % (severe) |
|---|---|---|
| Home | 1.6 (2) | 6.3 (2) |
| My List | 3.2 (2) | 4.0 (0) |
| Anime detail | 0.8 (1) | 0.0 (0) |
| Explore | 0.8 (0) (NOT valid: most strips are grey error boxes) | 2.4 (2) |
Baseline 2026-10-27 was MWL 22 % on home: big improvement. No screen clearly jankier than DAL (Explore must be re-measured once fixed).

## 16. Home "Fall 2026 Anime" content (verified, cause not found)
MWL requests MalApi.getAnimeSeasonal(sortType: AnimeNumListUsers) (lib/pages/MAL/mal_home_page.dart:442-447). The same API call (curl, same fields) returns One Piece 2.74M, Meitantei Conan, Steel Ball Run, Kusuriya 3, Cyberpunk Edgerunners 2, Black Clover 2nd Season... MWL's row starts with Black Clover 2nd Season then Doraemon (2005) (24K members, not in the top 10), also after pull-to-refresh. The top 5 (all in the user's list) are missing and an unrelated item follows. Should fix: investigate HomeAsync cache (lib/widgets/home/home_sections.dart:97) and the row source; DAL shows the top titles with the user's status badge.

# USELESS TEXT (MWL shows, DAL does not; adds nothing)
| # | Text on screen | Key | Renders at |
|---|---|---|---|
| U1 | "Search anime, manga, characters, users and more" + "Start with # for special searches, for example #airing, ..." (search home, bottom) | Srch_Start_Title, Srch_Special_Tip | lib/screens/search/search_home_view.dart:115, :121 |
| U2 | "Tap a value to keep only matching entries; tap it again to exclude them." (My List filter sheet) | UserList_Filter_Hint | lib/widgets/common/list_sort_filter.dart:565 |
| U3 | "Tap once to include, twice to exclude, three times to clear." (search genres) | Srch_Genres_Hint | lib/screens/search/search_filter_panel.dart:762 |
| U4 | "These options apply to anime and manga results." (search Display tab) | Srch_Display_Hint | lib/screens/search/search_filter_panel.dart:281 |
| U5 | 'Pick "Order by" first' (search Filters, Direction) | Srch_Needs_Order | lib/screens/search/search_filter_panel.dart:397 |
| U6 | "857 options" (any searchable picker, e.g. Studio) | Kit_Options_Count | lib/widgets/common/select/searchable_select.dart:151 |
| U7 | "Every anime studio, with its logo and its anime" (Explore Studios card) | Exp_Studios_Caption | lib/screens/explore/explore_sections.dart:383 |
| U8 | "18 genres" / "3 genres" / "52 genres" under genre picture cards | Exp_Genre_Count | lib/screens/explore/explore_sections.dart:177 |
| U9 | Search field "Search anime, manga, characters and more" under the Explore app bar (second search entry) | Explore_Search_Hint | lib/pages/MAL/mal_explore_page.dart:216 |
| U10 | "Based on scored entries only" (profile Genres / Media types cards) | Prof_Dist_Scored_Only | lib/screens/user_profile/sections/stats_section.dart:501 |
| U11 | "Friends since Feb 28, 4:14 AM" third line per friend | Prof_Friends_Since | lib/screens/user_profile/sections/friends_section.dart:140 |
| U12 | "Source: MyAnimeList" under score stats (detail) | Res_Source_Mal | lib/widgets/MAL/content/scorestatisticswidget.dart:140, :258 |
| U13 | "No featured articles yet" empty block (detail) | Res_Featured_Empty | lib/widgets/MAL/content/show_featured.dart:383 (hide the section instead) |
| U14 | "Adaptation" chip on each adaptation card (repeats the section title) | relation.type via Rg_Rel_Adaptation | lib/widgets/MAL/content/adaptation_widget.dart:67 |
| U15 | "95 episodes this week" (calendar) | Cal_Week_Count | lib/screens/calendar/calendar_screen.dart:178 |
| U16 | "Connect MyAnimeList to highlight the anime on your list." (calendar, signed out) | Cal_Connect_Hint | lib/screens/calendar/calendar_screen.dart:222 (not seen signed in) |
| U17 | "Your color stays, whatever the background" + pin icon (theme) | Theme_Accent_Now_Fixed (and the season/wallpaper variants) | lib/screens/settings/theme_settings.dart:497-501 |
| U18 | "Preview" card with sample buttons/chips (theme) | Preview | lib/screens/settings/theme_settings.dart:433 |
| U19 | "Other trackers" + "MyAnimeList · Completed · 10 · Ep. 10" (edit sheet) | Sync_Section_Title + summary | lib/widgets/user/sync/ (sync panel under the edit sheet) |
| U20 | "A short verdict with the pros and cons found in the reviews" (AI summary card subtitle) | Social_AI_Summary_Hint | lib/widgets/MAL/review/review_summary.dart:110 (not reached in this walk) |
| U21 | "Tap a title for details, long-press it to select it..." (relation graph) | Rg_Legend_Hint | lib/widgets/graph/anime_graph_screen.dart:281 (not reached) |
Settings-row subtitles (Prefs_*_Desc, Notif_*_Desc) are kept: DAL's settings rows also carry a subtitle.

# FIX PROPOSALS, GROUPED BY FILE (disjoint sets)
A. lib/pages/MAL/mal_explore_page.dart + lib/screens/explore/explore_sections.dart + lib/screens/explore/explore_widgets.dart (Explore unit)
 1. BLOCKING: give HeaderWidget its own PageStorage (wrap in PageStorage(bucket: PageStorageBucket(), child: HeaderWidget(...)) at explore_sections.dart:422) or a PageStorageKey per strip ListView. Re-measure Explore fluidity afterwards.
 2. Drop the extra search field (U9), Exp_Studios_Caption (U7), Exp_Genre_Count (U8). Replicate DAL's tonal Random/Watching/Plan To Watch buttons with coloured icons (dailyal-108 lib/pages/explorepage.dart:420-450, _randomButton) instead of filled brown ones; replicate DAL's arrow-only section header instead of "View All >"; regular-weight titles.
 3. Status-bar scrim when the floating app bar is hidden.
B. lib/services/api/MAL/scrapper/html_parsers.dart:76-90 (search parser, alone)
 4. Parse search/all lines by content ("(n eps)", "Scored x", "n members"), not by index. Add a fixture test with the current MAL markup.
C. lib/screens/search/search_home_view.dart + search_tiles.dart + search_filter_panel.dart + lib/widgets/common/select/searchable_select.dart (search unit)
 5. Remove U1, U3, U4, U5 (hide Direction until an order is set), U6.
 6. Result row: replicate DAL's row (dailyal-108 lib/screens/generalsearchscreen.dart result list): #rank, score + users, type (eps), pencil.
 7. Season picker on search home: reuse Explore's SeasonalPicker (DAL SeasonalWidget) so the app has one picker; replace the 22 ranking chips by DAL's "Anime Categories" picture row.
 8. Searchable picker: show the current value as selected.
D. lib/screens/user_profile/user_profile_view.dart + sections/*.dart (profile unit)
 9. Add a "List" tab first for other users, opening on it (dailyal-108 lib/screens/user_profile.dart:124-129, 368-380, UserPage).
 10. Remove U10, U11; label birthday / last-online facts; check the duplicate "2026 Challenge" club rows.
 11. Consider DAL's icon tab strip (dailyal-108 lib/screens/user_profile.dart:50 profileHeaderWidget) so all 6 tabs fit.
E. lib/widgets/MAL/review/* + reviewer tap (user preview sheet) (social unit)
 12. Reviewer tap: open the profile directly (DAL lib/pages/userpop.dart:165) instead of the preview sheet + "Open full profile" step. Default review sort "Helpful" like DAL.
F. lib/widgets/MAL/content/scorestatisticswidget.dart, show_featured.dart, adaptation_widget.dart (detail content unit)
 13. Remove U12; hide Featured Articles when empty (U13); replicate DAL's adaptation tile (dailyal-108 lib/pages/animedetailed/adaptations.dart) without the chip (U14).
 14. Characters & staff page: fixed thumbnail size (Flamme row misaligned) (lib/screens/MAL/characters_staff_screen.dart).
G. Edit sheet + sync panel (lib/widgets/user/edit*, lib/widgets/user/sync/*) (edit unit)
 15. Replicate DAL's single compact card (dailyal-108 lib/widgets/user/contenteditwidget.dart): status button, episodes -/+ stepper, score chips, delete. Move "Other trackers" behind "More options" (no auto-loading spinners), drop its summary line (U19), and keep the close FAB clear of the Sync button.
H. lib/screens/calendar/calendar_screen.dart + lib/widgets/calendar/* (calendar unit)
 16. Replicate DAL's week list grouped by day with countdowns and the PTW/Watching filters (dailyal-108 lib/widgets/home/anime_calendar.dart:63+), or at least never open on an empty day; drop U15.
I. lib/screens/seasonal/seasonal_screen.dart (seasonal unit)
 17. Replicate DAL's header: "Seasonal" + season tabs, no big title + dropdown pair (dailyal-108 lib/screens/seasonal_screen.dart:31+); DAL list row with progress and +/- is more useful than the grid.
J. lib/screens/settings/theme_settings.dart (theme unit)
 18. Remove U17 and the Preview card (U18); fix the "Select a background image" row wrapping on 3 lines.
K. lib/pages/MAL/mal_home_page.dart + lib/widgets/home/home_sections.dart + home app bar (home unit)
 19. Investigate the Fall 2026 row content (section 16); show the user's status badge on home cards like DAL (dailyal-108 lib/widgets/home/animecard.dart:32); drop the date banner on season cards; "News" title; plain header icons without the grey pill (dailyal-108 lib/widgets/homeappbar.dart:24).
L. lib/screens/MAL/interest_stack_detail_screen.dart (stack unit)
 20. Keep MAL's title case (no standardize()); floating back/menu buttons must not cover entries (use a collapsing app bar); single-line tab labels.
M. Forum list (lib/screens/forum/forum_topics_screen.dart + topic tile)
 21. Replicate DAL's ForumTopicWidget (dailyal-108 lib/widgets/forum/forumtopicwidget.dart:79): regular-weight title, one meta line.
N. Sidebar (side bar widget) 
 22. Replicate DAL's AppSideBar items (dailyal-108 lib/pages/side_bar.dart:110-126); drop Profile/Stats duplicates.
Keep MWL: Settings grouping (clearer than DAL's flat list), profile Stats page (richer, DAL's shows zeros), History grouped by date expanded, Studios directory.

# RECENTLY MERGED: VERDICTS
| Item | Verdict | Notes |
|---|---|---|
| News (home + detail) #166 | works | loads with Jikan down |
| Cast / reviews like DAL #166 | works | characters row = DAL; reviews default sort Newest (DAL Helpful) |
| Friends #178 | works | 28 friends, last seen; extra "Friends since" line |
| Other user's profile #180 | works with defects | loads from MAL page; no List tab; extra preview-sheet step |
| Explore pictures / Explicit / Studios / Seasonal / Stacks / heart / no hamburger #172, #182 | BROKEN | pictures, Explicit card, Studios entry, DAL seasonal picker and no-hamburger verified; but #182 HeaderWidget breaks the strips (grey ErrorWidget boxes for Recommendations/Reviews/Stacks/Characters/Seiyuu on 1st visit, top half on 2nd visit), so Stacks and heart badges cannot be seen |
| Search filters incl. studio Arch #170 | works with defects | Arch filter returns 7 anime; default "All" search rows show wrong members, no score/eps (parser) |
| Interest stack page #177 | works with defects | 100x150 covers, tabs fit; title lower-cased; floating buttons overlap |
| Splash #179 | works | navy + logo on cold start, no white flash |
| Launcher label #174 | works | aapt: application-label 'MyWatchList' |
| Character page #181 | not in build | PR #181 open; page shows "Could not load this page" |

# VERIFIED vs SUSPECTED
Verified by running: Explore grey boxes + logcat exception; search/all parser misreading (on screen + curl + line mapping); Arch filter; edit sheet close FAB over Sync; calendar empty today; other-user profile without List tab; interest stack lowercase title (code); home Fall row differs from the same API call; perf numbers.
Suspected from reading / not proven: #182 HeaderWidget as the PageStorage writer (exception verified, writer inferred from the diff); duplicate club rows; home Fall row cause.
Not run: tools/heavy.sh tools/verify.sh (UI walk only, per the owner's instructions).
