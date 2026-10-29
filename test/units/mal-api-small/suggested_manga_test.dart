import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/search/search_queries.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';

void main() {
  test('suggested@anime parses, suggested@manga is not a special query', () {
    expect(SpecialQuery.parse('suggested@anime'), isA<SuggestedQuery>());
    expect(SpecialQuery.parse('suggested@manga'), isNull);
  });

  test('manga suggestions answer empty without any request', () async {
    final result = await MalApi.getContentSuggestionsResult(category: 'manga');
    expect(result.data, isEmpty);
  });
}
