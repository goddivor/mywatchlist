import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/calendar/add_to_calendar_sheet.dart';
import 'package:mywatchlist/widgets/calendar/calendar_cubit.dart';
import 'package:mywatchlist/widgets/calendar/calendar_logic.dart';
import 'package:mywatchlist/widgets/calendar/calendar_models.dart';
import 'package:mywatchlist/widgets/calendar/calendar_tiles.dart';

/// Weekly airing schedule (DAL `AnimeCalendarWidget`): the seven days from
/// today as one list grouped by day ("Wednesday (2)", foldable), each episode
/// with its time and countdown, a "now" line inside today, and DailyAL's
/// All / Plan to Watch / Watching chips (both statuses on by default). Today
/// keeps the episodes that already aired. Each row opens the anime or the "add
/// to calendar" sheet (device calendar or .ics). Open it with
/// `AppRoutes.openCalendar`.
///
/// Times follow the time zone preference (JST, UTC or local).
class CalendarScreen extends StatelessWidget {
  /// A ready-made cubit (tests); by default one is created and loaded.
  final CalendarCubit? cubit;

  const CalendarScreen({super.key, this.cubit});

  static bool _listKnown(AccountState state) =>
      state is AccountLoaded && state.selectedAccountType == AccountType.myanimelist;

  @override
  Widget build(BuildContext context) {
    final existing = cubit;
    return BlocProvider<CalendarCubit>(
      create: (context) =>
          existing ??
          (CalendarCubit(
            timezone: Preferences.content.timezone,
            listKnown: _listKnown(context.read<AccountBloc>().state),
            initialFilter: CalendarFilter.watchingOrPlanned,
          )..load()),
      child: MultiBlocListener(
        listeners: [
          BlocListener<AccountBloc, AccountState>(
            listener: (context, state) => context.read<CalendarCubit>().setListKnown(_listKnown(state)),
          ),
          BlocListener<PreferencesBloc, AppPreferences>(
            listenWhen: (a, b) => a.content.timezone != b.content.timezone,
            listener: (context, state) => context.read<CalendarCubit>().setTimezone(state.content.timezone),
          ),
        ],
        child: const _CalendarView(),
      ),
    );
  }
}

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  final ValueNotifier<int> _seconds = ValueNotifier(DateTime.now().millisecondsSinceEpoch ~/ 1000);
  final ValueNotifier<int> _minute = ValueNotifier(DateTime.now().millisecondsSinceEpoch ~/ 60000);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _seconds.value = now ~/ 1000;
      if (now ~/ 60000 != _minute.value) {
        _minute.value = now ~/ 60000;
        context.read<CalendarCubit>().tick();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _seconds.dispose();
    _minute.dispose();
    super.dispose();
  }

  CalendarCubit get _cubit => context.read<CalendarCubit>();

  void _setTimezone(TimezonePref pref) {
    _cubit.setTimezone(pref);
    context.read<PreferencesBloc>().add(ContentPreferencesChanged((p) => p.copyWith(timezone: pref)));
  }

  void _announceNext(CalendarState state) {
    final now = DateTime.now();
    CalendarEntry? next;
    for (final day in state.days) {
      for (final e in day.entries) {
        if (e.airingAt.isAfter(now)) {
          next = e;
          break;
        }
      }
      if (next != null) break;
    }
    if (next == null) return;
    final shown = DateFormat('EEE HH:mm', Localizations.localeOf(context).toString())
        .format(inTimezone(next.airingAt, state.timezone));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(S.current.Cal_Next_Show(next.title, '$shown ${timezoneLabel(state.timezone)}')),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.Cal_Title),
        actions: [
          BlocSelector<CalendarCubit, CalendarState, TimezonePref>(
            selector: (s) => s.timezone,
            builder: (context, tz) => PopupMenuButton<TimezonePref>(
              tooltip: S.current.Cal_Timezone,
              icon: const Icon(Icons.public),
              onSelected: _setTimezone,
              itemBuilder: (_) => [
                for (final option in [
                  (TimezonePref.local, S.current.Prefs_Timezone_Local),
                  (TimezonePref.jst, S.current.Prefs_Timezone_Jst),
                  (TimezonePref.utc, S.current.Prefs_Timezone_Utc),
                ])
                  CheckedPopupMenuItem<TimezonePref>(
                    value: option.$1,
                    checked: option.$1 == tz,
                    child: Text(option.$2),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: S.current.Cal_Refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => _cubit.load(refresh: true),
          ),
        ],
      ),
      body: BlocBuilder<CalendarCubit, CalendarState>(
        builder: (context, state) {
          if (state.status == CalendarStatus.loading) return const _LoadingSkeleton();
          if (state.status == CalendarStatus.failure) {
            return _Message(
              icon: Icons.cloud_off_outlined,
              title: S.current.Cal_Error_Title,
              description: S.current.Cal_Error_Desc,
              actionLabel: S.current.Cal_Retry,
              onAction: () => _cubit.load(refresh: true),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _cubit.load(refresh: true),
            child: _WeekList(
              state: state,
              seconds: _seconds,
              minute: _minute,
              onAnnounceNext: () => _announceNext(state),
            ),
          );
        },
      ),
    );
  }
}

