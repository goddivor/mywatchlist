import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType, DisplayType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/select/select_option.dart';

/// Sort direction of a list.
enum SortDirection {
  ascending,
  descending;

  SortDirection get flipped =>
      this == SortDirection.ascending ? SortDirection.descending : SortDirection.ascending;
}

/// One way to sort a list: [key] is stable (saved), [label] translated.
@immutable
class ListSortOption {
  final String key;
  final String label;

  /// Direction used when the option is picked (titles A→Z, scores high→low).
  final SortDirection defaultDirection;
  final IconData? icon;

  const ListSortOption(this.key, this.label,
      {this.defaultDirection = SortDirection.descending, this.icon});
}

/// A group of filter values (media type, genres…). Each value can be
/// included and, when [allowExclude], excluded.
@immutable
class ListFilterFacet {
  final String key;
  final String label;
  final List<SelectOption<String>> options;
  final bool allowExclude;

  /// Values of one facet are ORed when false (any of them), ANDed when true
  /// (all of them, e.g. genres).
  final bool matchAll;

  const ListFilterFacet({
    required this.key,
    required this.label,
    required this.options,
    this.allowExclude = false,
    this.matchAll = false,
  });
}

/// Filter of a list: per facet key, the included and excluded values.
@immutable
class ListFilter {
  final Map<String, Set<String>> included;
  final Map<String, Set<String>> excluded;

  const ListFilter({this.included = const {}, this.excluded = const {}});

  static const ListFilter none = ListFilter();

  bool get isEmpty => activeCount == 0;

  /// Number of selected values (included or excluded).
  int get activeCount =>
      included.values.fold<int>(0, (n, s) => n + s.length) +
      excluded.values.fold<int>(0, (n, s) => n + s.length);

  Set<String> includedOf(String facet) => included[facet] ?? const {};
  Set<String> excludedOf(String facet) => excluded[facet] ?? const {};

  /// Next state of [value] in [facet]: none → included → excluded (when
  /// [allowExclude]) → none.
  ListFilter toggle(String facet, String value, {bool allowExclude = false}) {
    final inc = {for (final e in included.entries) e.key: {...e.value}};
    final exc = {for (final e in excluded.entries) e.key: {...e.value}};
    final i = inc.putIfAbsent(facet, () => {});
    final x = exc.putIfAbsent(facet, () => {});
    if (i.contains(value)) {
      i.remove(value);
      if (allowExclude) x.add(value);
    } else if (x.contains(value)) {
      x.remove(value);
    } else {
      i.add(value);
    }
    inc.removeWhere((_, s) => s.isEmpty);
    exc.removeWhere((_, s) => s.isEmpty);
    return ListFilter(included: inc, excluded: exc);
  }

  /// The filter without [facet].
  ListFilter clearFacet(String facet) => ListFilter(
        included: {...included}..remove(facet),
        excluded: {...excluded}..remove(facet),
      );

  Map<String, dynamic> toJson() => {
        'in': {for (final e in included.entries) e.key: e.value.toList()},
        'out': {for (final e in excluded.entries) e.key: e.value.toList()},
      };

  static ListFilter fromJson(Object? json) {
    if (json is! Map) return none;
    Map<String, Set<String>> read(Object? m) {
      if (m is! Map) return const {};
      final result = <String, Set<String>>{};
      m.forEach((k, v) {
        if (k is String && v is List) {
          final values = v.whereType<String>().toSet();
          if (values.isNotEmpty) result[k] = values;
        }
      });
      return result;
    }

    return ListFilter(included: read(json['in']), excluded: read(json['out']));
  }

  @override
  bool operator ==(Object other) =>
      other is ListFilter &&
      _sameSets(other.included, included) &&
      _sameSets(other.excluded, excluded);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(included.entries.map((e) => Object.hash(e.key, Object.hashAllUnordered(e.value)))),
        Object.hashAllUnordered(excluded.entries.map((e) => Object.hash(e.key, Object.hashAllUnordered(e.value)))),
      );

  static bool _sameSets(Map<String, Set<String>> a, Map<String, Set<String>> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final other = b[e.key];
      if (other == null || !setEquals(other, e.value)) return false;
    }
    return true;
  }
}

/// How a list is drawn.
@immutable
class ListDisplay {
  /// [DisplayType.list_vert] or [DisplayType.grid].
  final DisplayType type;

