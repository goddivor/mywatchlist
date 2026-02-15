import 'dart:async';

/// Matches URL paths with wildcard support for routing.
///
/// Patterns like `anime/*id` match `anime/12345` and extract `12345` as a param.
class PathMatcher {
  final String path;
  final Future<Map<String, dynamic>> Function(PathMatcher, Uri, Map<String, String>) handler;
  final List<String> mandatoryCachedFields;
  static const _emptyList = <String>[];

  const PathMatcher(this.path, this.handler,
      [this.mandatoryCachedFields = _emptyList]);

  /// Check if a URL path matches this pattern.
  bool hasMatch(String url) {
    final splitPaths = url.split('/');
    if (splitPaths.length != _splitPathLength) {
      return false;
    }
    for (var i = 0; i < _splitPathLength; i++) {
      final pathA = _splitPaths[i];
      final pathB = splitPaths[i];
      if (!pathA.startsWith('*') && pathA.compareTo(pathB) != 0) {
        return false;
      }
    }
    return true;
  }

  /// Extract all wildcard parameters from a matched URL.
  List<String> pathParams(String url) {
    final list = <String>[];
    final splitPaths = url.split('/');
    for (var i = 0; i < _splitPathLength; i++) {
      final pathA = _splitPaths[i];
      final pathB = splitPaths[i];
      if (pathA.startsWith('*')) {
        list.add(pathB);
      }
    }
    return list;
  }

  /// Extract a single wildcard parameter by index.
  T pathParam<T>(String url, [int at = 0]) {
    final params = pathParams(url);
    if (at >= params.length) {
      throw ArgumentError('Path param index $at out of range (${params.length})');
    }
    if (T == int) {
      return int.tryParse(params[at]) as T;
    }
    return params[at] as T;
  }

  List<String> get _splitPaths => path.split('/');
  int get _splitPathLength => _splitPaths.length;
}
