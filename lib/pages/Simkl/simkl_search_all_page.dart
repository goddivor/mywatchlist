import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart' hide SimklFormat;
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/pages/Simkl/simkl_explore_page.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_catalogue.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart';

/// One search over every Simkl catalogue: TV shows, anime and movies at once, one row of
/// posters per catalogue. "See all" opens that catalogue's own search page.
class SimklSearchAllPage extends StatefulWidget {
  const SimklSearchAllPage({super.key, this.service, this.initialQuery = ''});

  /// Test hook; defaults to the shared Simkl discover service.
  final SimklDiscoverService? service;
  final String initialQuery;

  @override
  State<SimklSearchAllPage> createState() => _SimklSearchAllPageState();
}

class _SimklSearchAllPageState extends State<SimklSearchAllPage> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;

  /// The answers of the last query per catalogue; a missing one is still loading.
  final Map<SimklKind, List<SimklMedia>> _results = {};
  final Set<SimklKind> _failed = {};
  int _run = 0;

  SimklDiscoverService get _service => widget.service ?? SimklDiscoverService.instance;
  String get _text => _controller.text.trim();

  @override
  void initState() {
    super.initState();
    if (_text.isNotEmpty) _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  /// Asks the three catalogues side by side; a late answer of an older query is dropped.
  void _search() {
    final run = ++_run;
    final text = _text;
    setState(() {
      _results.clear();
      _failed.clear();
    });
    if (text.isEmpty) return;
    for (final kind in SimklKind.values) {
      _service.search(text, kind: kind).then((items) {
        if (!mounted || run != _run) return;
        setState(() => _results[kind] = items);
      }, onError: (Object _) {
        if (!mounted || run != _run) return;
        setState(() => _failed.add(kind));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: widget.initialQuery.isEmpty,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(hintText: s.Skn_Search_All, border: InputBorder.none),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                _search();
              },
            ),
        ],
      ),
      body: _text.isEmpty
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [for (final kind in SimklKind.values) _section(context, kind)],
            ),
    );
  }

  Widget _section(BuildContext context, SimklKind kind) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final items = _results[kind];
    final Widget body;
    if (_failed.contains(kind)) {
      body = _note(context, s.Ahx_Row_Failed);
    } else if (items == null) {
      body = const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    } else if (items.isEmpty) {
      body = _note(context, s.Srch_No_Results);
    } else {
      body = SizedBox(
        height: 250,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final m = items[i];
            return SimklPosterCard(
              media: m,
              width: 120,
              onTap: () => openSimklTitle(context,
                  simklId: m.simklId, kind: m.kind, title: m.title, posterUrl: m.posterUrl),
            );
          },
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 4, 4),
          child: Row(
            children: [
              Icon(simklKindIcon(kind), size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(simklKindLabel(kind), style: theme.textTheme.titleMedium)),
              if (items != null && items.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => SimklExplorePage(kind: kind, initialQuery: _text))),
                  child: Text(s.View_All),
                ),
            ],
          ),
        ),
        body,
      ],
    );
  }

  Widget _note(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
