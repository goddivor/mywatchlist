import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart' show SimklClient, SimklHttpError;
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The period of a Simkl trending file.
enum SimklTrendingWindow {
  today,
  week,
  month;

  /// File name part on the CDN (`today_100.json`).
  String get file => name;
}

/// Plain GET used by [SimklCdn] (replaced by a fake in tests).
typedef SimklCdnGet = Future<http.Response> Function(Uri uri, Map<String, String> headers);

/// Simkl's free data files on `https://data.simkl.in`: no user token, no daily quota, cached by
/// Cloudflare (trending one hour, calendar five hours). Docs: https://api.simkl.org (Trending,
/// Calendar).
///
/// - Trending anime of the day, week or month (`/discover/trending/anime/{window}_100.json`).
/// - The anime calendar: every episode airing in a rolling 33-day window, with the title's
///   metadata (`/calendar/v2/anime.json`).
///
/// Answers are kept in memory (trending 30 min, calendar 1 h) and a request already running is
/// shared, so the home rows and the Explore tab download each file once.
class SimklCdn {
  SimklCdn({
    SimklCdnGet? get,
    String Function()? clientId,
    Future<String> Function()? appVersion,
    DateTime Function()? now,
  })  : _get = get ?? _defaultGet,
        _clientId = clientId ?? (() => Constants.simklClientId),
        _appVersion = appVersion ?? _packageVersion,
        _now = now ?? DateTime.now;

  static const String host = 'https://data.simkl.in';

  /// How long a trending answer is reused.
  static const Duration trendingTtl = Duration(minutes: 30);

  /// How long the calendar is reused.
  static const Duration calendarTtl = Duration(hours: 1);

  /// Shared instance; tests build their own with a fake [SimklCdnGet].
  static SimklCdn instance = SimklCdn();

  final SimklCdnGet _get;
  final String Function() _clientId;
  final Future<String> Function() _appVersion;
  final DateTime Function() _now;

  String? _version;
  final Map<String, ({DateTime at, List<SimklMedia> items})> _kept = {};
  final Map<String, Future<List<SimklMedia>>> _running = {};

  static Future<String> _packageVersion() async {
    try {
      return (await PackageInfo.fromPlatform().timeout(const Duration(seconds: 2))).version;
    } catch (_) {
      return '0.0.0';
    }
  }

  static Future<http.Response> _defaultGet(Uri uri, Map<String, String> headers) =>
      http.get(uri, headers: headers).timeout(const Duration(seconds: 25));

  /// The URL of [path] with the identification Simkl asks for on every request (the CDN does
  /// not check it, but the docs list it).
  Uri uri(String path) => Uri.parse('$host$path').replace(queryParameters: {
        'client_id': _clientId(),
        'app-name': SimklClient.appName,
        'app-version': _version ?? '0.0.0',
      });

  /// The trending anime of [window], most watched first (100 titles).
  Future<List<SimklMedia>> trending(SimklTrendingWindow window) =>
      _cached('trending_${window.file}', trendingTtl, () async {
        final body = await _fetch('/discover/trending/anime/${window.file}_100.json');
        return _parse(parseSimklTrending, body);
      });

  /// Every episode of the calendar file, by air time; each item carries its episode number and
  /// air date ([SimklMedia.episode], [SimklMedia.airDate], UTC).
  Future<List<SimklMedia>> calendar() => _cached('calendar', calendarTtl, () async {
        final body = await _fetch('/calendar/v2/anime.json');
        return _parse(parseSimklCalendar, body);
      });

  /// The calendar episodes airing on the local day of [day].
  Future<List<SimklMedia>> airingOn(DateTime day) async => episodesOn(await calendar(), day);

  /// Forgets the kept answers (pull to refresh).
  void invalidate() => _kept.clear();

