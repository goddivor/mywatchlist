part of 'general_search_screen.dart';

/// The bar on top: back or clear, the field, the filter button, then the sections of an "all"
/// search and the chips of the active filters.
extension _SearchBar on _GeneralSearchScreenState {
  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = _searchController.text.isNotEmpty;
    final loadedAll = _category == SearchCategory.all && _stage == SearchStage.loaded && _allTabs.isNotEmpty;
    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  _buildLeading(hasText),
                  if (_specialQuery) _buildSpecialTag(theme),
                  Expanded(child: _buildField()),
                  _buildFilterButton(theme),
                ],
              ),
            ),
            if (_filters.isNotEmpty)
              _ActiveFilters(
                filters: _filters,
                category: _category,
                onRemove: _removeFilter,
                onRemoveGenre: _setGenreOff,
              ),
            // Hidden under an open panel, as in DailyAL: the panel's category tab replaces them.
            if (loadedAll && !_showPanel)
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final tab in _allTabs) Tab(text: SearchOptions.categoryLabel(tab)),
                ],
              )
            else
              const Divider(height: 1, thickness: 0.5),
          ],
        ),
      ),
    );
  }

  Widget _buildLeading(bool hasText) {
    if (hasText || _filters.isNotEmpty) {
      return IconButton(
        tooltip: S.current.Srch_Clear,
        icon: const Icon(Icons.close_rounded),
        onPressed: _clearAll,
      );
    }
    if (widget.showBackButton) {
      return IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: const BackButtonIcon(),
        onPressed: () => Navigator.maybePop(context),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Icon(Icons.search_rounded),
    );
  }

  Widget _buildSpecialTag(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        S.current.Srch_Special,
        style: theme.textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildField() {
    return TextField(
      focusNode: _focusNode,
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (value) {
        if (value.trim().isNotEmpty || _filters.isNotEmpty) _runSearch(value);
      },
      style: TextStyle(fontWeight: _specialQuery ? FontWeight.bold : FontWeight.normal),
      decoration: InputDecoration(
        hintText: _category == SearchCategory.all
            ? S.current.Srch_Hint_All
            : S.current.Srch_Hint_In(SearchOptions.categoryLabel(_category)),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
      ),
    );
  }

  Widget _buildFilterButton(ThemeData theme) {
    final count = _filters.activeCount;
    return IconButton(
      tooltip: S.current.Srch_Tab_Filter,
      isSelected: _showPanel,
      onPressed: () {
        _focusNode.unfocus();
        _set(() => _showPanel = !_showPanel);
      },
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: Icon(_filters.isNotEmpty ? Icons.filter_alt_rounded : Icons.filter_alt_outlined),
      ),
    );
  }
}
