import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_studio_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart' show AnilistMediaQuery;
import 'package:mywatchlist/services/api/Anilist/anilist_media_detail.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart' show AnilistRecommendationVote;
import 'package:mywatchlist/utils/web_launcher.dart' show openLink;
import 'package:mywatchlist/widgets/Anilist/anilist_chips.dart' show openAnilistBrowse;
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_cards.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_format.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_html.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_review_tile.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// The synopsis (AniList HTML, spoilers hidden), five lines until expanded.
class AnilistSynopsis extends StatefulWidget {
  const AnilistSynopsis({super.key, required this.html});

  final String html;

  @override
  State<AnilistSynopsis> createState() => _AnilistSynopsisState();
}

class _AnilistSynopsisState extends State<AnilistSynopsis> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final style = Theme.of(context).textTheme.bodyMedium;
    final lines = (style?.fontSize ?? 14) * (style?.height ?? 1.45) * 5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: const Cubic(0.23, 1, 0.32, 1),
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: _open ? double.infinity : lines),
              child: ClipRect(child: AnilistHtml(widget.html, style: style)),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? s.Amp_Show_Less : s.Amp_Show_More),
            ),
          ),
        ],
      ),
    );
  }
}

/// Genre chips; a tap searches the genre.
class AnilistGenreChips extends StatelessWidget {
  const AnilistGenreChips({super.key, required this.detail});

  final AnilistMediaDetail detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        children: [
          for (final g in detail.genres)
            ActionChip(
              visualDensity: VisualDensity.compact,
              label: Text(g),
              onPressed: () => openAnilistBrowse(
                context,
                g,
                AnilistMediaQuery(category: detail.category, sort: 'POPULARITY_DESC', genre: g),
              ),
            ),
        ],
      ),
    );
  }
}

/// The official episode after the user's progress: thumbnail, title and site.
class AnilistContinueCard extends StatelessWidget {
  const AnilistContinueCard({super.key, required this.episode});

  final AnilistStreamingEpisode episode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openLink(context, episode.url),
          child: Row(
            children: [
              AppImage(url: episode.thumbnail, width: 128, height: 72, placeholderColor: scheme.surfaceContainerHighest),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.of(context).Amp_Continue_Watching,
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary)),
                    Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                    if (episode.site != null)
                      Text(episode.site!,
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.play_circle_fill_rounded, color: scheme.primary, size: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Overview tab: information, tags, relations, characters, trailer, episodes, where to
/// watch, links, titles, recommendations and the best reviews. Sections without data are
/// not built.
class AnilistOverview extends StatelessWidget {
  const AnilistOverview({
    super.key,
    required this.detail,
    required this.onVote,
    required this.onShowTab,
  });

  final AnilistMediaDetail detail;
  final void Function(AnilistRecommendation r, AnilistRecommendationVote vote) onVote;

  /// Jumps to a tab of the page (Characters, Relations, Reviews).
  final ValueChanged<AnilistMediaTab> onShowTab;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = detail;
    final streaming = [for (final l in d.links) if (l.streaming) l];
    final other = [for (final l in d.links) if (!l.streaming) l];
    final relations = d.sortedRelations;
    final children = <Widget>[
      AnilistInfoTable(detail: d),
      if (d.tags.isNotEmpty) AnilistTagCloud(detail: d),
      if (relations.isNotEmpty) ...[
        AnilistSectionTitle(s.Related, trailing: _all(context, AnilistMediaTab.relations)),
        AnilistMediaStrip(
          height: 210,
          itemWidth: 104,
          itemCount: relations.length,
          itemBuilder: (_, i) =>
              AnilistTitleCard(media: relations[i].media, label: AnilistMediaFormat.relation(relations[i].type)),
        ),
      ],
      if (d.characters.isNotEmpty) ...[
        AnilistSectionTitle(s.Characters, trailing: _all(context, AnilistMediaTab.characters)),
        AnilistMediaStrip(
          height: AnilistCastCard.height,
          itemWidth: 280,
          itemCount: d.characters.length,
          itemBuilder: (_, i) => AnilistCastCard(edge: d.characters[i]),
        ),
      ],
      if (d.trailer != null) ...[
        AnilistSectionTitle(s.Amp_Trailer),
        _Trailer(trailer: d.trailer!),
      ],
      if (d.streamingEpisodes.isNotEmpty) ...[
        AnilistSectionTitle(s.Episodes),
        AnilistMediaStrip(
          height: 150,
          itemWidth: 200,
          itemCount: d.streamingEpisodes.length,
          itemBuilder: (_, i) => _EpisodeCard(episode: d.streamingEpisodes[i]),
        ),
      ],
      if (streaming.isNotEmpty) ...[
        AnilistSectionTitle(s.Amp_Where_To_Watch),
        _Links(links: streaming),
      ],
      if (other.isNotEmpty) ...[
        AnilistSectionTitle(s.Amp_Links),
        _Links(links: other),
      ],
      AnilistTitlesTable(detail: d),
      if (d.recommendations.isNotEmpty) ...[
        AnilistSectionTitle(s.Recommendations, trailing: _all(context, AnilistMediaTab.relations)),
        AnilistMediaStrip(
          height: 244,
          itemWidth: 104,
          itemCount: d.recommendations.length,
          itemBuilder: (_, i) {
            final r = d.recommendations[i];
            return AnilistTitleCard(
              media: r.media,
              footer: AnilistVoteBar(recommendation: r, onVote: (v) => onVote(r, v)),
            );
          },
        ),
      ],
      if (d.reviews.isNotEmpty) ...[
        AnilistSectionTitle(s.Reviews, trailing: _all(context, AnilistMediaTab.reviews)),
        for (final r in d.reviews.take(3)) AnilistReviewTile(review: r, showMedia: false),
      ],
      const SizedBox(height: 96),
    ];
    return SliverList.list(children: children);
  }

  Widget _all(BuildContext context, AnilistMediaTab tab) => TextButton(
        onPressed: () => onShowTab(tab),
        child: Text(S.of(context).View_All),
      );
}

/// The tabs of the title page, in order.
enum AnilistMediaTab { overview, characters, staff, relations, stats, social, reviews }

/// Key / value rows; empty values are not built. Studios open their page.
class AnilistInfoTable extends StatelessWidget {
  const AnilistInfoTable({super.key, required this.detail});

