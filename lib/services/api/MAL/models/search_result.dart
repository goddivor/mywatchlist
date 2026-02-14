import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/models/paging.dart';

/// Wrapper for MAL API list responses with pagination support.
/// Parses the standard MAL format: {"data": [{"node": {...}, "ranking": {...}}], "paging": {...}}
class SearchResult {
  final List<Anime> data;
  final Paging? paging;
  final String? url;
  final bool fromCache;
  final DateTime? lastUpdated;

  SearchResult({
    this.data = const [],
    this.paging,
    this.url,
    this.fromCache = false,
    this.lastUpdated,
  });

  factory SearchResult.fromJson(Map<String, dynamic>? json,
      {String category = "anime"}) {
    if (json == null) return SearchResult();

    final dataList = json['data'] as List<dynamic>? ?? [];
    final items = dataList.map((item) {
      final node = item['node'] as Map<String, dynamic>?;
      if (node == null) return null;
      return Anime.fromMAlJson(node);
    }).whereType<Anime>().toList();

    return SearchResult(
      data: items,
      paging:
          json['paging'] != null ? Paging.fromJson(json['paging']) : null,
      url: json['url'] as String?,
      fromCache: json['fromCache'] as bool? ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((a) => {'node': a.toJson()}).toList(),
      if (paging != null) 'paging': paging!.toJson(),
      if (url != null) 'url': url,
      'fromCache': fromCache,
      if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
    };
  }

  bool get hasNextPage => paging?.next != null;
  bool get hasPreviousPage => paging?.previous != null;

  /// Convenience getter for backward compatibility
  List<Anime> get items => data;
}
