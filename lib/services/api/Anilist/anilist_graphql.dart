import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/user/user_anilist_v2.dart';

/// The AniList session is dead (signed out, or the token could not be renewed).
class AnilistSessionExpired implements Exception {
  const AnilistSessionExpired();

  @override
  String toString() => 'AnilistSessionExpired';
}

/// AniList answered with an error status or a GraphQL error.
class AnilistError implements Exception {
  final int statusCode;
  final String? message;
  const AnilistError(this.statusCode, [this.message]);

  /// 429: too many requests. Always an [AnilistRateLimited] when thrown by [AnilistGraphql].
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'AnilistError($statusCode${message == null ? '' : ', $message'})';
}

/// AniList refused the call with a 429 (rate limit). [retryAfter] is how long AniList asked
/// to wait (its `Retry-After` header, else `X-RateLimit-Reset`, else a minute). Every AniList
/// call of the app already waits that long before its next request: a page only shows the
/// error and offers to try again.
class AnilistRateLimited extends AnilistError {
  final Duration retryAfter;
  const AnilistRateLimited(this.retryAfter, [String? message]) : super(429, message);

  @override
  String toString() => 'AnilistRateLimited(${retryAfter.inSeconds}s)';
}

/// Sends one JSON body to AniList's GraphQL endpoint. [auth] true must use the signed-in
/// account (and return null when there is none). Replaceable in tests.
typedef GraphqlSender = Future<http.Response?> Function(String body, {required bool auth});

/// Token bucket shared by every AniList request of the app.
///
/// AniList allows `X-RateLimit-Limit` requests a minute per IP (30 in its degraded mode, in
/// place since 2024; 90 normally). The bucket starts full at [limit] tokens and earns one back
/// every `60 s / limit`; each request takes one, waiting when none is left (waiters go in
/// call order). Each answer is fed to [observe]: the limit follows `X-RateLimit-Limit`, the
/// tokens never exceed `X-RateLimit-Remaining`, and a 429 pauses every request until its
/// `Retry-After` is over.
class AnilistRateLimiter {
  AnilistRateLimiter({
    int limit = defaultLimit,
    DateTime Function()? clock,
    Future<void> Function(Duration)? sleep,
  })  : assert(limit > 0),
        _limit = limit,
        _tokens = limit.toDouble(),
        _clock = clock ?? DateTime.now,
        _sleep = sleep ?? _defaultSleep {
    _stamp = _clock();
  }

  /// The limiter of the app: every [AnilistGraphql] built without a fake sender uses it.
  static final AnilistRateLimiter shared = AnilistRateLimiter();

  /// Requests a minute assumed until AniList says otherwise (its current degraded limit).
  static const int defaultLimit = 30;

  /// Wait after a 429 that carries no `Retry-After` nor `X-RateLimit-Reset`.
  static const Duration defaultPause = Duration(minutes: 1);

  final DateTime Function() _clock;
  final Future<void> Function(Duration) _sleep;
  int _limit;
  double _tokens;
  late DateTime _stamp;
  DateTime? _pausedUntil;
  Future<void> _queue = Future<void>.value();

  static Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

  /// Requests a minute currently allowed.
  int get limit => _limit;

  /// Requests that may start right now without waiting (whole tokens).
  int get available {
    _refill(_clock());
    return _pausedUntil != null && _clock().isBefore(_pausedUntil!) ? 0 : _tokens.floor();
  }

  /// End of the pause asked by the last 429, null when none is running.
  DateTime? get pausedUntil {
    final until = _pausedUntil;
    return until != null && _clock().isBefore(until) ? until : null;
  }

  Duration get _interval => Duration(microseconds: 60000000 ~/ _limit);

