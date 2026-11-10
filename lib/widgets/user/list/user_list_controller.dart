import 'package:flutter/foundation.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';

/// Entries of one status tab of one list (anime or manga), with paging.
///
/// Two modes:
/// * paged: the tracker sorts ([UserListAdapter.apiSort] is not null), no
///   filter and no search — pages of [pageSize] are loaded as the user scrolls
///   (DailyAL's `InfinitePagination`);
/// * whole list: any other sort, a filter or a search — every page is loaded,
///   then filtered and sorted on the device (DailyAL `getAllUserList`).
///
/// Screen state, created and disposed by `UserListView`; app-wide state stays
/// in the BLoCs and the status cache.
class UserListTabController extends ChangeNotifier {
  UserListTabController({
    required this.adapter,
    required this.category,
    required this.status,
    required ListViewSettings settings,
    String query = '',
    this.pageSize = 300,
    ListStatusCache? cache,
    DateTime Function()? clock,
  })  : _settings = settings,
        _query = query,
        _cache = cache ?? ListStatusCache.instance,
        _clock = clock ?? DateTime.now;

  final UserListAdapter adapter;
  final String category;

  /// Null = every status ("All" tab).
  final ListEntryStatus? status;
  final int pageSize;
  final ListStatusCache _cache;
  final DateTime Function() _clock;

  ListViewSettings _settings;
  String _query;
  List<ListEntryView> _raw = const [];
  List<ListEntryView> _visible = const [];
  bool _started = false;
  bool _pendingReload = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;
  Object? _moreError;
  int _generation = 0;
  bool _disposed = false;

  ListViewSettings get settings => _settings;
  String get query => _query;

  /// What the tab shows, filtered and sorted.
  List<ListEntryView> get entries => _visible;

  /// Every loaded entry of the status, before filter and search.
  List<ListEntryView> get loaded => _raw;
  bool get isStarted => _started;

  /// First load (or reload) in progress with nothing to show yet.
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _hasMore;

  /// Error of the last full load (nothing shown), or null.
  Object? get error => _error;

  /// Error of the last "next page" load (entries still shown), or null.
  Object? get loadMoreError => _moreError;

  /// Number of entries of the status when the whole status is loaded, else null.
  int? get totalCount => _started && !_loading && !_hasMore && _error == null ? _raw.length : null;

  String? get _apiSort => adapter.apiSort(category, _settings.sortKey, _settings.direction);

  bool _pagedFor(ListViewSettings s, String q) =>
      adapter.apiSort(category, s.sortKey, s.direction) != null &&
      s.filter.isEmpty &&
      q.trim().isEmpty;

  bool get isPaged => _pagedFor(_settings, _query);

  /// Starts loading when the tab is first shown, or applies a reload asked
  /// while it was hidden.
  void activate() {
    if (!_started || _pendingReload) {
      _started = true;
      _pendingReload = false;
      refresh();
    }
  }

  /// Reloads from the first page.
  Future<void> refresh() async {
    _started = true;
    _pendingReload = false;
    final gen = ++_generation;
    _loading = true;
    _error = null;
    _moreError = null;
    _notify();
    try {
      if (isPaged) {
        final page = await adapter.fetch(
            category: category, status: status, offset: 0, limit: pageSize, apiSort: _apiSort);
        if (gen != _generation) return;
        _raw = List.unmodifiable(page.entries);
        _hasMore = page.hasMore && page.entries.isNotEmpty;
      } else {
        await _loadAll(gen);
        if (gen != _generation) return;
      }
      _writeCache();
    } catch (e) {
      if (gen != _generation) return;
      _error = e;
      _raw = const [];
      _hasMore = true;
    } finally {
      if (gen == _generation) {
        _loading = false;
        _recompute();
        _notify();
      }
    }
  }

  Future<void> _loadAll(int gen) async {
    final all = <ListEntryView>[];
    var offset = 0;
    while (true) {
      final page = await adapter.fetch(
        category: category,
        status: status,
        offset: offset,
        limit: adapter.maxPageSize,
        apiSort: null,
      );
      if (gen != _generation) return;
      all.addAll(page.entries);
      offset += page.entries.length;
      if (!page.hasMore || page.entries.isEmpty) break;
      // Show what is there while the next pages come.
      _raw = List.unmodifiable(all);
      _hasMore = true;
      _loading = false;
      _recompute();
      _notify();
    }
    _raw = List.unmodifiable(all);
    _hasMore = false;
  }