  /// List: compact, comfortable, spacious or custom ([cardProfileId]).
  /// Grid: compact, comfortable or cover_only_grid.
  final DisplaySubType subType;
  final int gridColumns;
  final double gridHeight;
  final String? cardProfileId;

  static const int minColumns = 2;
  static const int maxColumns = 6;
  static const double minGridHeight = 160;
  static const double maxGridHeight = 360;

  const ListDisplay({
    this.type = DisplayType.list_vert,
    this.subType = DisplaySubType.comfortable,
    this.gridColumns = 3,
    this.gridHeight = 250,
    this.cardProfileId,
  });

  bool get isGrid => type == DisplayType.grid;

  ListDisplay copyWith({
    DisplayType? type,
    DisplaySubType? subType,
    int? gridColumns,
    double? gridHeight,
    String? cardProfileId,
    bool clearCardProfile = false,
  }) =>
      ListDisplay(
        type: type ?? this.type,
        subType: subType ?? this.subType,
        gridColumns: gridColumns ?? this.gridColumns,
        gridHeight: gridHeight ?? this.gridHeight,
        cardProfileId: clearCardProfile ? null : (cardProfileId ?? this.cardProfileId),
      );

  /// Same display with a sub type that exists for its type.
  ListDisplay normalized() {
    final allowed = subTypesFor(type);
    var display = allowed.contains(subType) ? this : copyWith(subType: DisplaySubType.comfortable);
    if (display.subType != DisplaySubType.custom && display.cardProfileId != null) {
      display = display.copyWith(clearCardProfile: true);
    }
    return display.copyWith(
      gridColumns: gridColumns.clamp(minColumns, maxColumns),
      gridHeight: gridHeight.clamp(minGridHeight, maxGridHeight),
    );
  }

  static List<DisplaySubType> subTypesFor(DisplayType type) => type == DisplayType.grid
      ? const [DisplaySubType.comfortable, DisplaySubType.compact, DisplaySubType.cover_only_grid]
      : const [
          DisplaySubType.comfortable,
          DisplaySubType.compact,
          DisplaySubType.spacious,
          DisplaySubType.custom,
        ];

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'subType': subType.name,
        'gridColumns': gridColumns,
        'gridHeight': gridHeight,
        'cardProfileId': cardProfileId,
      };

  static ListDisplay fromJson(Object? json, {ListDisplay fallback = const ListDisplay()}) {
    if (json is! Map) return fallback;
    T pick<T extends Enum>(List<T> values, Object? name, T d) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return d;
    }

    final type = pick(DisplayType.values, json['type'], fallback.type);
    return ListDisplay(
      type: type == DisplayType.list_horiz ? DisplayType.list_vert : type,
      subType: pick(DisplaySubType.values, json['subType'], fallback.subType),
      gridColumns: json['gridColumns'] is int ? json['gridColumns'] as int : fallback.gridColumns,
      gridHeight: json['gridHeight'] is num
          ? (json['gridHeight'] as num).toDouble()
          : fallback.gridHeight,
      cardProfileId: json['cardProfileId'] is String ? json['cardProfileId'] as String : null,
    ).normalized();
  }

  @override
  bool operator ==(Object other) =>
      other is ListDisplay &&
      other.type == type &&
      other.subType == subType &&
      other.gridColumns == gridColumns &&
      other.gridHeight == gridHeight &&
      other.cardProfileId == cardProfileId;

  @override
  int get hashCode => Object.hash(type, subType, gridColumns, gridHeight, cardProfileId);
}

/// Sort, filter and display of one list.
@immutable
class ListViewSettings {
  final String sortKey;
  final SortDirection direction;
  final ListFilter filter;
  final ListDisplay display;

  const ListViewSettings({
    required this.sortKey,
    this.direction = SortDirection.descending,
    this.filter = ListFilter.none,
    this.display = const ListDisplay(),
  });

  ListViewSettings copyWith({
    String? sortKey,
    SortDirection? direction,
    ListFilter? filter,
    ListDisplay? display,
  }) =>
      ListViewSettings(
        sortKey: sortKey ?? this.sortKey,
        direction: direction ?? this.direction,
        filter: filter ?? this.filter,
        display: display ?? this.display,
      );

