import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuMediaKind;
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_open.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart' show HomeMessage;

/// [items] whose next episode comes out on [day] (local time), by time.
List<KitsuCalendarItem> kitsuCalendarOn(List<KitsuCalendarItem> items, DateTime day) => [
      for (final i in items)
        if (_sameDay(i.nextRelease.toLocal(), day)) i,
    ];

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// The Kitsu calendar. Kitsu has no schedule, so it is built from the library: the Watching and
/// Plan to watch anime with a next episode date (`nextRelease`), on a day strip from today over
/// the week, in local time. A row opens the native Kitsu page.
class KitsuCalendarPage extends StatefulWidget {
  /// The library items; by default [KitsuLibrary.calendar].
  final Future<List<KitsuCalendarItem>> Function()? source;
  final DateTime Function()? now;

  const KitsuCalendarPage({super.key, this.source, this.now});

  @override
  State<KitsuCalendarPage> createState() => _KitsuCalendarPageState();
}

class _KitsuCalendarPageState extends State<KitsuCalendarPage> {
  static const int _days = 7;

  DateTime get _now => (widget.now ?? DateTime.now)();
  late final DateTime _today = () {
    final t = _now.toLocal();
    return DateTime(t.year, t.month, t.day);
  }();
  late DateTime _day = _today;
  late Future<List<KitsuCalendarItem>> _future = _load();

  Future<List<KitsuCalendarItem>> _load() => (widget.source ?? KitsuLibrary.instance.calendar)();

  Future<void> _refresh() async {
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
    return DateFormat.MMMEd(Intl.getCurrentLocale()).format(d);
  }

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < _days; i++) DateTime(_today.year, _today.month, _today.day + i)];
    return Scaffold(
      appBar: AppBar(title: Text(S.current.Skr_Calendar)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<KitsuCalendarItem>>(
          future: _future,
          builder: (context, snap) {
            final data = snap.data;
            return CustomScrollView(
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
                      itemBuilder: (_, i) {
                        final count = data == null ? 0 : kitsuCalendarOn(data, days[i]).length;
                        return Center(
                          child: ChoiceChip(
                            label: Text(count > 0 ? '${_dayLabel(days[i])} · $count' : _dayLabel(days[i])),
                            selected: days[i] == _day,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _day = days[i]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                ..._body(context, snap, data),
                SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, AsyncSnapshot<List<KitsuCalendarItem>> snap,
      List<KitsuCalendarItem>? data) {
    if (snap.hasError) {
      return [
        SliverToBoxAdapter(
          child: HomeMessage(
            icon: Icons.cloud_off_outlined,
            text: S.current.Kcal_Failed,
            actionLabel: S.current.Hw_Retry,
            onAction: _refresh,
          ),
        ),
      ];
    }
    if (data == null) {
      return const [
        SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        ),
      ];
    }
    final items = kitsuCalendarOn(data, _day);
    if (items.isEmpty) {
      return [
        SliverToBoxAdapter(child: HomeMessage(icon: Icons.event_busy_outlined, text: S.current.Kcal_Empty)),
      ];
    }
    return [
      SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) => KitsuCalendarTile(
          item: items[i],
          now: _now,
          onTap: () => openKitsuTitle(
            context,
            kind: KitsuMediaKind.anime,
            id: '${items[i].entry.id}',
            title: items[i].entry.title,
            posterUrl: items[i].entry.imageUrl,
          ),
        ),
      ),
    ];
  }
}

/// A calendar row: local time (accent until it comes out), poster, title, the list status in
/// its colour and the progress.
class KitsuCalendarTile extends StatelessWidget {
  final KitsuCalendarItem item;
  final DateTime now;
  final VoidCallback onTap;

  const KitsuCalendarTile({super.key, required this.item, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = item.entry;
    final out = !item.nextRelease.isAfter(now);
    final status = e.status;
    final progress = e.total > 0 ? '${e.progress} / ${e.total}' : '${e.progress}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                DateFormat.Hm(Intl.getCurrentLocale()).format(item.nextRelease.toLocal()),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: out ? scheme.onSurfaceVariant : scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            AppImage(
              url: e.imageUrl,
              width: 44,
              height: 64,
              borderRadius: BorderRadius.circular(8),
              placeholderColor: scheme.surfaceContainerHighest,
              semanticLabel: e.title,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (status != null) ...[
                        Icon(Icons.circle, size: 9, color: status.colors(context).color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${status.label(isAnime: true)} · $progress',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
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
