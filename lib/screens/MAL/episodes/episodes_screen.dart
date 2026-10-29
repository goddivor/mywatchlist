import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/episodes_page.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';

/// Full episode list of an anime, 100 episodes per page (chips switch pages).
class EpisodesScreen extends StatefulWidget {
  final int animeId;
  final String title;

  const EpisodesScreen({super.key, required this.animeId, required this.title});

  @override
  State<EpisodesScreen> createState() => _EpisodesScreenState();
}

class _EpisodesScreenState extends State<EpisodesScreen> {
  int _offset = 0;
  late Future<EpisodesPage> _future = _load();

  Future<EpisodesPage> _load() =>
      MalEpisodesPage.load(widget.animeId, offset: _offset);

  void _go(int offset) => setState(() {
        _offset = offset;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<EpisodesPage>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return SectionMessage.error(
                message: s.Ep_Failed, onRetry: () => _go(_offset), height: 300);
          }
          final page = snap.data;
          if (page == null) return const Center(child: CircularProgressIndicator());
          if (page.episodes.isEmpty) {
            return SectionMessage(
                icon: Icons.movie_outlined, message: s.Ep_Empty, height: 300);
          }
          return Column(
            children: [
              if (page.offsets.length > 1)
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: page.offsets.length,
                    separatorBuilder: (a, b) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final o = page.offsets[i];
                      final end = page.total != null && i == page.offsets.length - 1
                          ? page.total!
                          : o + MalEpisodesPage.pageSize;
                      return ChoiceChip(
                        label: Text(s.Ep_Range(o + 1, end)),
                        selected: o == page.offset,
                        onSelected: (_) => _go(o),
                      );
                    },
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: page.episodes.length,
                  itemBuilder: (_, i) => EpisodeTile(
                    animeId: widget.animeId,
                    episode: page.episodes[i],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One row of the episode list; tap opens [showEpisodeSheet].
class EpisodeTile extends StatelessWidget {
  final int animeId;
  final EpisodeEntry episode;

  const EpisodeTile({super.key, required this.animeId, required this.episode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final e = episode;
    final date = episodeDate(context, e);
    final metaStyle = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return ListTile(
      onTap: () => showEpisodeSheet(context, animeId, e),
      leading: SizedBox(
        width: 36,
        child: Text('${e.number}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary)),
      ),
      title: Text(e.title.isEmpty ? S.of(context).Ep_Number(e.number) : e.title,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (date.isNotEmpty) Text(date, style: metaStyle),
          if (e.replies > 0)
            Semantics(
              label: S.of(context).FixMalB4_Episode_Replies(e.replies),
              excludeSemantics: true,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.forum_outlined, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text(NumberFormat.decimalPattern(Localizations.localeOf(context).toString())
                    .format(e.replies), style: metaStyle),
              ]),
            ),
          if (e.filler) _Tag(S.of(context).Ep_Filler, colors.warning),
          if (e.recap) _Tag(S.of(context).Ep_Recap, colors.warning),
        ],
      ),
      trailing: e.score == null
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star_rounded, size: 16, color: colors.score.color),
              const SizedBox(width: 2),
              Text(e.score!.toStringAsFixed(1), style: theme.textTheme.labelLarge),
            ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final AppColorRole role;
  const _Tag(this.label, this.role);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
            color: role.container, borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: role.onContainer, fontWeight: FontWeight.bold)),
      );
}

/// Air date in the app's language, else MAL's raw text, else empty.
String episodeDate(BuildContext context, EpisodeEntry e) {
  final date = e.aired;
  if (date == null) return e.airedText;
  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date);
}

/// Detail sheet of one episode: titles, date, score, synopsis (read from the
/// MAL episode page), the discussion topic and the MAL link.
Future<void> showEpisodeSheet(BuildContext context, int animeId, EpisodeEntry e) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EpisodeSheet(animeId: animeId, episode: e),
  );
}

class _EpisodeSheet extends StatefulWidget {
  final int animeId;
  final EpisodeEntry episode;
  const _EpisodeSheet({required this.animeId, required this.episode});

  @override
  State<_EpisodeSheet> createState() => _EpisodeSheetState();
}

class _EpisodeSheetState extends State<_EpisodeSheet> {
  late final Future<String?> _synopsis =
      MalEpisodesPage.loadSynopsis(widget.animeId, widget.episode.number);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final e = widget.episode;
    final titles = [
      if (e.romaji.isNotEmpty) e.romaji,
      if (e.japanese.isNotEmpty) e.japanese,
    ];
    final date = episodeDate(context, e);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.Ep_Number(e.number),
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          Text(e.title.isEmpty ? s.Ep_Number(e.number) : e.title,
              style: theme.textTheme.titleLarge),
          if (titles.isNotEmpty)
            Text(titles.join('  ·  '),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(date, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          Text(s.Ep_Synopsis, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          FutureBuilder<String?>(
            future: _synopsis,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              final text = snap.data;
              return Text(text ?? s.Ep_No_Synopsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: text == null ? theme.colorScheme.onSurfaceVariant : null));
            },
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            if (e.topicId != null)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: Text(s.Ep_Discussion),
                onPressed: () {
                  Navigator.pop(context);
                  gotoPage(
                    context: context,
                    newPage: ForumPostsScreen(
                      topic: ForumTopicsData(
                        id: e.topicId,
                        title: e.title,
                        numberOfPosts: e.replies,
                      ),
                    ),
                  );
                },
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(s.Ep_Open_Mal),
              onPressed: () => openLink(
                  context, MalEpisodesPage.episodeUrl(widget.animeId, e.number).toString(),
                  confirm: false),
            ),
          ]),
        ],
      ),
    );
  }
}
