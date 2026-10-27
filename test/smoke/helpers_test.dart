import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/utils/file_extensions.dart';
import 'package:mywatchlist/utils/url_formatter.dart';

void main() {
  group('String.formatForUrl', () {
    test('turns a title into a MAL URL slug', () {
      expect('Re:Zero kara Hajimeru'.formatForUrl(), 'Re_Zero_kara_Hajimeru');
      expect('Fate/stay night'.formatForUrl(), 'Fate_stay_night');
      expect('Dr. Stone'.formatForUrl(), 'Dr_Stone');
    });

    test('keeps hyphens and drops other punctuation', () {
      expect('Spy x Family - Part 2!'.formatForUrl(), 'Spy_x_Family_-_Part_2');
    });

    test('collapses repeated separators', () {
      expect('a :  b'.formatForUrl(), 'a_b');
    });

    test('maps an ellipsis placeholder to a dash', () {
      expect(' ... '.formatForUrl(), '-');
    });
  });

  group('path string helpers', () {
    test('detect image paths case-insensitively', () {
      expect('/tmp/cover.JPG'.isImagePath, isTrue);
      expect('/tmp/cover.webp'.fileExtension, 'webp');
      expect('/tmp/notes.txt'.isImagePath, isFalse);
    });

    test('split a path into name and directory', () {
      expect('/a/b/poster.png'.fileName, 'poster.png');
      expect('/a/b/poster.png'.fileNameWithoutExtension, 'poster');
      expect('/a/b/poster.png'.directory, '/a/b');
    });
  });

  group('constants helpers', () {
    test('nullOrEmpty only accepts non-empty lists', () {
      expect(nullOrEmpty(null), isTrue);
      expect(nullOrEmpty(<int>[]), isTrue);
      expect(nullOrEmpty('text'), isTrue);
      expect(nullOrEmpty([1]), isFalse);
    });

    test('formatText flattens every kind of line break', () {
      expect(formatText('a\nb\r\nc\rd'), 'a b c d');
    });

    test('tryAt returns null out of range instead of throwing', () {
      final list = [10, 20];
      expect(list.tryAt(), 10);
      expect(list.tryAt(1), 20);
      expect(list.tryAt(2), isNull);
      expect(list.tryAt(-1), isNull);
    });

    test('getUserImage builds the MAL CDN avatar URL', () {
      expect(
        getUserImage(42),
        'https://cdn.myanimelist.net/images/userimages/42.jpg',
      );
    });
  });
}