  final AnilistMediaDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = detail;
    final main = [for (final st in d.studios) if (st.main) st];
    final producers = [for (final st in d.studios) if (!st.main) st];
    final season = [
      if (d.season != null) AnilistLabels.season(d.season!),
      if (d.seasonYear != null) '${d.seasonYear}',
    ].join(' ');
    final rows = <(String, Widget)>[
      if (d.format != null) (s.Amp_Format, _text(context, AnilistLabels.format(d.format!))),
      if (d.status != null) (s.Status, _text(context, AnilistLabels.status(d.status!))),
      if (d.episodes != null) (s.Episodes, _text(context, '${d.episodes}')),
      if (d.duration != null && d.duration! > 0) (s.Duration, _text(context, s.Als_Minutes_Short(d.duration!))),
      if (d.chapters != null) (s.Chapters, _text(context, '${d.chapters}')),
      if (d.volumes != null) (s.Volumes, _text(context, '${d.volumes}')),
      if (d.startDate != null) (s.Start_Date, _text(context, AnilistMediaFormat.date(d.startDate!))),
      if (d.endDate != null) (s.End_Date, _text(context, AnilistMediaFormat.date(d.endDate!))),
      if (season.isNotEmpty) (s.Season, _text(context, season)),
      if (d.source != null) (s.Source, _text(context, AnilistLabels.source(d.source!))),
      if (d.country != null) (s.Amp_Country, _text(context, AnilistLabels.country(d.country!))),
      if (main.isNotEmpty) (s.Studios, _studios(context, main)),
      if (producers.isNotEmpty) (s.Amp_Producers, _studios(context, producers)),
      if (d.hashtag != null) (s.Amp_Hashtag, _text(context, d.hashtag!)),
      if (d.isLicensed != null) (s.Amp_Licensed, _text(context, d.isLicensed! ? s.Amp_Yes : s.Amp_No)),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Table(title: s.Amp_Information, rows: rows);
  }