  /// Waits until one request may be sent, and takes its token.
  Future<void> acquire() {
    // The caller is released before the next waiter's turn starts: callers resume in order.
    final ticket = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        await _take();
        ticket.complete();
      } catch (e, st) {
        ticket.completeError(e, st);
      }
    });
    return ticket.future;
  }

  Future<void> _take() async {
    while (true) {
      final now = _clock();
      final until = _pausedUntil;
      if (until != null && now.isBefore(until)) {
        await _sleep(until.difference(now));
        continue;
      }
      _refill(now);
      if (_tokens >= 1) {
        _tokens -= 1;
        return;
      }
      await _sleep(_interval * (1 - _tokens));
    }
  }

  void _refill(DateTime now) {
    final elapsed = now.difference(_stamp);
    if (elapsed.isNegative) {
      _stamp = now;
      return;
    }
    _tokens = (_tokens + elapsed.inMicroseconds / _interval.inMicroseconds)
        .clamp(0, _limit.toDouble())
        .toDouble();
    _stamp = now;
  }

  /// Reads AniList's rate headers of one answer. Returns the pause a 429 asks for, else null.
  Duration? observe(int statusCode, Map<String, String> headers) {
    final now = _clock();
    _refill(now);
    int? header(String name) => int.tryParse(headers[name]?.trim() ?? '');

    final limit = header('x-ratelimit-limit');
    if (limit != null && limit > 0 && limit != _limit) {
      _limit = limit;
      if (_tokens > limit) _tokens = limit.toDouble();
    }
    final remaining = header('x-ratelimit-remaining');
    if (remaining != null && remaining >= 0 && remaining < _tokens) {
      _tokens = remaining.toDouble();
    }
    if (statusCode != 429) return null;

    final retryAfter = header('retry-after');
    final reset = header('x-ratelimit-reset');
    var pause = defaultPause;
    if (retryAfter != null && retryAfter >= 0) {
      pause = Duration(seconds: retryAfter);
    } else if (reset != null) {
      final at = DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true);
      final left = at.difference(now.toUtc());
      if (!left.isNegative) pause = left;
    }
    _tokens = 0;
    final until = now.add(pause);
    if (_pausedUntil == null || until.isAfter(_pausedUntil!)) _pausedUntil = until;
    return pause;
  }
}

/// A variable of a [AnilistGraphql.batch] request: its GraphQL type (`Int`, `[MediaFormat]`,
/// `MediaSeason!`…) and value.
@immutable
class GqlVar {
  final String type;
  final Object? value;
  const GqlVar(this.type, this.value);
}

/// The answer of [AnilistGraphql.batch]: each alias with its data, or the error AniList gave
/// for it. One alias failing (a title that does not exist, a private list) does not fail the
/// others.
@immutable
class AnilistBatch {
  /// The `data` object, keyed by alias (a failed alias maps to null).
  final Map<String, dynamic> data;

  /// The error of each failed alias. An error AniList did not tie to an alias is under every
  /// alias whose data is missing.
  final Map<String, AnilistError> errors;

  const AnilistBatch(this.data, this.errors);

  /// The object under [alias], null when it failed or is null (e.g. `Media` not found).
  Map<String, dynamic>? operator [](String alias) {
    final value = data[alias];
    return value is Map<String, dynamic> ? value : null;
  }

  /// The object under [alias]; throws its [AnilistError] when there is none.
  Map<String, dynamic> require(String alias) =>
      this[alias] ?? (throw errors[alias] ?? const AnilistError(404, 'No data'));
}

/// AniList's GraphQL endpoint, the one way the app talks to AniList.
///
/// - [query] for reads, [batch] for several reads in one request (AniList counts requests,
///   not fields: aliases are how a screen stays under the limit), [mutate] for writes.
/// - Public reads go out plain; `auth: true` reads and every write go through
///   `UserAnilistV2.sendAuthenticated` (token, one replay on 401). Reads are sent idempotent
///   (a network failure is retried), writes are not (a timeout never posts twice).
/// - Every request first takes a token of the [AnilistRateLimiter]. A read refused with a 429
///   waits for `Retry-After` and is sent once more when that wait is at most
///   [maxReadRetryWait]; otherwise, and for every write, [AnilistRateLimited] is thrown.
/// - Errors: [AnilistSessionExpired] without a usable session, [AnilistError] for any other
///   failure. Bodies over 32 KB are decoded off the UI isolate.
class AnilistGraphql {
  /// [sender] replaces the network for reads and, unless [mutationSender] is given, for writes
  /// too (tests). [limiter] defaults to [AnilistRateLimiter.shared] for the real network and
  /// to none with a fake [sender], so tests never wait unless they pass one.
  AnilistGraphql({
    GraphqlSender? sender,
    GraphqlSender? mutationSender,
    AnilistRateLimiter? limiter,
    this.maxReadRetryWait = const Duration(minutes: 1),
  })  : _sender = sender ?? _sendRead,
        _mutationSender = mutationSender ?? sender ?? _sendWrite,
        _limiter = limiter ?? (sender == null ? AnilistRateLimiter.shared : null);

