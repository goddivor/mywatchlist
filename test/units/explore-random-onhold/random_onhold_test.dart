import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/explore/random_picker.dart';

void main() {
  test('the on hold list is the same MAL status word for anime and manga', () {
    expect(randomListStatus(RandomSource.onHold, isAnime: true), 'on_hold');
    expect(randomListStatus(RandomSource.onHold, isAnime: false), 'on_hold');
  });

  test('no source picks from the dropped list', () {
    for (final source in RandomSource.values) {
      expect(randomListStatus(source, isAnime: true), isNot('dropped'));
      expect(randomListStatus(source, isAnime: false), isNot('dropped'));
    }
  });
}
