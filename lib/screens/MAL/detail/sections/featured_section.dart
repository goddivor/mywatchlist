import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_featured.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/utils/url_formatter.dart';
import 'package:mywatchlist/widgets/MAL/content/show_featured.dart';

/// MAL featured articles about this title. A title known to have none gets
/// no section at all (no title row, no tab), as in DailyAL.
DetailSection? featuredSection(DetailData data) {
  if (!data.hasContent) return null;
  if (FeaturedArticles.isKnownEmpty(data.id, data.category)) return null;
  return DetailSection(
    TabType.Featured_Articles,
    ShowAnimeFeatured(
      animeId: data.id,
      animeName: data.title,
      category: data.category,
    ),
  );
}

/// The featured articles of a title (mwl-api `content/featured`, a MAL page
/// parsed by the backend), loaded once per page and shared by the detail
/// screen (which drops the section when there are none) and the section
/// body. A failed load is forgotten, so Retry asks again.
class FeaturedArticles {
  FeaturedArticles._();

  /// Longest wait for the page.
  static const Duration timeout = Duration(seconds: 20);

  /// The backend call (replaceable in tests).
  static Future<Map<String, dynamic>?> Function(int id, String category, String name)
      fetch = _fetch;

  static final Map<String, Future<AnimeFeaturedResult>> _loads = {};
  static final Set<String> _empty = {};
  static const int _maxEntries = 40;

  static String _key(int id, String category) => '$category:$id';

  static Future<Map<String, dynamic>?> _fetch(int id, String category, String name) =>
      MwlApi.i.getContentFeaturedArticles(id, category, name: name.formatForUrl());

  /// True once a load of this title answered with no article.
  static bool isKnownEmpty(int id, String category) => _empty.contains(_key(id, category));

  /// The articles of the title ([name] is its MAL title, used in the page
  /// URL). [refresh] forgets the previous answer. Throws on a failed page.
  static Future<AnimeFeaturedResult> load(int id, String category, String name,
      {bool refresh = false}) {
    final key = _key(id, category);
    if (refresh) _loads.remove(key);
    final known = _loads[key];
    if (known != null) return known;
    if (_loads.length >= _maxEntries) _loads.remove(_loads.keys.first);
    final future = () async {
      final response = await fetch(id, category, name).timeout(timeout);
      // A null answer is a failed page, not an empty one.
      if (response == null) throw StateError('no featured articles page');
      final result = AnimeFeaturedResult.fromJson(response);
      if (result.featuredArticles.isEmpty) {
        _empty.add(key);
      } else {
        _empty.remove(key);
      }
      return result;
    }();
    _loads[key] = future;
    future.then<void>((_) {}, onError: (Object _) {
      if (identical(_loads[key], future)) _loads.remove(key);
    });
    return future;
  }

  /// Forgets every answer (tests).
  @visibleForTesting
  static void reset() {
    _loads.clear();
    _empty.clear();
    fetch = _fetch;
  }
}
