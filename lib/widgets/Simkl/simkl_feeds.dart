import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';

/// The Simkl catalogue lists the home sections and the Explore tab show.
enum SimklFeed {
  airing,
  trending,
  premieres;

  /// Translated title.
  String get title => switch (this) {
        SimklFeed.airing => S.current.Sk_Feed_Airing,
        SimklFeed.trending => S.current.Sk_Feed_Trending,
        SimklFeed.premieres => S.current.Sk_Feed_Premieres,
      };

  Future<List<SimklMedia>> load(SimklDiscoverService service) => switch (this) {
        SimklFeed.airing => service.airingToday(),
        SimklFeed.trending => service.trending(),
        SimklFeed.premieres => service.premieres(),
      };

  /// Key of the in-memory answer (`HomeSectionCache`).
  String get cacheKey => 'simkl_feed_$name';
}