  /// The client every AniList page uses; tests replace it.
  static AnilistGraphql instance = AnilistGraphql();

  static const String endpoint = 'https://graphql.anilist.co';

  final GraphqlSender _sender;
  final GraphqlSender _mutationSender;
  final AnilistRateLimiter? _limiter;

  /// Longest `Retry-After` a read waits through by itself before it gives up with
  /// [AnilistRateLimited].
  final Duration maxReadRetryWait;

  static Future<http.Response?> _sendRead(String body, {required bool auth}) =>
      _post(body, auth: auth, idempotent: true);

  static Future<http.Response?> _sendWrite(String body, {required bool auth}) =>
      _post(body, auth: auth, idempotent: false);

  static Future<http.Response?> _post(String body,
      {required bool auth, required bool idempotent}) {
    const headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (!auth) {
      return http
          .post(Uri.parse(endpoint), headers: headers, body: body)
          .timeout(const Duration(seconds: 20));
    }
    return UserAnilistV2.instance.sendAuthenticated(
      (client, token) => client.post(
        Uri.parse(endpoint),
        headers: {...headers, 'Authorization': 'Bearer $token'},
        body: body,
      ),
      // A read may be replayed after a network failure; a write only when it provably never
      // left the device (the replay after a 401 is always allowed: AniList refused it).
      idempotent: idempotent,
    );
  }

  /// Runs the read [query] and returns its `data` object. Throws [AnilistSessionExpired]
  /// without a usable session ([auth] true) and [AnilistError] on any failure.
  Future<Map<String, dynamic>> query(
    String query, {
    Map<String, dynamic> variables = const {},
    bool auth = false,
  }) async {
    final (status, decoded) = await _exchange(query, variables, auth: auth, write: false);
    return _dataOf(status, decoded);
  }

  /// Runs the write [mutation] (`mutation (...) { ... }`) as the signed-in user and returns
  /// its `data` object. Sent once: no replay on a network failure, none on a 429 (the error
  /// is thrown, AniList did not apply it). Same errors as [query].
  Future<Map<String, dynamic>> mutate(
    String mutation, {
    Map<String, dynamic> variables = const {},
  }) async {
    final (status, decoded) = await _exchange(mutation, variables, auth: true, write: true);
    return _dataOf(status, decoded);
  }

  /// Runs several reads in one request (it costs one token): each entry of [parts] is an
  /// alias and the root field it selects, e.g.
  ///
  /// ```dart
  /// final rows = await gql.batch({
  ///   'trending': 'Page(perPage: 10) { media(type: ANIME, sort: TRENDING_DESC) { id } }',
  ///   'top': r'Page(perPage: 10) { media(type: $type, sort: SCORE_DESC) { id } }',
  /// }, variables: {'type': const GqlVar('MediaType', 'ANIME')});
  /// rows['trending']?['media'];
  /// ```
  ///
  /// [variables] are shared by every part (one name, one value). Aliases and variable names
  /// must be GraphQL names (`[A-Za-z_][A-Za-z0-9_]*`); an empty [parts] answers without a
  /// request. AniList rejects over-complex requests: keep each part's connections small and
  /// split very large batches. Throws like [query] when the whole request fails; a failed
  /// alias only shows in [AnilistBatch.errors].
  Future<AnilistBatch> batch(
    Map<String, String> parts, {
    Map<String, GqlVar> variables = const {},
    bool auth = false,
  }) async {
    if (parts.isEmpty) return const AnilistBatch({}, {});
    for (final name in [...parts.keys, ...variables.keys]) {
      if (!_name.hasMatch(name)) throw ArgumentError.value(name, 'name', 'Not a GraphQL name');
    }
    final buffer = StringBuffer('query');
    if (variables.isNotEmpty) {
      buffer.write(' (');
      buffer.write(variables.entries.map((e) => '\$${e.key}: ${e.value.type}').join(', '));
      buffer.write(')');
    }
    buffer.writeln(' {');
    parts.forEach((alias, part) => buffer.writeln('  $alias: ${part.trim()}'));
    buffer.write('}');

    final (status, decoded) = await _exchange(
      buffer.toString(),
      {for (final e in variables.entries) e.key: e.value.value},
      auth: auth,
      write: false,
    );
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) throw _errorOf(status, decoded);

