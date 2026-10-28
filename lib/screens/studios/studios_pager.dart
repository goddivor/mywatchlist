import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mwl_commons/mwl_commons.dart' show CompanyHtml, CompanyPageHtml;
import 'package:mywatchlist/screens/search/search_sources.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';

/// Where the studios directory is.
enum StudiosStage { loading, loaded, empty, error }

/// The pages of the studios directory (MyAnimeList's `/company`, 50 per page, logos) for one
/// search text, no widget. MAL's directory stops after about 2,050 companies; the whole
/// directory (no search text) then goes on with the other producers of MAL's search form, A to
/// Z, without logos, so every studio is listed. The screen calls [start] for a new text and [loadMore] near the end
/// of the list; [onChanged] runs after every change. An answer for an older text is dropped.
class StudiosPager {
  StudiosPager({
    required this.onChanged,
    Future<CompanyPageHtml?> Function(String query, int page)? fetch,
    Future<Map<int, String>?> Function()? fetchOthers,
  })  : _fetch = fetch ?? defaultFetch,
        _fetchOthers = fetchOthers ?? defaultFetchOthers;

  /// Every producer of MAL's search form (id to name), for the end of the directory.
  static Future<Map<int, String>?> Function() defaultFetchOthers = _mwlStudios;

  static Future<Map<int, String>?> _mwlStudios() async {
    try {
      final all = await MwlApi.i.getStudios().timeout(MwlApi.searchPageTimeout);
      return all.isEmpty ? null : all;
    } catch (_) {
      return null;
    }
  }

  /// The source of every pager built without `fetch` (tests replace it).
  static Future<CompanyPageHtml?> Function(String query, int page) defaultFetch = _mwlApi;

  static Future<CompanyPageHtml?> _mwlApi(String query, int page) =>
      MwlApi.i.getCompanies(query: query, page: page);

  @visibleForTesting
  static void reset() {
    defaultFetch = _mwlApi;
    defaultFetchOthers = _mwlStudios;
  }

  static const int _pageSize = 50;

  final void Function() onChanged;
  final Future<CompanyPageHtml?> Function(String query, int page) _fetch;
  final Future<Map<int, String>?> Function() _fetchOthers;

  /// Producers left after MAL's directory, A to Z (null until the directory ended).
  List<CompanyHtml>? _others;
  bool _directoryDone = false;

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
    _others = null;
    _directoryDone = false;
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
    if (_directoryDone) {
      await _loadOthers(token);
      return;
    }
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
    if (!hasMore && query.isEmpty) {
      // The directory ended: the other producers come next.
      _directoryDone = true;
      hasMore = true;
    }
  }

  Future<void> _loadOthers(int token) async {
    var others = _others;
    if (others == null) {
      final all = await _fetchOthers();
      if (_disposed || token != _token) return;
      if (all == null) {
        loadingMore = false;
        loadMoreFailed = true;
        _notify();
        return;
      }
      final known = {for (final c in items) c.id};
      others = [
        for (final entry in all.entries)
          if (!known.contains(entry.key)) CompanyHtml(id: entry.key, name: entry.value),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _others = others;
    }
    final take = others.take(_pageSize).toList();
    others.removeRange(0, take.length);
    items.addAll(take);
    hasMore = others.isNotEmpty;
    loadingMore = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) onChanged();
  }

  void dispose() => _disposed = true;
}