  /// True when [other] differs only by its display (no reload, no re-sort).
  bool sameQuery(ListViewSettings other) =>
      other.sortKey == sortKey && other.direction == direction && other.filter == filter;

  Map<String, dynamic> toJson() => {
        'sort': sortKey,
        'dir': direction.name,
        'filter': filter.toJson(),
        'display': display.toJson(),
      };

  static ListViewSettings fromJson(Object? json, ListViewSettings fallback) {
    if (json is! Map) return fallback;
    return ListViewSettings(
      sortKey: json['sort'] is String ? json['sort'] as String : fallback.sortKey,
      direction: json['dir'] == SortDirection.ascending.name
          ? SortDirection.ascending
          : json['dir'] == SortDirection.descending.name
              ? SortDirection.descending
              : fallback.direction,
      filter: ListFilter.fromJson(json['filter']),
      display: ListDisplay.fromJson(json['display'], fallback: fallback.display),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ListViewSettings && sameQuery(other) && other.display == display;

  @override
  int get hashCode => Object.hash(sortKey, direction, filter, display);
}

/// What the sheet offers.
class ListSortFilterOptions {
  final List<ListSortOption> sorts;
  final List<ListFilterFacet> facets;

  /// Display types the list supports; empty hides the Display tab.
  final List<DisplayType> displayTypes;

  /// Custom card layouts (id → name) offered in list mode, read each time
  /// the Display tab builds (so layouts made in the editor show up at once).
  final List<SelectOption<String>> Function() cardProfiles;

  /// Opens the custom card editor; null hides the button.
  final Future<void> Function(BuildContext context)? onManageCards;

  const ListSortFilterOptions({
    required this.sorts,
    this.facets = const [],
    this.displayTypes = const [DisplayType.list_vert, DisplayType.grid],
    this.cardProfiles = _noProfiles,
    this.onManageCards,
  });

  static List<SelectOption<String>> _noProfiles() => const [];
}

/// Tab the sheet opens on.
enum ListSortFilterTab { sort, filter, display }

/// Opens the sort / filter / display sheet (DailyAL `SortFilterPopup`) on a
/// copy of [settings]; returns the new settings on Apply, null when closed.
Future<ListViewSettings?> showListSortFilterSheet(
  BuildContext context, {
  required ListViewSettings settings,
  required ListSortFilterOptions options,
  ListSortFilterTab initialTab = ListSortFilterTab.sort,
}) {
  return showModalBottomSheet<ListViewSettings>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ListSortFilterSheet(
      settings: settings,
      options: options,
      initialTab: initialTab,
    ),
  );
}

/// Body of [showListSortFilterSheet]; pops with the applied settings.
class ListSortFilterSheet extends StatefulWidget {
  final ListViewSettings settings;
  final ListSortFilterOptions options;
  final ListSortFilterTab initialTab;

  const ListSortFilterSheet({
    super.key,
    required this.settings,
    required this.options,
    this.initialTab = ListSortFilterTab.sort,
  });

