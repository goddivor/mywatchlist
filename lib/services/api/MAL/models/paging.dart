/// Pagination model for MAL API responses.
/// Contains next/previous page URLs for cursor-based pagination.
class Paging {
  final String? next;
  final String? previous;

  Paging({this.next, this.previous});

  factory Paging.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Paging();
    return Paging(
      next: json['next'] as String?,
      previous: json['previous'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (next != null) 'next': next,
      if (previous != null) 'previous': previous,
    };
  }
}
