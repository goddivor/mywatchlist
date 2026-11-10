import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';

/// What the insights need from one list entry, read off MAL's JSON.
class InsightRow {
  final int id;
  final String title;
  final String? pictureUrl;
  final String status;
  final int score;
  final double? mean;
  final String? mediaType;
  final String? source;
  final List<InsightLabel> genres;
  final List<InsightLabel> studios;
  final List<InsightLabel> authors;

  const InsightRow({
    required this.id,
    required this.title,
    required this.pictureUrl,
    required this.status,
    required this.score,
    required this.mean,
    required this.mediaType,
    required this.source,
    required this.genres,
    required this.studios,
    required this.authors,
  });
}

/// A genre, a studio or an author: the [id] is MAL's, 0 when unknown.
class InsightLabel {
  final int id;
  final String name;
  const InsightLabel(this.id, this.name);
}

/// Sum and count of the scores of one genre, studio, author, media type or source.
class DistributionItem {
  final String name;
  final int id;
  int count = 0;
  int scoreSum = 0;

  DistributionItem(this.name, this.id);

  double get mean => count == 0 ? 0 : scoreSum / count;
}

/// An entry the user rated well above the community.
class AboveMeanEntry {
  final int id;
  final String title;
  final String? pictureUrl;
  final int score;
  final double mean;

  const AboveMeanEntry(this.id, this.title, this.pictureUrl, this.score, this.mean);

  double get gap => score - mean;
}

enum InsightKind { genre, mediaType, source, studio, author }

/// Charts computed from a whole list. Only scored entries count (as DailyAL does); the
/// others are only counted in [unrated].
class UserInsights {
  /// Status keys of the list, in display order.
  final List<String> statuses;

  /// Score (1 to 10) to per-status counts, in the order of [statuses].
  final Map<int, List<int>> scoreByStatus;
  final int unrated;

  /// Per kind, per status key, per item name.
  final Map<InsightKind, Map<String, Map<String, DistributionItem>>> distributions;
  final List<AboveMeanEntry> aboveMean;

  const UserInsights({
    required this.statuses,
    required this.scoreByStatus,
    required this.unrated,
    required this.distributions,
    required this.aboveMean,
  });

  static const int maxAboveMean = 30;

  static List<String> statusesFor(String category) => category == 'manga'
      ? const ['reading', 'completed', 'on_hold', 'dropped', 'plan_to_read']
      : const ['watching', 'completed', 'on_hold', 'dropped', 'plan_to_watch'];

  /// Pure computation over [rows]; call it off the UI isolate with [compute].
  factory UserInsights.fromRows(List<InsightRow> rows, String category) {
    final statuses = statusesFor(category);
    final byScore = <int, List<int>>{
      for (var s = 1; s <= 10; s++) s: List<int>.filled(statuses.length, 0),
    };
    final dist = <InsightKind, Map<String, Map<String, DistributionItem>>>{
      for (final k in InsightKind.values)
        k: {for (final s in statuses) s: <String, DistributionItem>{}},
    };
    final above = <AboveMeanEntry>[];
    final seen = <int>{};
    var unrated = 0;

    void add(InsightKind kind, String status, String name, int id, int score) {
      final item = dist[kind]![status]!
          .putIfAbsent(name, () => DistributionItem(name, id));
      item.count++;
      item.scoreSum += score;
    }

    for (final row in rows) {
      if (row.id != 0 && !seen.add(row.id)) continue;
      final statusIndex = statuses.indexOf(row.status);
      if (statusIndex < 0) continue;
      if (row.score <= 0) {
        unrated++;
        continue;
      }
      final score = row.score.clamp(1, 10);
      byScore[score]![statusIndex]++;

      final mean = row.mean;
      if (mean != null &&
          mean > 0 &&
          mean < 7.05 &&
          row.score > 7 &&
          (row.status == statuses.first || row.status == 'completed')) {
        above.add(AboveMeanEntry(row.id, row.title, row.pictureUrl, row.score, mean));
      }
      for (final g in row.genres) {
        add(InsightKind.genre, row.status, g.name, g.id, row.score);
      }
      for (final s in row.studios) {
        add(InsightKind.studio, row.status, s.name, s.id, row.score);
      }
      for (final a in row.authors) {
        add(InsightKind.author, row.status, a.name, a.id, row.score);
      }
      final media = row.mediaType;
      if (media != null && media.isNotEmpty) {
        add(InsightKind.mediaType, row.status, media, 0, row.score);
      }
      final source = row.source;
      if (source != null && source.isNotEmpty) {
        add(InsightKind.source, row.status, source, 0, row.score);
      }
    }
    above.sort((a, b) => b.gap.compareTo(a.gap));
    return UserInsights(
      statuses: statuses,
      scoreByStatus: byScore,
      unrated: unrated,
      distributions: dist,
      aboveMean: above.length > maxAboveMean ? above.sublist(0, maxAboveMean) : above,
    );
  }

