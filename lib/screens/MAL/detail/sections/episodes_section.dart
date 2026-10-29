import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType, gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/screens/MAL/episodes/episodes_screen.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/episodes_page.dart';

/// First episodes of an anime; the arrow opens the full list. Anime only.
DetailSection? episodesSection(DetailData data) {
  if (!data.isAnime || !data.hasContent) return null;
  return DetailSection(
    TabType.Episodes,
    _EpisodesPreview(animeId: data.id),
    onViewAll: (context) => gotoPage(
      context: context,
      newPage: EpisodesScreen(animeId: data.id, title: data.title),
    ),
  );
}

class _EpisodesPreview extends StatefulWidget {
  final int animeId;
  const _EpisodesPreview({required this.animeId});

  @override
  State<_EpisodesPreview> createState() => _EpisodesPreviewState();
}

class _EpisodesPreviewState extends State<_EpisodesPreview>
    with AutomaticKeepAliveClientMixin {
  static const _shown = 5;
  late Future<EpisodesPage> _future = MalEpisodesPage.load(widget.animeId);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    return FutureBuilder<EpisodesPage>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return SectionMessage.error(
            message: s.Ep_Failed,
            onRetry: () => setState(
                () => _future = MalEpisodesPage.load(widget.animeId)),
          );
        }
        final page = snap.data;
        if (page == null) {
          return const SizedBox(
              height: 160, child: Center(child: CircularProgressIndicator()));
        }
        if (page.episodes.isEmpty) {
          return SectionMessage(icon: Icons.movie_outlined, message: s.Ep_Empty);
        }
        return Column(children: [
          for (final e in page.episodes.take(_shown))
            EpisodeTile(animeId: widget.animeId, episode: e),
        ]);
      },
    );
  }
}
