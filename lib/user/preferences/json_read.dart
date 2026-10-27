/// Tolerant readers for the persisted preference JSON.
///
/// A saved value of the wrong type (an older build, a hand-edited backup) falls back to the
/// default instead of throwing, so one bad field never resets the whole group.
library;

bool readBool(Map<String, dynamic> json, String key, bool fallback) {
  final value = json[key];
  return value is bool ? value : fallback;
}

int readInt(Map<String, dynamic> json, String key, int fallback) {
  final value = json[key];
  return value is int ? value : (value is num ? value.toInt() : fallback);
}

double readDouble(Map<String, dynamic> json, String key, double fallback) {
  final value = json[key];
  return value is num ? value.toDouble() : fallback;
}

double? readDoubleOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is num ? value.toDouble() : null;
}

String readString(Map<String, dynamic> json, String key, String fallback) {
  final value = json[key];
  return value is String ? value : fallback;
}

/// Reads an enum saved by name; an unknown or missing name gives [fallback].
T readEnum<T extends Enum>(Map<String, dynamic> json, String key, List<T> values, T fallback) {
  final value = json[key];
  if (value is! String) return fallback;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return fallback;
}

List<int> readIntList(Map<String, dynamic> json, String key, List<int> fallback) {
  final value = json[key];
  if (value is! List) return fallback;
  final ints = value.whereType<num>().map((e) => e.toInt()).toList();
  return ints.length == value.length ? ints : fallback;
}

Map<String, dynamic>? readMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

List<Map<String, dynamic>> readMapList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}