/// DailyAL's status toggles: All, Plan to Watch, Watching.
class _FilterBar extends StatelessWidget {
  final String? filter;
  final ValueChanged<String> onTap;

  const _FilterBar({required this.filter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final chip in [
            (CalendarFilter.all, S.current.Kit_Status_All),
            (CalendarFilter.planToWatch, S.current.Kit_Status_Plan_To_Watch),
            (CalendarFilter.watching, S.current.Kit_Status_Watching),
          ])
            FilterChip(
              label: Text(chip.$2),
              selected: isChipOn(filter, chip.$1),
              onSelected: (_) => onTap(chip.$1),
            ),
        ],
      ),
    );
  }
}

/// One row of the week list.
sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  final CalendarDay day;
  const _HeaderRow(this.day);
}

class _NowRow extends _Row {
  const _NowRow();
}

/// One episode, or two side by side on wide screens.
class _EntriesRow extends _Row {
  final List<CalendarEntry> entries;
  const _EntriesRow(this.entries);
}

class _WeekList extends StatefulWidget {
  final CalendarState state;
  final ValueListenable<int> seconds;
  final ValueListenable<int> minute;
  final VoidCallback onAnnounceNext;

  const _WeekList({
    required this.state,
    required this.seconds,
    required this.minute,
    required this.onAnnounceNext,
  });

  @override
  State<_WeekList> createState() => _WeekListState();
}

class _WeekListState extends State<_WeekList> {
  /// Days the user folded, by date.
  final Set<DateTime> _folded = {};

  CalendarState get state => widget.state;

  bool get _filtered => state.listKnown && state.filter != null && state.filter != CalendarFilter.all;

  void _toggle(DateTime date) => setState(() => _folded.contains(date) ? _folded.remove(date) : _folded.add(date));

  /// Today always (it carries the "now" line), then every day with episodes.
  List<_Row> _rows(DateTime now, int columns) {
    final rows = <_Row>[];
    void addEntries(List<CalendarEntry> list) {
      for (var i = 0; i < list.length; i += columns) {
        rows.add(_EntriesRow(list.sublist(i, i + columns > list.length ? list.length : i + columns)));
      }
    }

    for (var i = 0; i < state.days.length; i++) {
      final day = state.days[i];
      if (i > 0 && day.isEmpty) continue;
      rows.add(_HeaderRow(day));
      if (_folded.contains(day.date)) continue;
      if (i == 0) {
        final aired = day.entries.where((e) => !e.airingAt.isAfter(now)).toList();
        addEntries(aired);
        rows.add(const _NowRow());
        addEntries(day.entries.sublist(aired.length));
      } else {
        addEntries(day.entries);
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CalendarCubit>();
    final filterBar = state.listKnown
        ? _FilterBar(filter: state.filter, onTap: (chip) => cubit.setFilter(toggleFilter(state.filter, chip)))
        : null;
    final empty = state.days.every((d) => d.isEmpty);
    if (empty) {
      final filtered = state.entries.isNotEmpty && _filtered;
      return _Message(
        header: filterBar,
        icon: Icons.event_busy_outlined,
        title: filtered ? S.current.Cal_Empty_Filtered : S.current.Cal_Empty_Schedule,
        actionLabel: filtered ? S.current.Cal_Clear_Filter : null,
        onAction: filtered ? () => cubit.setFilter(CalendarFilter.all) : null,
      );
    }

    final columns = MediaQuery.sizeOf(context).width >= 600 ? 2 : 1;
    return ValueListenableBuilder<int>(
      valueListenable: widget.minute,
      builder: (context, _, __) {
        final now = DateTime.now();
        final rows = _rows(now, columns);
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (filterBar != null) SliverToBoxAdapter(child: filterBar),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) => switch (rows[index]) {
                  _HeaderRow(:final day) => DayHeader(
                      key: ValueKey(day.date),
                      date: day.date,
                      count: day.entries.length,
                      open: !_folded.contains(day.date),
                      onToggle: () => _toggle(day.date),
                    ),
                  _NowRow() => NowDivider(now: now, timezone: state.timezone, onTap: widget.onAnnounceNext),
                  _EntriesRow(:final entries) => columns == 1
                      ? _tile(entries.first, now)
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < columns; i++)
                              Expanded(child: i < entries.length ? _tile(entries[i], now) : const SizedBox.shrink()),
                          ],
                        ),
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(CalendarEntry entry, DateTime now) => EpisodeTile(
        key: ValueKey('${entry.malId}-${entry.episode}'),
        entry: entry,
        timezone: state.timezone,
        clock: widget.seconds,
        showStatus: state.listKnown,
        onOpen: () => AppRoutes.openContent(context, id: entry.malId),
        onAddToCalendar: entry.airingAt.isAfter(now)
            ? () => showAddToCalendarSheet(context, entry: entry, timezone: state.timezone)
            : null,
      );
}

class _Message extends StatelessWidget {
  /// Shown above the message (the filter chips, so a filter can be undone).
  final Widget? header;
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    this.header,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (header != null) header!,
        const SizedBox(height: 64),
        Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        ),
        if (description != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              description!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          Center(child: FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!))),
        ],
      ],
    );
  }
}

/// Static placeholder rows while the schedule loads (no animation to run).
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 80, 12, 0),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
          child: const SizedBox(height: 106, width: double.infinity),
        ),
      ),
    );
  }
}
