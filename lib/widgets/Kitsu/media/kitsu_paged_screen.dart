import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';

/// The whole list of one section of a Kitsu title (episodes, chapters, characters, staff,
/// reactions), fetched page by page as the user scrolls. The first page is the one the title
/// page already holds, so the screen opens filled.
class KitsuPagedScreen<T> extends StatefulWidget {
  final String title;
  final KitsuConnection<T> first;
  final Future<KitsuConnection<T>> Function(KitsuPageArgs page) load;
  final Widget Function(BuildContext context, T item) itemBuilder;

  const KitsuPagedScreen({
    super.key,
    required this.title,
    required this.first,
    required this.load,
    required this.itemBuilder,
  });

  @override
  State<KitsuPagedScreen<T>> createState() => _KitsuPagedScreenState<T>();
}

class _KitsuPagedScreenState<T> extends State<KitsuPagedScreen<T>> {
  final ScrollController _scroll = ScrollController();
  late final List<T> _items = [...widget.first.nodes];
  late KitsuPageArgs? _next = widget.first.nextPage();
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // A first page shorter than the screen would never reach the scroll threshold.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _next == null || _loading || _failed) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 600) _more();
  }

  Future<void> _more() async {
    final page = _next;
    if (page == null || _loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await widget.load(page);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.nodes);
        _next = result.nextPage();
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final footer = _failed || _loading || _next != null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _items.length + (footer ? 1 : 0),
        itemBuilder: (context, i) {
          if (i < _items.length) return widget.itemBuilder(context, _items[i]);
          if (_failed) {
            return SectionMessage(
              icon: Icons.cloud_off_outlined,
              message: S.current.Kmp_List_Load_Error,
              onRetry: _more,
              height: 120,
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        },
      ),
    );
  }
}
