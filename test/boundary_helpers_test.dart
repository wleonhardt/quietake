import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/library/tag_sort.dart';
import 'package:quietake/vault/file_name.dart';

void main() {
  group('checkedFileName', () {
    test('returns ordinary names unchanged', () {
      for (final name in ['a.shtr', 'photo 1.jpg', '..hidden', 'é.mp4']) {
        expect(checkedFileName(name), name);
      }
    });

    test('rejects names that could leave the target directory', () {
      for (final name in [
        '',
        '.',
        '..',
        'a/b',
        '/abs',
        r'a\b',
        'a\u0000b',
        '../x',
      ]) {
        expect(
          () => checkedFileName(name),
          throwsA(isA<FormatException>()),
          reason: 'name: ${name.codeUnits}',
        );
      }
    });
  });

  group('sortedTags', () {
    const albums = {
      '1': 'beach',
      '2': 'Archive',
      '3': 'trip',
      '4': 'Beach days',
    };

    test('sorts by name ignoring case', () {
      expect(sortedTags(albums, '').map((e) => e.key), ['2', '1', '4', '3']);
    });

    test('filters by trimmed case-insensitive substring', () {
      expect(sortedTags(albums, '  BEACH ').map((e) => e.key), ['1', '4']);
      expect(sortedTags(albums, 'zzz'), isEmpty);
    });

    test('omits the excluded tag even when it matches', () {
      expect(sortedTags(albums, 'beach', exclude: '1').map((e) => e.key), [
        '4',
      ]);
    });
  });
}
