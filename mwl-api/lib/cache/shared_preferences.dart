/// In-memory key-value store that mimics SharedPreferences for the backend.
///
/// No Flutter dependency — uses a simple HashMap.
class SharedPreferences {
  final Map<String, dynamic> _store = {};

  dynamic get(String key) => _store[key];

  void set(String key, dynamic value) {
    _store[key] = value;
  }

  void remove(String key) {
    _store.remove(key);
  }

  bool containsKey(String key) => _store.containsKey(key);

  void clear() => _store.clear();
}
