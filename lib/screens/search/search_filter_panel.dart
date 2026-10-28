import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType, DisplayType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_catalog.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/search/search_options.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// How anime and manga results are laid out.
@immutable
class SearchDisplay {
  final DisplayType type;
  final DisplaySubType subType;
  final int gridColumns;
  final double gridHeight;

  const SearchDisplay({
    this.type = DisplayType.grid,
    this.subType = DisplaySubType.compact,
    this.gridColumns = 3,
    this.gridHeight = 200,
  });

  static const defaults = SearchDisplay();

  SearchDisplay copyWith({
    DisplayType? type,
    DisplaySubType? subType,
    int? gridColumns,
    double? gridHeight,
  }) =>
      SearchDisplay(
        type: type ?? this.type,
        subType: subType ?? this.subType,
        gridColumns: gridColumns ?? this.gridColumns,
        gridHeight: gridHeight ?? this.gridHeight,
      );

  bool get isGrid => type == DisplayType.grid;
}

/// What the panel hands back when the user applies it.
@immutable
class SearchPanelResult {
  final String category;
  final SearchFilters filters;
  final SearchDisplay display;

  const SearchPanelResult(this.category, this.filters, this.display);
}

enum _PanelTab { category, filter, display }

/// The sheet under the search bar, laid out like DailyAL's sort/filter popup: a tab bar (category,
/// filters, display), radio lists for the category and the display, the reset / close / apply bar.
/// It edits a draft and hands the whole thing back through [onApply]; nothing is searched while
/// the user is still choosing.
class SearchFilterPanel extends StatefulWidget {
  final String category;
  final SearchFilters filters;
  final SearchDisplay display;
  final ValueChanged<SearchPanelResult> onApply;
  final VoidCallback onClose;

  const SearchFilterPanel({
    super.key,
    required this.category,
    required this.filters,
    required this.display,
    required this.onApply,
    required this.onClose,
  });

  @override
  State<SearchFilterPanel> createState() => _SearchFilterPanelState();
}

class _SearchFilterPanelState extends State<SearchFilterPanel> with TickerProviderStateMixin {
  late String _category = widget.category;
  late SearchFilters _filters = widget.filters.forCategory(widget.category);
  late SearchDisplay _display = widget.display;
  late TabController _controller = _newController(
    initialTab: _tabs.contains(_PanelTab.filter) ? _PanelTab.filter : _PanelTab.category,
  );

  bool get _hasFilters => SearchFilters.allowedKeys(_category).isNotEmpty;
  bool get _hasDisplay => SearchCategory.isMedia(_category);

  List<_PanelTab> get _tabs => [
        _PanelTab.category,
        if (_hasFilters) _PanelTab.filter,
        if (_hasDisplay) _PanelTab.display,
      ];

  _PanelTab get _currentTab {
    final tabs = _tabs;
    return _controller.index < tabs.length ? tabs[_controller.index] : _PanelTab.category;
  }

  TabController _newController({required _PanelTab initialTab}) {
    final tabs = _tabs;
    return TabController(
      length: tabs.length,
      initialIndex: tabs.indexOf(initialTab).clamp(0, tabs.length - 1),
      vsync: this,
    );
  }

