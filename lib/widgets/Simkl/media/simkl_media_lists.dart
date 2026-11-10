import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_sections.dart';

/// Full-screen list of a section ("view all"): the items it already has show at once, then
/// [load] (when given) replaces them. Loading, error with Retry and empty end states; the list
/// is built lazily.
class SimklListScreen<T> extends StatefulWidget {
  final String title;
  final List<T> initial;
  final Future<List<T>?> Function({bool force})? load;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final EdgeInsets padding;

  const SimklListScreen({
    super.key,
    required this.title,
    required this.itemBuilder,
    this.initial = const [],
    this.load,
    this.padding = const EdgeInsets.only(top: 8, bottom: 24),
  });

  @override
  State<SimklListScreen<T>> createState() => _SimklListScreenState<T>();
}

class _SimklListScreenState<T> extends State<SimklListScreen<T>> {
  late List<T> _items = widget.initial;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run({bool force = false}) async {
    final load = widget.load;
    if (load == null) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final items = await load(force: force);
      if (!mounted) return;
      setState(() {
        if (items != null && (items.isNotEmpty || _items.isEmpty)) _items = items;
        _failed = items == null && _items.isEmpty;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = _items.isEmpty;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_items.isEmpty && _loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty && _failed) {
      body = SectionMessage(
        icon: Icons.cloud_off_outlined,
        message: S.current.Smp_Load_Error,
        onRetry: () => _run(force: true),
      );
    } else if (_items.isEmpty) {
      body = SectionMessage(icon: Icons.inbox_outlined, message: S.current.Smp_Empty);
    } else {
      body = ListView.builder(
        padding: widget.padding,
        itemCount: _items.length + (_loading ? 1 : 0),
        itemBuilder: (context, i) => i >= _items.length
            ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
            : widget.itemBuilder(context, _items[i]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: const [SizedBox.shrink()]),
      body: RefreshIndicator(
        onRefresh: () => _run(force: true),
        notificationPredicate: (_) => widget.load != null,
        child: body,
      ),
    );
  }
}

/// A row of the episode list: still, number, title, date and the description.
class SimklEpisodeRow extends StatelessWidget {
  final SimklEpisode episode;
  final VoidCallback? onTap;
  final bool watched;
  final bool upcoming;

  const SimklEpisodeRow({super.key, required this.episode, this.onTap, this.watched = false, this.upcoming = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = episode.date;
    final heading = episode.number != null && !episode.isSpecial
        ? S.current.Smp_Episode_Number(episode.number!)
        : S.current.Smp_Specials;
    final meta = [
      if (date != null && (upcoming || !episode.aired))
        SimklFormat.dateClock(date)
      else if (!episode.aired)
        S.current.Smp_Not_Aired
      else if (date != null)
        SimklFormat.episodeDate(date),
      if (episode.runtime != null && episode.runtime! > 0) S.current.Smp_Minutes(episode.runtime!),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: simklPagePadding, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SimklEpisodeStill(
              url: episode.imageUrl,
              width: 140,
              height: 79,
              radius: 10,
              watched: watched,
              upcoming: upcoming || !episode.aired,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(heading, style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
                  Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  if (meta.isNotEmpty)
                    Text(meta, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  if (episode.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Memos grouped under their rating bucket header ("6 to 10 stars").
List<Object> groupMemos(List<SimklMemo> memos) {
  final out = <Object>[];
  String? last;
  for (final m in memos) {
    final key = m.minStars == null || m.maxStars == null ? null : '${m.minStars}-${m.maxStars}';
    if (key != null && key != last) out.add(S.current.Smp_Memo_Bucket(m.minStars!, m.maxStars!));
    last = key;
    out.add(m);
  }
  return out;
}

/// The header row of a memo bucket.
class SimklBucketHeader extends StatelessWidget {
  final String label;

  const SimklBucketHeader(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(simklPagePadding + 10, 16, simklPagePadding, 6),
      child: Text(label, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}
