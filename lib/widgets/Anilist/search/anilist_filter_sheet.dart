import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_catalog.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_tag_explorer.dart';

/// AniList's filter sheet (AniHyou / anilist.co's search filters): format, status, season and
/// years, genres and tags to include or exclude, minimum tag rank, tag categories, streaming
/// (or reading) services, country, source, length ranges, score, popularity, my list,
/// licensing and adult content. Answers the edited query, null when dismissed.
Future<AnilistMediaQuery?> showAnilistFilterSheet(
  BuildContext context, {
  required AnilistMediaQuery query,
  required AnilistCatalogData catalog,
  required bool signedIn,
  required bool adultAllowed,
}) {
  return showModalBottomSheet<AnilistMediaQuery>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AnilistFilterSheet(
      query: query,
      catalog: catalog,
      signedIn: signedIn,
      adultAllowed: adultAllowed,
    ),
  );
}

/// The sort sheet: every sort key of the category and the direction. Answers the `MediaSort`.
Future<String?> showAnilistSortSheet(BuildContext context, {required AnilistMediaQuery query}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _SortSheet(query: query),
  );
}

class _SortSheet extends StatefulWidget {
  final AnilistMediaQuery query;
  const _SortSheet({required this.query});

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late bool _descending = widget.query.sort == AnilistSorts.searchMatch || AnilistSorts.isDescending(widget.query.sort);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final current = AnilistSorts.keyOf(widget.query.sort);
    final keys = [
      if (widget.query.hasSearch || current == AnilistSorts.searchMatch) AnilistSorts.searchMatch,
      ...AnilistSorts.keysFor(widget.query.category),
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(child: Text(s.Als_Sort, style: Theme.of(context).textTheme.titleLarge)),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.arrow_upward_rounded),
                        tooltip: s.Als_Sort_Ascending),
                    ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.arrow_downward_rounded),
                        tooltip: s.Als_Sort_Descending),
                  ],
                  selected: {_descending},
                  onSelectionChanged: (v) => setState(() => _descending = v.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: keys.length,
              itemBuilder: (context, i) {
                final key = keys[i];
                final selected = key == current;
                return ListTile(
                  selected: selected,
                  title: Text(AnilistLabels.sortKey(key)),
                  trailing: selected ? const Icon(Icons.check_rounded) : null,
                  // The current key too: it applies a new direction.
                  onTap: () => Navigator.of(context).pop(AnilistSorts.of(key, descending: _descending)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AnilistFilterSheet extends StatefulWidget {
  final AnilistMediaQuery query;
  final AnilistCatalogData catalog;
  final bool signedIn;
  final bool adultAllowed;

  const AnilistFilterSheet({
    super.key,
    required this.query,
    required this.catalog,
    required this.signedIn,
    required this.adultAllowed,
  });

  @override
  State<AnilistFilterSheet> createState() => _AnilistFilterSheetState();
}

class _AnilistFilterSheetState extends State<AnilistFilterSheet> {
  late AnilistMediaQuery _q = widget.query;

  bool get _manga => _q.category == 'manga';

  void _set(AnilistMediaQuery q) => setState(() => _q = q);

  List<T> _toggle<T>(List<T> list, T v) => list.contains(v) ? ([...list]..remove(v)) : [...list, v];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final catalog = widget.catalog;
    final adult = widget.adultAllowed;
    final sources = catalog.sourcesFor(_q.category);
    final sections = <Widget>[
      _Section(
        title: s.Als_Sec_Format,
        child: _Chips<String>(
          values: AnilistFilterValues.formatsFor(_q.category),
          label: AnilistLabels.format,
          selected: _q.formats.contains,
          onTap: (v) => _set(_q.copyWith(formats: _toggle(_q.formats, v))),
        ),
      ),
      _Section(
        title: s.Als_Sec_Status,
        child: _Chips<String>(
          values: AnilistFilterValues.statuses,
          label: AnilistLabels.status,
          selected: _q.allStatuses.contains,
          onTap: (v) => _set(_q.copyWith(status: null, statuses: _toggle(_q.allStatuses, v))),
        ),
      ),
      if (!_manga)
        _Section(
          title: s.Als_Sec_Season,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Chips<String>(
                values: AnilistFilterValues.seasons,
                label: AnilistLabels.season,
                selected: (v) => _q.season == v,
                onTap: (v) => _set(_q.copyWith(
                  season: _q.season == v ? null : v,
                  seasonYear: _q.season == v ? null : (_q.seasonYear ?? DateTime.now().year),
                )),
              ),
              if (_q.season != null) ...[
                const SizedBox(height: 8),
                DropdownMenu<int>(
                  initialSelection: _q.seasonYear,
                  label: Text(s.Als_Sec_Year),
                  menuHeight: 320,
                  onSelected: (y) => _set(_q.copyWith(seasonYear: y)),
                  dropdownMenuEntries: [
                    for (var y = AnilistFilterValues.lastYear; y >= AnilistFilterValues.firstYear; y--)
                      DropdownMenuEntry(value: y, label: '$y'),
                  ],
                ),
              ],
            ],
          ),
        ),
      _RangeSection(
        title: s.Als_Sec_Year,
        min: AnilistFilterValues.firstYear,
        max: AnilistFilterValues.lastYear,
        value: _q.years,
        group: false,
        onChanged: (r) => _set(_q.copyWith(years: r)),
      ),
      _Section(
        title: s.Als_Sec_Genres,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in catalog.genresFor(adult: adult))
              _TriChip(
                label: g,
                state: _q.allGenres.contains(g)
                    ? _Tri.include
                    : _q.genresExcluded.contains(g)
                        ? _Tri.exclude
                        : _Tri.none,
                onTap: () {
                  final included = _q.allGenres.contains(g);
                  final excluded = _q.genresExcluded.contains(g);
                  _set(_q.copyWith(
                    genre: null,
                    genres: included ? ([..._q.allGenres]..remove(g)) : excluded ? _q.allGenres : [..._q.allGenres, g],
                    genresExcluded: included
                        ? [..._q.genresExcluded, g]
                        : excluded
                            ? ([..._q.genresExcluded]..remove(g))
                            : _q.genresExcluded,
                  ));
                },
              ),
          ],
        ),
      ),
      if (catalog.tags.isNotEmpty) ...[
        _Section(
          title: s.Als_Sec_Tags,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.sell_outlined),
              label: Text(s.Als_Tag_Count(_q.allTags.length + _q.tagsExcluded.length)),
              onPressed: () async {
                final picked = await pickAnilistTags(
                  context,
                  catalog: catalog,
                  adultAllowed: adult,
                  included: _q.allTags,
                  excluded: _q.tagsExcluded,
                );
                if (picked != null) {
                  _set(_q.copyWith(tag: null, tags: picked.included, tagsExcluded: picked.excluded));
                }
              },
            ),
          ),
        ),
        _Section(
          title: '${s.Als_Sec_Tag_Rank}: ${_q.minimumTagRank ?? 0}%',
          child: Slider(
            value: (_q.minimumTagRank ?? 0).toDouble(),
            max: 100,
            divisions: 20,
            label: '${_q.minimumTagRank ?? 0}%',
            onChanged: (v) => _set(_q.copyWith(minimumTagRank: v.round() == 0 ? null : v.round())),
          ),
        ),
        _Section(
          title: s.Als_Sec_Tag_Categories,
          child: _Chips<String>(
            values: catalog.categoriesFor(adult: adult),
            label: (c) => c,
            selected: _q.tagCategories.contains,
            onTap: (v) => _set(_q.copyWith(tagCategories: _toggle(_q.tagCategories, v))),
          ),
        ),
      ],
      if (sources.isNotEmpty)
        _Section(
          title: _manga ? s.Als_Sec_Reading : s.Als_Sec_Streaming,
          child: _SourcesPicker(
            sources: sources,
            selected: _q.licensedByIds,
            onChanged: (ids) => _set(_q.copyWith(licensedByIds: ids)),
          ),
        ),
      _Section(
        title: s.Als_Sec_Country,
        child: _Chips<String>(
          values: AnilistFilterValues.countries,
          label: AnilistLabels.country,
          selected: _q.allCountries.contains,
          onTap: (v) => _set(_q.copyWith(country: null, countries: _toggle(_q.allCountries, v))),
        ),
      ),
      _Section(
        title: s.Als_Sec_Source,
        child: _Chips<String>(
          values: AnilistFilterValues.sources,
          label: AnilistLabels.source,
          selected: _q.sources.contains,
          onTap: (v) => _set(_q.copyWith(sources: _toggle(_q.sources, v))),
        ),
      ),
      if (!_manga) ...[
        _RangeSection(
          title: s.Als_Sec_Episodes,
          min: 0,
          max: AnilistFilterValues.maxEpisodes,
          value: _q.episodes,
          onChanged: (r) => _set(_q.copyWith(episodes: r)),
        ),
        _RangeSection(
          title: s.Als_Sec_Duration,
          min: 0,
          max: AnilistFilterValues.maxDuration,
          value: _q.duration,
          onChanged: (r) => _set(_q.copyWith(duration: r)),
        ),
      ] else ...[
        _RangeSection(
          title: s.Als_Sec_Chapters,
          min: 0,
          max: AnilistFilterValues.maxChapters,
          value: _q.chapters,
          onChanged: (r) => _set(_q.copyWith(chapters: r)),
        ),
        _RangeSection(
          title: s.Als_Sec_Volumes,
          min: 0,
          max: AnilistFilterValues.maxVolumes,
          value: _q.volumes,
          onChanged: (r) => _set(_q.copyWith(volumes: r)),
        ),
      ],
      _RangeSection(
        title: s.Als_Sec_Score,
        min: 0,
        max: 100,
        divisions: 20,
        openMax: false,
        suffix: '%',
        value: _q.score,
        onChanged: (r) => _set(_q.copyWith(score: r)),
      ),
      _Section(
        title: s.Als_Sec_Popularity,
        child: _Single<int?>(
          values: const [null, 1000, 10000, 50000, 100000],
          label: (v) => v == null
              ? s.Als_Any
              : s.Als_Popularity_Min(NumberFormat.compact(locale: Intl.getCurrentLocale()).format(v)),
          value: _q.popularityMin,
          onChanged: (v) => _set(_q.copyWith(popularityMin: v)),
        ),
      ),
      if (widget.signedIn)
        _Section(
          title: s.Als_Sec_My_List,
          child: _Single<bool?>(
            values: const [null, true, false],
            label: (v) => v == null ? s.Als_Any : (v ? s.Als_On_List : s.Als_Off_List),
            value: _q.onList,
            onChanged: (v) => _set(_q.copyWith(onList: v)),
          ),
        ),
      _Section(
        title: s.Als_Sec_Licensing,
        child: _Single<bool?>(
          values: const [null, true, false],
          label: (v) => v == null ? s.Als_Any : (v ? s.Als_Licensed : s.Als_Doujin),
          value: _q.isLicensed,
          onChanged: (v) => _set(_q.copyWith(isLicensed: v)),
        ),
      ),
      if (adult)
        _Section(
          title: s.Als_Sec_Adult,
          child: _Single<bool?>(
            values: const [null, false, true],
            label: (v) => v == null ? s.Als_Any : (v ? s.Als_Adult_Only : s.Als_Adult_Hide),
            value: _q.adult,
            onChanged: (v) => _set(_q.copyWith(adult: v)),
          ),
        ),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text(s.Als_Filters, style: theme.textTheme.titleLarge)),
                TextButton(
                  onPressed: _q.hasFilters ? () => _set(_q.cleared()) : null,
                  child: Text(s.Als_Reset),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: sections.length,
              itemBuilder: (context, i) => sections[i],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_q),
                  child: Text(s.Als_Apply),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Several values, each on or off.
