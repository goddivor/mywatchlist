import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/explore/random_picker.dart';

void main() {
  test('the dropped list is the same MAL status word for anime and manga', () {
    expect(randomListStatus(RandomSource.dropped, isAnime: true), 'dropped');
    expect(randomListStatus(RandomSource.dropped, isAnime: false), 'dropped');
  });
}
