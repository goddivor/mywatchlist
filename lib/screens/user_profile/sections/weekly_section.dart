import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/mal_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// Tabs of the week: Monday to Sunday, then the airing titles without a broadcast slot.
const int weeklyDayCount = 8;

/// Day index (0 = Monday … 6 = Sunday) a JST broadcast [slot] falls on in the time zone
/// [pref]; 7 when the slot is unknown. [localOffset] is the device offset (tests).
int weeklyDayOf(BroadcastSlot? slot, TimezonePref pref, {Duration? localOffset}) {
  if (slot == null) return 7;
  const week = 7 * 24 * 60;
  final jst = (slot.weekday - 1) * 24 * 60 + slot.minutes;
  final offset = switch (pref) {
    TimezonePref.utc => 0,
    TimezonePref.jst => 9 * 60,
    TimezonePref.local => (localOffset ?? DateTime.now().timeZoneOffset).inMinutes,
  };
  final minutes = ((jst - 9 * 60 + offset) % week + week) % week;
  return minutes ~/ (24 * 60);
}

/// Minutes after midnight of a slot in the time zone [pref] (sorts a day by airing time).
int _minuteOfDay(BroadcastSlot slot, TimezonePref pref) {
  final offset = switch (pref) {
    TimezonePref.utc => 0,
    TimezonePref.jst => 9 * 60,
    TimezonePref.local => DateTime.now().timeZoneOffset.inMinutes,
  };
  return ((slot.minutes - 9 * 60 + offset) % 1440 + 1440) % 1440;
}

/// [entries] that are airing, grouped by broadcast day in [pref], each day by airing time.
List<List<ListEntryView>> groupWeekly(Iterable<ListEntryView> entries, TimezonePref pref,
    {Duration? localOffset}) {
  final days = List.generate(weeklyDayCount, (_) => <ListEntryView>[]);
  final seen = <int>{};
  for (final e in entries) {
    if (e.releaseState != ReleaseState.releasing || !seen.add(e.id)) continue;
    days[weeklyDayOf(e.broadcast, pref, localOffset: localOffset)].add(e);
  }
  for (final day in days.take(7)) {
    day.sort((a, b) => _minuteOfDay(a.broadcast!, pref).compareTo(_minuteOfDay(b.broadcast!, pref)));
  }
  days[7].sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return days;
}

/// Your own profile's "Weekly" tab (DailyAL's weekly anime of the user page): the airing
/// anime of your Watching and Plan to Watch lists, one chip per broadcast day (today first
/// selected), in the time zone of the preferences. Cards edit and step like My List.
class WeeklySection extends StatefulWidget {
  /// Overrides for tests.
  final MalUserListAdapter? adapter;

  const WeeklySection({super.key, this.adapter});

  @override
  State<WeeklySection> createState() => _WeeklySectionState();
}

class _WeeklySectionState extends State<WeeklySection> with AutomaticKeepAliveClientMixin {
  late final MalUserListAdapter _adapter = widget.adapter ?? MalUserListAdapter();
  final ValueNotifier<Set<int>> _busy = ValueNotifier(const {});
  late final EntryActions _actions = EntryActions(
    onOpen: (e) => _adapter.open(context, e),
    onEdit: _edit,
    onStep: _step,
    canStep: _adapter.canStep,
    busy: _busy,
  );

