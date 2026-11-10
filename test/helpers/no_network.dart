import 'dart:io';

/// Thrown when a test tries to open a real network connection.
class NetworkAccessInTest implements Exception {
  NetworkAccessInTest(this.target);

  final String target;

  @override
  String toString() =>
      'NetworkAccessInTest: a test tried to reach $target. Tests must never '
      'hit the network; use a fake from test/helpers/ instead.';
}

/// [HttpOverrides] that fails every outgoing connection, so a test that
/// accidentally calls a tracker API fails fast instead of hitting the network.
///
/// `package:http` (IOClient) and `dart:io` both go through [HttpClient], so
/// installing this override covers every HTTP path of the app.
class NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _NoNetworkClient();
}

/// Installs [NoNetworkHttpOverrides] globally for the current test isolate.
void forbidNetwork() {
  HttpOverrides.global = NoNetworkHttpOverrides();
}

class _NoNetworkClient implements HttpClient {
  Never _deny(Object target) => throw NetworkAccessInTest('$target');

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _deny(url);

  @override
  Future<HttpClientRequest> open(
          String method, String host, int port, String path) async =>
      _deny('$host:$port$path');

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _deny(url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _deny(url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) async => _deny(url);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async => _deny(url);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) async => _deny(url);

  @override
  Future<HttpClientRequest> headUrl(Uri url) async => _deny(url);

  @override
  Future<HttpClientRequest> get(String host, int port, String path) async =>
      _deny('$host:$port$path');

  @override
  Future<HttpClientRequest> post(String host, int port, String path) async =>
      _deny('$host:$port$path');

  @override
  Future<HttpClientRequest> put(String host, int port, String path) async =>
      _deny('$host:$port$path');

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) async =>
      _deny('$host:$port$path');

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) async =>
      _deny('$host:$port$path');

  @override
  Future<HttpClientRequest> head(String host, int port, String path) async =>
      _deny('$host:$port$path');

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
