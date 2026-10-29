import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart' show openSimklMedia;
import 'package:mywatchlist/widgets/Simkl/simkl_states.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// One episode of Simkl's calendar, joined with the user's list entry of its title.
@immutable
class SimklAiring {
  final SimklMedia media;
  final ListEntryView? entry;

  const SimklAiring(this.media, [this.entry]);

  /// Episode 1: the title premieres.
  bool get premiere => media.episode == 1;

  /// The last episode of the user's entry (Simkl's `finale_type` is not in the parsed calendar,
  /// so a finale is known only for titles of the list with a known total).
  bool get finale {
    final e = entry;
    final n = media.episode;
    return e != null && n != null && e.total > 0 && n == e.total && n > 1;
  }
}

/// The day of [utc] in the time zone setting.
DateTime simklZoneDay(DateTime utc, {TimezonePref? zone}) {
  final t = SimklFormat.inZone(utc, zone: zone);
  return DateTime(t.year, t.month, t.day);
}

/// The calendar episodes airing on [day] (in the time zone setting), by air time, joined with
/// [list] (Simkl id to entry). [mine] keeps only titles of the list; [mineFirst] puts them before
/// the others, keeping the time order inside each group.
List<SimklAiring> simklAiringOn(
  List<SimklMedia> calendar,
  DateTime day, {
  Map<int, ListEntryView> list = const {},
  bool mine = false,
  bool mineFirst = false,
  TimezonePref? zone,
}) {
  final target = DateTime(day.year, day.month, day.day);
  final out = <SimklAiring>[
    for (final m in calendar)
      if (m.airDate case final at? when simklZoneDay(at, zone: zone) == target)
        if (!mine || list.containsKey(m.simklId)) SimklAiring(m, list[m.simklId]),
  ]..sort((a, b) => a.media.airDate!.compareTo(b.media.airDate!));
  if (!mineFirst) return out;
  return [...out.where((a) => a.entry != null), ...out.where((a) => a.entry == null)];
}

/// The signed-in user's list by Simkl id, or empty (signed out, dead session, network).
Future<Map<int, ListEntryView>> simklListById({SimklListService? service}) async {
  if (!simklSignedIn && service == null) return const {};
  try {
    final list = await (service ?? SimklListService.instance).anime();
    return {for (final e in list) e.id: e};
  } catch (_) {
    return const {};
  }
}

/// A small tonal badge (Premiere, Finale).
class SimklBadge extends StatelessWidget {
  final String label;
  final bool strong;

  const SimklBadge(this.label, {super.key, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = strong ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final fg = strong ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
      ),
    );
  }
}

/// A calendar row: exact time (time zone setting), poster, title, episode, Premiere / Finale
/// badges and a dot in the list status colour when the title is on the user's list.
class SimklAiringTile extends StatelessWidget {
  final SimklAiring airing;
  final VoidCallback onTap;
  final DateTime? now;

  const SimklAiringTile({super.key, required this.airing, required this.onTap, this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = airing.media;
    final at = m.airDate;
    final entry = airing.entry;
    final status = entry?.status;
    final aired = at != null && !at.isAfter(now ?? DateTime.now());
    final timeStyle = theme.textTheme.titleSmall?.copyWith(
      color: aired ? scheme.onSurfaceVariant : scheme.primary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 52, child: Text(at == null ? '' : SimklFormat.clock(at), style: timeStyle)),
            AppImage(
              url: m.posterUrl,
              width: 44,
              height: 64,
              borderRadius: BorderRadius.circular(8),
              placeholderColor: scheme.surfaceContainerHighest,
              semanticLabel: m.title,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (status != null)
                        Icon(Icons.circle, size: 9, color: status.colors(context).color),
                      if (m.episode != null)
                        Text(
                          S.current.Sk_Episode_Short(m.episode!),
                          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      if (airing.premiere) SimklBadge(S.current.Skr_Premiere),
                      if (airing.finale) SimklBadge(S.current.Skr_Finale, strong: true),
                      if (m.watchers != null && m.watchers! > 0)
                        Text(
                          S.current.Skr_Watchers(SimklFormat.compact(m.watchers!)),
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
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
}

/// "My shows / All anime" switch (shown only with a Simkl account).
class SimklMineSwitch extends StatelessWidget {
  final bool mine;
  final ValueChanged<bool> onChanged;

  const SimklMineSwitch({super.key, required this.mine, required this.onChanged});

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: true, label: Text(S.current.Skr_My_Shows)),
          ButtonSegment(value: false, label: Text(S.current.Skr_All_Anime)),
        ],
        selected: {mine},
        onSelectionChanged: (v) => onChanged(v.first),
      );
}

/// Simkl's anime calendar: a day strip from yesterday over the next two weeks (Simkl's file
/// covers yesterday and 33 days), My shows / All anime (My shows first when signed in), the
/// day's episodes by exact time in the time zone setting, with Premiere and Finale badges. A
/// tap opens the native Simkl page.
class SimklCalendarPage extends StatefulWidget {
  final SimklDiscoverService? service;
  final SimklListService? listService;
  final DateTime Function()? now;

  const SimklCalendarPage({super.key, this.service, this.listService, this.now});

  @override
  State<SimklCalendarPage> createState() => _SimklCalendarPageState();
}

class _SimklCalendarPageState extends State<SimklCalendarPage> {
  static const int _days = 16;

  late final DateTime _today = simklZoneDay((widget.now ?? DateTime.now)().toUtc());
  late DateTime _day = _today;
  late bool _mine = simklSignedIn || widget.listService != null;
  late Future<(List<SimklMedia>, Map<int, ListEntryView>)> _future = _load();

  SimklDiscoverService get _service => widget.service ?? SimklDiscoverService.instance;
  bool get _hasList => simklSignedIn || widget.listService != null;

  Future<(List<SimklMedia>, Map<int, ListEntryView>)> _load() async {
    final list = simklListById(service: widget.listService);
    final calendar = await _service.calendar();
    return (calendar, await list);
  }

  Future<void> _refresh() async {
    _service.cdn.invalidate();
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  String _dayLabel(DateTime d) {
    final diff = d.difference(_today).inDays;
    if (diff == 0) return S.current.Scf_Window_Today;
    if (diff == 1) return S.current.Scf_Tomorrow;
    if (diff == -1) return S.current.Skr_Yesterday;
    return DateFormat.MMMEd().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = -1; i < _days - 1; i++) DateTime(_today.year, _today.month, _today.day + i)];
    return Scaffold(
      appBar: AppBar(title: Text(S.current.Skr_Calendar), actions: const [SizedBox.shrink()]),
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
            if (_hasList)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 4, 15, 8),
                  child: SimklMineSwitch(mine: _mine, onChanged: (v) => setState(() => _mine = v)),
                ),
              ),
            FutureBuilder<(List<SimklMedia>, Map<int, ListEntryView>)>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return SliverToBoxAdapter(
                    child: HomeMessage(
                      icon: Icons.cloud_off_outlined,
                      text: S.current.Sk_Load_Failed,
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
                final items = simklAiringOn(data.$1, _day, list: data.$2, mine: _mine && _hasList);
                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: HomeMessage(icon: Icons.event_busy_outlined, text: S.current.Sk_Feed_Empty),
                  );
                }
                return SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => SimklAiringTile(
                    airing: items[i],
                    now: widget.now?.call(),
                    onTap: () => openSimklMedia(context, items[i].media),
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
