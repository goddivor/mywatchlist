import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/screens/seasonal/seasonal_data.dart';

void main() {
  const fall = SeasonKey(SeasonType.FALL, 2026);
  const winter = SeasonKey(SeasonType.WINTER, 2026);

  test('a show from an earlier season is continuing', () {
    expect(SeasonalData.isContinuing('2026-07-05', fall), isTrue);
    expect(SeasonalData.isContinuing('2025-10-02', fall), isTrue);
    expect(SeasonalData.isContinuing('2025-12-28', winter), isTrue);
  });

  test('a show of the season is new', () {
    expect(SeasonalData.isContinuing('2026-10-01', fall), isFalse);
    expect(SeasonalData.isContinuing('2026-12-30', fall), isFalse);
    expect(SeasonalData.isContinuing('2026-01-10', winter), isFalse);
  });

  test('missing or partial dates count as new', () {
    expect(SeasonalData.isContinuing(null, fall), isFalse);
    expect(SeasonalData.isContinuing('2026', fall), isFalse);
    expect(SeasonalData.isContinuing('junk', fall), isFalse);
  });

  test('continuingIds is empty before a load', () {
    expect(SeasonalData.continuingIds(const SeasonKey(SeasonType.WINTER, 1990)), isEmpty);
  });
}
