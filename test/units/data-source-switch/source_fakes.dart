import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Tenrai/tenrai_client.dart';
import 'package:mywatchlist/services/api/jikan_source.dart';

/// How a fake server behaves.
enum ServerMode { up, refused, silent, error503 }

/// Counts the requests in flight on BOTH fake servers, so a test can check that no
/// request is ever sent to Jikan and Tenrai at the same time.
class InFlight {
  int now = 0;
  int max = 0;

  Future<T> track<T>(Future<T> Function() body) async {
    now++;
    if (now > max) max = now;
    try {
      return await body();
    } finally {
      now--;
    }
  }
}

/// A fake server (Jikan or Tenrai) answering `{"data":{"title":"<name>"}}`.
class FakeServer {
  FakeServer(this.name, this.mode, this.inFlight);

  final String name;
  ServerMode mode;
  final InFlight inFlight;
  final List<Uri> requests = [];

  /// Body of an `up` answer (default: a small object naming the server).
  String Function(Uri url)? body;

  late final MockClient client = MockClient((request) {
    if (mode == ServerMode.silent) {
      // Never answers: the client gives up on it (not counted as in flight).
      requests.add(request.url);
      return Completer<http.Response>().future;
    }
    return inFlight.track(() async {
        requests.add(request.url);
        // Let a concurrent request on the other server overlap if the code ever sent one.
        await Future<void>.delayed(const Duration(milliseconds: 5));
        switch (mode) {
          case ServerMode.up:
            final custom = body;
            return http.Response(
                custom != null ? custom(request.url) : '{"data":{"mal_id":1,"title":"$name"}}', 200);
          case ServerMode.refused:
            throw http.ClientException('Connection refused', request.url);
          case ServerMode.silent:
            return Completer<http.Response>().future;
          case ServerMode.error503:
            return http.Response('{"status":503}', 503);
        }
      });
  });
}

/// A probe whose answer the test decides; counts its calls.
class FakeProbe {
  FakeProbe(this.answer);

  /// true: Jikan answers; false: it does not; null: never completes.
  bool? answer;
  int calls = 0;
  Completer<bool>? pending;

  Future<bool> call() {
    calls++;
    final value = answer;
    if (value == null) return (pending = Completer<bool>()).future;
    return Future.value(value);
  }
}

/// A Jikan / Tenrai pair behind one [JikanClient], with a fake clock.
class SourceRig {
  SourceRig({
    ServerMode jikan = ServerMode.up,
    ServerMode tenrai = ServerMode.up,
    bool? probe = true,
    DateTime? now,
    Duration requestTimeout = const Duration(milliseconds: 200),
    Duration readyTimeout = const Duration(seconds: 5),
  })  : clock = now ?? DateTime(2026, 10, 30, 12) {
    inFlight = InFlight();
    jikanServer = FakeServer('jikan', jikan, inFlight);
    tenraiServer = FakeServer('tenrai', tenrai, inFlight);
    this.probe = FakeProbe(probe);
    source = JikanSource(
      tenrai: TenraiClient(client: tenraiServer.client, minInterval: Duration.zero, requestTimeout: requestTimeout),
      probe: this.probe.call,
      probeTimeout: const Duration(milliseconds: 300),
      readyTimeout: readyTimeout,
      now: () => clock,
    );
    client = JikanClient(
      client: jikanServer.client,
      minInterval: Duration.zero,
      requestTimeout: requestTimeout,
      source: source,
      now: () => clock,
    );
  }

  DateTime clock;
  late final InFlight inFlight;
  late final FakeServer jikanServer;
  late final FakeServer tenraiServer;
  late final FakeProbe probe;
  late final JikanSource source;
  late final JikanClient client;

  static Uri jikanUrl(String path) => Uri.parse('https://api.jikan.moe/v4$path');

  Future<http.Response> get(String path) => client.get(jikanUrl(path), useCache: false);
}
