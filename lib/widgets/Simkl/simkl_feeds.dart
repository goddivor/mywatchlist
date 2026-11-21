import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';

/// The Simkl catalogue lists the home rows and the Explore tab show.
///
/// The home rows use [airing], [trending] and [premieres] (see `simklHomePlan`); Explore offers
/// every value, in this order.
enum SimklFeed {
  trending,
  airing,
  premieres,
  soon,
  best,
  genres;

  /// The lists Simkl has for [kind]: movies have no premieres and no best list, and their
  /// "airing" list is the release calendar.
  static List<SimklFeed> of(SimklKind kind) => kind == SimklKind.movie
      ? const [SimklFeed.trending, SimklFeed.airing, SimklFeed.genres]
      : SimklFeed.values;

  /// Translated title of the home row of [kind].
  String titleOf(SimklKind kind) =>
      kind == SimklKind.movie && this == SimklFeed.airing ? S.current.Skm_Feed_Releases_Today : title;

  /// Translated title of the home row.
  String get title => switch (this) {
        SimklFeed.airing => S.current.Sk_Feed_Airing,
        SimklFeed.trending => S.current.Sk_Feed_Trending,
        SimklFeed.premieres => S.current.Sk_Feed_Premieres,
        SimklFeed.soon => S.current.Scf_Feed_Soon,
        SimklFeed.best => S.current.Scf_Feed_Best,
        SimklFeed.genres => S.current.Scf_Feed_Genres,
      };

  /// Translated label of the Explore chip (the airing list there covers several days).
  String exploreTitleOf(SimklKind kind) => this != SimklFeed.airing
      ? title
      : kind == SimklKind.movie
          ? S.current.Skm_Feed_Releases
          : S.current.Scf_Feed_Schedule;

  /// The default list of the feed (home rows, "View all").
  Future<List<SimklMedia>> load(SimklDiscoverService service, [SimklKind kind = SimklKind.anime]) =>
      SimklFeedQuery(this, kind: kind).loadAll(service);

  /// Key of the in-memory answer (`HomeSectionCache`).
  String cacheKeyOf(SimklKind kind) => 'simkl_feed_${kind.name}_$name';
}

/// One Explore list: a feed and its options. Options that do not apply to the feed are ignored.
@immutable
class SimklFeedQuery {
  final SimklFeed feed;

  /// The catalogue: shows, anime or movies.
  final SimklKind kind;
  final SimklTrendingWindow window;
  final SimklBest best;
  final SimklFormat format;
  final String genre;
  final SimklGenreSort sort;

  /// Airing: days after today (0 = today).
  final int dayOffset;

  const SimklFeedQuery(
    this.feed, {
    this.kind = SimklKind.anime,
    this.window = SimklTrendingWindow.today,
    this.best = SimklBest.all,
    this.format = SimklFormat.all,
    this.genre = 'all',
    this.sort = SimklGenreSort.popularMonth,
    this.dayOffset = 0,
  });

  /// Whether the feed has a format filter (anime only: TV, movies, OVAs, ONAs).
  bool get hasFormat => kind == SimklKind.anime && switch (feed) {
        SimklFeed.premieres || SimklFeed.soon || SimklFeed.best || SimklFeed.genres => true,
        _ => false,
      };

  /// Whether the list is paged (genre browse).
  bool get paged => feed == SimklFeed.genres;

  SimklFeedQuery copyWith({
    SimklFeed? feed,
    SimklKind? kind,
    SimklTrendingWindow? window,
    SimklBest? best,
    SimklFormat? format,
    String? genre,
    SimklGenreSort? sort,
    int? dayOffset,
  }) =>
      SimklFeedQuery(
        feed ?? this.feed,
        kind: kind ?? this.kind,
        window: window ?? this.window,
        best: best ?? this.best,
        format: format ?? this.format,
        genre: genre ?? this.genre,
        sort: sort ?? this.sort,
        dayOffset: dayOffset ?? this.dayOffset,
      );

  /// Key of the answer in `HomeSectionCache`; the default query of a feed shares the home row's.
  String get cacheKey {
    final base = feed.cacheKeyOf(kind);
    final extra = switch (feed) {
      SimklFeed.trending => window == SimklTrendingWindow.today ? '' : window.name,
      SimklFeed.airing => dayOffset == 0 ? '' : 'd$dayOffset:${_day(DateTime.now()).toIso8601String()}',
      SimklFeed.premieres || SimklFeed.soon => format == SimklFormat.all ? '' : format.name,
      SimklFeed.best => best == SimklBest.all && format == SimklFormat.all ? '' : '${best.name}:${format.name}',
      SimklFeed.genres => genre == 'all' && format == SimklFormat.all && sort == SimklGenreSort.popularMonth
          ? ''
          : '$genre:${format.name}:${sort.name}',
    };
    return extra.isEmpty ? base : '$base:$extra';
  }