  @override
  State<ListSortFilterSheet> createState() => _ListSortFilterSheetState();
}

class _ListSortFilterSheetState extends State<ListSortFilterSheet>
    with SingleTickerProviderStateMixin {
  late ListViewSettings _value = widget.settings;
  late final List<ListSortFilterTab> _tabs = [
    ListSortFilterTab.sort,
    if (widget.options.facets.isNotEmpty) ListSortFilterTab.filter,
    if (widget.options.displayTypes.isNotEmpty) ListSortFilterTab.display,
  ];
  late final TabController _controller = TabController(
    length: _tabs.length,
    vsync: this,
    initialIndex: _tabs.contains(widget.initialTab) ? _tabs.indexOf(widget.initialTab) : 0,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _tabLabel(ListSortFilterTab tab) => switch (tab) {
        ListSortFilterTab.sort => S.current.UserList_Sort,
        ListSortFilterTab.filter => widget.settings.filter.isEmpty && _value.filter.isEmpty
            ? S.current.UserList_Filter
            : S.current.UserList_Filter_Count(_value.filter.activeCount),
        ListSortFilterTab.display => S.current.UserList_Display,
      };

  void _resetCurrent() {
    final tab = _tabs[_controller.index];
    setState(() {
      _value = switch (tab) {
        ListSortFilterTab.sort => _value.copyWith(
            sortKey: widget.settings.sortKey, direction: widget.settings.direction),
        ListSortFilterTab.filter => _value.copyWith(filter: ListFilter.none),
        ListSortFilterTab.display => _value.copyWith(display: widget.settings.display),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: height * 0.72,
      child: Column(
        children: [
          TabBar(
            controller: _controller,
            tabs: [for (final t in _tabs) Tab(text: _tabLabel(t))],
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: [
                for (final t in _tabs)
                  switch (t) {
                    ListSortFilterTab.sort => _SortTab(
                        options: widget.options.sorts,
                        sortKey: _value.sortKey,
                        direction: _value.direction,
                        onChanged: (key, dir) =>
                            setState(() => _value = _value.copyWith(sortKey: key, direction: dir)),
                      ),
                    ListSortFilterTab.filter => _FilterTab(
                        facets: widget.options.facets,
                        filter: _value.filter,
                        onChanged: (f) => setState(() => _value = _value.copyWith(filter: f)),
                      ),
                    ListSortFilterTab.display => _DisplayTab(
                        options: widget.options,
                        display: _value.display,
                        onChanged: (d) => setState(() => _value = _value.copyWith(display: d)),
                        onManageCards: widget.options.onManageCards == null
                            ? null
                            : () async {
                                await widget.options.onManageCards!(context);
                                if (!mounted) return;
                                // A deleted layout can no longer be the selected one.
                                final ids = widget.options.cardProfiles().map((p) => p.value);
                                setState(() {
                                  final d = _value.display;
                                  if (d.subType == DisplaySubType.custom &&
                                      !ids.contains(d.cardProfileId)) {
                                    _value = _value.copyWith(
                                        display: d.copyWith(
                                            subType: DisplaySubType.comfortable,
                                            clearCardProfile: true));
                                  }
                                });
                              },
                      ),
                  },
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                TextButton(onPressed: _resetCurrent, child: Text(S.current.UserList_Reset)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.current.Cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_value.copyWith(
                    display: _value.display.normalized(),
                  )),
                  child: Text(S.current.UserList_Apply),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortTab extends StatelessWidget {
  final List<ListSortOption> options;
  final String sortKey;
  final SortDirection direction;
  final void Function(String key, SortDirection direction) onChanged;

  const _SortTab({
    required this.options,
    required this.sortKey,
    required this.direction,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: options.length,
      itemBuilder: (context, i) {
        final option = options[i];
        final selected = option.key == sortKey;
        final asc = direction == SortDirection.ascending;
        return ListTile(
          leading: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
          title: Text(option.label),
          selected: selected,
          trailing: selected
              ? TextButton.icon(
                  onPressed: () => onChanged(option.key, direction.flipped),
                  icon: Icon(asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 18),
                  label: Text(asc ? S.current.UserList_Ascending : S.current.UserList_Descending),
                )
              : null,
          onTap: () => selected
              ? onChanged(option.key, direction.flipped)
              : onChanged(option.key, option.defaultDirection),
        );
      },
    );
  }
}

class _FilterTab extends StatelessWidget {
  final List<ListFilterFacet> facets;
  final ListFilter filter;
  final ValueChanged<ListFilter> onChanged;

  const _FilterTab({required this.facets, required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: facets.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(S.current.UserList_Filter_Hint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          );
        }
        final facet = facets[i - 1];
        final inc = filter.includedOf(facet.key);
        final exc = filter.excludedOf(facet.key);
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(facet.label, style: theme.textTheme.titleSmall)),
                  if (inc.isNotEmpty || exc.isNotEmpty)
                    TextButton(
                      onPressed: () => onChanged(filter.clearFacet(facet.key)),
                      child: Text(S.current.UserList_Clear),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final option in facet.options)
                    _FacetChip(
                      label: option.label,
                      included: inc.contains(option.value),
                      excluded: exc.contains(option.value),
                      onTap: () => onChanged(filter.toggle(facet.key, option.value,
                          allowExclude: facet.allowExclude)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FacetChip extends StatelessWidget {
  final String label;
  final bool included;
  final bool excluded;
  final VoidCallback onTap;

  const _FacetChip({
    required this.label,
    required this.included,
    required this.excluded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: included || excluded,
      showCheckmark: false,
      avatar: included
          ? Icon(Icons.check_rounded, size: 16, color: scheme.onSecondaryContainer)
          : excluded
              ? Icon(Icons.remove_rounded, size: 16, color: scheme.onErrorContainer)
              : null,
      selectedColor: excluded ? scheme.errorContainer : scheme.secondaryContainer,
      labelStyle: TextStyle(
        color: excluded
            ? scheme.onErrorContainer
            : included
                ? scheme.onSecondaryContainer
                : null,
        decoration: excluded ? TextDecoration.lineThrough : null,
      ),
      tooltip: excluded
          ? S.current.UserList_Excluded
          : included
              ? S.current.UserList_Included
              : null,
      onSelected: (_) => onTap(),
    );
  }
}

class _DisplayTab extends StatelessWidget {
  final ListSortFilterOptions options;
  final ListDisplay display;
  final ValueChanged<ListDisplay> onChanged;
  final VoidCallback? onManageCards;

  const _DisplayTab({
    required this.options,
    required this.display,
    required this.onChanged,
    required this.onManageCards,
  });

  String _subTypeLabel(DisplaySubType t) => switch (t) {
        DisplaySubType.comfortable => S.current.UserList_Comfortable,
        DisplaySubType.compact => S.current.UserList_Compact,
        DisplaySubType.spacious => S.current.UserList_Spacious,
        DisplaySubType.cover_only_grid => S.current.UserList_Cover_Only,
        DisplaySubType.custom => S.current.UserList_Custom_Card,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = options.displayTypes;
    final subTypes = ListDisplay.subTypesFor(display.type)
        .where((t) => t != DisplaySubType.custom)
        .toList();
    final profiles = options.cardProfiles();
    final showCustom = !display.isGrid && (profiles.isNotEmpty || onManageCards != null);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        if (types.length > 1) ...[
          Text(S.current.UserList_Layout, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<DisplayType>(
            segments: [
              for (final t in types)
                ButtonSegment(
                  value: t,
                  icon: Icon(t == DisplayType.grid
                      ? Icons.grid_view_rounded
                      : Icons.view_agenda_outlined),
                  label: Text(t == DisplayType.grid
                      ? S.current.UserList_Layout_Grid
                      : S.current.UserList_Layout_List),
                ),
            ],
            selected: {display.type},
            onSelectionChanged: (s) => onChanged(
                display.copyWith(type: s.first, subType: DisplaySubType.comfortable)
                    .normalized()),
          ),
          const SizedBox(height: 20),
        ],
        Text(S.current.UserList_Card_Style, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in subTypes)
              ChoiceChip(
                label: Text(_subTypeLabel(t)),
                selected: display.subType == t,
                onSelected: (_) => onChanged(display.copyWith(subType: t, clearCardProfile: true)),
              ),
          ],
        ),
        if (showCustom) ...[
          const SizedBox(height: 20),
          Text(S.current.UserList_Custom_Cards, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (profiles.isEmpty)
            Text(S.current.UserList_Custom_Cards_Empty,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in profiles)
                ChoiceChip(
                  label: Text(p.label),
                  selected: display.subType == DisplaySubType.custom &&
                      display.cardProfileId == p.value,
                  onSelected: (_) => onChanged(display.copyWith(
                      subType: DisplaySubType.custom, cardProfileId: p.value)),
                ),
            ],
          ),
          if (onManageCards != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onManageCards,
                icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                label: Text(S.current.UserList_Manage_Cards),
              ),
            ),
        ],
        if (display.isGrid) ...[
          const SizedBox(height: 20),
          Text(S.current.UserList_Grid_Columns(display.gridColumns),
              style: theme.textTheme.titleSmall),
          Slider(
            value: display.gridColumns.toDouble(),
            min: ListDisplay.minColumns.toDouble(),
            max: ListDisplay.maxColumns.toDouble(),
            divisions: ListDisplay.maxColumns - ListDisplay.minColumns,
            label: '${display.gridColumns}',
            onChanged: (v) => onChanged(display.copyWith(gridColumns: v.round())),
          ),
          Text(S.current.UserList_Grid_Height(display.gridHeight.round()),
              style: theme.textTheme.titleSmall),
          Slider(
            value: display.gridHeight,
            min: ListDisplay.minGridHeight,
            max: ListDisplay.maxGridHeight,
            divisions: 20,
            label: '${display.gridHeight.round()}',
            onChanged: (v) => onChanged(display.copyWith(gridHeight: v)),
          ),
        ],
      ],
    );
  }
}