  Widget _studios(BuildContext context, List<AnilistMediaStudio> studios) => Wrap(
        spacing: 4,
        children: [
          for (final st in studios)
            InkWell(
              onTap: () => openAnilistStudio(context, st.id),
              child: Text(
                st.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      );
}

Widget _text(BuildContext context, String value) => SelectableText(value, style: Theme.of(context).textTheme.bodyMedium);

/// Romaji, English, native and the synonyms.
class AnilistTitlesTable extends StatelessWidget {
  const AnilistTitlesTable({super.key, required this.detail});

  final AnilistMediaDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = detail;
    final rows = <(String, Widget)>[
      if (d.romaji != null) (s.Amp_Romaji, _text(context, d.romaji!)),
      if (d.english != null) (s.English, _text(context, d.english!)),
      if (d.native != null) (s.Amp_Native, _text(context, d.native!)),
      if (d.synonyms.isNotEmpty) (s.Synonyms, _text(context, d.synonyms.join('\n'))),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Table(title: s.Amp_Titles, rows: rows);
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.title, required this.rows});

  final String title;
  final List<(String, Widget)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnilistSectionTitle(title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  for (final (label, value) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(label,
                                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                          ),
                          Expanded(child: value),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tags with their rank %: the first ten, then "N more"; spoiler tags stay hidden until the
/// header toggle shows them. Long press shows the description, a tap searches the tag.
class AnilistTagCloud extends StatefulWidget {
  const AnilistTagCloud({super.key, required this.detail});

  final AnilistMediaDetail detail;

  @override
  State<AnilistTagCloud> createState() => _AnilistTagCloudState();
}

class _AnilistTagCloudState extends State<AnilistTagCloud> {
  bool _spoilers = false;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final d = widget.detail;
    final hasSpoilers = d.tags.any((t) => t.spoiler);
    final shown = [for (final t in d.tags) if (_spoilers || !t.spoiler) t];
    final visible = _all ? shown : shown.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnilistSectionTitle(
          s.Tags,
          trailing: hasSpoilers
              ? TextButton(
                  onPressed: () => setState(() => _spoilers = !_spoilers),
                  child: Text(_spoilers ? s.Amp_Hide_Spoilers : s.Amp_Show_Spoilers),
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in visible)
                Tooltip(
                  message: t.description ?? t.name,
                  triggerMode: TooltipTriggerMode.longPress,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => openAnilistBrowse(
                      context,
                      t.name,
                      AnilistMediaQuery(category: d.category, sort: 'POPULARITY_DESC', tag: t.name),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.spoiler ? AppColors.of(context).danger.container : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: t.name),
                            if (t.rank > 0)
                              TextSpan(
                                text: '  ${AnilistMediaFormat.percent(t.rank)}',
                                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                              ),
                          ]),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: t.spoiler ? AppColors.of(context).danger.onContainer : scheme.onSurface),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_all && shown.length > 10)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(s.Amp_More_Tags(shown.length - 10)),
                  onPressed: () => setState(() => _all = true),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Trailer extends StatelessWidget {
  const _Trailer({required this.trailer});

  final AnilistTrailer trailer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scrim = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Material(
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          color: scheme.surfaceContainerHighest,
          child: InkWell(
            onTap: () => openLink(context, trailer.url, confirm: false),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (trailer.thumbnail != null) AppImage(url: trailer.thumbnail),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: scrim.imageScrim, shape: BoxShape.circle),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.play_arrow_rounded, size: 36, color: scrim.onImageScrim),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.episode});

  final AnilistStreamingEpisode episode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => openLink(context, episode.url),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            url: episode.thumbnail,
            width: 200,
            height: 112,
            borderRadius: BorderRadius.circular(10),
            placeholderColor: scheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 4),
          Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Links as chips with the site's colour square and its language.
class _Links extends StatelessWidget {
  const _Links({required this.links});

  final List<AnilistExternalLink> links;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        children: [
          for (final l in links)
            ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: l.icon != null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: AnilistMediaFormat.hexColor(l.color) ?? scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: AppImage(url: l.icon, width: 14, height: 14, fit: BoxFit.contain),
                      ),
                    )
                  : Icon(Icons.link, size: 18, color: AnilistMediaFormat.hexColor(l.color) ?? scheme.primary),
              label: Text([l.site, if (l.language != null) l.language!].join(' · ')),
              onPressed: () => openLink(context, l.url),
            ),
        ],
      ),
    );
  }
}