  Future<List<SimklMedia>> _cached(
    String key,
    Duration ttl,
    Future<List<SimklMedia>> Function() load,
  ) {
    final kept = _kept[key];
    if (kept != null && _now().difference(kept.at) < ttl) return Future.value(kept.items);
    final running = _running[key];
    if (running != null) return running;
    final future = load().then((items) {
      _kept[key] = (at: _now(), items: items);
      return items;
    }).whenComplete(() => _running.remove(key));
    _running[key] = future;
    return future;
  }

  Future<String> _fetch(String path) async {
    _version ??= await _appVersion();
    final response = await _get(uri(path), {
      'Accept': 'application/json',
      'User-Agent': '${SimklClient.appName}/${_version ?? '0.0.0'}',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SimklHttpError(response.statusCode);
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// The files weigh 160 KB to 270 KB: decoded off the UI isolate.
  static Future<List<SimklMedia>> _parse(List<SimklMedia> Function(String) parser, String body) =>
      body.length > 32 * 1024 ? compute(parser, body) : Future.value(parser(body));
}

/// The items of [calendar] airing on the local day of [day], by air time.
List<SimklMedia> episodesOn(List<SimklMedia> calendar, DateTime day) {
  final local = day.toLocal();
  return [
    for (final item in calendar)
      if (item.airDate case final at? when _sameDay(at.toLocal(), local)) item,
  ];
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

final RegExp _tags = RegExp(r'<[^>]*>');
final RegExp _year = RegExp(r'\b(19|20)\d{2}\b');

/// One title of a CDN file. Trending dates are `MM/DD/YYYY` and overviews carry `<br>` tags,
/// which [SimklMedia.fromJson] does not expect.
SimklMedia? _media(Map<Object?, Object?> raw) {
  final media = SimklMedia.fromJson(raw);
  if (media == null) return null;
  final release = raw['release_date'];
  final year = media.year ?? (release is String ? int.tryParse(_year.firstMatch(release)?.group(0) ?? '') : null);
  final overview = media.overview?.replaceAll(_tags, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return SimklMedia(
    simklId: media.simklId,
    malId: media.malId,
    slug: media.slug,
    title: media.title,
    posterUrl: media.posterUrl,
    year: year,
    rating: media.rating,
    overview: overview == null || overview.isEmpty ? null : overview,
    animeType: media.animeType,
    genres: media.genres,
    episode: media.episode,
    airDate: media.airDate,
  );
}

/// Parses a trending file (`[{title, ids, ratings, ...}]`); top level so `compute` can run it.
List<SimklMedia> parseSimklTrending(String body) {
  final data = json.decode(body);
  if (data is! List) return const [];
  final seen = <int>{};
  return [
    for (final raw in data)
      if (raw is Map)
        if (_media(raw) case final item? when seen.add(item.simklId)) item,
  ];
}

/// Parses the calendar file (`{calendar: [{simkl_id, date, episode}], metadata: {id: title}}`)
/// into one item per episode, by air time; episodes without metadata or date are dropped.
/// Top level so `compute` can run it.
List<SimklMedia> parseSimklCalendar(String body) {
  final data = json.decode(body);
  if (data is! Map) return const [];
  final calendar = data['calendar'];
  final metadata = data['metadata'];
  if (calendar is! List || metadata is! Map) return const [];
  final items = <SimklMedia>[];
  final seen = <String>{};
  for (final entry in calendar) {
    if (entry is! Map) continue;
    final id = entry['simkl_id'];
    final meta = metadata['$id'];
    final date = entry['date'];
    if (meta is! Map || date is! String || DateTime.tryParse(date) == null) continue;
    final episode = entry['episode'];
    final number = episode is Map ? episode['episode'] : null;
    if (!seen.add('$id:$number:$date')) continue;
    final media = _media({
      ...meta,
      'ids': {...?(meta['ids'] as Map?), 'simkl_id': id},
      'date': date,
      'episode': number,
    });
    if (media != null) items.add(media);
  }
  items.sort((a, b) => a.airDate!.compareTo(b.airDate!));
  return items;
}
