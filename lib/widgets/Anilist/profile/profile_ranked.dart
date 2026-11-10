import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_actions.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_favourites.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistLink;
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart' show anilistErrorText;
import 'package:mywatchlist/widgets/user/profile/profile_format.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

enum _RankedSort { count, mean, time }

/// A ranked statistic of a profile (genres, tags, voice actors, staff, studios): one row per
/// entry with the count as a bar, the mean score and the time; sortable; a tap lists the
/// titles counted there.
class AnilistRankedStats extends StatefulWidget {
  final String username;
  final String category;
  final AnilistStatsPart part;
  final AnilistProfileService? service;

  const AnilistRankedStats({
    super.key,
    required this.username,
    required this.category,
    required this.part,
    this.service,
  });

  @override
  State<AnilistRankedStats> createState() => _AnilistRankedStatsState();
}

class _AnilistRankedStatsState extends State<AnilistRankedStats> {
  List<AnilistRankedStat>? _rows;
  Object? _error;
  _RankedSort _sort = _RankedSort.count;

  AnilistProfileService get _service => widget.service ?? AnilistProfileService.instance;
  bool get _manga => widget.category == 'manga';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await _service.loadRanked(widget.username, widget.category, widget.part);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  int _time(AnilistRankedStat r) => _manga ? r.chapters : r.minutes;

  List<AnilistRankedStat> get _sorted {
    final rows = [..._rows!];
    switch (_sort) {
      case _RankedSort.count:
        rows.sort((a, b) => b.count.compareTo(a.count));
      case _RankedSort.mean:
        rows.sort((a, b) => b.mean.compareTo(a.mean));
      case _RankedSort.time:
        rows.sort((a, b) => _time(b).compareTo(_time(a)));
    }
    return rows;
  }

  String _timeText(S s, AnilistRankedStat r) {
    if (_manga) return s.Alpp_Chapters_Count(r.chapters);
    final hours = r.minutes / 60;
    return s.Alpp_Hours(NumberFormat.decimalPattern().format(hours.round()));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    if (_error != null) {
      return SizedBox(
        height: 260,
        child: ProfileMessage(
          icon: Icons.cloud_off_outlined,
          title: anilistErrorText(_error!),
          actionLabel: s.Prof_Retry,
          onAction: _load,
        ),
      );
    }
    final rows = _rows;
    if (rows == null) {
      return SizedBox(height: 260, child: ProfileLoading(label: s.Prof_Loading));
    }
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(s.Prof_Dist_Empty,
            textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
      );
    }
    final sorted = _sorted;
    final max = sorted.fold<int>(1, (a, b) => b.count > a ? b.count : a);
    final people = widget.part == AnilistStatsPart.voiceActors ||
        widget.part == AnilistStatsPart.staff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: SegmentedButton<_RankedSort>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(value: _RankedSort.count, label: Text(s.Prof_Dist_Sort_Count)),
              ButtonSegment(value: _RankedSort.mean, label: Text(s.Prof_Dist_Sort_Mean)),
              ButtonSegment(value: _RankedSort.time, label: Text(s.Alpp_Sort_Time)),
            ],
            selected: {_sort},
            onSelectionChanged: (v) => setState(() => _sort = v.first),
          ),
        ),
        for (final r in sorted)
          InkWell(
            onTap: () => _open(context, r),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(
                children: [
                  if (people) ...[
                    AnilistAvatar(name: r.name, url: r.imageUrl, size: 40),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(r.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium),
                            ),
                            Text(profileNumber(r.count), style: theme.textTheme.labelLarge),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (r.mean > 0) s.Prof_Dist_Mean(profileNumber(r.mean, digits: 2)),
                            if (_time(r) > 0) _timeText(s, r),
                          ].join(' · '),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (r.count / max).clamp(0.0, 1.0),
                            minHeight: 6,
                            color: theme.colorScheme.primary,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _open(BuildContext context, AnilistRankedStat row) {
    if (row.mediaIds.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _TitlesSheet(row: row, category: widget.category, service: widget.service),
    );
  }
}

/// The titles a statistic counted, most popular first; a tap opens the AniList title.
class _TitlesSheet extends StatefulWidget {
  final AnilistRankedStat row;
  final String category;
  final AnilistProfileService? service;

  const _TitlesSheet({required this.row, required this.category, this.service});

  @override
  State<_TitlesSheet> createState() => _TitlesSheetState();
}

class _TitlesSheetState extends State<_TitlesSheet> {
  late Future<List<AnilistFavorite>> _future = _fetch();

  Future<List<AnilistFavorite>> _fetch() =>
      (widget.service ?? AnilistProfileService.instance).titlesById(widget.row.mediaIds);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(widget.row.name, style: theme.textTheme.titleMedium),
          ),
          Expanded(
            child: FutureBuilder<List<AnilistFavorite>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ProfileMessage(
                    icon: Icons.cloud_off_outlined,
                    title: anilistErrorText(snapshot.error!),
                    actionLabel: s.Prof_Retry,
                    onAction: () => setState(() => _future = _fetch()),
                  );
                }
                final items = snapshot.data;
                if (items == null) return ProfileLoading(label: s.Prof_Loading);
                return ListView.builder(
                  controller: controller,
                  itemCount: items.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: SizedBox(
                        width: 40,
                        height: 56,
                        child: FavouriteImage(favorite: items[i], width: 40)),
                    title: Text(items[i].title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      Navigator.of(context).pop();
                      openAnilistLink(context, items[i].url);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