  /// Loads the next page (paged mode); called when the end of the list nears.
  Future<void> loadMore() async {
    if (!isPaged || !_hasMore || _loading || _loadingMore || _error != null) return;
    final gen = _generation;
    _loadingMore = true;
    _moreError = null;
    _notify();
    try {
      final page = await adapter.fetch(
          category: category,
          status: status,
          offset: _raw.length,
          limit: pageSize,
          apiSort: _apiSort);
      if (gen != _generation) return;
      final known = {for (final e in _raw) e.id};
      _raw = List.unmodifiable([..._raw, ...page.entries.where((e) => !known.contains(e.id))]);
      _hasMore = page.hasMore && page.entries.isNotEmpty;
      _writeCache(page: page.entries);
    } catch (e) {
      if (gen == _generation) _moreError = e;
    } finally {
      if (gen == _generation) {
        _loadingMore = false;
        _recompute();
        _notify();
      }
    }
  }

  /// New sort, filter or display. [visible] = the tab is on screen (a reload
  /// it needs runs now; a hidden tab reloads when it is next shown).
  void updateSettings(ListViewSettings value, {bool visible = false}) {
    final old = _settings;
    _settings = value;
    if (old.sameQuery(value)) return;
    _requery(old, _query, visible: visible);
  }

  /// New search text.
  void updateQuery(String value, {bool visible = false}) {
    final old = _query;
    if (old == value) return;
    _query = value;
    _requery(_settings, old, visible: visible);
  }

  void _requery(ListViewSettings oldSettings, String oldQuery, {required bool visible}) {
    if (!_started) return;
    final wasPaged = _pagedFor(oldSettings, oldQuery);
    final oldApi = adapter.apiSort(category, oldSettings.sortKey, oldSettings.direction);
    final needsReload =
        _hasMore && (!isPaged || !wasPaged || oldApi != _apiSort);
    if (needsReload || _error != null) {
      if (visible) {
        refresh();
      } else {
        _pendingReload = true;
      }
      return;
    }
    _recompute();
    _notify();
  }

  /// Applies an entry saved elsewhere (edit sheet, +1): it moves in or out
  /// of this tab according to its status.
  void applyChange(ListEntryView entry) {
    if (!_started) return;
    final belongs = status == null || entry.status == status;
    final index = _raw.indexWhere((e) => e.id == entry.id);
    if (index < 0 && !belongs) return;
    final next = [..._raw];
    if (index >= 0) {
      if (belongs) {
        next[index] = entry;
      } else {
        next.removeAt(index);
      }
    } else {
      next.insert(0, entry);
    }
    _raw = List.unmodifiable(next);
    _recompute();
    _notify();
  }

  /// Removes [id] (deleted from the list).
  void removeEntry(int id) {
    if (!_started) return;
    final next = _raw.where((e) => e.id != id).toList();
    if (next.length == _raw.length) return;
    _raw = List.unmodifiable(next);
    _recompute();
    _notify();
  }

  void _recompute() {
    final filtered = filterEntries(_raw, _settings.filter, query: _query, now: _clock());
    // A paged list keeps the tracker's order; a whole list is sorted here.
    _visible = isPaged && _hasMore
        ? List.unmodifiable(filtered)
        : List.unmodifiable(
            sortEntries(filtered, _settings.sortKey, _settings.direction, now: _clock()));
  }

  void _writeCache({List<ListEntryView>? page}) {
    final source = page ?? _raw;
    final values = {
      for (final e in source)
        if (e.status != null)
          e.id: CachedListStatus(
            status: e.status!.malValue(isAnime: e.isAnime),
            score: e.score,
            progress: e.progress,
          ),
    };
    if (page == null && !_hasMore) {
      _cache.replaceStatuses(values,
          statuses: status == null ? null : {status!.malValue(isAnime: category == 'anime')},
          category: category,
          tracker: adapter.tracker);
    } else {
      _cache.putAll(values, category: category, tracker: adapter.tracker);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
