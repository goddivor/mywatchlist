import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistTitle;
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart' show HomeMessage;
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ListEntryStatus;

/// [utc] in the time zone setting (local, JST or UTC).
DateTime anilistInZone(DateTime utc, TimezonePref zone) => switch (zone) {
      TimezonePref.utc => utc.toUtc(),
      TimezonePref.jst => utc.toUtc().add(const Duration(hours: 9)),
      TimezonePref.local => utc.toLocal(),
    };

/// The UTC start of [day] (a calendar date, its time ignored) in [zone].
DateTime anilistDayStart(DateTime day, TimezonePref zone) => switch (zone) {
      TimezonePref.utc => DateTime.utc(day.year, day.month, day.day),
      TimezonePref.jst => DateTime.utc(day.year, day.month, day.day).subtract(const Duration(hours: 9)),
      TimezonePref.local => DateTime(day.year, day.month, day.day).toUtc(),
    };

/// The list status of an AniList `MediaListStatus` value (`REPEATING` counts as watching).
ListEntryStatus? anilistListStatus(String? status) => switch (status) {
      'CURRENT' || 'REPEATING' => ListEntryStatus.current,
      'PLANNING' => ListEntryStatus.planned,
      'COMPLETED' => ListEntryStatus.completed,
      'PAUSED' => ListEntryStatus.onHold,
      'DROPPED' => ListEntryStatus.dropped,
      _ => null,
    };

/// AniList's weekly calendar (`airingSchedules`), as AniHyou shows it: a day strip from today
/// over the week, "My list" (watching or planning) or "All", the day's episodes by air time in
/// the time zone setting. A row opens the native AniList page.
class AnilistCalendarPage extends StatefulWidget {
  final AnilistDiscoverService? service;
  final DateTime Function()? now;
  final TimezonePref? zone;

  const AnilistCalendarPage({super.key, this.service, this.now, this.zone});

  @override
  State<AnilistCalendarPage> createState() => _AnilistCalendarPageState();
}

class _AnilistCalendarPageState extends State<AnilistCalendarPage> {
  static const int _days = 7;
  static const int _maxPages = 6;

  AnilistDiscoverService get _service => widget.service ?? AnilistDiscoverService.instance;
  TimezonePref get _zone => widget.zone ?? Preferences.content.timezone;
  DateTime get _now => (widget.now ?? DateTime.now)();

  late final DateTime _today = () {
    final t = anilistInZone(_now.toUtc(), _zone);
    return DateTime(t.year, t.month, t.day);
  }();
  late DateTime _day = _today;
  late bool _mine = _service.signedIn;
  final Map<DateTime, Future<List<AnilistAiring>>> _loads = {};

  Future<List<AnilistAiring>> _load(DateTime day) {
    return _loads.putIfAbsent(day, () async {
      final from = anilistDayStart(day, _zone);
      final to = anilistDayStart(DateTime(day.year, day.month, day.day + 1), _zone);
      final all = <AnilistAiring>[];
      for (var page = 1; page <= _maxPages; page++) {
        final result = await _service.schedule(from, to, page: page);
        all.addAll(result.items);
        if (!result.hasNext) break;
      }
      return all;
    });
  }

  Future<void> _refresh() async {
    _loads.remove(_day);
    final next = _load(_day);
    setState(() {});
    try {
      await next;
    } catch (_) {}
  }

  String _dayLabel(DateTime d) {
    final diff = d.difference(_today).inDays;
    if (diff == 0) return S.current.Scf_Window_Today;
    if (diff == 1) return S.current.Scf_Tomorrow;
    return DateFormat.MMMEd(Intl.getCurrentLocale()).format(d);
  }

  static bool _onMyList(AnilistAiring a) =>
      switch (anilistListStatus(a.listStatus)) { ListEntryStatus.current || ListEntryStatus.planned => true, _ => false };

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < _days; i++) DateTime(_today.year, _today.month, _today.day + i)];
    final signedIn = _service.signedIn;
    return Scaffold(
      appBar: AppBar(title: Text(S.current.Skr_Calendar)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Center(
                    child: ChoiceChip(
                      label: Text(_dayLabel(days[i])),
                      selected: days[i] == _day,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _day = days[i]),
                    ),
                  ),
                ),
              ),
            ),
            if (signedIn)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 4, 15, 8),
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: true, label: Text(S.current.Alc_My_List)),
                      ButtonSegment(value: false, label: Text(S.current.Alc_All)),
                    ],
                    selected: {_mine},
                    onSelectionChanged: (v) => setState(() => _mine = v.first),
                  ),
                ),
              ),
            FutureBuilder<List<AnilistAiring>>(
              key: ValueKey(_day),
              future: _load(_day),
              builder: (context, snap) {
                if (snap.hasError) {
                  return SliverToBoxAdapter(
                    child: HomeMessage(
                      icon: Icons.cloud_off_outlined,
                      text: S.current.Alc_Failed,
                      actionLabel: S.current.Hw_Retry,
                      onAction: _refresh,
                    ),
                  );
                }
                final data = snap.data;
                if (data == null) {
                  return const SliverToBoxAdapter(
                    child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                  );
                }
                final items = _mine && signedIn ? data.where(_onMyList).toList() : data;
                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: HomeMessage(
                      icon: Icons.event_busy_outlined,
                      text: _mine && signedIn ? S.current.Alc_Empty_Mine : S.current.Alc_Empty,
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => AnilistAiringTile(
                    airing: items[i],
                    zone: _zone,
                    now: _now,
                    onTap: () => openAnilistTitle(
                      context,
                      category: 'anime',
                      id: items[i].media.id,
                      title: items[i].media.title,
                      coverUrl: items[i].media.coverUrl,
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }
}

/// A calendar row: air time (time zone setting, accent until it airs), cover, title, episode
/// and a dot in the list status colour when the title is on the user's list.
class AnilistAiringTile extends StatelessWidget {
  final AnilistAiring airing;
  final TimezonePref zone;
  final DateTime now;
  final VoidCallback onTap;

  const AnilistAiringTile({
    super.key,
    required this.airing,
    required this.zone,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final aired = !airing.at.isAfter(now);
    final status = anilistListStatus(airing.listStatus);
    final clock = DateFormat.Hm(Intl.getCurrentLocale()).format(anilistInZone(airing.at, zone));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                clock,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: aired ? scheme.onSurfaceVariant : scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            AppImage(
              url: airing.media.coverUrl,
              width: 44,
              height: 64,
              borderRadius: BorderRadius.circular(8),
              placeholderColor: scheme.surfaceContainerHighest,
              semanticLabel: airing.media.title,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(airing.media.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (status != null) ...[
                        Icon(Icons.circle, size: 9, color: status.colors(context).color),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        _episodeLabel(),
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _episodeLabel() {
    final total = airing.media.episodes;
    final ep = S.current.Sk_Episode_Short(airing.episode);
    return total != null && total > 0 ? '$ep / $total' : ep;
  }
}
