import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_media_card.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart' show HomeMessage;

/// A paged grid of AniList titles: the "view all" page of a home or explore row, and, with
/// [searchable], AniList's own search (text field and an Anime / Manga switch).
class AnilistBrowseScreen extends StatefulWidget {
  final String title;
  final AnilistMediaQuery query;
  final bool searchable;
  final AnilistDiscoverService? service;

  const AnilistBrowseScreen({
    super.key,
    required this.title,
    required this.query,
    this.searchable = false,
    this.service,
  });

  @override
  State<AnilistBrowseScreen> createState() => _AnilistBrowseScreenState();
}

class _AnilistBrowseScreenState extends State<AnilistBrowseScreen> {
  static const int _perPage = 30;

  final TextEditingController _text = TextEditingController();
  Timer? _debounce;
  late AnilistMediaQuery _query = widget.query;
  final List<AnilistMedia> _items = [];
  int _page = 0;
  int _generation = 0;
  bool _loading = false;
  bool _hasNext = true;
  Object? _error;

  AnilistDiscoverService get _service => widget.service ?? AnilistDiscoverService.instance;

  /// A search screen waits for a word; a browse screen loads at once.
  bool get _idle => widget.searchable && (_query.search ?? '').trim().isEmpty;

  @override
  void initState() {
    super.initState();
    // No setState yet: the first build already shows the loading state.
    if (!_idle) _loadMore(initial: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _restart() {
    _generation++;
    _items.clear();
    _page = 0;
    _hasNext = true;
    _error = null;
    _loading = false;
    if (_idle) {
      setState(() {});
    } else {
      _loadMore();
    }
  }

  Future<void> _loadMore({bool initial = false}) async {
    if (_loading || !_hasNext) return;
    final generation = _generation;
    if (initial) {
      _loading = true;
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await _service.media(_query, page: _page + 1, perPage: _perPage);
      if (!mounted || generation != _generation) return;
      final known = {for (final m in _items) m.id};
      setState(() {
        _page++;
        _items.addAll(page.items.where((m) => !known.contains(m.id)));
        _hasNext = page.hasNext && page.items.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onText(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _query = _query.copyWith(search: value);
      _restart();
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 600) _loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: widget.searchable
            ? TextField(
                controller: _text,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: s.Al_Search_Hint,
                  border: InputBorder.none,
                ),
                onChanged: _onText,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  _query = _query.copyWith(search: v);
                  _restart();
                },
              )
            : Text(widget.title),
        bottom: widget.searchable
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: 'anime', label: Text(s.Prof_Anime)),
                        ButtonSegment(value: 'manga', label: Text(s.Prof_Manga)),
                      ],
                      selected: {_query.category},
                      onSelectionChanged: (v) {
                        _query = _query.copyWith(category: v.first);
                        _restart();
                      },
                    ),
                  ),
                ),
              )
            : null,
      ),
      backgroundColor: cs.surface,
      body: _body(s),
    );
  }

  Widget _body(S s) {
    if (_idle) {
      return HomeMessage(icon: Icons.search_rounded, text: s.Al_Search_Prompt);
    }
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return Center(
          child: HomeMessage(
            icon: Icons.cloud_off_outlined,
            text: s.Al_Load_Failed,
            actionLabel: s.Al_Retry,
            onAction: _loadMore,
          ),
        );
      }
      return HomeMessage(icon: Icons.inbox_outlined, text: s.Al_No_Results);
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                childAspectRatio: 0.54,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: _items.length,
              itemBuilder: (context, i) => RepaintBoundary(
                child: AnilistMediaCard(
                  media: _items[i],
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : _error != null
                        ? TextButton(onPressed: _loadMore, child: Text(s.Al_Retry))
                        : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