class _Chips<T> extends StatelessWidget {
  final List<T> values;
  final String Function(T) label;
  final bool Function(T) selected;
  final ValueChanged<T> onTap;

  const _Chips({required this.values, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          FilterChip(
            label: Text(label(v)),
            selected: selected(v),
            onSelected: (_) => onTap(v),
          ),
      ],
    );
  }
}

/// One value among [values].
class _Single<T> extends StatelessWidget {
  final List<T> values;
  final String Function(T) label;
  final T value;
  final ValueChanged<T> onChanged;

  const _Single({required this.values, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == value,
            onSelected: (_) => onChanged(v),
          ),
      ],
    );
  }
}

enum _Tri { none, include, exclude }

/// A chip that cycles none → included → excluded.
class _TriChip extends StatelessWidget {
  final String label;
  final _Tri state;
  final VoidCallback onTap;
  const _TriChip({required this.label, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (state) {
      _Tri.include => (cs.secondaryContainer, cs.onSecondaryContainer, Icons.check_rounded),
      _Tri.exclude => (cs.errorContainer, cs.onErrorContainer, Icons.remove_rounded),
      _Tri.none => (null, cs.onSurfaceVariant, null),
    };
    return FilterChip(
      label: Text(label, style: TextStyle(color: state == _Tri.none ? null : fg)),
      selected: state != _Tri.none,
      showCheckmark: false,
      avatar: icon == null ? null : Icon(icon, size: 18, color: fg),
      selectedColor: bg,
      onSelected: (_) => onTap(),
    );
  }
}

/// A range slider over [min]..[max]; the whole range is "any". With [openMax] the top of the
/// slider means "and more" (no upper bound).
class _RangeSection extends StatelessWidget {
  final String title;
  final int min;
  final int max;
  final int? divisions;
  final bool openMax;
  final bool group;
  final String suffix;
  final AnilistRange value;
  final ValueChanged<AnilistRange> onChanged;