  /// One page of the list ([page] counts from 1; only the genre browse has more than one).
  Future<SimklPage> load(SimklDiscoverService service, {int page = 1}) async => switch (feed) {
        SimklFeed.genres => service.byGenre(genre: genre, format: format, sort: sort, kind: kind, page: page),
        _ => SimklPage(await loadAll(service), hasMore: false),
      };

  /// The first page as a plain list.
  Future<List<SimklMedia>> loadAll(SimklDiscoverService service) async => switch (feed) {
        SimklFeed.trending => service.trending(window: window, kind: kind),
        SimklFeed.airing => service.airingToday(
            date: _day(DateTime.now()).add(Duration(days: dayOffset, hours: 12)),
            kind: kind,
            limit: 500,
          ),
        SimklFeed.premieres => service.premieres(format: format, kind: kind),
        SimklFeed.soon => service.comingSoon(format: format, kind: kind),
        SimklFeed.best => service.best(filter: best, format: format, kind: kind),
        SimklFeed.genres => (await service.byGenre(genre: genre, format: format, sort: sort, kind: kind)).items,
      };

  @override
  bool operator ==(Object other) =>
      other is SimklFeedQuery &&
      other.feed == feed &&
      other.kind == kind &&
      other.window == window &&
      other.best == best &&
      other.format == format &&
      other.genre == genre &&
      other.sort == sort &&
      other.dayOffset == dayOffset;

  @override
  int get hashCode => Object.hash(feed, kind, window, best, format, genre, sort, dayOffset);
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Days the Explore schedule offers: today and the six next ones.
const int simklScheduleDays = 7;

/// Translated labels of the feed options.
abstract final class SimklFeedLabels {
  static String window(SimklTrendingWindow w) => switch (w) {
        SimklTrendingWindow.today => S.current.Scf_Window_Today,
        SimklTrendingWindow.week => S.current.Scf_Window_Week,
        SimklTrendingWindow.month => S.current.Scf_Window_Month,
      };

  static String best(SimklBest b) => switch (b) {
        SimklBest.all => S.current.Scf_Best_All,
        SimklBest.year => S.current.Scf_Best_Year,
        SimklBest.month => S.current.Scf_Window_Month,
        SimklBest.voted => S.current.Scf_Best_Voted,
        SimklBest.watched => S.current.Scf_Best_Watched,
      };

  static String format(SimklFormat f) => switch (f) {
        SimklFormat.all => S.current.Scf_Format_All,
        SimklFormat.tv => S.current.Scf_Format_Tv,
        SimklFormat.movies => S.current.Scf_Format_Movies,
        SimklFormat.ovas => S.current.Scf_Format_Ova,
        SimklFormat.onas => S.current.Scf_Format_Ona,
      };

  static String sort(SimklGenreSort s) => switch (s) {
        SimklGenreSort.popularMonth => S.current.Scf_Sort_Popular_Month,
        SimklGenreSort.popularAll => S.current.Scf_Sort_Popular_All,
        SimklGenreSort.rank => S.current.Scf_Sort_Rank,
        SimklGenreSort.releaseDate => S.current.Scf_Sort_Newest,
        SimklGenreSort.voted => S.current.Scf_Best_Voted,
      };

  /// "Today", "Tomorrow", then the short date in the app language.
  static String day(int offset) {
    if (offset == 0) return S.current.Scf_Window_Today;
    if (offset == 1) return S.current.Scf_Tomorrow;
    return DateFormat.MMMEd().format(_day(DateTime.now()).add(Duration(days: offset, hours: 12)));
  }

