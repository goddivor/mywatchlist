import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';

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
      backgroundColor: Colors.transparent,
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
  late TextEditingController _searchController;
  List<TrackerSearchResult> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    // Auto-search on open
    if (widget.initialQuery.isNotEmpty) {
      _performSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _loading = true);
    final results = await TrackerSyncService.instance.search(
      widget.tracker,
      query,
      widget.category,
    );
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackerName = TrackerSyncService.trackerName(widget.tracker);
    final trackerLogo = TrackerSyncService.trackerLogo(widget.tracker);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: logo + title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        trackerLogo,
                        width: 28,
                        height: 28,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.link, size: 28),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Link to $trackerName',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Search field
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  onChanged: _onSearchChanged,
                  onSubmitted: (q) {
                    if (q.trim().isNotEmpty) _performSearch(q.trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search on $trackerName...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _results = []);
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Results
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'Type to search'
                                  : 'No results found',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _results.length,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return _buildResultTile(theme, item);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultTile(ThemeData theme, TrackerSearchResult item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onSelected(item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Cover image
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: item.imageUrl != null
                    ? Image.network(
                        item.imageUrl!,
                        width: 45,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 45,
                          height: 64,
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: const Icon(Icons.image, size: 20),
                        ),
                      )
                    : Container(
                        width: 45,
                        height: 64,
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: const Icon(Icons.image, size: 20),
                      ),
              ),
              const SizedBox(width: 12),

              // Title + details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.score != null) ...[
                          Icon(Icons.star,
                              size: 14,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 2),
                          Text(
                            '${item.score}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (item.mediaType != null)
                          Text(
                            item.mediaType!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Link button
              Icon(
                Icons.add_link,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
