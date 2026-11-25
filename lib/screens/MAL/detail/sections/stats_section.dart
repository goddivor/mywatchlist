import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType, loadingGraph;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/content_stats_source.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/content/animestatisticswidget.dart';

/// List status statistics: the MAL API's for an anime; a manga has none there, so its
/// come from Jikan or MAL's stats page ([ContentStatsSource], shared with Score stats).
DetailSection? statsSection(DetailData data) {
  final stats = data.content?.statistics;
  if (stats != null) {
    return DetailSection(TabType.Stats, AnimeStatisticsWidget(stats: stats, manga: data.isManga));
  }
  if (!data.isManga || !data.hasContent) return null;
  return DetailSection(TabType.Stats, MangaStatusStats(id: data.id));
}

/// The list statuses of a manga, loaded from [ContentStatsSource].
class MangaStatusStats extends StatefulWidget {
  final int id;
  const MangaStatusStats({required this.id, super.key});

  @override
  State<MangaStatusStats> createState() => _MangaStatusStatsState();
}

class _MangaStatusStatsState extends State<MangaStatusStats> with AutomaticKeepAliveClientMixin {
  late Future<ContentStats> _future = ContentStatsSource.load(widget.id, 'manga');

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<ContentStats>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SectionMessage.error(
            message: S.current.Res_Section_Failed,
            onRetry: () => setState(() => _future = ContentStatsSource.load(widget.id, 'manga')),
          );
        }
        final data = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done || data == null) {
          return SizedBox(height: 230, child: loadingGraph(context));
        }
        final s = data.stats;
        return AnimeStatisticsWidget(
          manga: true,
          stats: Statistics(
            status: Status(
              watching: s.watching ?? 0,
              completed: s.completed ?? 0,
              onHold: s.onHold ?? 0,
              dropped: s.dropped ?? 0,
              planToWatch: s.planToWatch ?? 0,
            ),
            numListUsers: s.total ?? 0,
          ),
        );
      },
    );
  }
}
