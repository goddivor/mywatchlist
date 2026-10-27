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
import 'package:mywatchlist/widgets/common/select/select_option.dart';
import 'package:mywatchlist/widgets/common/select/three_state_select_bar.dart';

/// Weekly airing schedule (DAL `AnimeCalendarWidget`): a strip of the next seven
/// days, list-status filter chips and the episodes of the chosen day with their
/// countdown, the user's watching / plan-to-watch entries highlighted, and an
/// "add to calendar" sheet (device calendar or .ics). Open it with
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
          return Column(
            children: [
              DayStrip(days: state.days, selected: state.selectedDay, onSelected: _cubit.selectDay),
              _FilterBar(state: state, onChanged: _cubit.setFilter),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    S.current.Cal_Week_Count(state.weekCount),
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _cubit.load(refresh: true),
                  child: _DayList(
                    state: state,
                    seconds: _seconds,
                    minute: _minute,
                    onAnnounceNext: () => _announceNext(state),
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

class _FilterBar extends StatelessWidget {
  final CalendarState state;
  final ValueChanged<String?> onChanged;

  const _FilterBar({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (!state.listKnown) {
      final scheme = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.current.Cal_Connect_Hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ]),
      );
    }
    return ThreeStateSelectBar<String>(
      options: [
        SelectOption(CalendarFilter.all, S.current.Kit_Status_All),
        SelectOption(CalendarFilter.watching, S.current.Kit_Status_Watching),
        SelectOption(CalendarFilter.planToWatch, S.current.Kit_Status_Plan_To_Watch),
      ],
      selected: state.filter ?? CalendarFilter.all,
      onChanged: onChanged,
      cycle: CycleOption(
        label: S.current.Kit_In_List,
        exclude: SelectOption(CalendarFilter.notInList, S.current.Kit_Not_In_List),
        include: SelectOption(CalendarFilter.inList, S.current.Kit_In_List),
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  final CalendarState state;
  final ValueListenable<int> seconds;
  final ValueListenable<int> minute;
  final VoidCallback onAnnounceNext;

  const _DayList({
    required this.state,
    required this.seconds,
    required this.minute,
    required this.onAnnounceNext,
  });

  bool get _filtered =>
      state.listKnown && state.filter != null && state.filter != CalendarFilter.all;

  @override
  Widget build(BuildContext context) {
    final day = state.day;
    if (day == null || day.isEmpty) {
      final String title;
      String? description;
      String? actionLabel;
      VoidCallback? onAction;
      if (state.entries.isEmpty) {
        title = S.current.Cal_Empty_Schedule;
        description = S.current.Cal_Empty_Schedule_Desc;
      } else if (_filtered) {
        title = S.current.Cal_Empty_Filtered;
        description = S.current.Cal_Empty_Filtered_Desc;
        actionLabel = S.current.Cal_Clear_Filter;
        onAction = () => context.read<CalendarCubit>().setFilter(null);
      } else {
        title = S.current.Cal_Empty_Day;
      }
      return _Message(
        icon: Icons.event_busy_outlined,
        title: title,
        description: description,
        actionLabel: actionLabel,
        onAction: onAction,
      );
    }

    final isToday = state.selectedDay == 0;
    return ValueListenableBuilder<int>(
      valueListenable: minute,
      builder: (context, _, __) {
        final now = DateTime.now();
        var dividerAt = -1;
        if (isToday) {
          dividerAt = day.entries.where((e) => e.airingAt.isBefore(now)).length;
        }
        final count = day.entries.length + (dividerAt >= 0 ? 1 : 0);
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          itemCount: count,
          itemBuilder: (context, index) {
            if (index == dividerAt) {
              return NowDivider(now: now, timezone: state.timezone, onTap: onAnnounceNext);
            }
            final entry = day.entries[dividerAt >= 0 && index > dividerAt ? index - 1 : index];
            return EpisodeTile(
              key: ValueKey('${entry.malId}-${entry.episode}'),
              entry: entry,
              timezone: state.timezone,
              clock: seconds,
              showStatus: state.listKnown,
              onOpen: () => AppRoutes.openContent(context, id: entry.malId),
              onAddToCalendar: () =>
                  showAddToCalendarSheet(context, entry: entry, timezone: state.timezone),
            );
          },
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
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
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      children: [
        Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