  static String genre(String slug) => switch (slug) {
        'all' => S.current.Scf_Genre_All,
        'action' => S.current.Scf_Genre_Action,
        'adventure' => S.current.Scf_Genre_Adventure,
        'comedy' => S.current.Scf_Genre_Comedy,
        'drama' => S.current.Scf_Genre_Drama,
        'ecchi' => S.current.Scf_Genre_Ecchi,
        'educational' => S.current.Scf_Genre_Educational,
        'fantasy' => S.current.Scf_Genre_Fantasy,
        'gag-humor' => S.current.Scf_Genre_Gag_Humor,
        'gore' => S.current.Scf_Genre_Gore,
        'harem' => S.current.Scf_Genre_Harem,
        'historical' => S.current.Scf_Genre_Historical,
        'horror' => S.current.Scf_Genre_Horror,
        'idol' => S.current.Scf_Genre_Idol,
        'isekai' => S.current.Scf_Genre_Isekai,
        'josei' => S.current.Scf_Genre_Josei,
        'kids' => S.current.Scf_Genre_Kids,
        'magic' => S.current.Scf_Genre_Magic,
        'martial-arts' => S.current.Scf_Genre_Martial_Arts,
        'mecha' => S.current.Scf_Genre_Mecha,
        'military' => S.current.Scf_Genre_Military,
        'music' => S.current.Scf_Genre_Music,
        'mystery' => S.current.Scf_Genre_Mystery,
        'mythology' => S.current.Scf_Genre_Mythology,
        'parody' => S.current.Scf_Genre_Parody,
        'psychological' => S.current.Scf_Genre_Psychological,
        'racing' => S.current.Scf_Genre_Racing,
        'reincarnation' => S.current.Scf_Genre_Reincarnation,
        'romance' => S.current.Scf_Genre_Romance,
        'samurai' => S.current.Scf_Genre_Samurai,
        'school' => S.current.Scf_Genre_School,
        'sci-fi' => S.current.Scf_Genre_Sci_Fi,
        'seinen' => S.current.Scf_Genre_Seinen,
        'shoujo' => S.current.Scf_Genre_Shoujo,
        'shoujo-ai' => S.current.Scf_Genre_Shoujo_Ai,
        'shounen' => S.current.Scf_Genre_Shounen,
        'shounen-ai' => S.current.Scf_Genre_Shounen_Ai,
        'slice-of-life' => S.current.Scf_Genre_Slice_Of_Life,
        'space' => S.current.Scf_Genre_Space,
        'sports' => S.current.Scf_Genre_Sports,
        'strategy-game' => S.current.Scf_Genre_Strategy_Game,
        'super-power' => S.current.Scf_Genre_Super_Power,
        'supernatural' => S.current.Scf_Genre_Supernatural,
        'thriller' => S.current.Scf_Genre_Thriller,
        'vampire' => S.current.Scf_Genre_Vampire,
        'yaoi' => S.current.Scf_Genre_Yaoi,
        'yuri' => S.current.Scf_Genre_Yuri,
        // Shows and movies.
        'animation' => S.current.Skm_Genre_Animation,
        'awards-show' => S.current.Skm_Genre_Awards_Show,
        'children' => S.current.Skm_Genre_Children,
        'crime' => S.current.Skm_Genre_Crime,
        'documentary' => S.current.Skm_Genre_Documentary,
        'erotica' => S.current.Skm_Genre_Erotica,
        'family' => S.current.Skm_Genre_Family,
        'food' => S.current.Skm_Genre_Food,
        'game-show' => S.current.Skm_Genre_Game_Show,
        'history' => S.current.Skm_Genre_History,
        'home-and-garden' => S.current.Skm_Genre_Home_Garden,
        'indie' => S.current.Skm_Genre_Indie,
        'mini-series' => S.current.Skm_Genre_Mini_Series,
        'musical' => S.current.Skm_Genre_Musical,
        'news' => S.current.Skm_Genre_News,
        'podcast' => S.current.Skm_Genre_Podcast,
        'reality' => S.current.Skm_Genre_Reality,
        'science-fiction' => S.current.Scf_Genre_Sci_Fi,
        'soap' => S.current.Skm_Genre_Soap,
        'sport' => S.current.Scf_Genre_Sports,
        'suspense' => S.current.Skm_Genre_Suspense,
        'talk-show' => S.current.Skm_Genre_Talk_Show,
        'travel' => S.current.Skm_Genre_Travel,
        'tv-movie' => S.current.Skm_Genre_Tv_Movie,
        'video-game-play' => S.current.Skm_Genre_Video_Games,
        'war' => S.current.Skm_Genre_War,
        'western' => S.current.Skm_Genre_Western,
        _ => slug,
      };
}

/// "View all" of a home row: the whole default list of [feed] as a poster grid.
class SimklFeedPage extends StatefulWidget {
  const SimklFeedPage({super.key, required this.feed, this.kind = SimklKind.anime, this.service});

  final SimklFeed feed;
  final SimklKind kind;

  /// Test hook; defaults to the shared Simkl discover service.
  final SimklDiscoverService? service;

  @override
  State<SimklFeedPage> createState() => _SimklFeedPageState();
}

class _SimklFeedPageState extends State<SimklFeedPage> {
  int _refresh = 0;

  SimklDiscoverService get _service => widget.service ?? SimklDiscoverService.instance;

  Future<void> _onRefresh() async {
    HomeSectionCache.clearPrefix(widget.feed.cacheKeyOf(widget.kind));
    _service.cdn.invalidate();
    setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.feed.titleOf(widget.kind))),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: HomeAsync<List<SimklMedia>>(
          cacheKey: widget.feed.cacheKeyOf(widget.kind),
          maxAge: const Duration(minutes: 30),
          refresh: _refresh,
          load: () => widget.feed.load(_service, widget.kind),
          loading: const Align(
            alignment: Alignment.topCenter,
            child: Padding(padding: EdgeInsets.only(top: 16), child: SimklRowSkeleton()),
          ),
          builder: (context, items) => CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (items.isEmpty)
                SliverToBoxAdapter(child: HomeMessage(icon: Icons.movie_filter_outlined, text: s.Sk_Feed_Empty))
              else
                SimklMediaGrid(items: items, onTap: (media) => openSimklMedia(context, media, service: _service)),
              SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
            ],
          ),
        ),
      ),
    );
  }
}
