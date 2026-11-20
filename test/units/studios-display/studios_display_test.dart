import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/studios/studios_screen.dart';

void main() {
  test('the directory logo becomes its 600x600 version, without the small signature', () {
    expect(
      studioLogoLarge('https://cdn.myanimelist.net/s/common/company_logos/'
          'b066ff17-81d3-40db-b1f2-2927de70c0e3_70x70_i?s=f40b4cd7c0563393f09bbb29e4937162'),
      'https://cdn.myanimelist.net/s/common/company_logos/'
      'b066ff17-81d3-40db-b1f2-2927de70c0e3_600x600_i',
    );
  });

  test('another URL is kept, no logo gives nothing', () {
    expect(studioLogoLarge('https://example.org/logo.png'), 'https://example.org/logo.png');
    expect(studioLogoLarge(null), '');
  });
}
