# Inventory — performance / fluidity (MWL `dev` vs DAL `upstream/2026.2.6+108`, 2026-10-27)

**Measured baseline (2026-10-27, AVD mwl_compare with `-gpu host`, MWL `--profile` vs DAL 2026.2.5+107 release, home screen, 6 fast swipes, `tools/perf/measure-scroll.sh`, two runs):** MWL 22.2 % / 23.0 % janky frames (3 severe); DAL 1.6 % / 1.6 % (1-2 severe). Target: MWL within a few points of DAL.

Causes below: static read; ratings inferred from code. The owner reports lag on scroll and page changes; DAL feels fluid.

| Rank | Cause | MWL evidence | DAL approach | Fix | Impact | Unit |
|---|---|---|---|---|---|---|
| 1 | No high refresh rate (stuck at 60 Hz on 90/120 Hz screens) | main.dart, no `flutter_displaymode` | main.dart:62 `FlutterDisplayMode.setHighRefreshRate()` | add package + call before runApp | high | perf-foundation |
| 2 | Home tab switch: animated `Opacity` over whole page (saveLayer 250 ms) + `IndexedStack` builds all 5 tabs eagerly (all network calls at once) | screens/home_screen.dart:142, :236-237, ~:116 | homescreen.dart:293-297 IndexedStack only with `keepPagesInMemory` | drop Opacity wrap, build current tab only unless pref | high | app-shell |
| 3 | Full-resolution decode of card images | widgets/MAL/home/animegridcard.dart:263-268, :456-468 | same (shared) | shared image helper with memCacheWidth = width × DPR, maxWidthDiskCache | high | perf-foundation (helper) + cards-upgrade (use) |
| 4 | Detail scroll: listener added 4× (never removed), localToGlobal on every tick, TabControllers leaked | screens/MAL/contentdetailedscreen.dart:328-343, :220/:237/:248/:258, :161 | same | listener once in initState, dispose old controller, update tab only on change | high | detail-split |
| 5 | Root rebuilds: BlocBuilders around Scaffold/nav/MaterialApp without buildWhen | home_screen.dart:88, :105; main.dart:192 | — | buildWhen / BlocSelector, split builders | med | perf-foundation (main.dart) + app-shell (home_screen) |
| 6 | SingleChildScrollView per review item | widgets/MAL/content/show_reviews.dart:174 | — | plain Column / lazy list | med | detail-social |
| 7 | ClipRRect + Opacity per list item, blur BoxShadow on every avatar | news_widget.dart:54-56; general_search_screen.dart:1582-2956 (~12); avatar_widget.dart:~63-68 | fewer sites | alpha colors, borderRadius on DecorationImage, no shadows on repeated items | med | home-wiring, search-upgrade, perf-foundation |
| 8 | 38 shimmers, each with its own repeating ticker | avatar_widget.dart:159-167; constants.dart:255-268; animegridcard.dart:266 | same | one shared ticker inside ShimmerColor | med | perf-foundation |
| 9 | JSON/HTML parsing on the UI isolate | services/api/mwl_api.dart:120,140,543; mal_clubs_api.dart:20,34,61; character_screen.dart:129 | same | Isolate.run / compute | med | backend-parsers (mwl_api), forum-clubs, featured-characters |
| 10 | BackdropFilter blur over PhotoView, re-blurred each frame | widgets/common/image_preview.dart:27-28, :222-223 | same | static scrim | med | perf-foundation |
| 11 | 500 ms fade on every avatar | avatar_widget.dart:132-134 | avatarwidget.dart:219 `fadeInDuration: Duration.zero` | zero fade | low-med | perf-foundation |
| 12 | Character screen: eager Column in SingleChildScrollView | screens/MAL/character_screen.dart:251-256 | — | CustomScrollView + slivers | low-med | featured-characters |
| 13 | Impeller default; DAL forces Skia | AndroidManifest.xml:13 | manifest :59-61 `EnableImpeller=false` | A/B measure before changing | test | perf-foundation |
| 14 | `Image.network` without cache/size | image_preview.dart:32; onboarding_trackers.dart:192 | same | cached provider with size | low | perf-foundation, accounts-ux |
| 15 | Route transitions | constants.dart:157-166; utils/page_transitions.dart | MaterialPageRoute / opacity route | cheap transitions; not a real cause | low | perf-foundation |
