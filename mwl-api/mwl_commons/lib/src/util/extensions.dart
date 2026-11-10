/// Regex for matching alphabetic characters and spaces.
final _alphaDigitExp = RegExp(r'[a-zA-Z ]');

/// Shared string extensions.
extension StringExtensions on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  bool equals(dynamic other) {
    if (other == null || this == null) return false;
    return this!.toLowerCase() == other.toString().toLowerCase();
  }
}

/// Non-nullable string extensions for parsing helpers.
extension StringParsingExtensions on String {
  /// Returns only alphabetic characters and spaces from the string.
  String getAlphabets() {
    final buffer = StringBuffer();
    for (int i = 0; i < length; ++i) {
      if (_alphaDigitExp.hasMatch(this[i])) {
        buffer.write(this[i]);
      }
    }
    return buffer.toString();
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

/// Safe index access on lists.
extension ListSafeAccess<T> on List<T> {
  T? tryAt([int index = 0]) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }
}