  const _RangeSection({
    required this.title,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.divisions,
    this.openMax = true,
    this.group = true,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final lo = (value.min ?? min).clamp(min, max).toDouble();
    final hi = (value.max ?? max).clamp(min, max).toDouble();
    String fmt(double v) {
      final n = v.round();
      final text = group ? NumberFormat.decimalPattern(Intl.getCurrentLocale()).format(n) : '$n';
      return n == max && openMax ? '$text+' : '$text$suffix';
    }

    return _Section(
      title: value.isOpen ? '$title: ${S.of(context).Als_Any}' : '$title: ${fmt(lo)} - ${fmt(hi)}',
      child: RangeSlider(
        values: RangeValues(lo, hi > lo ? hi : lo),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: divisions ?? (max - min),
        labels: RangeLabels(fmt(lo), fmt(hi)),
        onChanged: (v) {
          final a = v.start.round();
          final b = v.end.round();
          onChanged(AnilistRange(min: a <= min ? null : a, max: b >= max ? null : b));
        },
      ),
    );
  }
}

/// The selected services as chips, plus a button opening the searchable list of all of them.
class _SourcesPicker extends StatelessWidget {
  final List<AnilistLinkSource> sources;
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  const _SourcesPicker({required this.sources, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final byId = {for (final s in sources) s.id: s};
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in selected)
          InputChip(
            label: Text(byId[id]?.label ?? '#$id'),
            onDeleted: () => onChanged([...selected]..remove(id)),
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 18),
          label: Text(S.of(context).Als_Choose),
          onPressed: () async {
            final picked = await showModalBottomSheet<List<int>>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              builder: (_) => _SourcesSheet(sources: sources, selected: selected),
            );
            if (picked != null) onChanged(picked);
          },
        ),
      ],
    );
  }
}

class _SourcesSheet extends StatefulWidget {
  final List<AnilistLinkSource> sources;
  final List<int> selected;
  const _SourcesSheet({required this.sources, required this.selected});

  @override
  State<_SourcesSheet> createState() => _SourcesSheetState();
}

class _SourcesSheetState extends State<_SourcesSheet> {
  late final Set<int> _picked = {...widget.selected};
  final TextEditingController _search = TextEditingController();
  String _text = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final shown = [
      for (final src in widget.sources)
        if (_text.isEmpty || src.label.toLowerCase().contains(_text)) src,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 1,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (v) => setState(() => _text = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: shown.length,
              itemExtent: 52,
              itemBuilder: (context, i) {
                final src = shown[i];
                return CheckboxListTile(
                  value: _picked.contains(src.id),
                  title: Text(src.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onChanged: (on) => setState(() => on == true ? _picked.add(src.id) : _picked.remove(src.id)),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop([
                    for (final src in widget.sources)
                      if (_picked.contains(src.id)) src.id,
                  ]),
                  child: Text(s.Als_Apply),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
