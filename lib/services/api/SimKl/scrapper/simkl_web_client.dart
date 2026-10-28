import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// simkl.com answered something other than a page (403 Cloudflare challenge, 404, 5xx).
class SimklPageUnavailable implements Exception {
  final int statusCode;
  const SimklPageUnavailable(this.statusCode);

  @override
  String toString() => 'SimklPageUnavailable($statusCode)';
}

/// Plain GET of a page; tests pass a fake.
typedef SimklPageGet = Future<http.Response> Function(Uri uri, Map<String, String> headers);

/// Anonymous reads of simkl.com's public title pages (allowed by its robots.txt: title pages
/// and their `reviews/`, `comments/`, `memos/` sub-pages). Desktop User-Agent (the parsers read
/// the desktop markup), at most one request per [spacing] for the whole app, nothing written.
class SimklWebClient {
  SimklWebClient({
    SimklPageGet? get,
    this.spacing = const Duration(seconds: 1),
    this.timeout = const Duration(seconds: 20),
    DateTime Function()? now,
    Future<void> Function(Duration)? sleep,
  })  : _get = get ?? _defaultGet,
        _now = now ?? DateTime.now,
        _sleep = sleep ?? ((d) => Future<void>.delayed(d));

  static SimklWebClient instance = SimklWebClient();

  static const String userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  final SimklPageGet _get;
  final Duration spacing;
  final Duration timeout;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;

  /// When the next request may start; requests queue behind each other.
  DateTime? _nextSlot;

  static Future<http.Response> _defaultGet(Uri uri, Map<String, String> headers) => http.get(uri, headers: headers);

  Future<void> _waitTurn() async {
    final now = _now();
    final slot = _nextSlot;
    final start = slot == null || slot.isBefore(now) ? now : slot;
    _nextSlot = start.add(spacing);
    final wait = start.difference(now);
    if (wait > Duration.zero) await _sleep(wait);
  }

  /// The HTML of [url]; throws [SimklPageUnavailable] on a non-2xx answer.
  Future<String> page(String url) async {
    await _waitTurn();
    final response = await _get(Uri.parse(url), const {
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'en-US,en;q=0.8',
    }).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SimklPageUnavailable(response.statusCode);
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }
}
