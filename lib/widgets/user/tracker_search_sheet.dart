import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/sync/sync_labels.dart';

/// Searches [tracker] to link the MyAnimeList entry to one of its media.
class TrackerSearchSheet extends StatefulWidget {
  final AccountType tracker;
  final String initialQuery;
  final String category;
  final ValueChanged<TrackerSearchResult> onSelected;

  const TrackerSearchSheet({
    super.key,
    required this.tracker,
    required this.initialQuery,
    required this.category,
    required this.onSelected,
  });

  @override
  State<TrackerSearchSheet> createState() => _TrackerSearchSheetState();

  /// Show as a modal bottom sheet.
  static Future<TrackerSearchResult?> show(
    BuildContext context, {
    required AccountType tracker,
    required String initialQuery,
    required String category,
  }) {
    return showModalBottomSheet<TrackerSearchResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => TrackerSearchSheet(
        tracker: tracker,
        initialQuery: initialQuery,
        category: category,
        onSelected: (result) => Navigator.of(ctx).pop(result),
      ),
    );
  }
}

class _TrackerSearchSheetState extends State<TrackerSearchSheet> {
  late final TextEditingController _controller;
  List<TrackerSearchResult> _results = const [];
  bool _loading = false;
  bool _searched = false;
  Timer? _debounce;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().isNotEmpty) {
      _search(widget.initialQuery.trim());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) _search(query.trim());
    });
  }

  Future<void> _search(String query) async {
    final request = ++_request;
    setState(() => _loading = true);
    final results = await TrackerSyncService.instance
        .search(widget.tracker, query, widget.category);
    // A newer search superseded this one.
    if (!mounted || request != _request) return;
    setState(() {
      _results = results;
      _loading = false;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = TrackerSyncService.trackerName(widget.tracker);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  TrackerLogo(widget.tracker),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      S.current.Sync_Link_To(name),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (q) {
                  _debounce?.cancel();
                  if (q.trim().isNotEmpty) _search(q.trim());
                },
                decoration: InputDecoration(
                  hintText: S.current.Sync_Search_Hint(name),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (_, value, __) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: S.current.Sync_Clear,
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _results = const [];
                                _searched = false;
                              });
                            },
                          ),
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body(theme)),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _searched ? S.current.Sync_No_Results : S.current.Sync_Search_Prompt,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      itemBuilder: (context, index) => _ResultTile(
        item: _results[index],
        onTap: () => widget.onSelected(_results[index]),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.item, required this.onTap});

  final TrackerSearchResult item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: AppImage(
        url: item.imageUrl,
        width: 44,
        height: 62,
        borderRadius: BorderRadius.circular(6),
        placeholderColor: scheme.surfaceContainerHigh,
      ),
      title: Text(item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          if (item.score != null) ...[
            Icon(Icons.star, size: 14, color: scheme.primary),
            const SizedBox(width: 2),
            Text('${item.score}', style: theme.textTheme.bodySmall),
            const SizedBox(width: 8),
          ],
          if (item.mediaType != null)
            Flexible(
              child: Text(item.mediaType!,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
        ],
      ),
      trailing: Icon(Icons.add_link, color: scheme.primary),
    );
  }
}