  /// Items of [kind] merged over [status] (`null` = every status), sorted by [byMean] or
  /// by entry count, then by name.
  List<DistributionItem> items(InsightKind kind, {String? status, bool byMean = false}) {
    final merged = <String, DistributionItem>{};
    final perStatus = distributions[kind]!;
    for (final entry in perStatus.entries) {
      if (status != null && entry.key != status) continue;
      for (final item in entry.value.values) {
        final target = merged.putIfAbsent(item.name, () => DistributionItem(item.name, item.id));
        target.count += item.count;
        target.scoreSum += item.scoreSum;
      }
    }
    final list = merged.values.toList();
    list.sort((a, b) {
      final primary = byMean ? b.mean.compareTo(a.mean) : b.count.compareTo(a.count);
      if (primary != 0) return primary;
      final secondary = byMean ? b.count.compareTo(a.count) : b.mean.compareTo(a.mean);
      return secondary != 0 ? secondary : a.name.compareTo(b.name);
    });
    return list;
  }
}

/// Downloads a whole MAL list and turns it into [UserInsights]. Pages are decoded and
/// reduced off the UI isolate.
class UserInsightsLoader {
  UserInsightsLoader._();

  static const int pageSize = 1000;

  static String _fields(String category) => category == 'manga'
      ? 'list_status,mean,genres,media_type,authors{first_name,last_name}'
      : 'list_status,mean,genres,media_type,studios,source';

  /// Throws when the first page cannot be read (private list, network).
  static Future<UserInsights> load(String username, String category) async {
    final rows = <InsightRow>[];
    String? next = '${Constants.maluserBaseEndPoint}/${Uri.encodeComponent(username)}/${category}list'
        '?fields=${_fields(category)}&limit=$pageSize&nsfw=true';
    var first = true;
    var guard = 0;
    while (next != null && guard++ < 50) {
      final response = await MalApi.signedGet(next);
      if (response.statusCode != 200) {
        if (first) throw Exception('List unavailable (${response.statusCode})');
        break;
      }
      first = false;
      final body = response.body;
      final page = await compute(parsePage, body);
      rows.addAll(page.rows);
      next = page.next;
    }
    return compute(_build, _BuildArgs(rows, category));
  }

  static UserInsights _build(_BuildArgs args) => UserInsights.fromRows(args.rows, args.category);

  /// Reads one page of a MAL list (visible for tests).
  @visibleForTesting
  static ({List<InsightRow> rows, String? next}) parsePage(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final rows = <InsightRow>[];
    for (final item in (json['data'] as List? ?? const [])) {
      if (item is! Map) continue;
      final node = item['node'];
      final status = item['list_status'];
      if (node is! Map || status is! Map) continue;
      List<InsightLabel> labels(Object? raw) => [
            for (final e in (raw as List? ?? const []))
              if (e is Map && (e['name'] as String?)?.isNotEmpty == true)
                InsightLabel((e['id'] as num?)?.toInt() ?? 0, e['name'] as String),
          ];
      final authors = <InsightLabel>[];
      for (final a in (node['authors'] as List? ?? const [])) {
        final person = a is Map ? a['node'] : null;
        if (person is! Map) continue;
        final name = '${person['first_name'] ?? ''} ${person['last_name'] ?? ''}'.trim();
        if (name.isNotEmpty) authors.add(InsightLabel((person['id'] as num?)?.toInt() ?? 0, name));
      }
      final picture = node['main_picture'];
      rows.add(InsightRow(
        id: (node['id'] as num?)?.toInt() ?? 0,
        title: node['title'] as String? ?? '',
        pictureUrl: picture is Map
            ? (picture['medium'] ?? picture['large']) as String?
            : null,
        status: status['status'] as String? ?? '',
        score: (status['score'] as num?)?.toInt() ?? 0,
        mean: (node['mean'] as num?)?.toDouble(),
        mediaType: node['media_type'] as String?,
        source: node['source'] as String?,
        genres: labels(node['genres']),
        studios: labels(node['studios']),
        authors: authors,
      ));
    }
    final paging = json['paging'];
    final next = paging is Map ? paging['next'] as String? : null;
    return (rows: rows, next: next);
  }
}

class _BuildArgs {
  final List<InsightRow> rows;
  final String category;
  const _BuildArgs(this.rows, this.category);
}
