part of 'general_search_screen.dart';

/// The body under the bar: history, loading, results, nothing found, failure.
extension _SearchBody on _GeneralSearchScreenState {
  Widget _buildBody(BuildContext context) {
    switch (_stage) {
      case SearchStage.notStarted:
        return SearchHomeView(
          history: _history,
          suggestions: _suggestions,
          onQuery: _searchFrom,
        );
      case SearchStage.started:
        return const Align(
          alignment: Alignment.topCenter,
          child: Padding(padding: EdgeInsets.only(top: 60), child: CircularProgressIndicator()),
        );
      case SearchStage.loaded:
        final page = _page!;
        if (page.category == SearchCategory.all && _tabController != null) return _buildAllView(page);
        return _buildSingleView(page);
      case SearchStage.empty:
        final found = _page?.foundUser;
        return Column(
          children: [
            if (found != null) _UserFoundCard(name: found),
            Expanded(
              child: _buildMessage(
                icon: Icons.search_off_rounded,
                title: S.current.Srch_No_Results,
                hint: S.current.Srch_No_Results_Hint,
              ),
            ),
          ],
        );
      case SearchStage.error:
        return _buildMessage(
          icon: Icons.wifi_off_rounded,
          title: S.current.Srch_Error,
          hint: null,
          action: FilledButton.tonalIcon(
            onPressed: () => _runSearch(_request?.query ?? _searchController.text),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(S.current.Srch_Retry),
          ),
        );
    }
  }

  Widget _buildMessage({required IconData icon, required String title, String? hint, Widget? action}) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: muted.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: muted)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  // --- "All" view: one tab per category with results -----------------------------------------

  Widget _buildAllView(SearchPage page) {
    final all = page.all!;
    return TabBarView(
      controller: _tabController,
      children: [
        for (final (index, tab) in _allTabs.indexed) _buildAllTab(page, all.categories[tab] ?? const [], tab, index == 0),
      ],
    );
  }

  Widget _buildAllTab(SearchPage page, List<Anime> items, String tab, bool first) {
    final width = MediaQuery.sizeOf(context).width;
    final media = SearchCategory.isMedia(tab);
    final grid = media && width >= 600;
    final query = _request?.query ?? '';
    return CustomScrollView(
      key: PageStorageKey<String>('all-$tab'),
      slivers: [
        if (first && page.foundUser != null) SliverToBoxAdapter(child: _UserFoundCard(name: page.foundUser!)),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (grid)
          _gridSliver(items, tab, columns: width >= 840 ? 5 : 4, height: 200, subType: DisplaySubType.compact)
        else
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => media
                ? MediaTile(item: items[index], category: tab)
                : tab == SearchCategory.character || tab == SearchCategory.person
                    ? PersonTile(item: items[index], isCharacter: tab == SearchCategory.character)
                    : AllItemTile(item: items[index], category: tab),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: OutlinedButton(
              onPressed: () => gotoPage(
                context: context,
                newPage: GeneralSearchScreen(
                  category: tab,
                  searchQuery: query,
                  showBackButton: true,
                ),
              ),
              child: Text(S.current.Srch_Search_In(query, SearchOptions.categoryLabel(tab))),
            ),
          ),
        ),
      ],
    );
  }

  // --- One category ----------------------------------------------------------------------------

  Widget _buildSingleView(SearchPage page) {
    final category = page.category;
    final display = _display;
    final media = SearchCategory.isMedia(category);
    final Widget content;
    switch (category) {
      case SearchCategory.forum:
        content = SliverList.separated(
          itemCount: page.forum.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (_, i) => ForumTopicTile(topic: page.forum[i]),
        );
      case SearchCategory.user:
        content = SliverList.builder(
          itemCount: page.users.length,
          itemBuilder: (_, i) => UserTile(user: page.users[i]),
        );
      case SearchCategory.club:
        content = SliverList.builder(
          itemCount: page.clubs.length,
          itemBuilder: (_, i) => ClubTile(club: page.clubs[i]),
        );
      case SearchCategory.interestStack:
        content = SliverList.builder(
          itemCount: page.stacks.length,
          itemBuilder: (_, i) => StackTile(stack: page.stacks[i]),
        );
      case SearchCategory.news:
      case SearchCategory.featured:
        content = SliverList.builder(
          itemCount: page.articles.length,
          itemBuilder: (_, i) => ArticleTile(item: page.articles[i], isNews: category == SearchCategory.news),
        );
      case SearchCategory.character:
      case SearchCategory.person:
        content = SliverList.builder(
          itemCount: page.media.length,
          itemBuilder: (_, i) => PersonTile(item: page.media[i], isCharacter: category == SearchCategory.character),
        );
      default:
        if (media && display.isGrid) {
          content = _gridSliver(page.media, category,
              columns: display.gridColumns, height: display.gridHeight, subType: display.subType);
        } else {
          final size = switch (display.subType) {
            DisplaySubType.compact => MediaTileSize.compact,
            DisplaySubType.spacious => MediaTileSize.spacious,
            _ => MediaTileSize.comfortable,
          };
          content = SliverList.builder(
            itemCount: page.media.length,
            itemBuilder: (_, i) => MediaTile(item: page.media[i], category: category, size: size),
          );
        }
    }
    return CustomScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (page.foundUser != null) SliverToBoxAdapter(child: _UserFoundCard(name: page.foundUser!)),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        content,
        SliverToBoxAdapter(child: _buildLoadMore()),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _gridSliver(
    List<Anime> items,
    String category, {
    required int columns,
    required double height,
    required DisplaySubType subType,
  }) {
    final width = height * (2 / 3);
    final coverOnly = subType == DisplaySubType.cover_only_grid;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: width / (height + 36),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return AnimeGridCard(
            node: item,
            category: category,
            width: width,
            height: height,
            gridHeight: height + 36,
            showMemberCount: !coverOnly,
            showText: !coverOnly,
            displaySubType: subType,
            onTap: () => openMedia(context, item, category),
          );
        },
      ),
    );
  }

  Widget _buildLoadMore() {
    if (!_canLoadMore && _loadMoreStage != SearchStage.error) return const SizedBox.shrink();
    final theme = Theme.of(context);
    if (_loadMoreStage == SearchStage.started) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _loadMoreStage == SearchStage.error
          ? Center(
              child: TextButton.icon(
                onPressed: () {
                  _page?.hasMore = true;
                  _set(() => _loadMoreStage = SearchStage.notStarted);
                  _loadMore();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(S.current.Srch_Retry),
              ),
            )
          : OutlinedButton(
              onPressed: _loadMore,
              child: Text(S.current.Srch_Load_More, style: theme.textTheme.bodyMedium),
            ),
    );
  }
}

/// "User found as …": MyAnimeList knows a profile with the exact name that was typed.
class _UserFoundCard extends StatelessWidget {
  final String name;

  const _UserFoundCard({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: scheme.secondaryContainer,
      child: ListTile(
        leading: Icon(Icons.person_search_rounded, color: scheme.onSecondaryContainer),
        title: Text(S.current.Srch_User_Found(name), style: TextStyle(color: scheme.onSecondaryContainer)),
        trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSecondaryContainer),
        onTap: () => openUserProfile(context, name),
      ),
    );
  }
}
