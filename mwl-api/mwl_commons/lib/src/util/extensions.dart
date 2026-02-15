/// Shared string extensions.
extension StringExtensions on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  bool equals(dynamic other) {
    if (other == null || this == null) return false;
    return this!.toLowerCase() == other.toString().toLowerCase();
  }
}

/// Check if a value is null or empty (works for String, List, Map).
bool nullOrEmpty(dynamic value) {
  if (value == null) return true;
  if (value is String) return value.isEmpty;
  if (value is List) return value.isEmpty;
  if (value is Map) return value.isEmpty;
  return false;
}
