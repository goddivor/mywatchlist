import 'package:mwl_commons/mwl_commons.dart';

/// In-memory cache with TTL expiration for backend responses.
class CacheManager {
  static final CacheManager instance = CacheManager();

  final Map<String, _CacheEntry> _cache = {};

  /// Default cache duration: 1 hour.
  static const int defaultTtlHours = 1;

  /// Get cached result or compute via [orElse].
  ///
  /// Checks cache first (respecting TTL and mandatory fields),
  /// then calls [orElse] if cache miss/expired.
  Future<Map<String, dynamic>?> getCachedResult(
    Uri uri,
    PathMatcher matcher, {
    required Future<Map<String, dynamic>> Function() orElse,
    bool fromCache = true,
    int ttlHours = defaultTtlHours,
  }) async {
    final key = uri.toString();

    if (fromCache) {
      final cached = _cache[key];
      if (cached != null && !cached.isExpired(ttlHours)) {
        final data = cached.data;
        if (_hasAllFields(data, matcher.mandatoryCachedFields)) {
          data['fromCache'] = true;
          return data;
        }
      }
    }

    final result = await orElse();
    _putMeta(result, key);
    _cache[key] = _CacheEntry(Map<String, dynamic>.from(result), DateTime.now());
    return result;
  }

  /// Store a value in cache manually.
  void put(String key, Map<String, dynamic> data) {
    _cache[key] = _CacheEntry(data, DateTime.now());
  }

  /// Get a cached value without computing.
  Map<String, dynamic>? get(String key, {int ttlHours = defaultTtlHours}) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired(ttlHours)) {
      return entry.data;
    }
    return null;
  }

  /// Clear all cached data.
  void clear() => _cache.clear();

  void _putMeta(Map<String, dynamic> data, String key) {
    data['lastUpdated'] = DateTime.now().toIso8601String();
    data['fromCache'] = false;
    data['url'] = key;
  }

  bool _hasAllFields(Map<String, dynamic> data, List<String> fields) {
    for (final field in fields) {
      if (!data.containsKey(field) || data[field] == null) {
        return false;
      }
    }
    return true;
  }
}

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime createdAt;

  _CacheEntry(this.data, this.createdAt);

  bool isExpired(int ttlHours) {
    return DateTime.now().difference(createdAt).inHours >= ttlHours;
  }
}
