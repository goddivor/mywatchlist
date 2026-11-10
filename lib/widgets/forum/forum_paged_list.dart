import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';

/// A list that loads page after page as the user scrolls, with a skeleton on the first load, an
/// error state with Retry (also when a later page fails), an empty state and pull to refresh.
///
/// [fetch] receives the number of items already loaded (plus [startOffset]) and returns the next
/// page, or throws when the request failed. A page shorter than [pageSize] is the last one.
/// Give the widget a new `key` to restart it (a new search, for example).
class ForumPagedList<T> extends StatefulWidget {
  const ForumPagedList({
    super.key,
    required this.fetch,
    required this.pageSize,
    required this.itemBuilder,
    required this.emptyTitle,
    this.emptyBody,
    this.emptyIcon = Icons.inbox_outlined,
    this.startOffset = 0,
    this.skeleton = const ForumSkeleton(),
    this.padding = EdgeInsets.zero,
    this.onRestart,
  });

  final Future<List<T>> Function(int offset) fetch;
  final int pageSize;
  final int startOffset;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyTitle;
  final String? emptyBody;
  final IconData emptyIcon;
  final Widget skeleton;
  final EdgeInsetsGeometry padding;

  /// Called when a pull to refresh restarts the list from the first page (for callers that
  /// count pages themselves).
  final VoidCallback? onRestart;

  @override
  State<ForumPagedList<T>> createState() => _ForumPagedListState<T>();
}

class _ForumPagedListState<T> extends State<ForumPagedList<T>> {
  final _scroll = ScrollController();
  final List<T> _items = [];
  bool _loading = false;
  bool _failed = false;
  bool _hasMore = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 300) _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.fetch(widget.startOffset + _items.length);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length >= widget.pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());
  }

  /// A first page shorter than the screen never scrolls, so ask for the next one ourselves.
  void _fillViewport() {
    if (!mounted || _loading || _failed || !_hasMore || !_scroll.hasClients) return;
    if (_scroll.position.maxScrollExtent <= 0) _load();
  }

  Future<void> _refresh() async {
    _generation++;
    widget.onRestart?.call();
    setState(() {
      _items.clear();
      _hasMore = true;
      _loading = false;
      _failed = false;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_items.isEmpty && _loading) {
      body = ListView(physics: const AlwaysScrollableScrollPhysics(), children: [widget.skeleton]);
    } else if (_items.isEmpty && _failed) {
      body = ForumMessage.error(onRetry: _refresh);
    } else if (_items.isEmpty) {
      body = ForumMessage(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        body: widget.emptyBody,
        onRetry: _refresh,
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index < _items.length) return widget.itemBuilder(context, _items[index]);
          return _Footer(
            loading: _loading,
            failed: _failed,
            hasMore: _hasMore,
            onRetry: _load,
          );
        },
      );
    }
    return RefreshIndicator(onRefresh: _refresh, child: body);
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.loading,
    required this.failed,
    required this.hasMore,
    required this.onRetry,
  });

  final bool loading;
  final bool failed;
  final bool hasMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    if (failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(S.current.Fc_Load_More_Failed, style: textStyle)),
            const SizedBox(width: 8),
            TextButton(onPressed: onRetry, child: Text(S.current.Fc_Retry)),
          ],
        ),
      );
    }
    if (loading || hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(S.current.Fc_End_Of_List, style: textStyle)),
    );
  }
}