  late final TimezonePref _zone = Preferences.content.timezone;
  late int _day = _today();
  List<ListEntryView>? _entries;
  List<List<ListEntryView>> _days = const [];
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  int _today() {
    final utc = DateTime.now().toUtc();
    final day = switch (_zone) {
      TimezonePref.utc => utc.weekday,
      TimezonePref.jst => utc.add(const Duration(hours: 9)).weekday,
      TimezonePref.local => utc.toLocal().weekday,
    };
    return day - 1;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  Future<List<ListEntryView>> _whole(ListEntryStatus status) async {
    final out = <ListEntryView>[];
    var offset = 0;
    while (true) {
      final page = await _adapter.fetch(
        category: 'anime',
        status: status,
        offset: offset,
        limit: _adapter.maxPageSize,
      );
      out.addAll(page.entries);
      if (!page.hasMore || page.entries.isEmpty) return out;
      offset += page.entries.length;
    }
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _entries = null;
    });
    try {
      final lists = await Future.wait([
        _whole(ListEntryStatus.current),
        _whole(ListEntryStatus.planned),
      ]);
      if (!mounted) return;
      setState(() => _set([...lists[0], ...lists[1]]));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _set(List<ListEntryView> entries) {
    _entries = entries;
    _days = groupWeekly(entries, _zone);
  }

  void _replace(ListEntryView entry, {bool remove = false}) {
    final entries = _entries;
    if (entries == null) return;
    setState(() => _set([
          for (final e in entries)
            if (e.id != entry.id)
              e
            else if (!remove &&
                (entry.status == ListEntryStatus.current ||
                    entry.status == ListEntryStatus.planned))
              entry,
        ]));
  }

  Future<void> _edit(ListEntryView entry) async {
    final result = await _adapter.edit(context, entry);
    if (!mounted) return;
    switch (result) {
      case ListEditUpdated(entry: final saved):
        _replace(saved);
      case ListEditRemoved():
        _replace(entry, remove: true);
      case ListEditUnchanged():
        break;
    }
  }

  Future<void> _step(ListEntryView entry, int delta) async {
    if (_busy.value.contains(entry.id)) return;
    _busy.value = {..._busy.value, entry.id};
    try {
      final saved = await _adapter.step(entry, delta);
      if (mounted) _replace(saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(S.current.UserList_Update_Failed)));
      }
    } finally {
      _busy.value = {..._busy.value}..remove(entry.id);
    }
  }

  List<String> _dayNames(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    return [
      // 2024-01-01 is a Monday.
      for (var i = 0; i < 7; i++) cap(DateFormat('EEEE', locale).format(DateTime.utc(2024, 1, 1 + i))),
      S.of(context).Others,
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    Widget fill(Widget child) => SliverFillRemaining(hasScrollBody: false, child: child);
    final entries = _entries;
    final error = _error;
    if (error != null) {
      return ProfileTabScroll(
        storageKey: 'weekly',
        slivers: [fill(ProfileErrorView(error: error, onRetry: _load))],
      );
    }
    if (entries == null) {
      return ProfileTabScroll(
        storageKey: 'weekly',
        slivers: [fill(ProfileLoading(label: s.Prof_Loading))],
      );
    }
    if (_days.every((d) => d.isEmpty)) {
      return ProfileTabScroll(
        storageKey: 'weekly',
        slivers: [
          fill(ProfileMessage(
            icon: Icons.event_busy_outlined,
            title: s.Pl_Weekly_Empty,
            actionLabel: s.Prof_Retry,
            onAction: _load,
          )),
        ],
      );
    }
    final names = _dayNames(context);
    final day = _days[_day];
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    final general = Preferences.general;
    final style = EntryCardStyle(
      showStatus: true,
      showPriority: general.showPriority,
      showAiringInfo: true,
      cardBackground: general.showAnimeMangaCard,
    );
    return ProfileTabScroll(
      storageKey: 'weekly',
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _DaysDelegate(
            color: Theme.of(context).colorScheme.surface,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: weeklyDayCount,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                // "Others" only when some airing title has no slot.
                if (i == 7 && _days[7].isEmpty) return const SizedBox.shrink();
                return ChoiceChip(
                  label: Text(s.Pl_Count_Label(names[i], _days[i].length)),
                  selected: i == _day,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _day = i),
                );
              },
            ),
          ),
        ),
        if (day.isEmpty)
          fill(ProfileMessage(icon: Icons.inbox_outlined, title: s.Pl_Weekly_Day_Empty))
        else
          SliverPadding(
            padding: const EdgeInsets.only(top: 4),
            sliver: SliverFixedExtentList.builder(
              itemExtent: listRowExtent(DisplaySubType.comfortable),
              itemCount: day.length,
              itemBuilder: (context, i) => EntryListTile(
                key: ValueKey(day[i].id),
                entry: day[i],
                subType: DisplaySubType.comfortable,
                actions: _actions,
                style: style,
                now: now,
                locale: locale,
              ),
            ),
          ),
      ],
    );
  }
}

class _DaysDelegate extends SliverPersistentHeaderDelegate {
  static const double height = 48;

  final Widget child;
  final Color color;

  const _DaysDelegate({required this.child, required this.color});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: color, child: child);

  @override
  bool shouldRebuild(_DaysDelegate oldDelegate) => true;
}
