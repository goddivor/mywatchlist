/// Pagination block of a Tenrai (Jikan v4) list answer.
class TenraiPagination {
  final int? lastVisiblePage;
  final bool hasNextPage;
  final int? currentPage;
  final int? count;
  final int? total;
  final int? perPage;

  const TenraiPagination({
    this.lastVisiblePage,
    this.hasNextPage = false,
    this.currentPage,
    this.count,
    this.total,
    this.perPage,
  });

  static TenraiPagination? fromJson(Object? json) {
    if (json is! Map) return null;
    final items = json['items'];
    int? at(Object? v) => v is num ? v.toInt() : null;
    return TenraiPagination(
      lastVisiblePage: at(json['last_visible_page']),
      hasNextPage: json['has_next_page'] == true,
      currentPage: at(json['current_page']),
      count: items is Map ? at(items['count']) : null,
      total: items is Map ? at(items['total']) : null,
      perPage: items is Map ? at(items['per_page']) : null,
    );
  }
}

/// A decoded Tenrai answer kept as JSON, for endpoints without a Jikan model.
class TenraiResponse {
  /// The whole decoded body.
  final Map<String, dynamic> body;

  const TenraiResponse(this.body);

  /// The `data` field (a list or an object).
  Object? get data => body['data'];

  TenraiPagination? get pagination => TenraiPagination.fromJson(body['pagination']);

  /// `data` as a list of objects (empty when `data` is not a list).
  List<Map<String, dynamic>> get items => list(body);

  /// `data` as an object (empty when `data` is not an object).
  Map<String, dynamic> get entry {
    final value = data;
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  /// Number of entries of `data` (1 for an object, 0 when absent).
  int get count {
    final value = data;
    if (value is List) return value.length;
    return value == null ? 0 : 1;
  }

  /// `data` of [body] as an object; throws [FormatException] otherwise.
  static Map<String, dynamic> object(Map<String, dynamic> body) {
    final value = body['data'];
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Tenrai answer without a data object');
  }

  /// `data` of [body] as a list of objects (non-object rows are skipped).
  static List<Map<String, dynamic>> list(Map<String, dynamic> body) {
    final value = body['data'];
    if (value is! List) return const [];
    return [
      for (final row in value)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }
}

/// One page of a Tenrai list, rows parsed with a Jikan model.
class TenraiPage<T> {
  final List<T> data;
  final TenraiPagination? pagination;

  const TenraiPage(this.data, this.pagination);

  bool get hasNextPage => pagination?.hasNextPage ?? false;

  static TenraiPage<T> parse<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) row,
  ) =>
      TenraiPage(
        TenraiResponse.list(body).map(row).toList(),
        TenraiPagination.fromJson(body['pagination']),
      );
}
