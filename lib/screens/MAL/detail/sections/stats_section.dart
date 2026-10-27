import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType, loadingGraph;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/content_stats_source.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/widgets/MAL/content/animestatisticswidget.dart';

/// List status statistics: the MAL API `statistics`, or, when the details
/// came without them, the counts of [ContentStatsSource] (Jikan, then MAL's
/// stats page).
DetailSection? statsSection(DetailData data) {
  if (!data.hasContent) return null;
  final stats = data.content?.statistics;
  if (stats != null) return DetailSection(TabType.Stats, AnimeStatisticsWidget(stats: stats));
  return DetailSection(TabType.Stats, StatusStatsFallback(id: data.id, category: data.category));
}

/// Status counts loaded from [ContentStatsSource]; an error with Retry when
/// no source answered, an empty state when the answer has no counts.
class StatusStatsFallback extends StatefulWidget {
  final int id;
  final String category;

  const StatusStatsFallback({super.key, required this.id, required this.category});

  @override
  State<StatusStatsFallback> createState() => _StatusStatsFallbackState();
}

class _StatusStatsFallbackState extends State<StatusStatsFallback>
    with AutomaticKeepAliveClientMixin {
  late Future<ContentStats> _future = _fetch();

  Future<ContentStats> _fetch() => ContentStatsSource.load(widget.id, widget.category);

  void _retry() => setState(() {
        _future = _fetch();
      });

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<ContentStats>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SectionMessage.error(message: S.current.Res_Section_Failed, onRetry: _retry);
        }
        final data = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done || data == null) {
          return SizedBox(height: 230, child: loadingGraph(context));
        }
        final statistics = data.statusStatistics;
        if (statistics == null) {
          return SectionMessage(icon: Icons.bar_chart, message: S.current.No_Content);
        }
        return AnimeStatisticsWidget(stats: statistics);
      },
    );
  }
}
