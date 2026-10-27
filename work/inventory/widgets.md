# Inventory — widgets & cross-cutting UI (DAL `upstream/2026.2.6+108` vs MWL `dev`, 2026-10-27)

| Feature | DAL | Status | MWL | Notes |
|---|---|---|---|---|
| Related-anime graph + share PNG | widgets/anime_graph.dart | MISSING | widgets/MAL/content/relatedanimewidget.dart | `_setAnimeGraph()` empty (l.61), `_animeGraph` returns `SizedBox()` (l.77-79); `graphview` not in pubspec |
| Bar/radar charts, ExpandedCard | widgets/barchart.dart | MISSING | — | `fl_chart` not in pubspec |
| User stats screen | widgets/user/stats_screen.dart, user/charts/* | MISSING | scrapper services/api/MAL/scrapper/user_anime_statistics.dart (no UI) | |
| Home app bar | widgets/homeappbar.dart | PARTIAL | widgets/MAL/home/homeappbar.dart | **BUG** bookmarks/calendar no-op (pages/MAL/mal_home_page.dart:223-224) |
| Home accordion sections | widgets/home/accordion.dart | PORTED | MAL only | other trackers' home = placeholder |
| First-run feature showcase | widgets/home/feature_first.dart | MISSING | | |
| Anime grid card | widgets/home/animecard.dart | PARTIAL | widgets/MAL/home/animegridcard.dart | no dub icon, recommendation badge, favourites, score reveal. **BUG** `showContentEditSheet` empty stub (l.620-623) → edit button on cards and interest stacks (interest_stack_detail_screen.dart:771) dead. **BUG** `releaseProgress` faked `(eps-1)/eps` (~l.389) |
| Card bar / status badge | widgets/home/nodebadge.dart | PARTIAL | widgets/MAL/home/animecardbar.dart | no score reveal |
| Bookmarks | widgets/home/bookmarks_widget.dart | MISSING | screens/plainscreen.dart | **BUG** `bookmarkAction` pushes empty `SizedBox()` (l.31-34) |
| Anime calendar, .ics download/share, add to device calendar | widgets/home/anime_calendar.dart | MISSING | | `add_2_calendar` absent |
| Weekly schedule (3-state "in list" filter) | widgets/user/weeklyanime.dart | MISSING | | |
| User anime/manga list | widgets/user/contentlistwidget.dart, user/contentbuilder.dart | MISSING | pages/*/*_user_page.dart placeholders | list APIs exist in services |
| User profile header / history | widgets/user/user_header.dart | MISSING | placeholders | scrapers user_history.dart, user_friends.dart unused |
| List sort & filter popup | widgets/listsortfilter.dart | PARTIAL | screens/search/general_search_screen.dart:1119-1260 | search only |
| View modes grid/list/compact… | | PARTIAL | general_search_screen.dart, constants.dart:31-33 | no `custom`, not on user lists |
| Custom list layout editor | widgets/user/customizedlist.dart | MISSING | | |
| Sign-in widget | widgets/user/signinpage.dart | PORTED | widgets/common/signin_widget.dart, pages/login_page.dart | 4 trackers |
| Edit-entry sheet | widgets/user/contenteditwidget.dart | PARTIAL | widgets/user/contenteditwidget.dart | MAL API only. **BUG** chapters/volumes forced `'0'` on load (~l.115-122). **BUG** `_loadFromContent` (l.104-128) never pre-fills dates, priority, comments, tags, rewatch. **BUG** auto dates ignore pref and overwrite existing dates; completing via episode count sets no finish date (l.273-285) |
| Per-tracker edit inside sheet | `_anilistEditView` | PARTIAL (redesigned) | widgets/user/cross_tracker_widget.dart, tracker_search_sheet.dart | sync of MAL values only |
| Filter modal | widgets/search/filtermodal.dart | PARTIAL | widgets/MAL/search/filtermodal.dart | no `SearchableSelect`, no 3-state |
| Select widgets / top sheet | widgets/selectbottom.dart, selecttopper.dart | PARTIAL | widgets/MAL/search/selectbottom.dart | missing SelectButton, SelectSheet, SelectDate, ThreeStateSelectBar, showTopSheet |
| Tags widget | widgets/featured/tagswidget.dart | PARTIAL | screens/MAL/featured_screen.dart:264 | **BUG** `onTap: null` (:281) |
| BBCode, forum widgets, club list | widgets/forum/*, club/* | PORTED | widgets/forum/* | |
| Share builder | widgets/common/share_builder.dart | MISSING | | |
| App bar overflow menu (share, browser, bookmark) | widgets/customappbar.dart | MISSING | | |
| Image viewer | widgets/common/image_preview.dart | PORTED | widgets/common/image_preview.dart | |
| In-app webview / custom tabs | widgets/web/c_webview.dart | PARTIAL | constants.dart:1115 | deprecated `launch()`; internal URI handling commented (~:1148-1152) |
| Translator | widgets/translator.dart | MISSING | | `translator_plus` absent |
| Adaptive / tablet layout | widgets/common/adaptive_layout.dart | MISSING | | |
| Bottom nav, background, loading, misc | | PORTED | widgets/common/*, widgets/loading/* | |
