import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a backup carries the search history, the recents and the search display', () async {
    SharedPreferences.setMockInitialValues({
      'search_query_history': ['one piece'],
      'search_recent_anime': ['{}'],
      'search_recent_manga': ['{}'],
      'search_display_type': 1,
      'search_display_sub_type': 2,
      'search_grid_axis_count': 3,
      'search_grid_height': 220.0,
      'unrelated_cache': 'x',
    });
    final prefs = await SharedPreferences.getInstance();
    final out = BackupService.collectSettings(prefs);
    expect(out.keys, containsAll([
      'search_query_history',
      'search_recent_anime',
      'search_recent_manga',
      'search_display_type',
      'search_display_sub_type',
      'search_grid_axis_count',
      'search_grid_height',
    ]));
    expect(out.containsKey('unrelated_cache'), isFalse);
  });
}
