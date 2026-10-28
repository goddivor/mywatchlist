import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mwl_commons/mwl_commons.dart' show CompanyHtml, CompanyPageHtml;
import 'package:mywatchlist/screens/search/search_sources.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';

/// Where the studios directory is.
enum StudiosStage { loading, loaded, empty, error }

/// The pages of the studios directory (MyAnimeList's `/company`, 50 per page, logos) for one
/// search text, no widget. The screen calls [start] for a new text and [loadMore] near the end
/// of the list; [onChanged] runs after every change. An answer for an older text is dropped.
class StudiosPager {
  StudiosPager({required this.onChanged, Future<CompanyPageHtml?> Function(String query, int page)? fetch})
      : _fetch = fetch ?? defaultFetch;

  /// The source of every pager built without `fetch` (tests replace it).
  static Future<CompanyPageHtml?> Function(String query, int page) defaultFetch = _mwlApi;

  static Future<CompanyPageHtml?> _mwlApi(String query, int page) =>
      MwlApi.i.getCompanies(query: query, page: page);

  @visibleForTesting
  static void reset() => defaultFetch = _mwlApi;

  final void Function() onChanged;
  final Future<CompanyPageHtml?> Function(String query, int page) _fetch;

  String query = '';
  StudiosStage stage = StudiosStage.loading;
  SearchFailureKind failure = SearchFailureKind.source;
  final List<CompanyHtml> items = [];
  bool hasMore = false;
  bool loadingMore = false;
  bool loadMoreFailed = false;

  int _page = 0;
  int _token = 0;
  bool _disposed = false;

  /// First page for [text] (trimmed; empty = the whole directory, most favorited first).
  Future<void> start(String text) async {
    query = text.trim();
    final token = ++_token;
    items.clear();
    _page = 0;
    hasMore = false;
    loadingMore = false;
    loadMoreFailed = false;
    stage = StudiosStage.loading;
    _notify();
    final result = await _fetch(query, 1);
    if (_disposed || token != _token) return;
    if (result == null) {
      failure = await SearchFailures.classify(StateError('studios'));
      if (_disposed || token != _token) return;
      stage = StudiosStage.error;
    } else {
      _page = 1;
      _add(result);
      stage = items.isEmpty ? StudiosStage.empty : StudiosStage.loaded;
    }
    _notify();
  }

  /// The next page, once at a time; a failure shows a Retry footer ([loadMoreFailed]).
  Future<void> loadMore() async {
    if (!hasMore || loadingMore || stage != StudiosStage.loaded) return;
    final token = _token;
    loadingMore = true;
    loadMoreFailed = false;
    _notify();
    final result = await _fetch(query, _page + 1);
    if (_disposed || token != _token) return;
    loadingMore = false;
    if (result == null) {
      loadMoreFailed = true;
    } else {
      _page++;
      _add(result);
    }
    _notify();
  }

  /// Retries what failed: the first page, or the next one.
  Future<void> retry() => stage == StudiosStage.error ? start(query) : loadMore();

  void _add(CompanyPageHtml page) {
    final known = {for (final c in items) c.id};
    items.addAll(page.items.where((c) => known.add(c.id)));
    hasMore = page.hasNext && page.items.isNotEmpty;
  }

  void _notify() {
    if (!_disposed) onChanged();
  }

  void dispose() => _disposed = true;
}