  /// The tab list follows the category; when its length changes the controller is replaced, and
  /// the user stays on the category tab they are using.
  void _syncController() {
    if (_controller.length == _tabs.length) return;
    final old = _controller;
    _controller = _newController(initialTab: _PanelTab.category);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setCategory(String category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      _filters = SearchFilters.empty;
      _syncController();
    });
  }

  void _setFilters(SearchFilters filters) => setState(() => _filters = filters);

  void _reset() {
    setState(() {
      switch (_currentTab) {
        case _PanelTab.category:
          _category = SearchCategory.all;
          _filters = SearchFilters.empty;
          _syncController();
        case _PanelTab.filter:
          _filters = SearchFilters.empty;
        case _PanelTab.display:
          _display = SearchDisplay.defaults;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabs = _tabs;
    return Material(
      color: theme.colorScheme.surface,
      elevation: 4,
      child: Column(
        children: [
          SizedBox(
            height: 50,
            child: TabBar(
              controller: _controller,
              padding: EdgeInsets.zero,
              tabs: [for (final tab in tabs) Tab(text: _tabLabel(tab))],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: [
                for (final tab in tabs)
                  switch (tab) {
                    _PanelTab.category => _CategoryTab(selected: _category, onSelected: _setCategory),
                    _PanelTab.filter => _FiltersTab(
                        key: ValueKey(_category),
                        category: _category,
                        filters: _filters,
                        onChanged: _setFilters,
                      ),
                    _PanelTab.display =>
                      _DisplayTab(display: _display, onChanged: (d) => setState(() => _display = d)),
                  },
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                TextButton(onPressed: _reset, child: Text(S.current.Srch_Reset)),
                const Spacer(),
                TextButton(onPressed: widget.onClose, child: Text(S.current.Srch_Close)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => widget.onApply(SearchPanelResult(_category, _filters, _display)),
                  child: Text(_filters.activeCount > 0
                      ? S.current.Srch_Apply_Count(_filters.activeCount)
                      : S.current.Srch_Apply),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tabLabel(_PanelTab tab) => switch (tab) {
        _PanelTab.category => S.current.Srch_Tab_Category,
        _PanelTab.filter => S.current.Srch_Tab_Filter,
        _PanelTab.display => S.current.Srch_Tab_Display,
      };
}

/// DailyAL's category view: one radio row per category, scrolled to the selected one.
class _CategoryTab extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryTab({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final options = SearchOptions.categories();
    final index = options.indexWhere((o) => o.value == selected);
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
      child: ScrollablePositionedList.builder(
        padding: const EdgeInsets.only(top: 30, bottom: 16),
        itemCount: options.length,
        initialScrollIndex: index < 0 ? 0 : index,
        itemBuilder: (context, i) => RadioListTile<String>(
          value: options[i].value,
          title: Text(options[i].label),
        ),
      ),
    );
  }
}

/// DailyAL's display view: radio rows for the layout and its density, then the grid sliders with
/// their bounds on each side.
class _DisplayTab extends StatelessWidget {
  final SearchDisplay display;
  final ValueChanged<SearchDisplay> onChanged;

  const _DisplayTab({required this.display, required this.onChanged});

  static const _minColumns = 2;
  static const _maxColumns = 8;
  static const _minHeight = 160.0;
  static const _maxHeight = 360.0;

  @override
  Widget build(BuildContext context) {
    final subTypes = display.isGrid
        ? [
            SelectOption(DisplaySubType.comfortable, S.current.Srch_Display_Comfortable),
            SelectOption(DisplaySubType.compact, S.current.Srch_Display_Compact),
            SelectOption(DisplaySubType.cover_only_grid, S.current.Srch_Display_CoverOnly),
          ]
        : [
            SelectOption(DisplaySubType.comfortable, S.current.Srch_Display_Comfortable),
            SelectOption(DisplaySubType.compact, S.current.Srch_Display_Compact),
            SelectOption(DisplaySubType.spacious, S.current.Srch_Display_Spacious),
          ];
    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 16),
      children: [
        ListTile(title: Text(S.current.Srch_Display_Layout)),
        RadioGroup<DisplayType>(
          groupValue: display.type,
          onChanged: (value) {
            if (value != null) onChanged(display.copyWith(type: value, subType: DisplaySubType.comfortable));
          },
          child: Column(
            children: [
              RadioListTile<DisplayType>(value: DisplayType.grid, title: Text(S.current.Srch_Display_Grid)),
              RadioListTile<DisplayType>(value: DisplayType.list_vert, title: Text(S.current.Srch_Display_List)),
            ],
          ),
        ),
        ListTile(title: Text(S.current.Srch_Display_Density)),
        RadioGroup<DisplaySubType>(
          groupValue: display.subType,
          onChanged: (value) {
            if (value != null) onChanged(display.copyWith(subType: value));
          },
          child: Column(
            children: [
              for (final option in subTypes) RadioListTile<DisplaySubType>(value: option.value, title: Text(option.label)),
            ],
          ),
        ),
        if (display.isGrid) ...[
          _BoundedSlider(
            title: S.current.Srch_Display_Columns(display.gridColumns),
            value: display.gridColumns.toDouble(),
            min: _minColumns.toDouble(),
            max: _maxColumns.toDouble(),
            divisions: _maxColumns - _minColumns,
            minLabel: '$_minColumns',
            maxLabel: '$_maxColumns',
            label: '${display.gridColumns}',
            onChanged: (v) => onChanged(display.copyWith(gridColumns: v.round())),
          ),
          const SizedBox(height: 10),
          _BoundedSlider(
            title: S.current.Srch_Display_Height(display.gridHeight.round()),
            value: display.gridHeight.clamp(_minHeight, _maxHeight),
            min: _minHeight,
            max: _maxHeight,
            divisions: 100,
            minLabel: '${_minHeight.round()}',
            maxLabel: '${_maxHeight.round()}',
            label: '${display.gridHeight.round()}',
            onChanged: (v) => onChanged(display.copyWith(gridHeight: v.roundToDouble())),
          ),
        ],
      ],
    );
  }
}

/// A titled slider with its minimum and maximum written on each side, as in DailyAL.
class _BoundedSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String minLabel;
  final String maxLabel;
  final String label;
  final ValueChanged<double> onChanged;

  const _BoundedSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.minLabel,
    required this.maxLabel,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 10),
              Text(minLabel),
              const SizedBox(width: 10),
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: label,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Text(maxLabel),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------------------------------

typedef _RowBuilder = Widget Function(BuildContext context);

class _FiltersTab extends StatelessWidget {
  final String category;
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  const _FiltersTab({super.key, required this.category, required this.filters, required this.onChanged});

  static final List<SelectOption<int>> _producerOptions = [
    for (final entry in SearchCatalog.producers) SelectOption(entry.key, entry.value),
  ];
  static final List<SelectOption<int>> _magazineOptions = [
    for (final entry in SearchCatalog.magazines) SelectOption(entry.key, entry.value),
  ];

  List<_RowBuilder> _rows() {
    final manga = category == SearchCategory.manga;
    final f = filters;

    _RowBuilder chips<T>(String title, String key, List<SelectOption<T>> options, {String? disabled}) {
      return (context) => _FilterSection(
            title: title,
            active: f.has(key),
            onClear: () => onChanged(f.remove(key)),
            child: disabled != null
                ? _Hint(disabled)
                : ThreeStateSelectBar<T>(
                    padding: EdgeInsets.zero,
                    options: options,
                    selected: f.has(key) ? (key == FilterKey.score || key == FilterKey.gender ? f.integer(key) : f.text(key)) as T? : null,
                    onChanged: (value) => onChanged(f.set(key, value)),
                  ),
          );
    }

    _RowBuilder picker<T>(String title, String key, List<SelectOption<T>> options, {String? labelOverride}) {
      return (context) {
        final Object? raw = options.isNotEmpty && options.first.value is int ? f.integer(key) : f.text(key);
        final T? current = raw as T?;
        final label = labelOf(options, current) ?? labelOverride;
        return _FilterSection(
          title: title,
          active: f.has(key),
          onClear: () => onChanged(f.remove(key)),
          child: _PickerPill(
            label: label,
            onTap: () async {
              final picked = await showSelectSheet<T>(
                context,
                options: options,
                selected: current,
                title: title,
              );
              if (picked != null) onChanged(f.set(key, picked));
            },
          ),
        );
      };
    }

    _RowBuilder date(String title, String key) {
      return (context) => _FilterSection(
            title: title,
            active: f.has(key),
            onClear: () => onChanged(f.remove(key)),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SelectDate(
                date: DateTime.tryParse(f.text(key) ?? ''),
                firstDate: DateTime(1917),
                lastDate: DateTime(DateTime.now().year + 2, 12, 31),
                onChanged: (d) => onChanged(f.set(key, formatApiDate(d))),
                onClear: () => onChanged(f.remove(key)),
              ),
            ),
          );
    }

    _RowBuilder text(String title, String key, {bool digits = false, String? hint}) {
      return (context) => _FilterSection(
            title: title,
            active: f.has(key),
            onClear: null,
            child: _TextFilter(
              initial: digits ? (f.integer(key)?.toString() ?? '') : (f.text(key) ?? ''),
              hint: hint,
              digits: digits,
              onChanged: (value) => onChanged(f.set(key, digits ? int.tryParse(value) : value.trim())),
            ),
          );
    }

    _RowBuilder genres() => (context) => _GenresFilter(manga: manga, filters: f, onChanged: onChanged);

    final needsOrder = f.has(FilterKey.orderBy) ? null : S.current.Srch_Needs_Order;

    switch (category) {
      case SearchCategory.anime:
        return [
          chips(S.current.Srch_F_Type, FilterKey.type, SearchOptions.animeTypes()),
          chips(S.current.Srch_F_Status, FilterKey.status, SearchOptions.animeStatuses()),
          chips(S.current.Srch_F_Rated, FilterKey.rating, SearchOptions.ratings()),
          genres(),
          picker(S.current.Srch_F_OrderBy, FilterKey.orderBy, SearchOptions.animeOrders()),
          chips(S.current.Srch_F_Sort, FilterKey.sort, SearchOptions.sorts(), disabled: needsOrder),
          chips(S.current.Srch_F_MinScore, FilterKey.score, SearchOptions.scores()),
          date(S.current.Srch_F_Start, FilterKey.startDate),
          date(S.current.Srch_F_End, FilterKey.endDate),
          picker(S.current.Srch_F_Studio, FilterKey.producer, _producerOptions,
              labelOverride: f.text(FilterKey.producerLabel)),
          picker(S.current.Srch_F_Letter, FilterKey.letter, SearchOptions.letters()),
        ];
      case SearchCategory.manga:
        return [
          chips(S.current.Srch_F_Type, FilterKey.type, SearchOptions.mangaTypes()),
          chips(S.current.Srch_F_Status, FilterKey.status, SearchOptions.mangaStatuses()),
          genres(),
          picker(S.current.Srch_F_OrderBy, FilterKey.orderBy, SearchOptions.mangaOrders()),
          chips(S.current.Srch_F_Sort, FilterKey.sort, SearchOptions.sorts(), disabled: needsOrder),
          chips(S.current.Srch_F_MinScore, FilterKey.score, SearchOptions.scores()),
          date(S.current.Srch_F_Start, FilterKey.startDate),
          date(S.current.Srch_F_End, FilterKey.endDate),
          picker(S.current.Srch_F_Magazine, FilterKey.magazine, _magazineOptions,
              labelOverride: f.text(FilterKey.magazineLabel)),
          picker(S.current.Srch_F_Letter, FilterKey.letter, SearchOptions.letters()),
        ];
      case SearchCategory.forum:
        return [
          picker(S.current.Srch_F_Board, FilterKey.boardId, SearchOptions.boards()),
          picker(S.current.Srch_F_SubBoard, FilterKey.subboardId, SearchOptions.subBoards()),
          text(S.current.Srch_F_TopicUser, FilterKey.topicUser),
          text(S.current.Srch_F_Username, FilterKey.user),
        ];
      case SearchCategory.user:
        return [
          text(S.current.Srch_F_Location, FilterKey.location, hint: S.current.Srch_F_Location_Hint),
          text(S.current.Srch_F_AgeLow, FilterKey.ageLow, digits: true, hint: '18'),
          text(S.current.Srch_F_AgeHigh, FilterKey.ageHigh, digits: true, hint: '24'),
          chips(S.current.Srch_F_Gender, FilterKey.gender, SearchOptions.genders()),
        ];
      case SearchCategory.featured:
        return [picker(S.current.Srch_F_Tag, FilterKey.tag, SearchOptions.featuredTags(), labelOverride: _tagLabel(f))];
      case SearchCategory.news:
        return [picker(S.current.Srch_F_Tag, FilterKey.tag, SearchOptions.newsTags(), labelOverride: _tagLabel(f))];
      case SearchCategory.interestStack:
        return [chips(S.current.Srch_F_StackType, FilterKey.stackType, SearchOptions.stackTypes())];
      default:
        return const [];
    }
  }

  static String? _tagLabel(SearchFilters f) {
    final tag = f.text(FilterKey.tag);
    return tag == null ? null : SearchOptions.tagLabel(tag) ?? tag;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    if (rows.isEmpty) {
      return Center(child: _Hint(S.current.Srch_No_Filters));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index](context),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback? onClear;
  final Widget child;

  const _FilterSection({required this.title, required this.active, required this.onClear, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: active ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
              if (active && onClear != null)
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(S.current.Srch_Clear),
                ),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _PickerPill extends StatelessWidget {
  final String? label;
  final VoidCallback onTap;

  const _PickerPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final picked = label != null;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ActionChip(
        onPressed: onTap,
        backgroundColor: picked ? scheme.secondaryContainer : null,
        label: Text(label ?? S.current.Select),
        avatar: Icon(Icons.arrow_drop_down_rounded, color: picked ? scheme.onSecondaryContainer : null),
      ),
    );
  }
}

/// A text field that reports each edit; owns its controller.
class _TextFilter extends StatefulWidget {
  final String initial;
  final String? hint;
  final bool digits;
  final ValueChanged<String> onChanged;

  const _TextFilter({required this.initial, required this.onChanged, this.hint, this.digits = false});

  @override
  State<_TextFilter> createState() => _TextFilterState();
}

class _TextFilterState extends State<_TextFilter> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: widget.digits ? TextInputType.number : TextInputType.text,
      inputFormatters: widget.digits ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)] : null,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        isDense: true,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: S.current.Srch_Clear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Genres: include / exclude
// ---------------------------------------------------------------------------------------------

class _GenresFilter extends StatelessWidget {
  final bool manga;
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  const _GenresFilter({required this.manga, required this.filters, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final any = filters.genresIn.isNotEmpty || filters.genresOut.isNotEmpty;
    return _FilterSection(
      title: S.current.Srch_F_Genres,
      active: any,
      onClear: () => onChanged(filters.remove(FilterKey.genresIn).remove(FilterKey.genresOut)),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final id in filters.genresIn)
            InputChip(
              avatar: Icon(Icons.check_rounded, size: 18, color: scheme.onPrimaryContainer),
              backgroundColor: scheme.primaryContainer,
              label: Text(SearchCatalog.genreLabel(id, manga: manga), style: TextStyle(color: scheme.onPrimaryContainer)),
              deleteIconColor: scheme.onPrimaryContainer,
              onPressed: () => onChanged(filters.cycleGenre(id)),
              onDeleted: () => onChanged(filters.set(FilterKey.genresIn, [...filters.genresIn]..remove(id))),
            ),
          for (final id in filters.genresOut)
            InputChip(
              avatar: Icon(Icons.remove_rounded, size: 18, color: scheme.onErrorContainer),
              backgroundColor: scheme.errorContainer,
              label: Text(SearchCatalog.genreLabel(id, manga: manga), style: TextStyle(color: scheme.onErrorContainer)),
              deleteIconColor: scheme.onErrorContainer,
              onPressed: () => onChanged(filters.cycleGenre(id)),
              onDeleted: () => onChanged(filters.set(FilterKey.genresOut, [...filters.genresOut]..remove(id))),
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: Text(any ? S.current.Srch_Genres_Edit : S.current.Srch_Genres_Choose),
            onPressed: () async {
              final result = await showModalBottomSheet<SearchFilters>(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                showDragHandle: true,
                useSafeArea: true,
                builder: (_) => DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.8,
                  minChildSize: 0.4,
                  maxChildSize: 0.95,
                  builder: (context, controller) => GenrePicker(
                    manga: manga,
                    filters: filters,
                    scrollController: controller,
                  ),
                ),
              );
              if (result != null) onChanged(result);
            },
          ),
        ],
      ),
    );
  }
}

/// The genre list: every genre cycles off → included → excluded → off on tap. Searchable, built
/// lazily, grouped like MyAnimeList (Genres, Explicit genres, Themes, Demographics). Pops with the
/// edited filters when the user taps Done.
class GenrePicker extends StatefulWidget {
  final bool manga;
  final SearchFilters filters;
  final ScrollController? scrollController;

  const GenrePicker({super.key, required this.manga, required this.filters, this.scrollController});

  @override
  State<GenrePicker> createState() => _GenrePickerState();
}

class _GenrePickerState extends State<GenrePicker> {
  late SearchFilters _filters = widget.filters;
  final TextEditingController _query = TextEditingController();
  late final List<_GenreRow> _rows = _buildRows();
  late List<_GenreRow> _visible = _rows;

  List<_GenreRow> _buildRows() {
    final rows = <_GenreRow>[];
    for (final group in SearchCatalog.genreGroups(manga: widget.manga)) {
      rows.add(_GenreRow.header(group.title));
      for (final id in group.ids) {
        final label = SearchCatalog.genreLabel(id, manga: widget.manga);
        rows.add(_GenreRow(id, label, foldForSearch(label)));
      }
    }
    return rows;
  }

  void _filter(String text) {
    final needle = foldForSearch(text.trim());
    setState(() {
      _visible = needle.isEmpty ? _rows : [for (final r in _rows) if (r.id != null && r.key.contains(needle)) r];
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
          child: Row(
            children: [
              Expanded(child: Text(S.current.Srch_F_Genres, style: theme.textTheme.titleLarge)),
              FilledButton(onPressed: () => Navigator.of(context).pop(_filters), child: Text(S.current.Srch_Done)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _query,
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: S.current.Kit_Search_Options,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              S.current.Srch_Genres_Hint,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _visible.length,
            itemBuilder: (context, index) {
              final row = _visible[index];
              final id = row.id;
              if (id == null) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                  child: Text(row.label,
                      style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                );
              }
              final state = _filters.genreState(id);
              final (IconData icon, Color? color) = switch (state) {
                GenreState.included => (Icons.check_circle_rounded, scheme.primary),
                GenreState.excluded => (Icons.remove_circle_rounded, scheme.error),
                GenreState.off => (Icons.radio_button_unchecked_rounded, scheme.outline),
              };
              return ListTile(
                dense: true,
                leading: Icon(icon, color: color),
                title: Text(row.label),
                trailing: switch (state) {
                  GenreState.included => Text(S.current.Srch_Included, style: TextStyle(color: scheme.primary)),
                  GenreState.excluded => Text(S.current.Srch_Excluded, style: TextStyle(color: scheme.error)),
                  GenreState.off => null,
                },
                onTap: () => setState(() => _filters = _filters.cycleGenre(id)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GenreRow {
  final int? id;
  final String label;
  final String key;

  const _GenreRow(int this.id, this.label, this.key);
  const _GenreRow.header(this.label)
      : id = null,
        key = '';
}
