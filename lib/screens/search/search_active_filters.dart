part of 'general_search_screen.dart';

/// A horizontal row of removable chips, one per active filter (each genre has its own).
class _ActiveFilters extends StatelessWidget {
  final SearchFilters filters;
  final String category;
  final void Function(List<String> keys) onRemove;
  final void Function(int genreId) onRemoveGenre;

  const _ActiveFilters({
    required this.filters,
    required this.category,
    required this.onRemove,
    required this.onRemoveGenre,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final manga = category == SearchCategory.manga;
    final chips = <Widget>[];

    for (final id in filters.genresIn) {
      chips.add(_chip(SearchCatalog.genreLabel(id, manga: manga), () => onRemoveGenre(id),
          background: scheme.primaryContainer, foreground: scheme.onPrimaryContainer));
    }
    for (final id in filters.genresOut) {
      chips.add(_chip('− ${SearchCatalog.genreLabel(id, manga: manga)}', () => onRemoveGenre(id),
          background: scheme.errorContainer, foreground: scheme.onErrorContainer));
    }
    for (final entry in _describe()) {
      chips.add(_chip(entry.$2, () => onRemove(entry.$1)));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, index) => Center(child: chips[index]),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onDeleted, {Color? background, Color? foreground}) {
    return InputChip(
      label: Text(label, style: TextStyle(color: foreground, fontSize: 12)),
      backgroundColor: background,
      deleteIconColor: foreground,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onDeleted: onDeleted,
    );
  }

  /// (keys to remove, text) for every non-genre filter.
  List<(List<String>, String)> _describe() {
    final manga = category == SearchCategory.manga;
    String? option<T>(List<SelectOption<T>> options, T? value) => labelOf(options, value);
    final f = filters;
    final out = <(List<String>, String)>[];
    void add(String key, String? text, {List<String>? keys}) {
      if (text != null && text.isNotEmpty) out.add((keys ?? [key], text));
    }

    add(FilterKey.type, option(manga ? SearchOptions.mangaTypes() : SearchOptions.animeTypes(), f.text(FilterKey.type)));
    add(FilterKey.status,
        option(manga ? SearchOptions.mangaStatuses() : SearchOptions.animeStatuses(), f.text(FilterKey.status)));
    add(FilterKey.rating, option(SearchOptions.ratings(), f.text(FilterKey.rating)));
    final order = option(manga ? SearchOptions.mangaOrders() : SearchOptions.animeOrders(), f.text(FilterKey.orderBy));
    final sort = option(SearchOptions.sorts(), f.text(FilterKey.sort));
    add(FilterKey.orderBy, order == null ? null : (sort == null ? order : '$order · $sort'),
        keys: [FilterKey.orderBy, FilterKey.sort]);
    if (f.integer(FilterKey.score) != null) add(FilterKey.score, '${f.integer(FilterKey.score)}+');
    add(FilterKey.letter, f.text(FilterKey.letter));
    add(FilterKey.startDate, f.text(FilterKey.startDate) == null ? null : '≥ ${f.text(FilterKey.startDate)}');
    add(FilterKey.endDate, f.text(FilterKey.endDate) == null ? null : '≤ ${f.text(FilterKey.endDate)}');
    final producer = f.integer(FilterKey.producer);
    if (producer != null) {
      add(FilterKey.producer, SearchCatalog.producerName(producer) ?? f.text(FilterKey.producerLabel) ?? '#$producer');
    }
    final magazine = f.integer(FilterKey.magazine);
    if (magazine != null) {
      add(FilterKey.magazine, SearchCatalog.magazineName(magazine) ?? f.text(FilterKey.magazineLabel) ?? '#$magazine');
    }
    final board = f.integer(FilterKey.boardId);
    if (board != null) add(FilterKey.boardId, option(SearchOptions.boards(), board));
    final subBoard = f.integer(FilterKey.subboardId);
    if (subBoard != null) add(FilterKey.subboardId, option(SearchOptions.subBoards(), subBoard));
    add(FilterKey.topicUser, f.text(FilterKey.topicUser));
    add(FilterKey.user, f.text(FilterKey.user));
    add(FilterKey.location, f.text(FilterKey.location));
    if (f.integer(FilterKey.ageLow) != null) add(FilterKey.ageLow, '≥ ${f.integer(FilterKey.ageLow)}');
    if (f.integer(FilterKey.ageHigh) != null) add(FilterKey.ageHigh, '≤ ${f.integer(FilterKey.ageHigh)}');
    if (f.integer(FilterKey.gender) != null) add(FilterKey.gender, option(SearchOptions.genders(), f.integer(FilterKey.gender)));
    final tag = f.text(FilterKey.tag);
    if (tag != null) add(FilterKey.tag, SearchOptions.tagLabel(tag) ?? tag);
    add(FilterKey.stackType, option(SearchOptions.stackTypes(), f.text(FilterKey.stackType)));
    return out;
  }
}