    final errors = <String, AnilistError>{};
    AnilistError? untied;
    final list = decoded['errors'];
    if (list is List) {
      for (final e in list) {
        if (e is! Map) continue;
        final path = e['path'];
        final error = AnilistError(
          (e['status'] as num?)?.toInt() ?? (status == 200 ? 400 : status),
          e['message']?.toString(),
        );
        if (path is List && path.isNotEmpty && parts.containsKey(path.first)) {
          errors.putIfAbsent(path.first as String, () => error);
        } else {
          untied ??= error;
        }
      }
    }
    if (untied != null) {
      for (final alias in parts.keys) {
        if (data[alias] == null) errors.putIfAbsent(alias, () => untied!);
      }
    }
    return AnilistBatch(data, errors);
  }

  static final RegExp _name = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  /// Sends one operation through the limiter; maps a missing session and a 429.
  Future<(int, Map<String, dynamic>)> _exchange(
    String operation,
    Map<String, dynamic> variables, {
    required bool auth,
    required bool write,
  }) async {
    final body = jsonEncode({'query': operation, 'variables': variables});
    final send = write ? _mutationSender : _sender;
    var retried = false;
    while (true) {
      await _limiter?.acquire();
      final response = await send(body, auth: auth);
      if (response == null) throw const AnilistSessionExpired();
      final pause = _limiter?.observe(response.statusCode, response.headers);
      if (response.statusCode == 401 && auth) throw const AnilistSessionExpired();
      if (response.statusCode == 429) {
        final wait = pause ?? _retryAfterOf(response.headers);
        // The limiter holds every request (this one included) until the pause is over.
        if (!write && !retried && wait <= maxReadRetryWait && _limiter != null) {
          retried = true;
          continue;
        }
        throw AnilistRateLimited(wait, _messageOf(await _decode(response)));
      }
      return (response.statusCode, await _decode(response));
    }
  }

  static Duration _retryAfterOf(Map<String, String> headers) {
    final seconds = int.tryParse(headers['retry-after']?.trim() ?? '');
    return seconds != null && seconds >= 0
        ? Duration(seconds: seconds)
        : AnilistRateLimiter.defaultPause;
  }

  static Map<String, dynamic> _dataOf(int status, Map<String, dynamic> decoded) {
    final data = decoded['data'];
    if (status != 200 || data is! Map<String, dynamic>) throw _errorOf(status, decoded);
    return data;
  }

  static AnilistError _errorOf(int status, Map<String, dynamic> decoded) =>
      AnilistError(status, _messageOf(decoded));

  static String? _messageOf(Map<String, dynamic> decoded) {
    final errors = decoded['errors'];
    return errors is List && errors.isNotEmpty && errors.first is Map
        ? (errors.first as Map)['message']?.toString()
        : null;
  }

  static Future<Map<String, dynamic>> _decode(http.Response response) async {
    try {
      // A whole list is a few hundred KB: decode it off the UI isolate.
      final decoded = response.body.length > 32 * 1024
          ? await compute(_decodeMap, response.body)
          : _decodeMap(response.body);
      return decoded;
    } catch (_) {
      return const {};
    }
  }
}

Map<String, dynamic> _decodeMap(String body) {
  final decoded = json.decode(body);
  return decoded is Map<String, dynamic> ? decoded : const {};
}
