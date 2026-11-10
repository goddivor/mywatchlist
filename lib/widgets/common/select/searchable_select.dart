import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/select/select_option.dart';
import 'package:mywatchlist/widgets/common/select/select_sheet.dart';

/// Opens a tall bottom sheet with a search field above [options] and completes
/// with the picked value, or null when dismissed. Made for long lists (genres,
/// studios, years…): the list is built lazily and filtered as the user types,
/// ignoring case and accents.
///
/// ```dart
/// final studio = await showSearchableSelect(
///   context,
///   title: S.current.Studios,
///   options: studios.map((s) => SelectOption(s.id, s.name)).toList(),
/// );
/// ```
Future<T?> showSearchableSelect<T>(
  BuildContext context, {
  required List<SelectOption<T>> options,
  T? selected,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => SearchableSelect<T>(
        options: options,
        selected: selected,
        title: title,
        scrollController: scrollController,
        onSelected: (value) => Navigator.of(sheetContext).pop(value),
      ),
    ),
  );
}

/// Body of [showSearchableSelect]: a search field and the filtered options, the
/// current value (checked) first. Give it a bounded height (sheet, dialog, Expanded).
class SearchableSelect<T> extends StatefulWidget {
  final List<SelectOption<T>> options;
  final T? selected;
  final String? title;
  final ValueChanged<T> onSelected;

  /// Controller of the surrounding [DraggableScrollableSheet], if any.
  final ScrollController? scrollController;

  const SearchableSelect({
    super.key,
    required this.options,
    required this.onSelected,
    this.selected,
    this.title,
    this.scrollController,
  });

  @override
  State<SearchableSelect<T>> createState() => _SearchableSelectState<T>();
}

class _SearchableSelectState<T> extends State<SearchableSelect<T>> {
  final _query = TextEditingController();
  late List<String> _keys;
  late List<SelectOption<T>> _visible;

  @override
  void initState() {
    super.initState();
    _index();
  }

  @override
  void didUpdateWidget(covariant SearchableSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.options, widget.options)) _index();
  }

  void _index() {
    _keys = [for (final option in widget.options) foldForSearch(option.label)];
    _visible = _filter(_query.text);
  }

  /// The options for [query]. With no query the current value comes first, so a long list
  /// opens on what is selected instead of hiding it far down.
  List<SelectOption<T>> _filter(String query) {
    final needle = foldForSearch(query.trim());
    if (needle.isEmpty) {
      final current = widget.selected;
      final at = current == null ? -1 : widget.options.indexWhere((o) => o.value == current);
      if (at <= 0) return widget.options;
      return [widget.options[at], ...widget.options.take(at), ...widget.options.skip(at + 1)];
    }
    return [
      for (var i = 0; i < widget.options.length; i++)
        if (_keys[i].contains(needle)) widget.options[i],
    ];
  }

  void _onQuery(String query) => setState(() => _visible = _filter(query));

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(widget.title!, style: theme.textTheme.titleLarge),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _query,
            onChanged: _onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: S.current.Kit_Search_Options,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: S.current.Clear,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _query.clear();
                        _onQuery('');
                      },
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      S.current.No_results_found,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _visible.length,
                  itemBuilder: (context, index) {
                    final option = _visible[index];
                    return SelectOptionTile<T>(
                      option: option,
                      checked: option.value == widget.selected,
                      onTap: () => widget.onSelected(option.value),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

const _accents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ō': 'o',
  'ø': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ý': 'y',
  'ÿ': 'y',
};

/// Lower-cases [text] and strips the common Latin accents, so "Pokemon" finds
/// "Pokémon" and "shonen" finds "Shōnen".
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}
