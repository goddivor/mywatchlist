import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart';

/// Full-screen, endless version of an Explore strip (recommendations, reviews, interest stacks,
/// characters, voice actors): one page at a time, the next one asked when the end is reached.
///
/// Pass [grid] for a grid of posters, otherwise each item is a row of [itemExtent] pixels.
class ExploreListScreen<T> extends StatefulWidget {
  final String title;

  /// Items of page [page] (starting at 1); an empty list ends the list.
  final Future<List<T>> Function(int page) loadPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double itemExtent;
  final SliverGridDelegate? grid;

  /// False when [loadPage] gives everything on page 1.
  final bool paged;

  const ExploreListScreen({
    super.key,
    required this.title,
    required this.loadPage,
    required this.itemBuilder,
    this.itemExtent = 300,
    this.grid,
    this.paged = true,
  });

  @override
  State<ExploreListScreen<T>> createState() => _ExploreListScreenState<T>();
}

class _ExploreListScreenState<T> extends State<ExploreListScreen<T>> {
  final List<T> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _done = false;
  bool _failed = false;

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final next = await widget.loadPage(_page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(next);
        _done = next.isEmpty || !widget.paged;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final grid = widget.grid;
    final Widget list = grid != null
        ? SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
            sliver: SliverGrid.builder(
              gridDelegate: grid,
              itemCount: _items.length,
              itemBuilder: (context, i) => widget.itemBuilder(context, _items[i]),
            ),
          )
        : SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
            sliver: SliverFixedExtentList.builder(
              itemExtent: widget.itemExtent,
              itemCount: _items.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: widget.itemBuilder(context, _items[i]),
              ),
            ),
          );
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          list,
          SliverToBoxAdapter(child: _footer()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_failed) {
      return SectionMessage(
        icon: Icons.cloud_off_rounded,
        text: S.current.Explore_Section_Failed,
        onRetry: _loadMore,
      );
    }
    if (_done) {
      return _items.isEmpty
          ? SectionMessage(icon: Icons.inbox_outlined, text: S.current.Explore_Section_Empty)
          : const SizedBox.shrink();
    }
    // Built only when the end of the list nears the viewport: ask the next page then.
    if (!_loading) WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
    );
  }
}
